import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/habit_icons.dart';
import '../core/locale.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../widgets/goal_progress.dart';
import '../widgets/habit_dialog.dart';
import '../widgets/month_calendar.dart';
import '../widgets/tally_marks.dart';
import '../widgets/ui.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.habit});

  final Habit habit;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  HabitMonth get _key => (habitId: widget.habit.id, month: formatMonth(_month));

  /// Versión más reciente del hábito (cambia al editarlo).
  Habit _latest(List<Habit>? habits) =>
      habits?.where((h) => h.id == widget.habit.id).firstOrNull ?? widget.habit;

  Future<void> _edit() async {
    final result = await showHabitDialog(
      context,
      initial: _latest(ref.read(habitsProvider).value),
    );
    if (result == null) return;
    try {
      await ref
          .read(habitsProvider.notifier)
          .edit(
            widget.habit.id,
            result.name,
            colorToHex(result.color),
            icon: result.icon,
            goal: result.goal,
            activeDays: result.activeDays,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e, context.l10n))));
      }
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _onDayTap(DateTime day, LogStatus? current) async {
    final api = ref.read(apiProvider);
    final date = formatDay(day);
    final habit = _latest(ref.read(habitsProvider).value);
    // Un día inactivo no se puede marcar; si ya tenía marca, solo se quita.
    if (!habit.isActiveOn(day)) {
      if (current == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.inactiveDayHint)));
        return;
      }
      try {
        await api.clearLog(widget.habit.id, date);
        ref.invalidate(logsProvider);
        ref.invalidate(statsProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage(e, context.l10n))),
          );
        }
      }
      return;
    }
    try {
      switch (current) {
        case null:
          await api.setLog(widget.habit.id, date, LogStatus.done);
        case LogStatus.done:
          await api.setLog(widget.habit.id, date, LogStatus.partial);
        case LogStatus.partial:
          await api.clearLog(widget.habit.id, date);
      }
      ref.invalidate(logsProvider);
      ref.invalidate(statsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e, context.l10n))));
      }
    }
  }

  Future<void> _delete() async {
    final name = _latest(ref.read(habitsProvider).value).name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteHabitTitle),
        content: Text(ctx.l10n.deleteHabitBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(habitsProvider.notifier).remove(widget.habit.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e, context.l10n))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = _latest(ref.watch(habitsProvider).value);
    final color = habit.displayColor;
    final theme = Theme.of(context);
    final l = context.l10n;
    final logs = ref.watch(logsProvider(_key));
    final stats = ref.watch(statsProvider(_key));
    final title = toBeginningOfSentenceCase(
      DateFormat.yMMMM(Localizations.localeOf(context).toString())
          .format(_month),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                RoundAction(
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const Spacer(),
                RoundAction(
                  child: IconButton(
                    tooltip: l.editHabit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _edit,
                  ),
                ),
                const SizedBox(width: 10),
                RoundAction(
                  child: IconButton(
                    tooltip: l.deleteHabit,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _delete,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: habitGradient(color),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HabitAvatar(
                          icon: habit.icon,
                          color: color,
                          label: habit.name,
                          radius: 26,
                          inverted: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                habit.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (habit.createdAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    l.habitSince(
                                      _fmtDate(context, habit.createdAt!),
                                    ),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroStat(
                            emoji: '🔥',
                            value: stats.value?.currentStreak,
                            label: l.currentStreak,
                          ),
                        ),
                        Expanded(
                          child: _HeroStat(
                            emoji: '🏆',
                            value: stats.value?.longestStreak,
                            label: l.longestStreak,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              index: 1,
              child: AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: l.previousMonth,
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _shift(-1),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l.nextMonth,
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _shift(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    logs.when(
                      loading: () => const SizedBox(
                        height: 260,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(errorMessage(e, context.l10n)),
                        ),
                      ),
                      data: (list) => MonthCalendar(
                        month: _month,
                        color: color,
                        logs: {for (final x in list) x.date: x.status},
                        onDayTap: _onDayTap,
                        activeDays: habit.activeDays,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 18,
                      children: [
                        _LegendDot(
                          color: color,
                          filled: true,
                          label: l.statusDone,
                        ),
                        _LegendDot(
                          color: color,
                          filled: false,
                          label: l.statusPartial,
                        ),
                        _LegendDot(
                          color: color,
                          filled: false,
                          label: l.todayLabel,
                          ringOnly: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.tapDayHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            stats.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text(errorMessage(e, context.l10n)),
              data: (s) => Column(
                children: [
                  if (s.goal != null) ...[
                    FadeSlideIn(
                      index: 2,
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.goalTitle,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            if (habit.goalStart != null) ...[
                              Text(
                                habit.goalEnd == null
                                    ? l.goalPeriodFrom(
                                        _fmtDay(context, habit.goalStart!),
                                      )
                                    : l.goalPeriodRange(
                                        _fmtDay(context, habit.goalStart!),
                                        _fmtDay(context, habit.goalEnd!),
                                      ),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            GoalProgressBar(
                              goal: s.goal!,
                              color: color,
                              showDaysLeft: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  FadeSlideIn(
                    index: 2,
                    child: _TallyCard(
                      // En meses pasados se muestra el nombre del mes en vez de "Este mes".
                      title: _isCurrentMonth ? l.thisMonth : title,
                      big: '${s.monthDone}',
                      detail: s.monthPartial > 0
                          ? l.partialCount(s.monthPartial)
                          : null,
                      tally: s.monthTally,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    index: 3,
                    child: _TallyCard(
                      title: l.total,
                      big: '${s.totalDone}',
                      tally: s.totalTally,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$emoji ${value ?? '–'}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 30,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.filled,
    required this.label,
    this.ringOnly = false,
  });

  final Color color;
  final bool filled;
  final String label;

  /// Solo un aro (leyenda del día de hoy).
  final bool ringOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringOnly
                ? null
                : (filled ? color : color.withValues(alpha: 0.18)),
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

String _fmtDate(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);

/// Formatea una fecha AAAA-MM-DD del servidor.
String _fmtDay(BuildContext context, String day) {
  final d = DateTime.tryParse(day);
  return d == null ? day : _fmtDate(context, d);
}

class _TallyCard extends StatelessWidget {
  const _TallyCard({
    required this.title,
    required this.big,
    required this.tally,
    required this.color,
    this.detail,
  });

  final String title;
  final String big;
  final String? detail;
  final Tally tally;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  big,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  [l.doneWord(int.tryParse(big) ?? 0), ?detail].join(' · '),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TallyMarks(tally: tally, color: color, height: 32),
          ],
        ),
      ),
    );
  }
}
