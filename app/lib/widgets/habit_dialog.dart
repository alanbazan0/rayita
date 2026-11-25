import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api.dart' show formatDay;
import '../core/habit_icons.dart';
import '../core/locale.dart';
import '../core/models.dart';

const habitPalette = <Color>[
  Color(0xFF4F46E5),
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFF64748B),
];

typedef HabitFormResult = ({
  String name,
  Color color,
  String? icon,
  GoalForm? goal,
  List<int> activeDays,
});

/// Diálogo para crear (initial == null) o editar un hábito.
/// Devuelve null si se cancela.
Future<HabitFormResult?> showHabitDialog(
  BuildContext context, {
  Habit? initial,
}) {
  return showDialog<HabitFormResult>(
    context: context,
    builder: (_) => HabitDialog(initial: initial),
  );
}

class HabitDialog extends StatefulWidget {
  const HabitDialog({super.key, this.initial});

  final Habit? initial;

  @override
  State<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<HabitDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name,
  );
  late Color _color = widget.initial?.displayColor ?? habitPalette.first;
  late String? _icon =
      widget.initial?.icon; // opcional; tocar el elegido lo quita

  late final Set<int> _weekdays = {
    ...(widget.initial?.activeDays ?? allWeekdays),
  };

  // Meta opcional.
  late bool _goalOn = widget.initial?.hasGoal ?? false;
  late bool _byDates = widget.initial?.goalEnd != null;
  late final TextEditingController _days = TextEditingController(
    text: widget.initial?.goalEnd == null
        ? widget.initial?.goalDays?.toString()
        : null,
  );
  late DateTime? _start = _parseDay(widget.initial?.goalStart);
  late DateTime? _end = _parseDay(widget.initial?.goalEnd);
  late String _onFail = widget.initial?.goalOnFail ?? 'reset';
  String? _goalError;
  bool _restartFromStreak = false;

  static DateTime? _parseDay(String? v) =>
      v == null ? null : DateTime.tryParse(v);

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final goal = _buildGoal();
    if (_goalOn && goal == null) return; // _goalError ya indica qué falta
    Navigator.of(context).pop((
      name: name,
      color: _color,
      icon: _icon,
      goal: goal,
      activeDays: (_weekdays.toList()..sort()),
    ));
  }

  /// Meta del formulario; null si está apagada o es inválida (con mensaje).
  GoalForm? _buildGoal() {
    if (!_goalOn) return null;
    final l = context.l10n;
    String? error;
    GoalForm? goal;
    if (_byDates) {
      if (_start == null || _end == null) {
        error = l.validationGoalDates;
      } else if (_end!.isBefore(_start!)) {
        error = l.validationGoalRange;
      } else {
        goal = GoalForm(
          start: formatDay(_start!),
          end: formatDay(_end!),
          onFail: _onFail,
        );
      }
    } else {
      final n = int.tryParse(_days.text.trim());
      if (n == null || n < 1 || n > 3650) {
        error = l.validationGoalDays;
      } else {
        // Al editar se conserva el inicio original para no perder el avance. Sin
        // inicio (meta nueva, o "contar desde mi racha") el servidor la hace empezar
        // donde empieza la racha actual, para que los días ya cumplidos cuenten.
        final keepStart = widget.initial?.goalEnd == null
            ? widget.initial?.goalStart
            : null;
        goal = GoalForm(
          days: n,
          start: _restartFromStreak ? null : keepStart,
          onFail: _onFail,
        );
      }
    }
    setState(() => _goalError = error);
    return goal;
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final current = (start ? _start : _end) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: context.l10n.pickDate,
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  Widget _dateButton(String label, DateTime? value, bool start) {
    final text = value == null
        ? '—'
        : DateFormat.yMMMd(Localizations.localeOf(context).toString())
              .format(value);
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _pickDate(start: start),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _daysSection(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final initials = l.weekdayInitials.split(',');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.activeDays, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              Semantics(
                button: true,
                selected: _weekdays.contains(d),
                label: DateFormat.EEEE(locale).format(DateTime(2024, 1, d)),
                child: FilterChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  label: Text(initials[d - 1]),
                  selected: _weekdays.contains(d),
                  onSelected: (on) => setState(() {
                    // Siempre debe quedar al menos un día.
                    if (on) {
                      _weekdays.add(d);
                    } else if (_weekdays.length > 1) {
                      _weekdays.remove(d);
                    }
                  }),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(l.activeDaysHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _goalSection(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.goalEnable),
          value: _goalOn,
          onChanged: (v) => setState(() {
            _goalOn = v;
            _goalError = null;
          }),
        ),
        if (_goalOn) ...[
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(l.goalByDays)),
              ButtonSegment(value: true, label: Text(l.goalByDates)),
            ],
            selected: {_byDates},
            onSelectionChanged: (v) => setState(() {
              _byDates = v.first;
              _goalError = null;
            }),
          ),
          const SizedBox(height: 12),
          if (_byDates)
            Row(
              children: [
                _dateButton(l.goalStartLabel, _start, true),
                const SizedBox(width: 8),
                _dateButton(l.goalEndLabel, _end, false),
              ],
            )
          else
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              decoration: InputDecoration(
                labelText: l.goalDaysLabel,
                counterText: '',
              ),
            ),
          if (!_byDates &&
              widget.initial?.goalDays != null &&
              widget.initial?.goalEnd == null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: _restartFromStreak,
              onChanged: (v) => setState(() => _restartFromStreak = v ?? false),
              title: Text(l.goalRestartFromStreak),
            ),
          const SizedBox(height: 12),
          Text(l.goalOnFail, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'reset', label: Text(l.goalReset)),
              ButtonSegment(value: 'accumulate', label: Text(l.goalAccumulate)),
            ],
            selected: {_onFail},
            onSelectionChanged: (v) => setState(() => _onFail = v.first),
          ),
          const SizedBox(height: 6),
          Text(
            _onFail == 'reset' ? l.goalResetHint : l.goalAccumulateHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_goalError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _goalError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(_editing ? context.l10n.editHabit : context.l10n.newHabit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 100,
            decoration: InputDecoration(labelText: context.l10n.habitNameLabel),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in habitPalette)
                Semantics(
                  button: true,
                  selected: c == _color,
                  label: context.l10n.color,
                  child: GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: c,
                      child: c == _color
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.iconOptional,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in habitIcons.entries)
                  Semantics(
                    button: true,
                    selected: entry.key == _icon,
                    label: context.l10n.iconSemantic(entry.key),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(
                        () => _icon = entry.key == _icon ? null : entry.key,
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: entry.key == _icon
                            ? _color
                            : _color.withValues(alpha: 0.12),
                        child: Icon(
                          entry.value,
                          size: 20,
                          color: entry.key == _icon ? Colors.white : _color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _daysSection(context),
          const SizedBox(height: 12),
          Text(
            context.l10n.goalSection,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          _goalSection(context),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_editing ? context.l10n.save : context.l10n.create),
        ),
      ],
    );
  }
}
