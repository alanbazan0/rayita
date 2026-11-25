import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/locale.dart';
import '../core/models.dart';
import '../core/providers.dart';
import 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart'
    as impl;

/// Divisor "o" y botón "Continuar con Google": el botón oficial de Google en
/// web y uno propio con el estilo de marca en Android/iOS.
class GoogleLoginSection extends ConsumerStatefulWidget {
  const GoogleLoginSection({
    super.key,
    required this.config,
    required this.onIdToken,
    required this.onError,
    this.lineColor = const Color(0x331B2340),
    this.textColor = const Color(0xFF1B2340),
  });

  final AppConfig config;
  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error) onError;
  final Color lineColor;
  final Color textColor;

  @override
  ConsumerState<GoogleLoginSection> createState() => _GoogleLoginSectionState();
}

class _GoogleLoginSectionState extends ConsumerState<GoogleLoginSection> {
  bool _busy = false;

  Future<void> _handle(String idToken) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onIdToken(idToken);
    } catch (e) {
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _native() async {
    setState(() => _busy = true);
    try {
      final token = await ref.read(googleAuthProvider).signIn(widget.config);
      if (token == null) return; // canceló
      await widget.onIdToken(token);
    } catch (e) {
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: widget.lineColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l.orDivider,
                style: TextStyle(
                  color: widget.textColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            Expanded(child: Divider(color: widget.lineColor)),
          ],
        ),
        const SizedBox(height: 14),
        if (kIsWeb)
          impl.buildGoogleWebButton(
            clientId: widget.config.googleWebClientId!,
            onIdToken: _handle,
            onError: widget.onError,
          )
        else
          GoogleSignInButton(onPressed: _native, loading: _busy),
      ],
    );
  }
}

/// Botón "Continuar con Google" con el estilo de marca de Google (fondo blanco,
/// texto gris oscuro e ícono "G" multicolor).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          side: const BorderSide(color: Color(0xFFDADCE0)),
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(painter: _GoogleLogoPainter()),
              ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                context.l10n.continueWithGoogle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final stroke = size.width * 0.22;

    void arc(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - stroke / 2),
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }

    arc(-50, 100, const Color(0xFF4285F4));
    arc(50, 80, const Color(0xFF34A853));
    arc(130, 70, const Color(0xFFFBBC05));
    arc(200, 110, const Color(0xFFEA4335));
    // Barra horizontal de la "G".
    canvas.drawRect(
      Rect.fromLTWH(r, r - stroke / 2, r, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
