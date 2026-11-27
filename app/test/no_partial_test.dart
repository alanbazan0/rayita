import 'dart:convert';
import 'dart:typed_data';

import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/habit_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

/// Un día solo está cumplido o sin marca: el estado "parcial" ya no existe.
const _habit = Habit(id: 1, name: 'Leer', color: '#0EA5E9');

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);

  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _Tokens extends TokenStorage {
  _Tokens() : super();

  @override
  Future<String?> read() async => null;
}

class _Api extends Api {
  final List<String> calls = [];
  late final String doneDay;

  @override
  Future<List<Habit>> habits() async => const [_habit];

  @override
  Future<List<HabitLog>> logs(int habitId, String month) async => [
    HabitLog(habitId: 1, date: doneDay, status: LogStatus.done),
  ];

  @override
  Future<void> setLog(int habitId, String date, LogStatus status) async =>
      calls.add('set $date ${status.name}');

  @override
  Future<void> clearLog(int habitId, String date) async =>
      calls.add('clear $date');

  @override
  Future<HabitStats> stats(int habitId, String month) async =>
      HabitStats.fromJson({
        'current_streak': 0,
        'longest_streak': 0,
        'month': {
          'month': month,
          'done': 1,
          'tally': {'total': 1, 'groups': 0, 'remainder': 1},
        },
        'total': {
          'done': 1,
          'tally': {'total': 1, 'groups': 0, 'remainder': 1},
        },
        'goal': null,
      });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'las marcas parciales antiguas que aún manda un servidor viejo se ignoran',
    () async {
      final api = Api(
        tokens: _Tokens(),
        dio: Dio(BaseOptions(baseUrl: 'http://x'))
          ..httpClientAdapter = _Adapter({
            'data': [
              {'habit_id': 1, 'date': '2026-11-14', 'status': 'partial'},
              {'habit_id': 1, 'date': '2026-11-20', 'status': 'done'},
            ],
          }),
      );

      final logs = await api.logs(1, '2026-11');

      expect(logs, hasLength(1));
      expect(logs.single.date, '2026-11-20');
      expect(logs.single.status, LogStatus.done);
    },
  );

  test('HabitStats ya no depende del campo partial', () {
    final stats = HabitStats.fromJson({
      'current_streak': 1,
      'longest_streak': 1,
      'month': {
        'done': 1,
        'tally': {'total': 1, 'groups': 0, 'remainder': 1},
      },
      'total': {
        'done': 1,
        'tally': {'total': 1, 'groups': 0, 'remainder': 1},
      },
    });
    expect(stats.monthDone, 1);
  });

  Future<_Api> pumpPastMonth(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final prev = DateTime(DateTime.now().year, DateTime.now().month - 1);
    final api = _Api()
      ..doneDay = formatDay(DateTime(prev.year, prev.month, 12));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: testApp(home: const HabitDetailScreen(habit: _habit)),
      ),
    );
    await tester.pumpAndSettle();
    // Un mes pasado: ningún día es futuro.
    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets(
    'el calendario ya no ofrece "parcial" ni en la leyenda ni en el texto',
    (tester) async {
      await pumpPastMonth(tester);
      expect(find.text('parcial'), findsNothing);
      expect(find.textContaining('parcial'), findsNothing);
      expect(find.text('cumplido'), findsOneWidget);
      expect(
        find.text(
          'Toca un día para marcarlo como cumplido, o tócalo de nuevo para quitarlo.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('tocar un día sin marca lo marca como cumplido', (tester) async {
    final api = await pumpPastMonth(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^10 .*sin marca')));
    await tester.pumpAndSettle();

    expect(api.calls, hasLength(1));
    expect(api.calls.single, endsWith('-10 done'));
  });

  testWidgets('tocar un día cumplido le quita la marca (sin paso intermedio)', (
    tester,
  ) async {
    final api = await pumpPastMonth(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^12 .*cumplido')));
    await tester.pumpAndSettle();

    expect(api.calls, hasLength(1));
    expect(api.calls.single, startsWith('clear '));
    expect(api.calls.single, endsWith('-12'));
  });
}
