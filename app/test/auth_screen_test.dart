import 'package:calendar_check/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpAuth(WidgetTester tester) async {
    // Pantalla alta de teléfono para que todo quede a la vista.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: testApp(home: const AuthScreen())),
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
}
