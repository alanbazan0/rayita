import 'package:calendar_check/core/ads.dart';
import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/core/view_mode.dart';
import 'package:calendar_check/screens/habits_screen.dart';
import 'package:calendar_check/widgets/tally_marks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

/// Los cuatro hábitos de la maqueta: dos con marcas, uno con meta y dos sin nada.
class _Api extends Api {
  @override
  Future<User?> restoreSession() async => const User(
    id: 1,
    name: 'Ana',
    email: 'ana@example.com',
    emailVerified: true,
  );

  @override
  Future<List<Habit>> habits() async => const [
    Habit(
      id: 1,
      name: 'Abstinencia con un nombre bastante largo',
      color: '#5C60DB',
      icon: 'smoke_free',
    ),
    Habit(id: 2, name: 'No becarias', color: '#E8A93C'),
    Habit(id: 3, name: 'gym', color: '#E0675F'),
    Habit(id: 4, name: 'esfudiar', color: '#D96BA3'),
  ];

  @override
  Future<List<HabitLog>> logs(int habitId, String month) async => [];

  @override
  Future<HabitStats> stats(int habitId, String month) async {
    final total = {1: 3, 2: 13, 3: 0, 4: 0}[habitId]!;
    return HabitStats.fromJson({
      'current_streak': total,
      'longest_streak': total,
      'month': {
        'done': total,
        'partial': 0,
        'tally': {'total': total, 'groups': total ~/ 5, 'remainder': total % 5},
      },
      'total': {
        'done': total,
        'partial': 0,
        'tally': {'total': total, 'groups': total ~/ 5, 'remainder': total % 5},
      },
      'goal': habitId == 1
          ? {
              'target': 10,
              'progress': 1,
              'on_fail': 'reset',
              'status': 'active',
            }
          : null,
    });
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    HabitsView view, {
    Size size = const Size(360, 780),
  }) async {
    SharedPreferences.setMockInitialValues({'habits_view': view.name});
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // Árbol vacío primero: así cada vista arranca de cero y lee su preferencia.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(_Api()),
          adsEnabledProvider.overrideWithValue(false),
          windowFocusListenerProvider.overrideWithValue((_) => () {}),
        ],
        child: testApp(home: const HabitsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final view in HabitsView.values) {
    group('vista ${view.name}', () {
      testWidgets('muestra los cuatro hábitos y los checks, sin desbordar', (
        tester,
      ) async {
        await pump(tester, view);
        expect(tester.takeException(), isNull);
        expect(find.text('No becarias'), findsOneWidget);
        expect(find.text('gym'), findsOneWidget);
        expect(find.text('esfudiar'), findsOneWidget);
        expect(find.byTooltip('Marcar hoy'), findsNWidgets(4));
      });

      testWidgets('también en un teléfono muy angosto (320 dp)', (
        tester,
      ) async {
        await pump(tester, view, size: const Size(320, 640));
        expect(tester.takeException(), isNull);
        expect(find.text('No becarias'), findsOneWidget);
      });

      testWidgets('y en una pantalla ancha (tablet)', (tester) async {
        await pump(tester, view, size: const Size(900, 1100));
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Marcar hoy'), findsNWidgets(4));
      });
    });
  }

  for (final view in [HabitsView.cards, HabitsView.wide, HabitsView.compact]) {
    testWidgets('${view.name}: los palitos siguen siendo lo principal', (
      tester,
    ) async {
      await pump(tester, view);
      // Dos hábitos tienen marcas este mes; los otros dicen "Sin marcas".
      expect(find.byType(TallyMarks), findsNWidgets(4));
      expect(find.text('Sin marcas'), findsNWidgets(2));
    });
  }

  testWidgets('los palitos de la vista ancha son más grandes que en tarjetas', (
    tester,
  ) async {
    await pump(tester, HabitsView.cards);
    final cards = tester.getSize(find.byType(TallyMarks).at(1)).height;
    await pump(tester, HabitsView.wide);
    final wide = tester.getSize(find.byType(TallyMarks).at(1)).height;
    expect(wide, greaterThan(cards));
  });

  testWidgets('los palitos de tarjetas bajas no bajan de un mínimo legible', (
    tester,
  ) async {
    await pump(tester, HabitsView.compact);
    expect(
      tester.getSize(find.byType(TallyMarks).at(1)).height,
      greaterThanOrEqualTo(16),
    );
  });

