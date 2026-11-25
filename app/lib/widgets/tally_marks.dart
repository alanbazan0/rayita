import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/locale.dart';
import '../core/models.dart';

/// Conteo estilo "palitos": grupos de 4 rayas verticales tachadas por una
/// diagonal (el 5.º) y, al final, las rayas sueltas del resto.
/// Si no caben en el ancho disponible, los grupos pasan a la siguiente fila.
class TallyMarks extends StatelessWidget {
  const TallyMarks({
    super.key,
    required this.tally,
    required this.color,
    this.height = 28,
    this.emptyColor,
  });

  final Tally tally;
  final Color color;

  /// Alto de cada fila de palitos.
  final double height;

  /// Color del texto "sin marcas" (por defecto el del tema).
  final Color? emptyColor;

  @override
  Widget build(BuildContext context) {
    if (tally.total == 0) {
      return Text(
        context.l10n.noMarks,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: emptyColor),
      );
    }
    return Semantics(
      label: context.l10n.marksCount(tally.total),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _TallyLayout(tally, height, constraints.maxWidth);
          return CustomPaint(
            size: Size(layout.width, layout.totalHeight),
            painter: _TallyPainter(tally: tally, color: color, layout: layout),
          );
        },
      ),
    );
  }
}

class _TallyLayout {
  _TallyLayout(this.tally, this.rowHeight, double maxWidth) {
    groupW = rowHeight * 0.9;
    step = groupW + rowHeight * 0.35;
    units = tally.groups + (tally.remainder > 0 ? 1 : 0);
    final fit = maxWidth.isFinite
        ? ((maxWidth - groupW) / step).floor() + 1
        : units;
    perRow = math.max(1, math.min(units, fit));
    rows = (units / perRow).ceil();
    width = groupW + (perRow - 1) * step + rowHeight * 0.1;
    totalHeight = rows * rowHeight + (rows - 1) * rowHeight * 0.25;
  }

  final Tally tally;
  final double rowHeight;
  late final double groupW;
  late final double step;
  late final int units;
  late final int perRow;
  late final int rows;
  late final double width;
  late final double totalHeight;
}

class _TallyPainter extends CustomPainter {
  _TallyPainter({
    required this.tally,
    required this.color,
    required this.layout,
  });

  final Tally tally;
  final Color color;
  final _TallyLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final h = layout.rowHeight;
    final groupW = layout.groupW;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = h * 0.09
      ..strokeCap = StrokeCap.round;

    void drawUnit(int index, int bars, {required bool slashed}) {
      final row = index ~/ layout.perRow;
      final col = index % layout.perRow;
      final x0 = col * layout.step + h * 0.05;
      final y0 = row * (h * 1.25);
      final spacing = groupW / 4;
      for (var i = 0; i < bars; i++) {
        final x = x0 + spacing * 0.5 + spacing * i;
        canvas.drawLine(
          Offset(x, y0 + h * 0.08),
          Offset(x, y0 + h * 0.92),
          stroke,
        );
      }
      if (slashed) {
        canvas.drawLine(
          Offset(x0 - groupW * 0.05, y0 + h * 0.78),
          Offset(x0 + groupW * 1.05, y0 + h * 0.22),
          stroke,
        );
      }
    }

    for (var g = 0; g < tally.groups; g++) {
      drawUnit(g, 4, slashed: true);
    }
    if (tally.remainder > 0) {
      drawUnit(tally.groups, tally.remainder, slashed: false);
    }
  }

  @override
  bool shouldRepaint(_TallyPainter old) =>
      old.tally.total != tally.total ||
      old.color != color ||
      old.layout.perRow != layout.perRow;
}
