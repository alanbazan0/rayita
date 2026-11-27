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
import '../core/view_mode.dart';
import '../widgets/ad_banner.dart';
import '../widgets/tally_logo.dart';
import '../widgets/habit_dialog.dart';
import '../widgets/language_button.dart';
import '../widgets/tally_marks.dart';
import '../widgets/ui.dart';
import 'account_screen.dart';
import 'habit_detail_screen.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with WidgetsBindingObserver {
  VoidCallback? _stopListeningFocus;
  DateTime? _lastAutoRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // En web, volver a esta ventana (aunque ninguna se haya ocultado) también refresca.
    _stopListeningFocus = ref.read(windowFocusListenerProvider)(_autoRefresh);
  }

  @override
  void dispose() {
    _stopListeningFocus?.call();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver a la app (o a la pestaña del navegador) se recarga lo que se
  /// haya cambiado desde otro dispositivo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoRefresh();
  }

  /// Refresco automático (volver a la app o a la ventana). El foco y la
  /// visibilidad suelen cambiar a la vez: se evita pedir dos veces seguidas.
  void _autoRefresh() {
    final now = DateTime.now();
    final last = _lastAutoRefresh;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }
    _lastAutoRefresh = now;
    _refreshAll();
  }

  void _refreshAll() {
    ref.invalidate(habitsProvider);
    ref.invalidate(logsProvider);
    ref.invalidate(statsProvider);
  }

  /// Deslizar hacia abajo: vuelve a pedir hábitos, marcas y estadísticas.
  Future<void> _onRefresh() async {
    _refreshAll();
    try {
      await ref.read(habitsProvider.future);
    } catch (_) {
      // El error ya se muestra en la pantalla (con su botón de reintentar).
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final view = ref.watch(viewModeProvider);
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
              tooltip: l.account,
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
              ),
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
                    ? RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: LayoutBuilder(
                          builder: (context, c) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: c.maxHeight,
                              child: _EmptyState(text: l.noHabits),
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Resumen y selector de vista quedan fijos: solo se
                          // desplaza la lista de hábitos.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Column(
                              children: [
                                FadeSlideIn(child: _TodaySummary(habits: list)),
                                const SizedBox(height: 16),
                                _SectionTitle(
                                  title: l.todayLabel,
                                  action: l.newHabit,
                                  onAction: () => _addHabit(context, ref),
                                  view: view,
                                  onView: ref
                                      .read(viewModeProvider.notifier)
                                      .set,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _onRefresh,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                // El ícono de cada tarjeta sobresale por arriba: el
                                // margen superior evita que el borde de la lista lo corte.
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  26,
                                  20,
                                  96,
                                ),
                                children: [
                                  if (view == HabitsView.list)
                                    for (var i = 0; i < list.length; i++) ...[
                                      FadeSlideIn(
                                        index: i + 1,
                                        child: _HabitRow(habit: list[i]),
                                      ),
                                      const SizedBox(height: 12),
                                    ]
                                  else if (view == HabitsView.wide)
                                    // Un hábito por renglón, siempre (también en pantallas
                                    // anchas): así los palitos tienen todo el ancho.
                                    for (var i = 0; i < list.length; i++) ...[
                                      FadeSlideIn(
                                        index: i + 1,
                                        child: _HabitWideCard(habit: list[i]),
                                      ),
                                      const SizedBox(height: 14),
                                    ]
                                  else
                                    LayoutBuilder(
                                      builder: (context, c) => _EqualRows(
                                        count: list.length,
                                        cols: (c.maxWidth / 170).floor().clamp(
                                          2,
                                          6,
                                        ),
                                        gap: 14,
                                        rowGap: 24,
                                        builder: (i) => FadeSlideIn(
                                          index: i + 1,
                                          child: _HabitCard(habit: list[i]),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            // Un solo banner discreto, sobre la barra inferior y fuera de la lista.
            const AdBannerSlot(),
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

/// Cuadrícula por filas: cada fila iguala la altura de sus tarjetas, así un nombre
/// de dos líneas o una barra de meta no deja una más alta que su vecina.
class _EqualRows extends StatelessWidget {
  const _EqualRows({
    required this.count,
    required this.cols,
    required this.gap,
    required this.rowGap,
    required this.builder,
  });

  final int count;
  final int cols;
  final double gap;
  final double rowGap;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var start = 0; start < count; start += cols) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) SizedBox(width: gap),
                  Expanded(
                    child: start + j < count
                        ? builder(start + j)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
          if (start + cols < count) SizedBox(height: rowGap),
        ],
      ],
    );
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
    required this.view,
    required this.onView,
  });

  final String title;
  final String action;
  final VoidCallback onAction;
  final HabitsView view;
  final ValueChanged<HabitsView> onView;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // En pantallas angostas el botón de agregar queda solo con ícono.
        final compact = constraints.maxWidth < 400;
        return Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 12),
            _ViewToggle(view: view, onChanged: onView),
            const Spacer(),
            if (compact)
              IconButton(
                tooltip: action,
                onPressed: onAction,
                color: AppColors.primary,
                icon: const Icon(Icons.add_circle_outline),
              )
            else
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
      },
    );
  }
}

