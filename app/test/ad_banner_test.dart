import 'package:calendar_check/core/ads.dart';
import 'package:calendar_check/widgets/ad_banner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int> pumpSlot(
    WidgetTester tester, {
    required bool enabled,
    required Future<bool> Function() prepare,
  }) async {
    var prepared = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsEnabledProvider.overrideWithValue(enabled),
          adsPreparerProvider.overrideWithValue(() {
            prepared++;
            return prepare();
          }),
          adBannerBuilderProvider.overrideWithValue(
            () => const SizedBox(key: Key('banner'), height: 50),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AdBannerSlot())),
      ),
    );
    await tester.pumpAndSettle();
    return prepared;
  }

  testWidgets('con anuncios activos y consentimiento muestra el banner', (
    tester,
  ) async {
    final prepared = await pumpSlot(
      tester,
      enabled: true,
      prepare: () async => true,
    );
    expect(prepared, 1);
    expect(find.byKey(const Key('banner')), findsOneWidget);
  });

  testWidgets(
    'si no se puede pedir anuncios (sin consentimiento) no muestra nada',
    (tester) async {
      await pumpSlot(tester, enabled: true, prepare: () async => false);
      expect(find.byKey(const Key('banner')), findsNothing);
    },
  );

  testWidgets('con anuncios desactivados (web o compra) ni se prepara el SDK', (
    tester,
  ) async {
    final prepared = await pumpSlot(
      tester,
      enabled: false,
      prepare: () async => true,
    );
    expect(prepared, 0);
    expect(find.byKey(const Key('banner')), findsNothing);
  });

  testWidgets('mientras el SDK se prepara no ocupa espacio', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsEnabledProvider.overrideWithValue(true),
          adsPreparerProvider.overrideWithValue(
            () => Future<bool>.delayed(const Duration(seconds: 5), () => true),
          ),
          adBannerBuilderProvider.overrideWithValue(
            () => const SizedBox(key: Key('banner'), height: 50),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AdBannerSlot())),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('banner')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const Key('banner')), findsOneWidget);
  });

  test('por defecto los anuncios usan el bloque de prueba de Google', () {
    expect(adBannerUnitId, startsWith('ca-app-pub-3940256099942544/'));
  });

  test('los anuncios solo se permiten en Android y nunca en web', () {
    // flutter test simula Android (no es web): ahí sí se admiten anuncios.
    expect(platformSupportsAds, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(platformSupportsAds, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
