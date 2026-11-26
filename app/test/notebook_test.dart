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

class _Api extends Api {
  _Api(this.history);

  final List<Map<String, Object?>> history;

  @override
  Future<List<Habit>> habits() async => const [_habit];

  @override
  Future<List<HabitLog>> logs(int habitId, String month) async => [];

  @override
  Future<HabitStats> stats(int habitId, String month) async {
    final total = history.fold<int>(0, (a, m) => a + (m['done']! as int));
    Map<String, Object?> tally(int n) => {
      'total': n,
      'groups': n ~/ 5,
      'remainder': n % 5,
    };
    return HabitStats.fromJson({
      'current_streak': 0,
      'longest_streak': 0,
      'month': {'done': 0, 'partial': 0, 'tally': tally(0)},
      'total': {'done': total, 'partial': 0, 'tally': tally(total)},
      'goal': null,
      'since': null,
      'history': history,
    });
  }
}

Map<String, Object?> _month(DateTime d, int done) => {
  'month': formatMonth(d),
  'done': done,
  'tally': {'total': done, 'groups': done ~/ 5, 'remainder': done % 5},
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    List<Map<String, Object?>> history,
  ) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_Api(history))],
        child: testApp(home: const HabitDetailScreen(habit: _habit)),
      ),
    );
    await tester.pumpAndSettle();
  }

  final now = DateTime.now();
  DateTime ago(int months) => DateTime(now.year, now.month - months);

  testWidgets('sin ninguna marca: el cuaderno muestra el mes en curso vacío', (
    tester,
  ) async {
    await pump(tester, []);
    expect(find.text('CUADERNO'), findsOneWidget);
    expect(find.text('Sin marcas'), findsOneWidget);
    expect(find.byType(TallyMarks), findsOneWidget);
  });

  testWidgets('un mes en curso sin marcas pero con meses anteriores', (
    tester,
  ) async {
    await pump(tester, [_month(ago(1), 12), _month(ago(2), 9)]);
    // Mes en curso (vacío) + 2 anteriores.
    expect(find.byType(TallyMarks), findsNWidgets(3));
    expect(find.text('Sin marcas'), findsOneWidget);
    expect(find.text('Ver todos los meses'), findsNothing);
  });

  testWidgets('con muchos meses se pliega y se puede ver todo', (tester) async {
    await pump(tester, [for (var i = 0; i < 8; i++) _month(ago(i), 33 + i)]);

    expect(find.byType(TallyMarks), findsNWidgets(4));
    expect(find.text('Ver todos los meses'), findsOneWidget);

    await tester.tap(find.text('Ver todos los meses'));
    await tester.pumpAndSettle();
    expect(find.byType(TallyMarks), findsNWidgets(8));
    expect(find.text('Ver menos'), findsOneWidget);

    await tester.tap(find.text('Ver menos'));
    await tester.pumpAndSettle();
    expect(find.byType(TallyMarks), findsNWidgets(4));
  });

  testWidgets('el mes en curso lleva los palitos más grandes', (tester) async {
    await pump(tester, [_month(now, 13), _month(ago(1), 12)]);
    final current = tester.getSize(find.byType(TallyMarks).at(0)).height;
    final previous = tester.getSize(find.byType(TallyMarks).at(1)).height;
    expect(current, greaterThan(previous));
  });

  testWidgets('los meses de otro año llevan el año en la etiqueta', (
    tester,
  ) async {
    await pump(tester, [
      _month(now, 5),
      _month(DateTime(now.year - 1, 12), 40),
    ]);
    final yy = ((now.year - 1) % 100).toString().padLeft(2, '0');
    expect(find.textContaining("'$yy"), findsOneWidget);
  });

  testWidgets(
    'el historial llega en cualquier orden y se muestra del más reciente al más antiguo',
    (tester) async {
      await pump(tester, [
        _month(ago(2), 41),
        _month(now, 35),
        _month(ago(1), 52),
      ]);
      double top(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(top('35'), lessThan(top('52')));
      expect(top('52'), lessThan(top('41')));
    },
  );

  test('un servidor sin historial deja al menos el mes que sí informa', () {
    final stats = HabitStats.fromJson({
      'current_streak': 2,
      'longest_streak': 2,
      'month': {
        'month': '2026-11',
        'done': 3,
        'partial': 0,
        'tally': {'total': 3, 'groups': 0, 'remainder': 3},
      },
      'total': {
        'done': 3,
        'partial': 0,
        'tally': {'total': 3, 'groups': 0, 'remainder': 3},
      },
      'goal': null,
    });
    expect(stats.since, isNull);
    expect(stats.history, hasLength(1));
    expect(stats.history.single.month, '2026-11');
    expect(stats.history.single.done, 3);
  });

  test('lee since e historial cuando el servidor los envía', () {
    final stats = HabitStats.fromJson({
      'current_streak': 3,
      'longest_streak': 3,
      'month': {
        'month': '2026-11',
        'done': 3,
        'partial': 0,
        'tally': {'total': 3, 'groups': 0, 'remainder': 3},
      },
      'total': {
        'done': 3,
        'partial': 0,
        'tally': {'total': 3, 'groups': 0, 'remainder': 3},
      },
      'goal': null,
      'since': '2026-11-23',
      'history': [
        {
          'month': '2026-11',
          'done': 3,
          'tally': {'total': 3, 'groups': 0, 'remainder': 3},
        },
      ],
    });
    expect(stats.since, DateTime(2026, 11, 23));
    expect(stats.history.single.tally.remainder, 3);
  });
}
