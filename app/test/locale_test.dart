import 'package:calendar_check/core/locale.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/widgets/language_button.dart';
import 'package:calendar_check/widgets/month_calendar.dart';
import 'package:calendar_check/widgets/tally_marks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('effectiveLanguageCode respeta la elección del usuario', () {
    expect(effectiveLanguageCode(const Locale('en')), 'en');
    expect(effectiveLanguageCode(const Locale('es')), 'es');
  });

  test('modo automático: español si el sistema es español, si no inglés', () {
    expect(resolveLanguage('es'), 'es');
    expect(resolveLanguage('ES'), 'es');
    expect(resolveLanguage('en'), 'en');
    expect(resolveLanguage('fr'), 'en');
    expect(resolveLanguage('pt'), 'en');
    expect(resolveLanguage(null), 'en');
    expect(resolveSystemLocale(const Locale('es', 'MX')), const Locale('es'));
    expect(resolveSystemLocale(const Locale('de', 'DE')), const Locale('en'));
    expect(resolveSystemLocale(null), const Locale('en'));
  });

  testWidgets('idioma del sistema: francés cae a inglés, español se respeta', (
    tester,
  ) async {
    Widget app() => MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (device, _) => resolveSystemLocale(device),
      home: Builder(builder: (context) => Text(context.l10n.myHabits)),
    );

    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('My habits'), findsOneWidget);

    tester.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
    await tester.pumpAndSettle();
    expect(find.text('Mis hábitos'), findsOneWidget);
  });

  testWidgets('los textos cambian entre español e inglés', (tester) async {
    Widget app(Locale l) => testApp(
      locale: l,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const TallyMarks(
                tally: Tally(total: 0, groups: 0, remainder: 0),
                color: Colors.blue,
              ),
              MonthCalendar(
                month: DateTime(2020, 2, 10),
                color: Colors.green,
                logs: const {},
                onDayTap: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(const Locale('es')));
    await tester.pumpAndSettle();
    expect(find.text('Sin marcas'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);

    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('No marks'), findsOneWidget);
    expect(find.text('Sin marcas'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('February 14')), findsOneWidget);
  });

  testWidgets('LanguageButton guarda el idioma elegido', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: testApp(home: const Scaffold(body: LanguageButton())),
      ),
    );
    await tester.tap(find.byType(LanguageButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), const Locale('en'));
    expect((await SharedPreferences.getInstance()).getString('locale'), 'en');

    // Volver a automático borra la preferencia.
    await container.read(localeProvider.notifier).set(null);
    expect(container.read(localeProvider), isNull);
    expect((await SharedPreferences.getInstance()).getString('locale'), isNull);
  });

  testWidgets('se restaura el idioma guardado', (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(localeProvider); // dispara la carga
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );

    expect(container.read(localeProvider), const Locale('en'));
  });
}