/// Un botón por vista (bajas, anchas y lista); el activo va relleno.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final HabitsView view;
  final ValueChanged<HabitsView> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget button(HabitsView v, IconData icon, String tooltip) {
      final selected = v == view;
      return Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softShadow(0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(HabitsView.compact, Icons.view_module_rounded, l.viewCompact),
          button(HabitsView.wide, Icons.view_agenda_rounded, l.viewWide),
          button(HabitsView.list, Icons.view_list_rounded, l.viewList),
        ],
      ),
    );
  }
}

/// Resumen del día en una franja: cumplidos, mejor racha y anillo de progreso.
/// Es compacto a propósito: deja lugar a los hábitos, que son lo importante.
class _TodaySummary extends ConsumerWidget {
  const _TodaySummary({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final month = formatMonth(now);

    var done = 0;
    var best = 0;
    // Solo cuentan los hábitos que aplican hoy.
    final due = habits.where((h) => h.isActiveOn(now)).toList();
    for (final h in due) {
      if (ref.watch(doneTodayProvider(h.id))) done++;
    }
    for (final h in habits) {
      final s = ref.watch(statsProvider((habitId: h.id, month: month))).value;
      if (s != null && s.currentStreak > best) best = s.currentStreak;
    }
    final ratio = due.isEmpty ? 0.0 : done / due.length;
    final l = context.l10n;

    Widget stat(Color accent, String label, String value, String unit) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text.rich(
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 20,
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
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(44),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: softShadow(0.1),
      ),
      child: Row(
        children: [
          Expanded(
            child: stat(
              AppColors.primaryLight,
              l.doneToday,
              '$done',
              '/ ${due.length}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: stat(const Color(0xFFF5A623), l.bestStreak, '$best', '🔥'),
          ),
          const SizedBox(width: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => SizedBox(
              width: 58,
              height: 58,
              child: CustomPaint(
                painter: _RingPainter(value, stroke: 6),
                child: Center(
                  child: Text(
                    '${(value * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
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
  _RingPainter(this.value, {this.stroke = 9.0});

  final double value;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
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
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.stroke != stroke;
}

/// Marca o desmarca hoy como cumplido; avisa si la API falla.
Future<void> toggleHabitToday(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  bool isDone,
) async {
  final api = ref.read(apiProvider);
  final pending = ref.read(pendingTodayProvider.notifier);
  // Un toque a medias aún no termina: se ignora el siguiente para no cruzar peticiones.
  if (ref.read(pendingTodayProvider).containsKey(habit.id)) return;
  final now = DateTime.now();
  final today = formatDay(now);
  // El check cambia al instante; si el servidor falla, vuelve a como estaba.
  pending.set(habit.id, !isDone);
  try {
    if (isDone) {
      await api.clearLog(habit.id, today);
    } else {
      await api.setLog(habit.id, today, LogStatus.done);
    }
    await refreshHabitMarks(ref, habit.id, day: now);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(e, context.l10n))));
    }
  } finally {
    pending.clear(habit.id);
  }
}

const _cardRadius = BorderRadius.only(
  topLeft: Radius.circular(14),
  topRight: Radius.circular(56),
  bottomLeft: Radius.circular(14),
  bottomRight: Radius.circular(14),
);

BoxDecoration _cardDecoration(Color color) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(color, Colors.white, 0.28)!, color],
  ),
  borderRadius: _cardRadius,
  boxShadow: [
    BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ],
);

void _openDetail(BuildContext context, Habit habit) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => HabitDetailScreen(habit: habit)),
  );
}

