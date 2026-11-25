import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/habit_icons.dart';
import '../core/locale.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../widgets/tally_logo.dart';
import '../widgets/habit_dialog.dart';
import '../widgets/language_button.dart';
import '../widgets/tally_marks.dart';
import '../widgets/ui.dart';
import 'habit_detail_screen.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final date = toBeginningOfSentenceCase(
      DateFormat.MMMMEEEEd(locale).format(DateTime.now()),
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addHabit(context, ref),
        tooltip: l.newHabit,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const LanguageButton(),
            const SizedBox(width: 56), // hueco del botón +
            IconButton(
              tooltip: l.logout,
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.myHabits,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _DatePill(text: date),
                ],
              ),
            ),
            Expanded(
              child: habits.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errorMessage(e, context.l10n)),
                      TextButton(
                        onPressed: () => ref.invalidate(habitsProvider),
                        child: Text(l.retry),
                      ),
                    ],
                  ),
                ),
                data: (list) => list.isEmpty
                    ? _EmptyState(text: l.noHabits)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                        children: [
                          FadeSlideIn(child: _TodaySummary(habits: list)),
                          const SizedBox(height: 22),
                          _SectionTitle(
                            title: l.todayLabel,
                            action: l.newHabit,
                            onAction: () => _addHabit(context, ref),
                          ),
                          const SizedBox(height: 28),
                          LayoutBuilder(
                            builder: (context, c) {
                              const gap = 14.0;
                              final cols = (c.maxWidth / 190).floor().clamp(
                                2,
                                5,
                              );
                              final w = (c.maxWidth - gap * (cols - 1)) / cols;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap + 16,
                                children: [
                                  for (var i = 0; i < list.length; i++)
                                    FadeSlideIn(
                                      index: i + 1,
                                      child: SizedBox(
                                        width: w,
                                        child: _HabitCard(habit: list[i]),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addHabit(BuildContext context, WidgetRef ref) async {
    final result = await showHabitDialog(context);
    if (result == null) return;
    try {
      await ref
          .read(habitsProvider.notifier)
          .create(
            result.name,
            colorToHex(result.color),
            icon: result.icon,
            goal: result.goal,
            activeDays: result.activeDays,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e, context.l10n))));
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: primaryGradient,
                shape: BoxShape.circle,
                boxShadow: softShadow(0.2),
              ),
              child: const Center(child: TallyLogo(size: 56)),
            ),
            const SizedBox(height: 20),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Píldora con la fecha de hoy.
class _DatePill extends StatelessWidget {
  const _DatePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softShadow(0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: AppColors.muted,
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat.MMMd(Localizations.localeOf(context).toString())
                .format(DateTime.now()),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text(
            action,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Resumen del día: tarjeta blanca con cifras a la izquierda y anillo de progreso.
class _TodaySummary extends ConsumerWidget {
  const _TodaySummary({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = formatDay(now);
    final month = formatMonth(now);

    var done = 0;
    var best = 0;
    // Solo cuentan los hábitos que aplican hoy.
    final due = habits.where((h) => h.isActiveOn(now)).toList();
    for (final h in due) {
      final logs = ref.watch(logsProvider((habitId: h.id, month: month))).value;
      if (logs?.any((x) => x.date == today && x.status == LogStatus.done) ??
          false) {
        done++;
      }
    }
    for (final h in habits) {
      final s = ref.watch(statsProvider((habitId: h.id, month: month))).value;
      if (s != null && s.currentStreak > best) best = s.currentStreak;
    }
    final ratio = due.isEmpty ? 0.0 : done / due.length;
    final l = context.l10n;

    Widget stat(Color accent, String label, String value, String unit) => Row(
      children: [
        Container(
          width: 3,
          height: 44,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(60),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: softShadow(0.1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stat(
                  AppColors.primaryLight,
                  l.doneToday,
                  '$done',
                  '/ ${due.length}',
                ),
                const SizedBox(height: 18),
                stat(const Color(0xFFF5A623), l.bestStreak, '$best', '🔥'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => SizedBox(
              width: 112,
              height: 112,
              child: CustomPaint(
                painter: _RingPainter(value),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(value * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l.todayLabel,
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
            ),
          ),
        ],
      ),
    );
  }
}

/// Anillo con degradado índigo, punta redondeada y un circulito blanco al final.
class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    const twoPi = 2 * math.pi;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final arc = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.primary.withValues(alpha: 0.12),
    );
    if (value <= 0) return;

    // Se gira el lienzo para que el arco empiece arriba (las 12) y el
    // degradado recorra solo el tramo dibujado.
    final sweep = twoPi * value;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 2);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      arc,
      0,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          endAngle: math.max(sweep, 0.05),
          colors: const [AppColors.primary, AppColors.primaryLight],
          transform: const GradientRotation(0),
        ).createShader(arc),
    );

    // Circulito blanco en la punta del arco; con el anillo completo (100 %) sobra.
    if (value < 0.995) {
      final tip = center + Offset(math.cos(sweep), math.sin(sweep)) * radius;
      canvas.drawCircle(
        tip,
        stroke * 0.95,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(tip, stroke * 0.62, Paint()..color = Colors.white);
      canvas.drawCircle(
        tip,
        stroke * 0.62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.primaryLight,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// Tarjeta de hábito con degradado de su color y una esquina grande redondeada.
class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.habit});

  final Habit habit;

  Future<void> _toggleToday(
    BuildContext context,
    WidgetRef ref,
    bool isDone,
  ) async {
    final api = ref.read(apiProvider);
    final today = formatDay(DateTime.now());
    try {
      if (isDone) {
        await api.clearLog(habit.id, today);
      } else {
        await api.setLog(habit.id, today, LogStatus.done);
      }
      ref.invalidate(logsProvider);
      ref.invalidate(statsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e, context.l10n))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final key = (habitId: habit.id, month: formatMonth(now));
    final stats = ref.watch(statsProvider(key));
    final logs = ref.watch(logsProvider(key));
    final color = habit.displayColor;
    final l = context.l10n;
    final today = formatDay(now);
    final activeToday = habit.isActiveOn(now);
    final isDone =
        logs.value?.any((x) => x.date == today && x.status == LogStatus.done) ??
        false;
    final streak = stats.value?.currentStreak ?? 0;

    const radius = BorderRadius.only(
      topLeft: Radius.circular(14),
      topRight: Radius.circular(56),
      bottomLeft: Radius.circular(14),
      bottomRight: Radius.circular(14),
    );

    final tooltip = !activeToday
        ? l.notToday
        : isDone
        ? l.unmarkToday
        : l.markToday;

    final card = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.28)!, color],
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Círculo translúcido detrás del ícono, recortado por la tarjeta.
            Positioned(
              left: -18,
              top: -56,
              child: IgnorePointer(
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HabitDetailScreen(habit: habit),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 46), // hueco del ícono que sobresale
                    Text(
                      habit.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: stats.maybeWhen(
                        data: (s) => _CardProgress(stats: s),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 34,
                                  height: 1,
                                ),
                              ),
                              Text(
                                l.streakLabel(streak),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: tooltip,
                          child: Tooltip(
                            message: tooltip,
                            child: GestureDetector(
                              onTap: !activeToday
                                  ? () => ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                          SnackBar(
                                            content: Text(l.inactiveDayHint),
                                          ),
                                        )
                                  : () => _toggleToday(context, ref, isDone),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDone
                                      ? Colors.white
                                      : Colors.white.withValues(
                                          alpha: activeToday ? 0.22 : 0.1,
                                        ),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: activeToday ? 1 : 0.4,
                                    ),
                                    width: 2.5,
                                  ),
                                  boxShadow: isDone ? softShadow(0.25) : null,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: isDone
                                      ? Icon(
                                          Icons.check,
                                          key: const ValueKey('on'),
                                          color: color,
                                          size: 26,
                                        )
                                      : !activeToday
                                      ? Icon(
                                          Icons.remove,
                                          key: const ValueKey('rest'),
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                        )
                                      : const SizedBox.shrink(
                                          key: ValueKey('off'),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // El ícono sobresale un poco por arriba de la tarjeta (como en la referencia).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -16,
          left: 14,
          child: IgnorePointer(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: habitIconFor(habit.icon) != null
                    ? Icon(habitIconFor(habit.icon), color: color, size: 30)
                    : Text(
                        habit.name.trim().isEmpty
                            ? '•'
                            : habit.name.trim().characters.first.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Zona media de la tarjeta: marcas de conteo y, si hay meta, su barra de avance.
class _CardProgress extends StatelessWidget {
  const _CardProgress({required this.stats});

  final HabitStats stats;

  @override
  Widget build(BuildContext context) {
    final goal = stats.goal;
    final l = context.l10n;
    return OverflowBox(
      alignment: Alignment.bottomLeft,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TallyMarks(
            tally: stats.monthTally,
            color: Colors.white,
            emptyColor: Colors.white.withValues(alpha: 0.85),
            height: 22,
          ),
          if (goal != null) ...[
            const SizedBox(height: 8),
            Text(
              goal.achieved
                  ? l.goalAchieved
                  : goal.failed
                  ? l.goalFailed
                  : l.goalProgress(goal.progress, goal.target),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: goal.fraction,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.28),
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
