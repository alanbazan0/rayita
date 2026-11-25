import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'locale.dart';
import 'models.dart';

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
    String passwordConfirmation,
  ) async {
    final user = await ref
        .read(apiProvider)
        .register(name, email, password, passwordConfirmation);
    state = AsyncData(user);
  }

  Future<void> verifyEmail(String code) async {
    final user = await ref.read(apiProvider).verifyEmail(code);
    state = AsyncData(user);
  }

  Future<void> logout() async {
    try {
      await ref.read(apiProvider).logout();
    } catch (_) {
      // El token local ya se borró; la sesión se cierra igual.
    }
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  @override
  Future<List<Habit>> build() => ref.read(apiProvider).habits();

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
    ref.invalidateSelf();
    await future;
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
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(int id) async {
    await ref.read(apiProvider).deleteHabit(id);
    ref.invalidateSelf();
    await future;
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
