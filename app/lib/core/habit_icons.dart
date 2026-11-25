import 'package:flutter/material.dart';

/// Íconos disponibles para un hábito. La clave (texto) es lo que se guarda
/// en la API (`icon`); no se guarda el código del ícono para que cambiar de
/// versión de Flutter no rompa los datos.
const habitIcons = <String, IconData>{
  'fitness_center': Icons.fitness_center,
  'directions_run': Icons.directions_run,
  'self_improvement': Icons.self_improvement,
  'menu_book': Icons.menu_book,
  'school': Icons.school,
  'water_drop': Icons.water_drop,
  'restaurant': Icons.restaurant,
  'bedtime': Icons.bedtime,
  'wb_sunny': Icons.wb_sunny,
  'code': Icons.code,
  'brush': Icons.brush,
  'music_note': Icons.music_note,
  'savings': Icons.savings,
  'cleaning_services': Icons.cleaning_services,
  'smoke_free': Icons.smoke_free,
  'no_drinks': Icons.no_drinks,
  'favorite': Icons.favorite,
  'pets': Icons.pets,
};

/// Ícono para una clave guardada, o null si no hay/no se reconoce.
IconData? habitIconFor(String? key) => key == null ? null : habitIcons[key];

/// Avatar del hábito: círculo de color con el ícono (o la inicial del nombre
/// si no tiene ícono). Con `inverted` se ve claro sobre fondos de color.
class HabitAvatar extends StatelessWidget {
  const HabitAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.radius = 20,
    this.label,
    this.inverted = false,
  });

  final String? icon;
  final Color color;
  final double radius;

  /// Nombre del hábito; su inicial se muestra si no hay ícono.
  final String? label;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final data = habitIconFor(icon);
    final bg = inverted ? Colors.white.withValues(alpha: 0.22) : color;
    Widget? child;
    if (data != null) {
      child = Icon(data, size: radius * 1.05, color: Colors.white);
    } else if (label != null && label!.trim().isNotEmpty) {
      child = Text(
        label!.trim().characters.first.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.95,
        ),
      );
    }
    return CircleAvatar(radius: radius, backgroundColor: bg, child: child);
  }
}
