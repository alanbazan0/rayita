import 'package:calendar_check/core/ad_free.dart';
import 'package:calendar_check/core/ads.dart';
import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/account_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

User _user({bool adsRemoved = false}) => User(
  id: 1,
  name: 'Ana',
  email: 'ana@example.com',
  emailVerified: true,
  adsRemoved: adsRemoved,
);

class _FakeApi extends Api {
  _FakeApi({this.adsRemoved = false});

  final bool adsRemoved;
  final List<List<String>> verified = [];

  /// Si no es null, el servidor rechaza la compra con ese estado y mensaje.
  int? rejectStatus;
  String rejectMessage = 'No pudimos confirmar la compra con Google Play.';

  @override
  Future<User?> restoreSession() async => _user(adsRemoved: adsRemoved);

  @override
  Future<List<Habit>> habits() async => const [];

  @override
  Future<User> verifyPurchase(String productId, String purchaseToken) async {
    verified.add([productId, purchaseToken]);
    if (rejectStatus != null) {
      final request = RequestOptions(path: '/purchases/verify');
      throw DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: rejectStatus,
          data: {'message': rejectMessage},
        ),
      );
    }
    return _user(adsRemoved: true);
  }
}

class _FakeStore implements AdFreeStore {
  _FakeStore({
    this.priceText = r'MX$49.00',
    this.result = const PurchaseResult(PurchaseOutcome.purchased, 'tok-1'),
    this.restoreToken,
  });

  final String? priceText;
  PurchaseResult result;
  String? restoreToken;
  int buys = 0;
  int restores = 0;

  @override
  Future<String?> price() async => priceText;

  @override
  Future<PurchaseResult> buy() async {
    buys++;
    return result;
  }

  @override
  Future<String?> restore() async {
    restores++;
    return restoreToken;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pumpAccount(
    WidgetTester tester,
    _FakeStore store, {
    required _FakeApi api,
    bool supported = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          adsSupportedProvider.overrideWithValue(supported),
          adFreeStoreProvider.overrideWithValue(store),
        ],
        child: testApp(home: const AccountScreen()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccountScreen)),
    );
    await container.read(authProvider.future);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('muestra la opción con el precio de la tienda', (tester) async {
    await pumpAccount(tester, _FakeStore(), api: _FakeApi());
    expect(find.text('ANUNCIOS'), findsOneWidget);
    expect(find.text('Quitar anuncios'), findsWidgets);
    expect(find.text(r'MX$49.00'), findsOneWidget);
    expect(find.text('Restaurar compra'), findsOneWidget);
  });

  testWidgets('sin precio (producto no disponible) la opción sigue visible', (
    tester,
  ) async {
    await pumpAccount(tester, _FakeStore(priceText: null), api: _FakeApi());
    expect(find.text('Quitar anuncios'), findsWidgets);
    expect(find.textContaining(r'MX$'), findsNothing);
  });

  testWidgets('en plataformas sin anuncios (web) no aparece', (tester) async {
    await pumpAccount(tester, _FakeStore(), api: _FakeApi(), supported: false);
    expect(find.text('ANUNCIOS'), findsNothing);
    expect(find.text('Restaurar compra'), findsNothing);
  });

