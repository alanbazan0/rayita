import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/widgets/goal_progress.dart';
import 'package:calendar_check/widgets/habit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Future<void> _open(
  WidgetTester tester,
  void Function(HabitFormResult?) onResult, {
  Habit? initial,
}) async {
  await tester.pumpWidget(
    testApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              onResult(await showHabitDialog(context, initial: initial)),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('modelos', () {
    test('Habit.fromJson lee la meta', () {
      final h = Habit.fromJson({
        'id': 1,
        'name': 'No fumar',
        'goal_days': 10,
        'goal_start': '2026-11-24',
        'goal_end': null,
        'goal_on_fail': 'accumulate',
      });
      expect(h.hasGoal, isTrue);
      expect(h.goalDays, 10);
      expect(h.goalOnFail, 'accumulate');
      expect(Habit.fromJson({'id': 2, 'name': 'X'}).hasGoal, isFalse);
    });

    test('GoalProgress: fracción acotada y estados', () {
      final g = GoalProgress.fromJson({
        'target': 10,
        'progress': 4,
        'on_fail': 'reset',
        'status': 'active',
        'days_left': 3,
      });
      expect(g.fraction, closeTo(0.4, 1e-9));
      expect(g.achieved, isFalse);
      expect(g.daysLeft, 3);
      const done = GoalProgress(
        target: 5,
        progress: 9,
        onFail: 'reset',
        status: 'achieved',
      );
      expect(done.fraction, 1.0);
      expect(done.achieved, isTrue);
    });
  });

  group('GoalProgressBar', () {
    Future<void> show(
      WidgetTester tester,
      GoalProgress g, {
      bool left = false,
    }) => tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: GoalProgressBar(
            goal: g,
            color: Colors.blue,
            showDaysLeft: left,
          ),
        ),
      ),
    );

    testWidgets('muestra el avance y los días restantes', (tester) async {
      await show(
        tester,
        const GoalProgress(
          target: 10,
          progress: 4,
          onFail: 'reset',
          status: 'active',
          daysLeft: 6,
        ),
        left: true,
      );
      expect(find.text('4 / 10 días'), findsOneWidget);
      expect(find.text('Quedan 6 días'), findsOneWidget);
      expect(find.text('Faltan 6 días'), findsOneWidget);
    });

    testWidgets('meta lograda y no lograda', (tester) async {
      await show(
        tester,
        const GoalProgress(
          target: 3,
          progress: 3,
          onFail: 'reset',
          status: 'achieved',
        ),
      );
      expect(find.text('¡Meta lograda! 🎉'), findsOneWidget);
      expect(find.textContaining('Falta'), findsNothing);
      await show(
        tester,
        const GoalProgress(
          target: 3,
          progress: 1,
          onFail: 'reset',
          status: 'failed',
        ),
      );
      expect(find.text('Meta no lograda'), findsOneWidget);
    });
  });

  group('formulario de meta', () {
    testWidgets('sin activar la meta no se manda ninguna', (tester) async {
      HabitFormResult? result;
      await _open(tester, (r) => result = r);
      await tester.enterText(find.byType(TextField).first, 'Leer');
      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(result!.goal, isNull);
    });

    testWidgets('meta por días con acumular', (tester) async {
      HabitFormResult? result;
      await _open(tester, (r) => result = r);
      await tester.enterText(find.byType(TextField).first, 'No fumar');
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Número de días'),
        '10',
      );
      await tester.ensureVisible(find.text('Acumular'));
      await tester.tap(find.text('Acumular'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(result!.goal!.days, 10);
      expect(result!.goal!.end, isNull);
      expect(result!.goal!.onFail, 'accumulate');
      // Meta nueva: sin inicio, el servidor la hace empezar en la racha actual.
      expect(result!.goal!.start, isNull);
    });

    testWidgets('días inválidos bloquean el guardado y muestran error', (
      tester,
    ) async {
      HabitFormResult? result;
      var closed = false;
      await _open(tester, (r) {
        result = r;
        closed = true;
      });
      await tester.enterText(find.byType(TextField).first, 'X');
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(find.text('Escribe los días (1 a 3650).'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('por fechas sin elegirlas pide las fechas', (tester) async {
      await _open(tester, (_) {});
      await tester.enterText(find.byType(TextField).first, 'X');
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Por fechas'));
      await tester.tap(find.text('Por fechas'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Elige las fechas de inicio y fin.'), findsOneWidget);
    });

    testWidgets('una meta nueva no ofrece "contar desde mi racha"', (
      tester,
    ) async {
      await _open(tester, (_) {});
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        find.text('Contar desde el inicio de mi racha actual'),
        findsNothing,
      );
    });

    testWidgets(
      'al editar una meta por días se puede reiniciar desde la racha',
      (tester) async {
        HabitFormResult? result;
        await _open(
          tester,
          (r) => result = r,
          initial: const Habit(
            id: 1,
            name: 'No fumar',
            goalDays: 10,
            goalStart: '2026-11-24',
            goalOnFail: 'reset',
          ),
        );
        const label = 'Contar desde el inicio de mi racha actual';
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        // Sin inicio: el servidor vuelve a calcularlo desde la racha actual.
        expect(result!.goal!.days, 10);
        expect(result!.goal!.start, isNull);
      },
    );

    testWidgets(
      'al editar precarga la meta, conserva el inicio y se puede quitar',
      (tester) async {
        HabitFormResult? result;
        await _open(
          tester,
          (r) => result = r,
          initial: const Habit(
            id: 1,
            name: 'No fumar',
            goalDays: 10,
            goalStart: '2026-11-01',
            goalOnFail: 'reset',
          ),
        );
        expect(find.text('10'), findsOneWidget);
        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(result!.goal!.days, 10);
        expect(result!.goal!.start, '2026-11-01');

        await _open(
          tester,
          (r) => result = r,
          initial: const Habit(
            id: 1,
            name: 'No fumar',
            goalDays: 10,
            goalStart: '2026-11-01',
          ),
        );
        await tester.ensureVisible(find.byType(Switch));
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(result!.goal, isNull);
      },
    );
  });

  group('días activos', () {
    testWidgets('por defecto todos y se pueden quitar el fin de semana', (
      tester,
    ) async {
      HabitFormResult? result;
      await _open(tester, (r) => result = r);
      await tester.enterText(find.byType(TextField).first, 'Madrugar');
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'S').first);
      // Chips: L M M J V S D -> los dos últimos son sábado y domingo.
      await tester.tap(find.widgetWithText(FilterChip, 'S'));
      await tester.tap(find.widgetWithText(FilterChip, 'D'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(result!.activeDays, [1, 2, 3, 4, 5]);
    });

    testWidgets('sin tocar nada aplica los 7 días', (tester) async {
      HabitFormResult? result;
      await _open(tester, (r) => result = r);
      await tester.enterText(find.byType(TextField).first, 'X');
      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(result!.activeDays, allWeekdays);
    });

    testWidgets('no deja quitar el último día', (tester) async {
      HabitFormResult? result;
      await _open(
        tester,
        (r) => result = r,
        initial: const Habit(id: 1, name: 'X', activeDays: [3]),
      );
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'M').first);
      await tester.tap(
        find.widgetWithText(FilterChip, 'M').at(1),
      ); // el miércoles
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(result!.activeDays, [3]);
    });

    test('Habit: lee active_days y sabe si aplica un día', () {
      final h = Habit.fromJson({
        'id': 1,
        'name': 'X',
        'active_days': [1, 2, 3, 4, 5],
      });
      expect(h.isActiveOn(DateTime(2026, 11, 27)), isTrue); // viernes
      expect(h.isActiveOn(DateTime(2026, 11, 28)), isFalse); // sábado
      expect(Habit.fromJson({'id': 2, 'name': 'Y'}).activeDays, allWeekdays);
    });
  });

  test('Habit: lee la fecha de creación en hora local', () {
    final h = Habit.fromJson({
      'id': 1,
      'name': 'X',
      'created_at': '2026-11-24T18:30:00.000000Z',
    });
    expect(h.createdAt, DateTime.utc(2026, 11, 24, 18, 30).toLocal());
    expect(Habit.fromJson({'id': 2, 'name': 'Y'}).createdAt, isNull);
  });
}
