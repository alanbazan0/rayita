import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/habit_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

const _habit = Habit(id: 1, name: 'Leer', color: '#0EA5E9');

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
        'done': 10,
        'partial': 0,
        'tally': {'total': 10, 'groups': 2, 'remainder': 0},
      },
      'goal': null,
    });
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'al ir a un mes pasado pide sus estadísticas y rotula la tarjeta con el mes',
    (tester) async {
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

      final now = DateTime.now();
      expect(find.text('ESTE MES'), findsOneWidget);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      final prev = DateTime(now.year, now.month - 1);
      expect(api.statsMonths.last, formatMonth(prev));
      expect(find.text('ESTE MES'), findsNothing);
      // El nombre del mes aparece en el calendario y como título de la tarjeta.
      expect(find.textContaining('${prev.year}'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('ESTE MES'), findsOneWidget);
    },
  );
}
