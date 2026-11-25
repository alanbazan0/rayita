import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de la app: fondo gris azulado, tarjetas blancas y acento índigo.
class AppColors {
  static const bg = Color(0xFFF2F3F8);
  static const ink = Color(0xFF17262A);
  static const muted = Color(0xFF6B7A8F);
  static const primary = Color(0xFF5C5EDD);
  static const primaryLight = Color(0xFF738AE6);
  static const line = Color(0xFFE3E6EF);
}

const primaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.primaryLight, AppColors.primary],
);

/// Degradado a partir del color de un hábito.
LinearGradient habitGradient(Color c) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color.lerp(c, Colors.white, 0.18)!,
    Color.lerp(c, Colors.black, 0.22)!,
  ],
);

List<BoxShadow> softShadow([double alpha = 0.08]) => [
  BoxShadow(
    color: const Color(0xFF3A5160).withValues(alpha: alpha),
    blurRadius: 18,
    offset: const Offset(0, 6),
  ),
];

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    surface: Colors.white,
  ).copyWith(primary: AppColors.primary);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.line),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