  testWidgets('comprar manda el token al servidor y quita los anuncios', (
    tester,
  ) async {
    final api = _FakeApi();
    final store = _FakeStore();
    final container = await pumpAccount(tester, store, api: api);
    expect(container.read(adsRemovedProvider), isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Quitar anuncios'));
    await tester.pumpAndSettle();

    expect(store.buys, 1);
    expect(api.verified, [
      ['remove_ads', 'tok-1'],
    ]);
    expect(container.read(adsRemovedProvider), isTrue);
    expect(find.text('Listo, ya no verás anuncios. ¡Gracias!'), findsOneWidget);
    expect(find.text('Restaurar compra'), findsNothing);
    expect(
      find.text('Los anuncios están desactivados. ¡Gracias por apoyar Rayita!'),
      findsOneWidget,
    );
  });

  testWidgets('si el servidor no confirma la compra, los anuncios siguen', (
    tester,
  ) async {
    final api = _FakeApi()..rejectStatus = 422;
    final container = await pumpAccount(tester, _FakeStore(), api: api);

    await tester.tap(find.widgetWithText(FilledButton, 'Quitar anuncios'));
    await tester.pumpAndSettle();

    expect(api.verified, hasLength(1));
    expect(container.read(adsRemovedProvider), isFalse);
    expect(
      find.text('No pudimos confirmar la compra con Google Play.'),
      findsOneWidget,
    );
    expect(find.text('Restaurar compra'), findsOneWidget);
  });

  testWidgets('con el servidor caído (503) avisa y permite reintentar', (
    tester,
  ) async {
    final api = _FakeApi()
      ..rejectStatus = 503
      ..rejectMessage =
          'No se pudo validar la compra ahora. Inténtalo más tarde.';
    final container = await pumpAccount(tester, _FakeStore(), api: api);

    await tester.tap(find.widgetWithText(FilledButton, 'Quitar anuncios'));
    await tester.pumpAndSettle();

    expect(container.read(adsRemovedProvider), isFalse);
    expect(
      find.text('No se pudo validar la compra ahora. Inténtalo más tarde.'),
      findsOneWidget,
    );
    expect(find.text('Restaurar compra'), findsOneWidget);
  });

  testWidgets('cancelar la compra no llama al servidor ni muestra error', (
    tester,
  ) async {
    final api = _FakeApi();
    final store = _FakeStore(
      result: const PurchaseResult(PurchaseOutcome.cancelled),
    );
    final container = await pumpAccount(tester, store, api: api);
    await tester.tap(find.widgetWithText(FilledButton, 'Quitar anuncios'));
    await tester.pumpAndSettle();

    expect(api.verified, isEmpty);
    expect(container.read(adsRemovedProvider), isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('producto no disponible avisa y deja los anuncios', (
    tester,
  ) async {
    final api = _FakeApi();
    final store = _FakeStore(
      result: const PurchaseResult(PurchaseOutcome.unavailable),
    );
    final container = await pumpAccount(tester, store, api: api);
    await tester.tap(find.widgetWithText(FilledButton, 'Quitar anuncios'));
    await tester.pumpAndSettle();

    expect(api.verified, isEmpty);
    expect(container.read(adsRemovedProvider), isFalse);
    expect(
      find.text('La compra aún no está disponible. Inténtalo más tarde.'),
      findsOneWidget,
    );
  });

  testWidgets('un fallo de la compra muestra el error', (tester) async {
    final api = _FakeApi();
    final store = _FakeStore(
      result: const PurchaseResult(PurchaseOutcome.failed),
    );
    final container = await pumpAccount(tester, store, api: api);
    await tester.tap(find.widgetWithText(FilledButton, 'Quitar anuncios'));
    await tester.pumpAndSettle();

    expect(api.verified, isEmpty);
    expect(container.read(adsRemovedProvider), isFalse);
    expect(find.text('No se pudo completar la compra.'), findsOneWidget);
  });

  testWidgets('restaurar con compra previa la valida y quita los anuncios', (
    tester,
  ) async {
    final api = _FakeApi();
    final store = _FakeStore(restoreToken: 'tok-viejo');
    final container = await pumpAccount(tester, store, api: api);
    await tester.tap(find.text('Restaurar compra'));
    await tester.pumpAndSettle();

    expect(store.restores, 1);
    expect(api.verified, [
      ['remove_ads', 'tok-viejo'],
    ]);
    expect(container.read(adsRemovedProvider), isTrue);
    expect(
      find.text('Compra restaurada. Anuncios desactivados.'),
      findsOneWidget,
    );
  });

  testWidgets('restaurar sin compra previa avisa y no llama al servidor', (
    tester,
  ) async {
    final api = _FakeApi();
    final container = await pumpAccount(tester, _FakeStore(), api: api);
    await tester.tap(find.text('Restaurar compra'));
    await tester.pumpAndSettle();

    expect(api.verified, isEmpty);
    expect(container.read(adsRemovedProvider), isFalse);
    expect(
      find.text('No encontramos una compra para restaurar.'),
      findsOneWidget,
    );
  });

  testWidgets('una cuenta que ya compró entra con los anuncios desactivados', (
    tester,
  ) async {
    final container = await pumpAccount(
      tester,
      _FakeStore(),
      api: _FakeApi(adsRemoved: true),
    );
    expect(container.read(adsRemovedProvider), isTrue);
    expect(find.text('Restaurar compra'), findsNothing);
  });

  test('User.fromJson lee ads_removed (falso si no viene)', () {
    final base = {'id': 1, 'name': 'A', 'email': 'a@a.com'};
    expect(User.fromJson(base).adsRemoved, isFalse);
    expect(User.fromJson({...base, 'ads_removed': true}).adsRemoved, isTrue);
    expect(User.fromJson({...base, 'ads_removed': false}).adsRemoved, isFalse);
  });

  test('quitar anuncios apaga adsEnabled aunque la plataforma los admita', () {
    final api = _FakeApi(adsRemoved: true);
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        adsSupportedProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(adsEnabledProvider), isTrue); // sesión aún sin cargar
    return container.read(authProvider.future).then((_) {
      expect(container.read(adsEnabledProvider), isFalse);
    });
  });
}
