import 'package:calendar_check/core/habit_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  test('habitIconFor resuelve claves conocidas y descarta el resto', () {
    expect(habitIconFor('fitness_center'), Icons.fitness_center);
    expect(habitIconFor('no_existe'), isNull);
    expect(habitIconFor(null), isNull);
  });

  test('las claves del catálogo caben en el límite de la API (50)', () {
    for (final key in habitIcons.keys) {
      expect(key.length, lessThanOrEqualTo(50));
    }
  });

  testWidgets('HabitAvatar muestra ícono o un punto si no hay', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: const Column(
          children: [
            HabitAvatar(icon: 'menu_book', color: Colors.blue),
            HabitAvatar(icon: null, color: Colors.blue),
          ],
        ),
      ),
    );
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNWidgets(2));
  });
}
