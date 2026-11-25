import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/core/view_mode.dart';
import 'package:calendar_check/screens/habits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

class _FakeApi extends Api {
  @override
  Future<List<Habit>> habits() async => const [
    Habit(id: 1, name: 'Leer', color: '#0EA5E9', icon: 'menu_book'),
    Habit(id: 2, name: 'Meditar', color: '#8B5CF6'),
  ];

  @override
  Future<List<HabitLog>> logs(int habitId, String month) async => [];

  @override
  Future<HabitStats> stats(int habitId, String month) async =>
      HabitStats.fromJson({
        'current_streak': 3,
        'longest_streak': 5,
        'month': {
          'done': 7,
          'partial': 0,
          'tally': {'total': 7, 'groups': 1, 'remainder': 2},
        },
        'total': {
          'done': 7,
          'partial': 0,
          'tally': {'total': 7, 'groups': 1, 'remainder': 2},
        },
        'goal': habitId == 1
            ? {
                'target': 10,
                'progress': 3,
                'on_fail': 'reset',
                'status': 'active',
              }
            : null,
      });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_FakeApi())],
        child: testApp(home: const HabitsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('por defecto se ven tarjetas', (tester) async {
    await pumpHome(tester);
    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('días de racha'), findsWidgets);
  });

  testWidgets('el selector cambia a lista y guarda la preferencia', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.byTooltip('Vista de lista'));
    await tester.pumpAndSettle();

    // En la lista cada fila resume la racha y el avance de la meta en una línea.
    expect(find.text('días de racha'), findsNothing);
    expect(find.textContaining('🔥 3 días'), findsNWidgets(2));
    expect(find.textContaining('3 / 10 días'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('habits_view'),
      'list',
    );

    await tester.tap(find.byTooltip('Vista de tarjetas'));
    await tester.pumpAndSettle();
    expect(find.text('días de racha'), findsWidgets);
    expect(
      (await SharedPreferences.getInstance()).getString('habits_view'),
      'cards',
    );
  });

  testWidgets('recuerda la vista elegida al abrir la app', (tester) async {
    SharedPreferences.setMockInitialValues({'habits_view': 'list'});
    await pumpHome(tester);
    expect(find.text('días de racha'), findsNothing);
    expect(find.textContaining('🔥 3 días'), findsNWidgets(2));
  });

  test('ViewModeNotifier ignora valores guardados que no conoce', () async {
    SharedPreferences.setMockInitialValues({'habits_view': 'galaxia'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(viewModeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(viewModeProvider), HabitsView.cards);
  });
}
