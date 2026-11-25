import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'models.dart';

/// URL base de la API. Se puede cambiar con --dart-define=API_URL=...
String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000/api'; // emulador Android -> host
  }
  return 'http://localhost:8000/api';
}

final _dayFormat = DateFormat('yyyy-MM-dd');
final _monthFormat = DateFormat('yyyy-MM');

String formatDay(DateTime d) => _dayFormat.format(d);
String formatMonth(DateTime d) => _monthFormat.format(d);

/// Convierte cualquier error de red/validación en un mensaje en español.
String errorMessage(Object e, AppLocalizations l10n) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      if (data['message'] is String) return data['message'] as String;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return l10n.errorConnection;
    }
  }
  return l10n.errorUnexpected;
}

class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_token';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}

/// Cliente de la API de Calendar Check.
class Api {
  Api({Dio? dio, TokenStorage? tokens, String Function()? language})
    : tokens = tokens ?? TokenStorage(),
      dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: apiBaseUrl,
              headers: {'Accept': 'application/json'},
              connectTimeout: const Duration(seconds: 10),
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await this.tokens.read();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          if (language != null) options.headers['Accept-Language'] = language();
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage tokens;

  Future<User> _authenticate(String path, Map<String, dynamic> body) async {
    final res = await dio.post(path, data: body);
    await tokens.write(res.data['token'] as String);
    return User.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  Future<User> login(String email, String password) =>
      _authenticate('/login', {'email': email, 'password': password});

  Future<User> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) => _authenticate('/register', {
    'name': name,
    'email': email,
    'password': password,
    'password_confirmation': passwordConfirmation,
  });

  /// Devuelve el usuario de la sesión guardada, o null si no hay/expiró.
  Future<User?> restoreSession() async {
    if (await tokens.read() == null) return null;
    try {
      final res = await dio.get('/me');
      return User.fromJson(res.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  /// Confirma el código de 6 dígitos que llegó por correo.
  Future<User> verifyEmail(String code) async {
    final res = await dio.post('/email/verify', data: {'code': code});
    return User.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  /// Pide un código nuevo. Devuelve los segundos de espera si aún no se puede
  /// (el servidor limita un envío cada 60 s), o 0 si se envió.
  Future<int> resendVerification() async {
    try {
      await dio.post('/email/resend');
      return 0;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 429 &&
          data is Map &&
          data['retry_after'] is int) {
        return data['retry_after'] as int;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await dio.post('/logout');
    } finally {
      await tokens.clear();
    }
  }

  Future<List<Habit>> habits() async {
    final res = await dio.get('/habits');
    return (res.data['data'] as List)
        .map((e) => Habit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Campos de la meta para la API; sin meta se mandan nulos para quitarla.
  Map<String, Object?> _goalData(GoalForm? goal) => {
    'goal_days': goal?.end == null ? goal?.days : null,
    'goal_start': goal?.start,
    'goal_end': goal?.end,
    'goal_on_fail': goal?.onFail,
  };

  /// Con los 7 días (o ninguno indicado) se manda null: el hábito aplica siempre.
  List<int>? _activeDaysData(List<int>? days) {
    if (days == null || days.length >= 7) return null;
    return (days.toList()..sort());
  }

  Future<Habit> createHabit(
    String name, {
    String? color,
    String? icon,
    GoalForm? goal,
    List<int>? activeDays,
  }) async {
    final res = await dio.post(
      '/habits',
      data: {
        'name': name,
        'color': color,
        'icon': icon,
        'active_days': _activeDaysData(activeDays),
        ..._goalData(goal),
      },
    );
    return Habit.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// Actualiza nombre, color e ícono (icon == null quita el ícono).
  Future<Habit> updateHabit(
    int id,
    String name, {
    String? color,
    String? icon,
    GoalForm? goal,
    List<int>? activeDays,
  }) async {
    final res = await dio.put(
      '/habits/$id',
      data: {
        'name': name,
        'color': color,
        'icon': icon,
        'active_days': _activeDaysData(activeDays),
        ..._goalData(goal),
      },
    );
    return Habit.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteHabit(int id) => dio.delete('/habits/$id');

  Future<List<HabitLog>> logs(int habitId, String month) async {
    final res = await dio.get(
      '/logs',
      queryParameters: {'month': month, 'habit_id': habitId},
    );
    return (res.data['data'] as List)
        .map((e) => HabitLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setLog(int habitId, String date, LogStatus status) =>
      dio.put('/habits/$habitId/logs/$date', data: {'status': status.name});

  Future<void> clearLog(int habitId, String date) =>
      dio.delete('/habits/$habitId/logs/$date');

  Future<HabitStats> stats(int habitId, String month) async {
    final res = await dio.get(
      '/habits/$habitId/stats',
      queryParameters: {'month': month, 'today': formatDay(DateTime.now())},
    );
    return HabitStats.fromJson(res.data as Map<String, dynamic>);
  }
}
