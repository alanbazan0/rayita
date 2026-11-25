import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/google_auth.dart';
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
  _FakeApi({
    this.requiresCode = false,
    this.configFails = false,
    this.googleEnabled = false,
    this.googleNeedsInvite = false,
  });

  final bool requiresCode;
  final bool configFails;
  final bool googleEnabled;

  /// Simula una cuenta nueva con servidor que exige invitación (código PRUEBAS).
  final bool googleNeedsInvite;
  final List<String?> inviteCodesSent = [];
  final List<({String token, String? code})> googleCalls = [];

  @override
  Future<User?> restoreSession() async => null;

  @override
  Future<AppConfig> fetchConfig() async {
    if (configFails) throw Exception('sin red');
    return AppConfig(
      requiresInviteCode: requiresCode,
      googleWebClientId: googleEnabled
          ? 'web.apps.googleusercontent.com'
          : null,
    );
  }

  @override
  Future<User> googleLogin(String idToken, {String? inviteCode}) async {
    googleCalls.add((token: idToken, code: inviteCode));
    if (googleNeedsInvite && inviteCode != 'PRUEBAS') {
      throw DioException(
        requestOptions: RequestOptions(path: '/google'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/google'),
          statusCode: 422,
          data: {
            'message': 'x',
            'errors': {
              'invite_code': [
                inviteCode == null
                    ? 'El código de invitación es obligatorio.'
                    : 'El código de invitación no es válido.',
              ],
            },
          },
        ),
      );
    }
    return const User(
      id: 1,
      name: 'Ana',
      email: 'ana@example.com',
      emailVerified: true,
    );
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

class _FakeGoogle extends GoogleAuthService {
  _FakeGoogle(this.token);

  final String? token;
  int calls = 0;

  @override
  Future<String?> signIn(AppConfig config) async {
    calls++;
    return token;
  }

  @override
  Future<void> signOut() async {}
}

/// Avanza unos fotogramas: con el diálogo abierto el spinner del botón sigue
/// animando, así que pumpAndSettle no termina.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpAuth(
    WidgetTester tester, {
    _FakeApi? api,
    _FakeGoogle? google,
  }) async {
    // Pantalla alta de teléfono para que todo quede a la vista.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api ?? _FakeApi()),
          googleAuthProvider.overrideWithValue(google ?? _FakeGoogle('tok')),
        ],
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

  group('Google', () {
    testWidgets('no se muestra si el servidor no lo tiene configurado', (
      tester,
    ) async {
      await pumpAuth(tester);
      expect(find.text('Continuar con Google'), findsNothing);
    });

    testWidgets(
      'se muestra en la bienvenida y en el formulario si está configurado',
      (tester) async {
        await pumpAuth(tester, api: _FakeApi(googleEnabled: true));
        expect(find.text('Continuar con Google'), findsOneWidget);

        await tester.tap(find.text('Crear una cuenta'));
        await tester.pumpAndSettle();
        expect(find.text('Continuar con Google'), findsOneWidget);
      },
    );

    testWidgets('al tocarlo envía el ID token a la API', (tester) async {
      final api = _FakeApi(googleEnabled: true);
      final google = _FakeGoogle('id-token-123');
      await pumpAuth(tester, api: api, google: google);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(google.calls, 1);
      expect(api.googleCalls, [(token: 'id-token-123', code: null)]);
    });

    testWidgets('si la persona cancela no se llama a la API', (tester) async {
      final api = _FakeApi(googleEnabled: true);
      await pumpAuth(tester, api: api, google: _FakeGoogle(null));

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(api.googleCalls, isEmpty);
    });

    testWidgets(
      'cuenta nueva con invitación: pide el código y reintenta con el mismo token',
      (tester) async {
        final api = _FakeApi(googleEnabled: true, googleNeedsInvite: true);
        await pumpAuth(tester, api: api, google: _FakeGoogle('tok-1'));

        await tester.tap(find.text('Continuar con Google'));
        await _frames(tester);
        expect(
          find.text(
            'Para crear tu cuenta con Google necesitas un código de invitación.',
          ),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField), 'PRUEBAS');
        await tester.tap(find.text('Continuar'));
        await _frames(tester);

        expect(api.googleCalls, [
          (token: 'tok-1', code: null),
          (token: 'tok-1', code: 'PRUEBAS'),
        ]);
      },
    );

    testWidgets('código incorrecto: vuelve a pedirlo mostrando el error', (
      tester,
    ) async {
      final api = _FakeApi(googleEnabled: true, googleNeedsInvite: true);
      await pumpAuth(tester, api: api, google: _FakeGoogle('tok-1'));

      await tester.tap(find.text('Continuar con Google'));
      await _frames(tester);
      await tester.enterText(find.byType(TextField), 'mal');
      await tester.tap(find.text('Continuar'));
      await _frames(tester);

      expect(
        find.text('El código de invitación no es válido.'),
        findsOneWidget,
      );
      expect(api.googleCalls.length, 2);
    });

    testWidgets('cancelar el diálogo de invitación no crea la cuenta', (
      tester,
    ) async {
      final api = _FakeApi(googleEnabled: true, googleNeedsInvite: true);
      await pumpAuth(tester, api: api, google: _FakeGoogle('tok-1'));

      await tester.tap(find.text('Continuar con Google'));
      await _frames(tester);
      await tester.tap(find.text('Cancelar'));
      await _frames(tester);

      expect(api.googleCalls.length, 1);
      expect(find.text('Código de invitación'), findsNothing);
    });
  });
}
