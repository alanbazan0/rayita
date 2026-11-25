import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/core/view_mode.dart';
import 'package:calendar_check/screens/account_screen.dart';
import 'package:calendar_check/screens/habits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

class _FakeApi extends Api {
  int habitsCalls = 0;
  final List<String> deletedEmails = [];
  int logouts = 0;

  @override
  Future<User?> restoreSession() async => const User(
    id: 1,
    name: 'Ana',
    email: 'ana@example.com',
    emailVerified: true,
  );

  @override
  Future<void> deleteAccount(String email) async => deletedEmails.add(email);

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<List<Habit>> habits() async {
    habitsCalls++;
    return const [
      Habit(id: 1, name: 'Leer', color: '#0EA5E9', icon: 'menu_book'),
      Habit(id: 2, name: 'Meditar', color: '#8B5CF6'),
    ];
  }

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

  Future<_FakeApi> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final api = _FakeApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: testApp(home: const HabitsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return api;
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

  testWidgets('deslizar hacia abajo vuelve a pedir los hábitos', (
    tester,
  ) async {
    final api = await pumpHome(tester);
    final antes = api.habitsCalls;

    await tester.fling(find.byType(ListView), const Offset(0, 500), 1000);
    await tester.pumpAndSettle();

    expect(api.habitsCalls, greaterThan(antes));
  });

  testWidgets('al volver a la app se refresca la lista', (tester) async {
    final api = await pumpHome(tester);
    final antes = api.habitsCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(api.habitsCalls, greaterThan(antes));
  });

  test('ViewModeNotifier ignora valores guardados que no conoce', () async {
    SharedPreferences.setMockInitialValues({'habits_view': 'galaxia'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(viewModeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(viewModeProvider), HabitsView.cards);
  });

  testWidgets('el ícono de Cuenta abre la pantalla de cuenta', (tester) async {
    final api = await pumpHome(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HabitsScreen)),
    );
    await container.read(authProvider.future);

    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('Ana'), findsWidgets);
    expect(api.deletedEmails, isEmpty);
  });
}
