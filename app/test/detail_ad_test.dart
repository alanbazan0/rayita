import 'package:calendar_check/core/ads.dart';
import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/habit_detail_screen.dart';
import 'package:calendar_check/widgets/ad_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

const _habit = Habit(id: 1, name: 'Leer', color: '#0EA5E9');

class _Api extends Api {
  @override
  Future<List<Habit>> habits() async => const [_habit];

  @override
  Future<List<HabitLog>> logs(int habitId, String month) async => [];

  @override
  Future<HabitStats> stats(int habitId, String month) async =>
      HabitStats.fromJson({
        'current_streak': 0,
        'longest_streak': 0,
        'month': {
          'month': month,
          'done': 0,
          'tally': {'total': 0, 'groups': 0, 'remainder': 0},
        },
        'total': {
          'done': 0,
          'tally': {'total': 0, 'groups': 0, 'remainder': 0},
        },
        'goal': null,
      });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final gaps = <double>[];

  Future<void> pump(WidgetTester tester, {required bool adsOn}) async {
    gaps.clear();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(_Api()),
          adsEnabledProvider.overrideWithValue(adsOn),
          adsPreparerProvider.overrideWithValue(() async => true),
          adBannerBuilderProvider.overrideWithValue((gap) {
            gaps.add(gap);
            return const SizedBox(key: Key('banner'), height: 50);
          }),
        ],
        child: testApp(home: const HabitDetailScreen(habit: _habit)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el detalle del hábito muestra el banner', (tester) async {
    await pump(tester, adsOn: true);
    expect(find.byKey(const Key('banner')), findsOneWidget);
  });

  testWidgets('sin anuncios (web o compra) el detalle no lleva banner', (
    tester,
  ) async {
    await pump(tester, adsOn: false);
    expect(find.byKey(const Key('banner')), findsNothing);
  });

  testWidgets('el banner queda fijo al pie, fuera de la zona que se desplaza', (
    tester,
  ) async {
    await pump(tester, adsOn: true);
    final before = tester.getTopLeft(find.byKey(const Key('banner'))).dy;
    final title = tester.getTopLeft(find.text('Leer')).dy;

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(const Key('banner'))).dy, before);
    expect(
      tester.getTopLeft(find.text('Leer')).dy,
      lessThan(title),
      reason: 'el contenido sí se desplaza',
    );
    // Está debajo de todo el contenido de la lista.
    expect(
      before,
      greaterThan(tester.getBottomLeft(find.byType(ListView)).dy - 1),
    );
  });

  testWidgets(
    'el detalle no deja hueco bajo el banner (no hay botón flotante)',
    (tester) async {
      await pump(tester, adsOn: true);
      expect(gaps, everyElement(0));
    },
  );

  testWidgets(
    'el calendario y los botones de editar y borrar siguen sin tapar el anuncio',
    (tester) async {
      await pump(tester, adsOn: true);
      final banner = tester.getRect(find.byKey(const Key('banner')));
      expect(
        banner.overlaps(tester.getRect(find.byTooltip('Editar hábito'))),
        isFalse,
      );
      expect(
        banner.overlaps(tester.getRect(find.byTooltip('Eliminar hábito'))),
        isFalse,
      );
      expect(
        banner.overlaps(tester.getRect(find.byTooltip('Mes anterior'))),
        isFalse,
      );
    },
  );
}
