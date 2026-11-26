import 'dart:async';

import 'package:calendar_check/core/ads.dart';
import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/habits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

/// API de mentira donde el servidor "tarda": las respuestas de setLog/clearLog
/// se liberan a mano, para ver qué muestra la pantalla mientras esperan.
class _SlowApi extends Api {
  final Map<int, Set<String>> done = {1: {}, 2: {}};
  final Map<int, int> logsCalls = {1: 0, 2: 0};
  final Map<int, int> statsCalls = {1: 0, 2: 0};
  Completer<void>? gate;
  Object? failWith;

  @override
  Future<User?> restoreSession() async => const User(
    id: 1,
    name: 'Ana',
    email: 'ana@example.com',
    emailVerified: true,
  );

  @override
  Future<List<Habit>> habits() async => const [
    Habit(id: 1, name: 'Leer', color: '#0EA5E9'),
    Habit(id: 2, name: 'Meditar', color: '#8B5CF6'),
  ];

  @override
  Future<void> setLog(int habitId, String date, LogStatus status) async {
    await gate?.future;
    if (failWith != null) throw failWith!;
    done[habitId]!.add(date);
  }

  @override
  Future<void> clearLog(int habitId, String date) async {
    await gate?.future;
    if (failWith != null) throw failWith!;
    done[habitId]!.remove(date);
  }

  @override
  Future<List<HabitLog>> logs(int habitId, String month) async {
    logsCalls[habitId] = logsCalls[habitId]! + 1;
    return [
      for (final d in done[habitId]!)
        HabitLog(habitId: habitId, date: d, status: LogStatus.done),
    ];
  }

  @override
  Future<HabitStats> stats(int habitId, String month) async {
    statsCalls[habitId] = statsCalls[habitId]! + 1;
    final n = done[habitId]!.length;
    return HabitStats.fromJson({
      'current_streak': n,
      'longest_streak': n,
      'month': {
        'done': n,
        'partial': 0,
        'tally': {'total': n, 'groups': 0, 'remainder': n},
      },
      'total': {
        'done': n,
        'partial': 0,
        'tally': {'total': n, 'groups': 0, 'remainder': n},
      },
      'goal': null,
    });
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_SlowApi> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final api = _SlowApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          adsEnabledProvider.overrideWithValue(false),
          windowFocusListenerProvider.overrideWithValue((_) => () {}),
        ],
        child: testApp(home: const HabitsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  Finder markButton(int index) => find.byTooltip('Marcar hoy').at(index);

  testWidgets('el check responde al instante, sin esperar al servidor', (
    tester,
  ) async {
    final api = await pumpHome(tester);
    api.gate = Completer<void>(); // el servidor aún no contesta

    expect(find.byTooltip('Marcar hoy'), findsNWidgets(2));
    await tester.tap(markButton(0));
    await tester.pump(); // un solo fotograma: nada se ha resuelto todavía

    // Ya se ve cumplido aunque la petición sigue en el aire.
    expect(find.byTooltip('Quitar la marca de hoy'), findsOneWidget);
    expect(find.byTooltip('Marcar hoy'), findsOneWidget);
    expect(api.done[1], isEmpty);

    api.gate!.complete();
    await tester.pumpAndSettle();

    expect(api.done[1], hasLength(1));
    expect(find.byTooltip('Quitar la marca de hoy'), findsOneWidget);
  });

  testWidgets('desmarcar también es instantáneo', (tester) async {
    final api = await pumpHome(tester);
    await tester.tap(markButton(0));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Quitar la marca de hoy'), findsOneWidget);

    api.gate = Completer<void>();
    await tester.tap(find.byTooltip('Quitar la marca de hoy'));
    await tester.pump();

    expect(find.byTooltip('Quitar la marca de hoy'), findsNothing);
    expect(find.byTooltip('Marcar hoy'), findsNWidgets(2));

    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(api.done[1], isEmpty);
  });

  testWidgets('solo recarga el hábito tocado, no todos', (tester) async {
    final api = await pumpHome(tester);
    final logs2 = api.logsCalls[2]!;
    final stats2 = api.statsCalls[2]!;
    final logs1 = api.logsCalls[1]!;
    final stats1 = api.statsCalls[1]!;

    await tester.tap(markButton(0));
    await tester.pumpAndSettle();

    expect(api.logsCalls[1], logs1 + 1);
    expect(api.statsCalls[1], stats1 + 1);
    expect(api.logsCalls[2], logs2, reason: 'el otro hábito no se recarga');
    expect(api.statsCalls[2], stats2, reason: 'el otro hábito no se recarga');
  });

  testWidgets('si el servidor falla, el check vuelve a como estaba y avisa', (
    tester,
  ) async {
    final api = await pumpHome(tester);
    api.gate = Completer<void>();

    await tester.tap(markButton(0));
    await tester.pump();
    expect(
      find.byTooltip('Quitar la marca de hoy'),
      findsOneWidget,
    ); // optimista

    api.failWith = StateError('sin conexión');
    api.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Quitar la marca de hoy'), findsNothing);
    expect(find.byTooltip('Marcar hoy'), findsNWidgets(2));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(api.done[1], isEmpty);
  });

  testWidgets('un segundo toque mientras se guarda no manda otra petición', (
    tester,
  ) async {
    final api = await pumpHome(tester);
    api.gate = Completer<void>();

    await tester.tap(markButton(0));
    await tester.pump();
    await tester.tap(find.byTooltip('Quitar la marca de hoy'));
    await tester.pump();

    api.gate!.complete();
    await tester.pumpAndSettle();

    // Si se hubieran cruzado, el segundo toque habría desmarcado.
    expect(api.done[1], hasLength(1));
    expect(find.byTooltip('Quitar la marca de hoy'), findsOneWidget);
  });

  testWidgets('el resumen del día cuenta el hábito marcado al instante', (
    tester,
  ) async {
    final api = await pumpHome(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HabitsScreen)),
    );
    api.gate = Completer<void>();
    expect(container.read(doneTodayProvider(1)), isFalse);

    await tester.tap(markButton(0));
    await tester.pump();

    expect(container.read(doneTodayProvider(1)), isTrue);
    expect(container.read(doneTodayProvider(2)), isFalse);
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(container.read(doneTodayProvider(1)), isTrue);
  });
}