  Rect cardOf(WidgetTester tester, String name) => tester.getRect(
    find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first,
  );

  testWidgets('tarjetas bajas: los 4 hábitos caben completos sin deslizar', (
    tester,
  ) async {
    await pump(tester, HabitsView.compact);
    // 780 dp de pantalla menos la barra inferior (64 dp).
    expect(cardOf(tester, 'esfudiar').bottom, lessThanOrEqualTo(780 - 64));
  });

  testWidgets('tarjetas y ancha: la primera fila completa se ve sin deslizar', (
    tester,
  ) async {
    for (final view in [HabitsView.cards, HabitsView.wide]) {
      await pump(tester, view);
      expect(
        cardOf(tester, 'No becarias').bottom,
        lessThanOrEqualTo(780 - 64),
        reason: 'vista ${view.name}',
      );
    }
  });

  testWidgets('en cada fila de la cuadrícula las tarjetas miden lo mismo', (
    tester,
  ) async {
    for (final view in [HabitsView.cards, HabitsView.compact]) {
      await pump(tester, view);
      // Fila 1: "Abstinencia" (con meta y nombre largo) junto a "No becarias".
      expect(
        cardOf(tester, 'Abstinencia con un nombre bastante largo').height,
        cardOf(tester, 'No becarias').height,
        reason: 'vista ${view.name}, fila 1',
      );
      // Fila 2: "gym" y "esfudiar".
      expect(
        cardOf(tester, 'gym').height,
        cardOf(tester, 'esfudiar').height,
        reason: 'vista ${view.name}, fila 2',
      );
    }
  });

  testWidgets('tarjetas bajas: las 4 miden igual, con meta o sin ella', (
    tester,
  ) async {
    await pump(tester, HabitsView.compact);
    final heights = {
      for (final n in [
        'Abstinencia con un nombre bastante largo',
        'No becarias',
        'gym',
        'esfudiar',
      ])
        cardOf(tester, n).height,
    };
    expect(heights, hasLength(1));
  });

  testWidgets(
    'el resumen y el selector quedan fijos: solo se desliza la lista',
    (tester) async {
      await pump(tester, HabitsView.cards);
      final summary = tester.getTopLeft(find.text('Cumplidos hoy')).dy;
      final selector = tester.getTopLeft(find.byTooltip('Vista de lista')).dy;
      final card = tester.getTopLeft(find.text('gym')).dy;

      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('Cumplidos hoy')).dy, summary);
      expect(tester.getTopLeft(find.byTooltip('Vista de lista')).dy, selector);
      expect(
        tester.getTopLeft(find.text('gym')).dy,
        lessThan(card),
        reason: 'las tarjetas sí se desplazan',
      );
    },
  );

  testWidgets('deslizar hacia abajo en la lista sigue recargando', (
    tester,
  ) async {
    await pump(tester, HabitsView.cards);
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('el selector tiene las cuatro vistas y recuerda la elegida', (
    tester,
  ) async {
    await pump(tester, HabitsView.cards);
    for (final tip in [
      'Vista de tarjetas',
      'Vista de tarjetas anchas',
      'Vista de tarjetas bajas',
      'Vista de lista',
    ]) {
      expect(find.byTooltip(tip), findsOneWidget, reason: tip);
    }

    await tester.tap(find.byTooltip('Vista de tarjetas anchas'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('habits_view'),
      'wide',
    );

    await tester.tap(find.byTooltip('Vista de tarjetas bajas'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('habits_view'),
      'compact',
    );

    await tester.tap(find.byTooltip('Vista de lista'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('habits_view'),
      'list',
    );
  });

  testWidgets(
    'una preferencia guardada antes de las nuevas vistas sigue valiendo',
    (tester) async {
      await pump(tester, HabitsView.list);
      expect(find.byTooltip('Marcar hoy'), findsNWidgets(4));
      SharedPreferences.setMockInitialValues({'habits_view': 'algo_raro'});
      // Un valor desconocido cae en tarjetas, la vista por defecto.
      await pump(tester, HabitsView.cards);
      expect(tester.takeException(), isNull);
    },
  );
}
