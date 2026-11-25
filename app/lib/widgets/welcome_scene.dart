import 'package:flutter/material.dart';

/// Colores de la pantalla de bienvenida (crema + azul noche).
class WelcomeColors {
  static const cream = Color(0xFFF6EFE6);
  static const sand = Color(0xFFEBDDC8);
  static const navy = Color(0xFF1B2340);
  static const leaf = Color(0xFF2E7D5B);
  static const leafDark = Color(0xFF1F5F44);
  static const teal = Color(0xFF3FA796);
  static const mustard = Color(0xFFF0B84A);
  static const orange = Color(0xFFE07A3F);
  static const pink = Color(0xFFF2A9A0);
}

/// Ilustración plana: un calendario con días cumplidos, la tarjeta de rayitas
/// y dos plantas. Se dibuja en un lienzo de 320 × 260 y se escala.
class WelcomeScene extends StatelessWidget {
  const WelcomeScene({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 320 / 260,
        child: CustomPaint(painter: _ScenePainter()),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 320, size.height / 260);

    Paint fill(Color c) => Paint()..color = c;
    void shadowRRect(RRect r, {double blur = 14, double dy = 8}) {
      canvas.drawRRect(
        r.shift(Offset(0, dy)),
        Paint()
          ..color = WelcomeColors.navy.withValues(alpha: 0.14)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    // Fondo: mancha arenosa y puntos decorativos.
    canvas.drawOval(
      const Rect.fromLTWH(20, 40, 280, 190),
      fill(WelcomeColors.sand),
    );
    canvas.drawCircle(const Offset(268, 34), 9, fill(WelcomeColors.pink));
    canvas.drawCircle(const Offset(40, 48), 6, fill(WelcomeColors.mustard));
    canvas.drawCircle(const Offset(286, 78), 4, fill(WelcomeColors.teal));

    // Suelo.
    canvas.drawOval(
      const Rect.fromLTWH(30, 224, 260, 16),
      fill(WelcomeColors.navy.withValues(alpha: 0.08)),
    );

    // Plantas (detrás de las tarjetas).
    _plant(canvas, const Offset(62, 226), WelcomeColors.mustard, 1.0, [
      -0.5,
      0.0,
      0.5,
    ]);
    _plant(canvas, const Offset(298, 226), WelcomeColors.orange, 0.85, [
      -0.35,
      0.25,
    ]);

    // Calendario.
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(78, 52, 168, 150),
      const Radius.circular(18),
    );
    shadowRRect(card);
    canvas.drawRRect(card, fill(Colors.white));
    // Cabecera.
    canvas.save();
    canvas.clipRRect(card);
    canvas.drawRect(
      const Rect.fromLTWH(78, 52, 168, 34),
      fill(WelcomeColors.navy),
    );
    canvas.restore();
    for (final x in const [112.0, 212.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 4, 44, 8, 18),
          const Radius.circular(4),
        ),
        fill(WelcomeColors.mustard),
      );
    }
    // Cuadrícula de 7 × 4 días.
    const cols = 7;
    const rows = 4;
    const done = 15;
    for (var i = 0; i < cols * rows; i++) {
      final cx = 96 + (i % cols) * 22.0;
      final cy = 104 + (i ~/ cols) * 22.0;
      if (i < done) {
        canvas.drawCircle(Offset(cx, cy), 8, fill(WelcomeColors.teal));
        final check = Path()
          ..moveTo(cx - 3.2, cy + 0.2)
          ..lineTo(cx - 0.8, cy + 2.8)
          ..lineTo(cx + 3.4, cy - 2.6);
        canvas.drawPath(
          check,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        );
      } else if (i == done) {
        canvas.drawCircle(
          Offset(cx, cy),
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = WelcomeColors.orange,
        );
      } else {
        canvas.drawCircle(Offset(cx, cy), 7, fill(WelcomeColors.cream));
      }
    }

    // Tarjeta de rayitas, superpuesta abajo a la derecha.
    final tally = RRect.fromRectAndRadius(
      const Rect.fromLTWH(196, 150, 92, 70),
      const Radius.circular(16),
    );
    shadowRRect(tally, blur: 10, dy: 6);
    canvas.drawRRect(tally, fill(Colors.white));
    final bar = Paint()
      ..color = WelcomeColors.navy
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final x = 216.0 + i * 15;
      canvas.drawLine(Offset(x, 163), Offset(x, 207), bar);
    }
    canvas.drawLine(
      const Offset(207, 199),
      const Offset(274, 171),
      Paint()
        ..color = WelcomeColors.mustard
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Maceta con hojas que salen en abanico (ángulos en radianes).
  void _plant(
    Canvas canvas,
    Offset base,
    Color pot,
    double k,
    List<double> angles,
  ) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(k);
    final leaf = Paint()..color = WelcomeColors.leaf;
    final leafDark = Paint()..color = WelcomeColors.leafDark;
    for (var i = 0; i < angles.length; i++) {
      canvas.save();
      canvas.translate(0, -26);
      canvas.rotate(angles[i]);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -26), width: 26, height: 56),
        i.isEven ? leaf : leafDark,
      );
      canvas.restore();
    }
    // Maceta trapezoidal.
    final potPath = Path()
      ..moveTo(-20, -28)
      ..lineTo(20, -28)
      ..lineTo(15, 0)
      ..lineTo(-15, 0)
      ..close();
    canvas.drawPath(potPath, Paint()..color = pot);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-23, -32, 46, 8),
        const Radius.circular(3),
      ),
      Paint()..color = Color.lerp(pot, WelcomeColors.navy, 0.15)!,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => false;
}