/// Círculo blanco con el ícono del hábito (o su inicial).
class _HabitBadge extends StatelessWidget {
  const _HabitBadge({required this.habit, this.size = 56});

  final Habit habit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = habit.displayColor;
    final icon = habitIconFor(habit.icon);
    return Container(
      width: size,
      height: size,
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
        child: icon != null
            ? Icon(icon, color: color, size: size * 0.54)
            : Text(
                habit.name.trim().isEmpty
                    ? '•'
                    : habit.name.trim().characters.first.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.43,
                ),
              ),
      ),
    );
  }
}

/// Círculo de "hoy": se rellena al marcar el día y avisa si hoy no toca.
class _CheckButton extends ConsumerWidget {
  const _CheckButton({required this.habit, this.size = 46});

  final Habit habit;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final color = habit.displayColor;
    final activeToday = habit.isActiveOn(DateTime.now());
    final isDone = ref.watch(doneTodayProvider(habit.id));
    final tooltip = !activeToday
        ? l.notToday
        : isDone
        ? l.unmarkToday
        : l.markToday;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: !activeToday
              ? () => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.inactiveDayHint)))
              : () => toggleHabitToday(context, ref, habit, isDone),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? Colors.white
                  : Colors.white.withValues(alpha: activeToday ? 0.22 : 0.1),
              border: Border.all(
                color: Colors.white.withValues(alpha: activeToday ? 1 : 0.4),
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
                      size: size * 0.56,
                    )
                  : !activeToday
                  ? Icon(
                      Icons.remove,
                      key: const ValueKey('rest'),
                      color: Colors.white.withValues(alpha: 0.6),
                    )
                  : const SizedBox.shrink(key: ValueKey('off')),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de hábito con degradado de su color y una esquina grande redondeada.
