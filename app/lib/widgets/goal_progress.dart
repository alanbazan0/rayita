import 'package:flutter/material.dart';

import '../core/locale.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Barra de avance de la meta con su texto (avance, lograda o no lograda).
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.goal,
    required this.color,
    this.showDaysLeft = false,
  });

  final GoalProgress goal;
  final Color color;
  final bool showDaysLeft;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = goal.achieved
        ? l.goalAchieved
        : goal.failed
        ? l.goalFailed
        : l.goalProgress(goal.progress, goal.target);
    final open = !goal.achieved && !goal.failed;
    // Días que faltan para llegar al objetivo.
    final remaining = open
        ? l.goalRemaining(goal.target - goal.progress)
        : null;
    // Con fecha final, además, cuántos días de calendario quedan.
    final left = showDaysLeft && open && goal.daysLeft != null
        ? l.goalDaysLeft(goal.daysLeft!)
        : null;
    final muted = const TextStyle(
      color: AppColors.muted,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );
    return Semantics(
      label: [label, ?remaining, ?left].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: goal.failed ? AppColors.muted : color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (remaining != null) Text(remaining, style: muted),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.fraction,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.14),
              color: goal.failed ? AppColors.muted : color,
            ),
          ),
          if (left != null) ...[
            const SizedBox(height: 6),
            Text(left, style: muted),
          ],
        ],
      ),
    );
  }
}
