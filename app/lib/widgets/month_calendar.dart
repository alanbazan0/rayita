import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/locale.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Calendario mensual de un hábito. Toca un día para alternar
/// sin marca → cumplido → sin marca. Cumplido = círculo lleno.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.logs,
    required this.color,
    required this.onDayTap,
    this.activeDays = allWeekdays,
  });

  /// Cualquier fecha del mes a mostrar.
  final DateTime month;
  final Map<String, LogStatus> logs;
  final Color color;
  final void Function(DateTime day, LogStatus? current) onDayTap;

  /// Días de la semana (ISO) en que aplica el hábito; los demás se atenúan.
  final List<int> activeDays;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // lunes = 0
    final todayKey = formatDay(DateTime.now());
    final rows = ((leading + daysInMonth) / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (final d in context.l10n.weekdayInitials.split(','))
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _cell(
                    context,
                    r * 7 + c - leading + 1,
                    daysInMonth,
                    todayKey,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    int day,
    int daysInMonth,
    String todayKey,
  ) {
    const cellHeight = 46.0;
    if (day < 1 || day > daysInMonth) return const SizedBox(height: cellHeight);

    final l = context.l10n;
    final date = DateTime(month.year, month.month, day);
    final key = formatDay(date);
    final status = logs[key];
    final isToday = key == todayKey;
    final isFuture = key.compareTo(todayKey) > 0;
    final isActive = activeDays.contains(date.weekday);
    final done = status == LogStatus.done;

    final statusText = done ? l.statusDone : l.statusNone;

    return Semantics(
      button: true,
      label:
          '${DateFormat.MMMMd(Localizations.localeOf(context).toString()).format(date)}: $statusText',
      child: InkResponse(
        radius: 24,
        onTap: isFuture ? null : () => onDayTap(date, status),
        child: SizedBox(
          height: cellHeight,
          child: Center(
            // Aro exterior separado: marca el día de hoy, también si ya está cumplido.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isToday ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : null,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w800,
                    fontSize: 14,
                    color: done
                        ? Colors.white
                        : isFuture || !isActive
                        ? AppColors.muted.withValues(alpha: 0.45)
                        : isToday
                        ? color
                        : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
