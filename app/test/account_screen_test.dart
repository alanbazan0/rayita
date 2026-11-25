import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:calendar_check/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

class _FakeApi extends Api {
  final List<String> deleted = [];
  int logouts = 0;

  @override
  Future<User?> restoreSession() async => User(
    id: 1,
    name: 'Ana Pérez',
    email: 'ana@example.com',
    emailVerified: true,
    createdAt: DateTime(2026, 11, 24),
  );

  @override
  Future<List<Habit>> habits() async => const [
    Habit(id: 1, name: 'Leer'),
    Habit(id: 2, name: 'Meditar'),
    Habit(id: 3, name: 'Agua'),
  ];

  @override
  Future<void> deleteAccount(String email) async => deleted.add(email);

  @override
  Future<void> logout() async => logouts++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _FakeApi api;
  late ProviderContainer container;
  late List<Uri> opened;
  bool openWorks = true;

  Future<void> pumpAccount(
    WidgetTester tester, {
    Locale locale = const Locale('es'),
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    api = _FakeApi();
    opened = [];
    openWorks = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          linkOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return openWorks;
          }),
        ],
        child: testApp(
          locale: locale,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountScreen(),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.text('abrir')));
    await container.read(authProvider.future);
    await container.read(habitsProvider.future);
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el perfil: inicial, nombre, correo y datos', (
    tester,
  ) async {
    await pumpAccount(tester);

    expect(find.text('A'), findsOneWidget); // inicial del avatar
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('Correo verificado'), findsOneWidget);
    expect(find.text('3 hábitos'), findsOneWidget);
    expect(find.text('Miembro desde Noviembre de 2026'), findsOneWidget);
  });

  testWidgets('los enlaces legales y de ayuda usan el idioma de la app', (
    tester,
  ) async {
    await pumpAccount(tester);
    await tester.tap(find.text('Política de privacidad'));
    await tester.tap(find.text('Términos y condiciones'));
    await tester.tap(find.text('Contacto y ayuda'));
    await tester.pump();

    expect(opened.map((u) => u.toString()), [
      'https://rayita.alanbazan.com.mx/privacidad',
      'https://rayita.alanbazan.com.mx/terminos',
      'mailto:support@alanbazan.com.mx',
    ]);
  });

  testWidgets('en inglés abre las páginas en inglés', (tester) async {
    await pumpAccount(tester, locale: const Locale('en'));
    await tester.tap(find.text('Privacy policy'));
    await tester.tap(find.text('Terms and conditions'));
    await tester.pump();

    expect(opened.map((u) => u.toString()), [
      'https://rayita.alanbazan.com.mx/privacy',
      'https://rayita.alanbazan.com.mx/terms',
    ]);
  });

  testWidgets('si el enlace no se puede abrir avisa', (tester) async {
    await pumpAccount(tester);
    openWorks = false;
    await tester.tap(find.text('Política de privacidad'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
  });

  testWidgets('cerrar sesión cierra la pantalla y la sesión', (tester) async {
    await pumpAccount(tester);
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(api.logouts, 1);
    expect(find.byType(AccountScreen), findsNothing);
    expect(container.read(authProvider).value, isNull);
  });

  testWidgets('la eliminación está en una zona de peligro aparte', (
    tester,
  ) async {
    await pumpAccount(tester);
    expect(find.text('ZONA DE PELIGRO'), findsOneWidget);
    expect(
      find.text('Elimina tu cuenta y todos tus datos para siempre.'),
      findsOneWidget,
    );
  });

  testWidgets('eliminar exige escribir el correo de la cuenta', (tester) async {
    await pumpAccount(tester);
    await tester.ensureVisible(find.text('Eliminar cuenta'));
    await tester.tap(find.text('Eliminar cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
    FilledButton button() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Eliminar para siempre'),
    );
    expect(button().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'otra@example.com');
    await tester.pump();
    expect(button().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  ANA@example.com ');
    await tester.pump();
    expect(button().onPressed, isNotNull);
    expect(api.deleted, isEmpty);
  });

  testWidgets('confirmar elimina la cuenta, cierra la pantalla y avisa', (
    tester,
  ) async {
    await pumpAccount(tester);
    await tester.ensureVisible(find.text('Eliminar cuenta'));
    await tester.tap(find.text('Eliminar cuenta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ana@example.com');
    await tester.pump();
    await tester.tap(find.text('Eliminar para siempre'));
    await tester.pumpAndSettle();

    expect(api.deleted, ['ana@example.com']);
    expect(container.read(authProvider).value, isNull);
    expect(find.byType(AccountScreen), findsNothing);
    expect(find.text('Tu cuenta fue eliminada.'), findsOneWidget);
  });

  testWidgets('cancelar no elimina nada', (tester) async {
    await pumpAccount(tester);
    await tester.ensureVisible(find.text('Eliminar cuenta'));
    await tester.tap(find.text('Eliminar cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(api.deleted, isEmpty);
    expect(container.read(authProvider).value, isNotNull);
    expect(find.byType(AccountScreen), findsOneWidget);
  });

  test('User.fromJson lee la fecha de creación en hora local', () {
    final u = User.fromJson({
      'id': 1,
      'name': 'A',
      'email': 'a@a.com',
      'created_at': '2026-11-24T18:30:00.000000Z',
    });
    expect(u.createdAt, DateTime.utc(2026, 11, 24, 18, 30).toLocal());
    expect(
      User.fromJson({'id': 2, 'name': 'B', 'email': 'b@b.com'}).createdAt,
      isNull,
    );
  });
}
