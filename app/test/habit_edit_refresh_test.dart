import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends Api {
  int habitsCalls = 0;
  int statsCalls = 0;
  int logsCalls = 0;
  String name = 'Leer';

  @override
  Future<List<Habit>> habits() async {
    habitsCalls++;
    return [Habit(id: 1, name: name)];
  }

  @override
  Future<HabitStats> stats(int habitId, String month) async {
    statsCalls++;
    return HabitStats.fromJson({
      'current_streak':
          statsCalls, // cambia en cada petición, como una racha real
      'longest_streak': 5,
      'month': {
        'done': 1,
        'partial': 0,
        'tally': {'total': 1, 'groups': 0, 'remainder': 1},
      },
      'total': {
        'done': 1,
        'partial': 0,
        'tally': {'total': 1, 'groups': 0, 'remainder': 1},
      },
      'goal': null,
    });
  }

  @override
  Future<List<HabitLog>> logs(int habitId, String month) async {
    logsCalls++;
    return [];
  }

  @override
  Future<Habit> updateHabit(
    int id,
    String name, {
    String? color,
    String? icon,
    GoalForm? goal,
    List<int>? activeDays,
  }) async {
    this.name = name;
    return Habit(id: id, name: name);
  }

  @override
  Future<Habit> createHabit(
    String name, {
    String? color,
    String? icon,
    GoalForm? goal,
    List<int>? activeDays,
  }) async => Habit(id: 2, name: name);

  @override
  Future<void> deleteHabit(int id) async {}
}

void main() {
  const key = (habitId: 1, month: '2026-11');
  late _FakeApi api;
  late ProviderContainer container;

  setUp(() {
    api = _FakeApi();
    container = ProviderContainer(
      overrides: [apiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
  });

  /// Deja las estadísticas y marcas del hábito ya cargadas (como en la pantalla).
  Future<void> warmUp() async {
    await container.read(habitsProvider.future);
    await container.read(statsProvider(key).future);
    await container.read(logsProvider(key).future);
  }

  test('editar un hábito vuelve a pedir sus estadísticas y marcas', () async {
    await warmUp();
    expect(api.statsCalls, 1);
    expect(api.logsCalls, 1);

    await container
        .read(habitsProvider.notifier)
        .edit(1, 'Leer más', '#0EA5E9');

    // La lista trae el nombre nuevo…
    expect(container.read(habitsProvider).value!.single.name, 'Leer más');
    // …y las estadísticas ya no son las viejas (antes se quedaban en caché).
    final stats = await container.read(statsProvider(key).future);
    expect(api.statsCalls, 2);
    expect(stats.currentStreak, 2);
    await container.read(logsProvider(key).future);
    expect(api.logsCalls, 2);
  });

  test('crear un hábito también refresca estadísticas y marcas', () async {
    await warmUp();
    await container.read(habitsProvider.notifier).create('Meditar', '#8B5CF6');
    await container.read(statsProvider(key).future);
    expect(api.statsCalls, 2);
  });

  test(
    'borrar un hábito también refresca la lista y las estadísticas',
    () async {
      await warmUp();
      final antes = api.habitsCalls;
      await container.read(habitsProvider.notifier).remove(2);
      expect(api.habitsCalls, antes + 1);
      await container.read(statsProvider(key).future);
      expect(api.statsCalls, 2);
    },
  );
}
