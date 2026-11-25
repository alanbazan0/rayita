import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/widgets/habit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('modo crear: título y botón', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showHabitDialog(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo hábito'), findsOneWidget);
    expect(find.text('Crear'), findsOneWidget);
  });

  testWidgets('modo editar: precarga datos y devuelve los cambios', (
    tester,
  ) async {
    HabitFormResult? result;
    await tester.pumpWidget(
      testApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showHabitDialog(
              context,
              initial: const Habit(
                id: 1,
                name: 'Leer',
                color: '#10B981',
                icon: 'menu_book',
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Editar hábito'), findsOneWidget);
    expect(find.text('Leer'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Leer 20 min');
    await tester.tap(
      find.byIcon(Icons.menu_book),
    ); // lo deselecciona: quita el ícono
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Leer 20 min');
    expect(result!.icon, isNull);
    expect(result!.color, const Color(0xFF10B981));
  });

  testWidgets('no permite guardar un nombre vacío', (tester) async {
    HabitFormResult? result;
    await tester.pumpWidget(
      testApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showHabitDialog(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo hábito'), findsOneWidget); // sigue abierto
    expect(result, isNull);
  });
}
