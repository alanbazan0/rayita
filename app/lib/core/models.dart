import 'package:flutter/material.dart';

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.emailVerified = false,
    this.createdAt,
    this.adsRemoved = false,
  });

  final int id;
  final String name;
  final String email;
  final bool emailVerified;

  /// El servidor ya validó con Google Play la compra de "quitar anuncios".
  final bool adsRemoved;

  /// Cuándo se creó la cuenta (hora local); null si el servidor no lo envía.
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] as int,
    name: j['name'] as String,
    email: j['email'] as String,
    emailVerified: j['email_verified_at'] != null,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal(),
    adsRemoved: j['ads_removed'] == true,
  );
}

/// Ajustes públicos del servidor (GET /config).
class AppConfig {
  const AppConfig({
    this.requiresInviteCode = false,
    this.googleWebClientId,
    this.googleIosClientId,
  });

  static const empty = AppConfig();

  final bool requiresInviteCode;

  /// Client ID "web" de Google: audiencia del token y serverClientId en móvil.
  final String? googleWebClientId;
  final String? googleIosClientId;

  /// El botón de Google solo se muestra si el servidor tiene Google configurado.
  bool get googleEnabled =>
      googleWebClientId != null && googleWebClientId!.isNotEmpty;

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final registration = j['registration'];
    final google = j['google'];
    String? id(Object? v) => v is String && v.isNotEmpty ? v : null;
    return AppConfig(
      requiresInviteCode:
          registration is Map && registration['requires_invite_code'] == true,
      googleWebClientId: google is Map ? id(google['web_client_id']) : null,
      googleIosClientId: google is Map ? id(google['ios_client_id']) : null,
    );
  }
}

const allWeekdays = [1, 2, 3, 4, 5, 6, 7];

class Habit {
  const Habit({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    this.activeDays = allWeekdays,
    this.createdAt,
    this.goalDays,
    this.goalStart,
    this.goalEnd,
    this.goalOnFail,
  });

  final int id;
  final String name;
  final String? color;
  final String? icon;

  /// Días de la semana en que aplica el hábito (ISO: 1 = lunes … 7 = domingo).
  final List<int> activeDays;

  /// Cuándo se creó el hábito (hora local); null si el servidor no lo envía.
  final DateTime? createdAt;

  bool isActiveOn(DateTime d) => activeDays.contains(d.weekday);

  /// Meta opcional: días objetivo, rango (AAAA-MM-DD) y qué hacer al fallar.
  final int? goalDays;
  final String? goalStart;
  final String? goalEnd;
  final String? goalOnFail; // 'reset' | 'accumulate'

  bool get hasGoal => goalDays != null;

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
    id: j['id'] as int,
    name: j['name'] as String,
    color: j['color'] as String?,
    icon: j['icon'] as String?,
    activeDays:
        (j['active_days'] as List?)?.map((e) => e as int).toList() ??
        allWeekdays,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal(),
    goalDays: j['goal_days'] as int?,
    goalStart: j['goal_start'] as String?,
    goalEnd: j['goal_end'] as String?,
    goalOnFail: j['goal_on_fail'] as String?,
  );

  /// Color del hábito; si no tiene, uno por defecto.
  Color get displayColor => parseHexColor(color) ?? const Color(0xFF4F46E5);
}

Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

String colorToHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Meta elegida en el formulario. Con `end` los días se calculan del rango.
class GoalForm {
  const GoalForm({this.days, this.start, this.end, this.onFail = 'reset'});

  final int? days;
  final String? start;
  final String? end;
  final String onFail; // 'reset' | 'accumulate'
}

/// Avance de la meta que calcula el servidor.
class GoalProgress {
  const GoalProgress({
    required this.target,
    required this.progress,
    required this.onFail,
    required this.status,
    this.end,
    this.daysLeft,
  });

  final int target;
  final int progress;
  final String onFail;
  final String status; // 'active' | 'achieved' | 'failed'
  final String? end;
  final int? daysLeft;

  bool get achieved => status == 'achieved';
  bool get failed => status == 'failed';
  double get fraction => target == 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  factory GoalProgress.fromJson(Map<String, dynamic> j) => GoalProgress(
    target: j['target'] as int,
    progress: j['progress'] as int,
    onFail: j['on_fail'] as String,
    status: j['status'] as String,
    end: j['end'] as String?,
    daysLeft: j['days_left'] as int?,
  );
}

enum LogStatus { done, partial }

class HabitLog {
  const HabitLog({
    required this.habitId,
    required this.date,
    required this.status,
  });

  final int habitId;
  final String date; // AAAA-MM-DD
  final LogStatus status;

  factory HabitLog.fromJson(Map<String, dynamic> j) => HabitLog(
    habitId: j['habit_id'] as int,
    date: j['date'] as String,
    status: j['status'] == 'partial' ? LogStatus.partial : LogStatus.done,
  );
}

class Tally {
  const Tally({
    required this.total,
    required this.groups,
    required this.remainder,
  });

  final int total;
  final int groups;
  final int remainder;

  factory Tally.fromJson(Map<String, dynamic> j) => Tally(
    total: j['total'] as int,
    groups: j['groups'] as int,
    remainder: j['remainder'] as int,
  );
}

/// Rayitas de un mes (una línea del cuaderno).
class MonthTally {
  const MonthTally({
    required this.month,
    required this.done,
    required this.tally,
  });

  final String month; // AAAA-MM
  final int done;
  final Tally tally;

  factory MonthTally.fromJson(Map<String, dynamic> j) => MonthTally(
    month: j['month'] as String,
    done: j['done'] as int,
    tally: Tally.fromJson(j['tally'] as Map<String, dynamic>),
  );
}

class HabitStats {
  const HabitStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.monthDone,
    required this.monthPartial,
    required this.monthTally,
    required this.totalDone,
    required this.totalTally,
    this.goal,
    this.since,
    this.history = const [],
  });

  final int currentStreak;
  final int longestStreak;
  final int monthDone;
  final int monthPartial;
  final Tally monthTally;
  final int totalDone;
  final Tally totalTally;
  final GoalProgress? goal;

  /// Primera marca del hábito (puede ser anterior al día en que se creó, porque
  /// se pueden registrar días atrás); null si aún no hay marcas.
  final DateTime? since;

  /// Días cumplidos por mes, del más reciente al más antiguo (el cuaderno).
  final List<MonthTally> history;

  factory HabitStats.fromJson(Map<String, dynamic> j) {
    final month = j['month'] as Map<String, dynamic>;
    final total = j['total'] as Map<String, dynamic>;
    return HabitStats(
      currentStreak: j['current_streak'] as int,
      longestStreak: j['longest_streak'] as int,
      monthDone: month['done'] as int,
      monthPartial: month['partial'] as int,
      monthTally: Tally.fromJson(month['tally'] as Map<String, dynamic>),
      totalDone: total['done'] as int,
      totalTally: Tally.fromJson(total['tally'] as Map<String, dynamic>),
      goal: j['goal'] == null
          ? null
          : GoalProgress.fromJson(j['goal'] as Map<String, dynamic>),
      since: DateTime.tryParse(j['since'] as String? ?? ''),
      history: j['history'] is List
          ? [
              for (final m in j['history'] as List)
                MonthTally.fromJson(m as Map<String, dynamic>),
            ]
          // Servidor anterior al cuaderno: al menos se ve el mes que sí conoce.
          : [
              if (month['month'] is String)
                MonthTally(
                  month: month['month'] as String,
                  done: month['done'] as int,
                  tally: Tally.fromJson(month['tally'] as Map<String, dynamic>),
                ),
            ],
    );
  }
}
