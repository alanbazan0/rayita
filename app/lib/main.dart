import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/locale.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/verify_email_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const ProviderScope(child: CalendarCheckApp()));
}

class CalendarCheckApp extends ConsumerWidget {
  const CalendarCheckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: ref.watch(localeProvider),
      // Modo automático: español si el sistema está en español; si no, inglés.
      localeResolutionCallback: (device, _) => resolveSystemLocale(device),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const AuthScreen(),
      data: (user) {
        if (user == null) return const AuthScreen();
        // Sin correo verificado solo se ve la pantalla del código.
        return user.emailVerified
            ? const HabitsScreen()
            : VerifyEmailScreen(user: user);
      },
    );
  }
}
