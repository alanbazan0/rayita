import 'package:flutter/material.dart';

import 'language_button.dart';
import 'welcome_scene.dart';

/// Botón oscuro con la etiqueta a la izquierda y una flecha a la derecha.
class NavyButton extends StatelessWidget {
  const NavyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: WelcomeColors.navy,
        foregroundColor: Colors.white,
        disabledBackgroundColor: WelcomeColors.navy.withValues(alpha: 0.7),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_forward),
        ],
      ),
    );
  }
}

/// "¿Ya tienes cuenta? **Entrar**".
class SwitchLine extends StatelessWidget {
  const SwitchLine({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: WelcomeColors.navy.withValues(alpha: 0.7),
      fontSize: 14,
    );
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text.rich(
            TextSpan(
              text: '$question ',
              style: base,
              children: [
                TextSpan(
                  text: action,
                  style: const TextStyle(
                    color: WelcomeColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector de idioma sin el círculo blanco, para el fondo crema.
class PlainLanguageButton extends StatelessWidget {
  const PlainLanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const IconTheme(
      data: IconThemeData(color: WelcomeColors.navy),
      child: LanguageButton(),
    );
  }
}
