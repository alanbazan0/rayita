import 'package:calendar_check/core/ads.dart';
import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

class _Api extends Api {
  _Api(this.user);

  final User user;

  @override
  Future<User?> restoreSession() async => user;

  @override
  Future<List<Habit>> habits() async => const [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, User user) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(_Api(user)),
          adsSupportedProvider.overrideWithValue(false),
        ],
        child: testApp(home: const AccountScreen()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccountScreen)),
    );
    await container.read(authProvider.future);
    await tester.pumpAndSettle();
  }

  const photo = 'https://lh3.googleusercontent.com/a/abc=s96-c';

  testWidgets('con foto de Google intenta mostrarla', (tester) async {
    await pump(
      tester,
      const User(
        id: 1,
        name: 'Ana',
        email: 'ana@example.com',
        emailVerified: true,
        avatarUrl: photo,
      ),
    );
    expect(find.byKey(const ValueKey('avatar-photo')), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('avatar-photo')),
    );
    expect((image.image as NetworkImage).url, photo);
  });

  testWidgets('si la foto no carga (sin red, foto retirada) se ve la inicial', (
    tester,
  ) async {
    await pump(
      tester,
      const User(
        id: 1,
        name: 'Ana',
        email: 'ana@example.com',
        emailVerified: true,
        avatarUrl: photo,
      ),
    );
    // En las pruebas la red está bloqueada: la carga falla y entra el respaldo.
    expect(find.text('A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sin foto (correo y contraseña) se ve la inicial, sin pedir nada',
    (tester) async {
      await pump(
        tester,
        const User(
          id: 1,
          name: 'Ana',
          email: 'ana@example.com',
          emailVerified: true,
        ),
      );
      expect(find.byKey(const ValueKey('avatar-photo')), findsNothing);
      expect(find.byKey(const ValueKey('avatar-initial')), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    },
  );

  test('User.fromJson lee avatar_url y tolera que falte o sea nulo', () {
    final base = {'id': 1, 'name': 'A', 'email': 'a@a.com'};
    expect(User.fromJson(base).avatarUrl, isNull);
    expect(User.fromJson({...base, 'avatar_url': null}).avatarUrl, isNull);
    expect(User.fromJson({...base, 'avatar_url': photo}).avatarUrl, photo);
  });
}
