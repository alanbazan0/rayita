import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/auth_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

class _FakeApi extends Api {
  _FakeApi({this.requiresCode = false, this.configFails = false});

  final bool requiresCode;
  final bool configFails;
  final List<String?> inviteCodesSent = [];

  @override
  Future<bool> requiresInviteCode() async {
    if (configFails) throw Exception('sin red');
    return requiresCode;
  }

  @override
  Future<User> register(
    String name,
    String email,
    String password,
    String passwordConfirmation, {
    String? inviteCode,
  }) async {
    inviteCodesSent.add(inviteCode);
    if (requiresCode && inviteCode != 'PRUEBAS') {
      throw DioException(
        requestOptions: RequestOptions(path: '/register'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/register'),
          statusCode: 422,
          data: {
            'message': 'x',
            'errors': {
              'invite_code': ['El código de invitación no es válido.'],
            },
          },
        ),
      );
    }
    return User(id: 1, name: name, email: email);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpAuth(WidgetTester tester, {_FakeApi? api}) async {
    // Pantalla alta de teléfono para que todo quede a la vista.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api ?? _FakeApi())],
        child: testApp(home: const AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empieza en la bienvenida, sin formulario', (tester) async {
    await pumpAuth(tester);
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Crear una cuenta'), findsOneWidget);
    expect(
      find.text('¿Ya tienes cuenta? '),
      findsNothing,
    ); // va dentro de un TextSpan
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('"Crear una cuenta" abre el registro con confirmación', (
    tester,
  ) async {
    await pumpAuth(tester);
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    // Nombre, correo, contraseña y confirmación.
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Confirmar contraseña'), findsOneWidget);
  });

  testWidgets('"Entrar" abre el inicio de sesión sin nombre ni confirmación', (
    tester,
  ) async {
    await pumpAuth(tester);
    await tester.tap(find.textContaining('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Confirmar contraseña'), findsNothing);
  });

  testWidgets('la flecha vuelve a la bienvenida', (tester) async {
    await pumpAuth(tester);
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('el formulario valida campos vacíos y contraseñas distintas', (
    tester,
  ) async {
    await pumpAuth(tester);
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Registrarme'));
    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu nombre.'), findsOneWidget);
    expect(find.text('Escribe un correo válido.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'ana@example.com');
    await tester.enterText(fields.at(2), 'secreto123');
    await tester.enterText(fields.at(3), 'otra-cosa');
    await tester.ensureVisible(find.text('Registrarme'));
    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
  });

  group('código de invitación', () {
    Future<void> openRegister(WidgetTester tester) async {
      await tester.tap(find.text('Crear una cuenta'));
      await tester.pumpAndSettle();
    }

    Future<void> fillAndSubmit(WidgetTester tester, {String? code}) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ana');
      await tester.enterText(fields.at(1), 'ana@example.com');
      await tester.enterText(fields.at(2), 'secreto123');
      await tester.enterText(fields.at(3), 'secreto123');
      if (code != null) await tester.enterText(fields.at(4), code);
      await tester.ensureVisible(find.text('Registrarme'));
      await tester.tap(find.text('Registrarme'));
      await tester.pumpAndSettle();
    }

    testWidgets('no se muestra si el servidor no lo exige', (tester) async {
      await pumpAuth(tester);
      await openRegister(tester);
      expect(find.text('Código de invitación'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('se muestra al registrarse si el servidor lo exige', (
      tester,
    ) async {
      await pumpAuth(tester, api: _FakeApi(requiresCode: true));
      await openRegister(tester);
      expect(find.text('Código de invitación'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(5));
    });

    testWidgets('nunca se pide al iniciar sesión', (tester) async {
      await pumpAuth(tester, api: _FakeApi(requiresCode: true));
      await tester.tap(find.textContaining('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Código de invitación'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('vacío no deja registrar y avisa', (tester) async {
      final api = _FakeApi(requiresCode: true);
      await pumpAuth(tester, api: api);
      await openRegister(tester);
      await fillAndSubmit(tester, code: '');
      expect(find.text('Escribe el código de invitación.'), findsOneWidget);
      expect(api.inviteCodesSent, isEmpty);
    });

    testWidgets('envía el código escrito al registrar', (tester) async {
      final api = _FakeApi(requiresCode: true);
      await pumpAuth(tester, api: api);
      await openRegister(tester);
      await fillAndSubmit(tester, code: 'PRUEBAS');
      expect(api.inviteCodesSent, ['PRUEBAS']);
    });

    testWidgets(
      'si no se pudo consultar y el servidor lo pide, aparece el campo',
      (tester) async {
        final api = _FakeApi(requiresCode: true, configFails: true);
        await pumpAuth(tester, api: api);
        await openRegister(tester);
        expect(find.text('Código de invitación'), findsNothing);

        // Se intenta registrar sin código: el servidor lo rechaza.
        await fillAndSubmit(tester);
        expect(
          find.text('El código de invitación no es válido.'),
          findsOneWidget,
        );
        expect(find.text('Código de invitación'), findsOneWidget);
      },
    );
  });
}
