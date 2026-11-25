import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/verify_email_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

const _unverified = User(id: 1, name: 'Ana', email: 'ana@example.com');
const _verified = User(
  id: 1,
  name: 'Ana',
  email: 'ana@example.com',
  emailVerified: true,
);

class FakeApi extends Api {
  int resendResult = 0;
  int resendCalls = 0;
  bool loggedOut = false;
  final List<String> attempts = [];

  @override
  Future<User?> restoreSession() async => _unverified;

  @override
  Future<User> verifyEmail(String code) async {
    attempts.add(code);
    if (code != '123456') {
      throw DioException(
        requestOptions: RequestOptions(path: '/email/verify'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/email/verify'),
          statusCode: 422,
          data: {'message': 'El código es incorrecto.', 'code': 'code_invalid'},
        ),
      );
    }
    return _verified;
  }

  @override
  Future<int> resendVerification() async {
    resendCalls++;
    return resendResult;
  }

  @override
  Future<void> logout() async => loggedOut = true;
}

void main() {
  late FakeApi api;
  late ProviderContainer container;

  Future<void> pumpScreen(WidgetTester tester) async {
    // Pantalla alta de teléfono: la ilustración y el formulario no caben en 800x600.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    api = FakeApi();
    container = ProviderContainer(
      overrides: [apiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: testApp(home: const VerifyEmailScreen(user: _unverified)),
      ),
    );
    await tester.pump(const Duration(seconds: 1)); // animación de entrada
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox()); // cancela el temporizador
  }

  test('User.fromJson detecta si el correo está verificado', () {
    expect(
      User.fromJson({
        'id': 1,
        'name': 'A',
        'email': 'a@a.com',
        'email_verified_at': null,
      }).emailVerified,
      isFalse,
    );
    expect(
      User.fromJson({'id': 1, 'name': 'A', 'email': 'a@a.com'}).emailVerified,
      isFalse,
    );
    expect(
      User.fromJson({
        'id': 1,
        'name': 'A',
        'email': 'a@a.com',
        'email_verified_at': '2026-11-24T10:00:00Z',
      }).emailVerified,
      isTrue,
    );
  });

  testWidgets('muestra el correo al que se envió el código', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Verifica tu correo'), findsOneWidget);
    expect(find.textContaining('ana@example.com'), findsOneWidget);
    await disposeScreen(tester);
  });

  testWidgets(
    'un código correcto verifica la sesión (se envía solo al llegar a 6 dígitos)',
    (tester) async {
      await pumpScreen(tester);
      expect(container.read(authProvider).value?.emailVerified, isFalse);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();
      expect(api.attempts, isEmpty);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      expect(api.attempts, ['123456']);
      expect(container.read(authProvider).value?.emailVerified, isTrue);
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'un código incorrecto muestra el error del servidor y limpia el campo',
    (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle();

      expect(find.text('El código es incorrecto.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(container.read(authProvider).value?.emailVerified, isFalse);
      await disposeScreen(tester);
    },
  );

  testWidgets('el botón verificar exige 6 dígitos', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Verificar'));
    await tester.pump();

    expect(find.text('Escribe el código de 6 dígitos.'), findsOneWidget);
    expect(api.attempts, isEmpty);
    await disposeScreen(tester);
  });

  testWidgets('solo acepta dígitos', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '12ab34');

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1234',
    );
    await disposeScreen(tester);
  });

  testWidgets('reenviar muestra aviso y arranca la cuenta atrás de 60 s', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Reenviar código'));
    await tester.pump();
    await tester.pump();

    expect(api.resendCalls, 1);
    expect(find.text('Te enviamos un nuevo código.'), findsOneWidget);
    expect(find.text('Reenviar en 60 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Reenviar en 50 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 50));
    expect(find.text('Reenviar código'), findsOneWidget);
    await disposeScreen(tester);
  });

  testWidgets('si el servidor pide esperar, usa sus segundos', (tester) async {
    await pumpScreen(tester);
    api.resendResult = 42;

    await tester.tap(find.text('Reenviar código'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Reenviar en 42 s'), findsOneWidget);
    expect(find.text('Te enviamos un nuevo código.'), findsNothing);
    await disposeScreen(tester);
  });

  testWidgets('usar otra cuenta cierra la sesión', (tester) async {
    await pumpScreen(tester);

    await tester.ensureVisible(find.text('Usar otra cuenta'));
    await tester.tap(find.text('Usar otra cuenta'));
    await tester.pumpAndSettle();

    expect(api.loggedOut, isTrue);
    expect(container.read(authProvider).value, isNull);
    await disposeScreen(tester);
  });
}
