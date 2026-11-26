import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'google_auth.dart';
import 'window_focus.dart';
import 'locale.dart';
import 'models.dart';

/// Inicio de sesión de Google en Android/iOS (en web se usa el botón oficial).
final googleAuthProvider = Provider<GoogleAuthService>(
  (ref) => const GoogleAuthService(),
);

/// Escucha cuándo la ventana del navegador recupera el foco (solo web). Se
/// sustituye en los tests.
final windowFocusListenerProvider =
    Provider<VoidCallback Function(VoidCallback)>((ref) => listenWindowFocus);

/// Abre un enlace fuera de la app (navegador o correo). Se sustituye en los tests.
final linkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final apiProvider = Provider<Api>(
  (ref) => Api(language: () => effectiveLanguageCode(ref.read(localeProvider))),
);

/// Sesión actual: null = sin sesión.
class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() => ref.read(apiProvider).restoreSession();

  Future<void> login(String email, String password) async {
    final user = await ref.read(apiProvider).login(email, password);
    state = AsyncData(user);
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String passwordConfirmation, {
    String? inviteCode,
  }) async {
    final user = await ref
        .read(apiProvider)
        .register(
          name,
          email,
          password,
          passwordConfirmation,
          inviteCode: inviteCode,
        );
    state = AsyncData(user);
  }

  /// Entra con un ID token de Google; si la cuenta es nueva y el servidor
  /// exige invitación, lanza un error 422 con `invite_code`.
  Future<void> loginWithGoogle(String idToken, {String? inviteCode}) async {
    final user = await ref
        .read(apiProvider)
        .googleLogin(idToken, inviteCode: inviteCode);
    state = AsyncData(user);
  }

  Future<void> verifyEmail(String code) async {
    final user = await ref.read(apiProvider).verifyEmail(code);
    state = AsyncData(user);
  }

  /// Elimina la cuenta y deja la app sin sesión.
  Future<void> deleteAccount(String email) async {
    await ref.read(apiProvider).deleteAccount(email);
    state = const AsyncData(null);
    if (!kIsWeb) unawaited(ref.read(googleAuthProvider).signOut());
  }

  /// Valida la compra en el servidor y guarda el usuario ya sin anuncios.
  Future<void> verifyPurchase(String productId, String purchaseToken) async {
    final user = await ref
        .read(apiProvider)
        .verifyPurchase(productId, purchaseToken);
    state = AsyncData(user);
  }

  Future<void> logout() async {
    try {
      await ref.read(apiProvider).logout();
    } catch (_) {
      // El token local ya se borró; la sesión se cierra igual.
    }
    // Que la próxima vez Google deje elegir la cuenta (no aplica en web).
    state = const AsyncData(null);
    if (!kIsWeb) unawaited(ref.read(googleAuthProvider).signOut());
  }
}

/// Ajustes públicos del servidor (invitación y Google). Si no se pueden
/// consultar, se asume el caso más simple: el servidor igual valida y avisa.
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  try {
    return await ref.read(apiProvider).fetchConfig();
  } catch (_) {
    return AppConfig.empty;
  }
});

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  @override
  Future<List<Habit>> build() => ref.read(apiProvider).habits();

  /// Tras crear, editar o borrar un hábito se vuelve a pedir todo lo suyo: la
  /// lista y también sus estadísticas y marcas (la meta o los días activos
  /// cambian la racha, las rayitas y el avance que muestran las tarjetas).
  Future<void> _reload() async {
    ref.invalidate(statsProvider);
    ref.invalidate(logsProvider);
    ref.invalidateSelf();
    await future;
  }

  Future<void> create(
    String name,
    String color, {
    String? icon,
    GoalForm? goal,
    List<int>? activeDays,
  }) async {
    await ref
        .read(apiProvider)
        .createHabit(
          name,
          color: color,
          icon: icon,
          goal: goal,
          activeDays: activeDays,
        );
    await _reload();
  }

  Future<void> edit(
    int id,
    String name,
    String color, {
    String? icon,
    GoalForm? goal,
    List<int>? activeDays,
  }) async {
    await ref
        .read(apiProvider)
        .updateHabit(
          id,
          name,
          color: color,
          icon: icon,
          goal: goal,
          activeDays: activeDays,
        );
    await _reload();
  }

  Future<void> remove(int id) async {
    await ref.read(apiProvider).deleteHabit(id);
    await _reload();
  }
}

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<Habit>>(
  HabitsNotifier.new,
);

typedef HabitMonth = ({int habitId, String month});

final logsProvider = FutureProvider.family<List<HabitLog>, HabitMonth>(
  (ref, key) => ref.read(apiProvider).logs(key.habitId, key.month),
);

final statsProvider = FutureProvider.family<HabitStats, HabitMonth>(
  (ref, key) => ref.read(apiProvider).stats(key.habitId, key.month),
);
