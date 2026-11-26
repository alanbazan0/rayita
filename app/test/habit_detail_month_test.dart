import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/habit_detail_screen.dart';
import 'package:calendar_check/widgets/tally_marks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

const _habit = Habit(id: 1, name: 'Leer', color: '#0EA5E9');

final _prevMonth = DateTime(DateTime.now().year, DateTime.now().month - 1);
String _two(int n) => n.toString().padLeft(2, '0');

class _FakeApi extends Api {
  final List<String> statsMonths = [];

  @override
  Future<List<Habit>> habits() async => const [_habit];

  @override
  Future<List<HabitLog>> logs(int habitId, String month) async => [];

  @override
  Future<HabitStats> stats(int habitId, String month) async {
    statsMonths.add(month);
    return HabitStats.fromJson({
      'current_streak': 0,
      'longest_streak': 0,
      'month': {
        'done': 3,
        'partial': 0,
        'tally': {'total': 3, 'groups': 0, 'remainder': 3},
      },
      'total': {
        'done': 58,
        'partial': 0,
        'tally': {'total': 58, 'groups': 11, 'remainder': 3},
      },
      'goal': null,
      'since': '${_prevMonth.year}-${_two(_prevMonth.month)}-10',
      'history': [
        {
          'month': formatMonth(DateTime.now()),
          'done': 3,
          'tally': {'total': 3, 'groups': 0, 'remainder': 3},
        },
        {
          'month': formatMonth(_prevMonth),
          'done': 41,
          'tally': {'total': 41, 'groups': 8, 'remainder': 1},
        },
      ],
    });
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_FakeApi> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final api = _FakeApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: testApp(home: const HabitDetailScreen(habit: _habit)),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets(
    'el cuaderno de rayitas va primero, con el total y una línea por mes',
    (tester) async {
      await pumpDetail(tester);

      expect(find.text('CUADERNO'), findsOneWidget);
      expect(
        find.text('58'),
        findsOneWidget,
      ); // total (no puede ser un día del calendario)
      expect(find.text('3'), findsWidgets); // este mes
      expect(find.text('41'), findsOneWidget); // mes anterior
      expect(find.byType(TallyMarks), findsNWidgets(2));

      // Está arriba del calendario.
      expect(
        tester.getTopLeft(find.text('CUADERNO')).dy,
        lessThan(tester.getTopLeft(find.byTooltip('Mes anterior')).dy),
      );
    },
  );

  testWidgets('"Desde" usa la primera marca si es anterior a la creación', (
    tester,
  ) async {
    await pumpDetail(tester);
    // El hábito de prueba no tiene fecha de creación: toma la primera marca (día 10).
    expect(find.textContaining('Desde el'), findsOneWidget);
    expect(find.textContaining('10'), findsWidgets);
  });

  testWidgets(
    'al ir a un mes pasado pide sus estadísticas y el cuaderno no desaparece',
    (tester) async {
      final api = await pumpDetail(tester);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(api.statsMonths.last, formatMonth(_prevMonth));
      expect(find.text('CUADERNO'), findsOneWidget);
      expect(find.byType(TallyMarks), findsNWidgets(2));

      // Y se puede volver al mes en curso sin perder el cuaderno.
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('CUADERNO'), findsOneWidget);
    },
  );

  testWidgets('tocar un mes del cuaderno lo abre en el calendario', (
    tester,
  ) async {
    final api = await pumpDetail(tester);

    await tester.tap(find.text('41')); // línea del mes anterior
    await tester.pumpAndSettle();

    expect(api.statsMonths.last, formatMonth(_prevMonth));
  });

  test(
    'habitStartDate elige la fecha más antigua entre creación y primera marca',
    () {
      final created = DateTime(2026, 11, 25);
      expect(
        habitStartDate(created, DateTime(2026, 11, 23)),
        DateTime(2026, 11, 23),
      );
      expect(habitStartDate(created, DateTime(2026, 11, 28)), created);
      expect(habitStartDate(created, null), created);
      expect(
        habitStartDate(null, DateTime(2026, 11, 23)),
        DateTime(2026, 11, 23),
      );
      expect(habitStartDate(null, null), isNull);
    },
  );
}
