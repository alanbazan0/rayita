import 'package:flutter/material.dart';

/// Logo de la app: cuatro rayas y la tachada del quinto (marca de conteo).
/// Dibuja lo mismo que el ícono (tool/make_icon.py), en cualquier tamaño.
class TallyLogo extends StatelessWidget {
  const TallyLogo({
    super.key,
    this.size = 48,
    this.barColor = Colors.white,
    this.slashColor = const Color(0xFFFFD166),
  });

  final double size;
  final Color barColor;
  final Color slashColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _TallyLogoPainter(barColor, slashColor),
      ),
    );
  }
}

class _TallyLogoPainter extends CustomPainter {
  _TallyLogoPainter(this.barColor, this.slashColor);

  final Color barColor;
  final Color slashColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Mismas proporciones que el ícono de 1024 px (rayas en x 344–680, y 292–732).
    final k = size.width / 1024 * 1.45; // se amplía: aquí no hay zona segura
    final cx = size.width / 2;
    final cy = size.height / 2;
    Offset p(double x, double y) =>
        Offset(cx + (x - 512) * k, cy + (y - 512) * k);

    final stroke = 60 * k;
    final bar = Paint()
      ..color = barColor
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    for (final x in const [344.0, 456.0, 568.0, 680.0]) {
      canvas.drawLine(p(x, 292 + 30), p(x, 732 - 30), bar);
    }
    canvas.drawLine(
      p(262, 660),
      p(762, 364),
      Paint()
        ..color = slashColor
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TallyLogoPainter old) =>
      old.barColor != barColor || old.slashColor != slashColor;
}