/// Es baja a propósito (caben los hábitos sin deslizar) y mantiene los palitos.
class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final key = (habitId: habit.id, month: formatMonth(now));
    final stats = ref.watch(statsProvider(key));
    final color = habit.displayColor;
    final l = context.l10n;
    final streak = stats.value?.currentStreak ?? 0;

    final badge = 46.0;
    final pad = 12.0;
    // Misma altura para todas las tarjetas de una cuadrícula, con o sin meta:
    // si no, las filas quedan dispares.
    final progressH = 60.0;

    final card = Container(
      decoration: _cardDecoration(color),
      child: Material(
        color: Colors.transparent,
        borderRadius: _cardRadius,
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
              onTap: () => _openDetail(context, habit),
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hueco del ícono que sobresale.
                    SizedBox(height: 34),
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 6),
                    SizedBox(
                      height: progressH,
                      child: stats.maybeWhen(
                        data: (s) => _CardProgress(stats: s, tallyHeight: 16),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ),
                    // El sobrante de una tarjeta más baja que su vecina va aquí.
                    const Spacer(),
                    SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$streak',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
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
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _CheckButton(habit: habit, size: 38),
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
      fit: StackFit.passthrough,
      children: [
        card,
        Positioned(
          top: -badge * 0.29,
          left: 14,
          child: IgnorePointer(
            child: _HabitBadge(habit: habit, size: badge),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta ancha (una por fila): los palitos van a todo lo ancho y más grandes.
class _HabitWideCard extends ConsumerWidget {
  const _HabitWideCard({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final key = (habitId: habit.id, month: formatMonth(now));
    final stats = ref.watch(statsProvider(key)).value;
    final color = habit.displayColor;
    final l = context.l10n;
    final streak = stats?.currentStreak ?? 0;
    final goal = stats?.goal;

    return Container(
      decoration: _cardDecoration(color),
      child: Material(
        color: Colors.transparent,
        borderRadius: _cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDetail(context, habit),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HabitBadge(habit: habit, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Con letra grande o pantalla angosta la etiqueta se recorta, no desborda.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 84),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$streak',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
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
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CheckButton(habit: habit, size: 44),
                  ],
                ),
                const SizedBox(height: 12),
                if (stats != null)
                  TallyMarks(
                    tally: stats.monthTally,
                    color: Colors.white,
                    emptyColor: Colors.white.withValues(alpha: 0.85),
                    height: 28,
                  ),
                if (goal != null) ...[
                  const SizedBox(height: 10),
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
          ),
        ),
      ),
    );
  }
}

/// Zona media de la tarjeta: marcas de conteo y, si hay meta, su barra de avance.
class _CardProgress extends StatelessWidget {
  const _CardProgress({required this.stats, this.tallyHeight = 22});

  final HabitStats stats;

  /// Alto de los palitos: son lo principal de la tarjeta, no se achican de más.
  final double tallyHeight;

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
            height: tallyHeight,
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

/// Fila de la vista de lista: avatar, nombre, racha, marcas y círculo de hoy.
class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final key = (habitId: habit.id, month: formatMonth(now));
    final stats = ref.watch(statsProvider(key)).value;
    final color = habit.displayColor;
    final l = context.l10n;
    final activeToday = habit.isActiveOn(now);
    final isDone = ref.watch(doneTodayProvider(habit.id));
    final goal = stats?.goal;
    final tooltip = !activeToday
        ? l.notToday
        : isDone
        ? l.unmarkToday
        : l.markToday;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HabitDetailScreen(habit: habit),
        ),
      ),
      child: Row(
        children: [
          HabitAvatar(
            icon: habit.icon,
            color: color,
            label: habit.name,
            radius: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                if (stats != null)
                  Text(
                    [
                      '🔥 ${l.streakDays(stats.currentStreak)}',
                      if (goal != null && !goal.achieved && !goal.failed)
                        l.goalProgress(goal.progress, goal.target),
                      if (goal != null && goal.achieved) l.goalAchieved,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                if (stats != null) ...[
                  const SizedBox(height: 8),
                  TallyMarks(tally: stats.monthTally, color: color, height: 18),
                  if (goal != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: goal.fraction,
                        minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.14),
                        color: goal.failed ? AppColors.muted : color,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: tooltip,
            child: Tooltip(
              message: tooltip,
              child: GestureDetector(
                onTap: !activeToday
                    ? () => ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l.inactiveDayHint)))
                    : () => toggleHabitToday(context, ref, habit, isDone),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? color : Colors.transparent,
                    border: Border.all(
                      color: activeToday ? color : color.withValues(alpha: 0.3),
                      width: 2.5,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isDone
                        ? const Icon(
                            Icons.check,
                            key: ValueKey('on'),
                            color: Colors.white,
                            size: 26,
                          )
                        : !activeToday
                        ? Icon(
                            Icons.remove,
                            key: const ValueKey('rest'),
                            color: color.withValues(alpha: 0.4),
                          )
                        : const SizedBox.shrink(key: ValueKey('off')),
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
