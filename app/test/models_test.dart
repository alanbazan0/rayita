import 'package:calendar_check/core/api.dart';
import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/l10n/app_localizations_en.dart';
import 'package:calendar_check/l10n/app_localizations_es.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Habit.fromJson y color por defecto', () {
    final h = Habit.fromJson({
      'id': 1,
      'name': 'Leer',
      'color': '#FF8800',
      'icon': null,
    });
    expect(h.displayColor, const Color(0xFFFF8800));
    expect(
      Habit.fromJson({'id': 2, 'name': 'X', 'color': null}).displayColor,
      const Color(0xFF4F46E5),
    );
    expect(parseHexColor('rojo'), isNull);
  });

  test('colorToHex', () {
    expect(colorToHex(const Color(0xFF4F46E5)), '#4F46E5');
  });

  test('HabitStats.fromJson', () {
    final s = HabitStats.fromJson({
      'current_streak': 2,
      'longest_streak': 6,
      'month': {
        'done': 7,
        'partial': 1,
        'tally': {'total': 7, 'groups': 1, 'remainder': 2},
      },
      'total': {
        'done': 8,
        'partial': 1,
        'tally': {'total': 8, 'groups': 1, 'remainder': 3},
      },
    });
    expect(s.currentStreak, 2);
    expect(s.monthTally.remainder, 2);
    expect(s.totalTally.total, 8);
  });

  test('HabitLog.fromJson distingue parcial', () {
    expect(
      HabitLog.fromJson({
        'habit_id': 1,
        'date': '2026-11-01',
        'status': 'partial',
      }).status,
      LogStatus.partial,
    );
    expect(
      HabitLog.fromJson({'habit_id': 1, 'date': '2026-11-01', 'status': 'done'})
          .status,
      LogStatus.done,
    );
  });

  test('formatDay y formatMonth', () {
    expect(formatDay(DateTime(2026, 3, 5)), '2026-03-05');
    expect(formatMonth(DateTime(2026, 3, 5)), '2026-03');
  });

  group('errorMessage', () {
    DioException err(
      Object data, {
      DioExceptionType type = DioExceptionType.badResponse,
    }) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        data: data,
        statusCode: 422,
      ),
    );

    test('usa el primer error de validación', () {
      expect(
        errorMessage(
          err({
            'message': 'x',
            'errors': {
              'email': ['Correo inválido.'],
            },
          }),
          AppLocalizationsEs(),
        ),
        'Correo inválido.',
      );
    });
    test('usa message si no hay errors', () {
      expect(
        errorMessage(
          err({'message': 'Correo o contraseña incorrectos.'}),
          AppLocalizationsEs(),
        ),
        'Correo o contraseña incorrectos.',
      );
    });
    test('error de conexión', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      expect(
        errorMessage(e, AppLocalizationsEs()),
        'No se pudo conectar con el servidor.',
      );
      expect(
        errorMessage(e, AppLocalizationsEn()),
        'Could not connect to the server.',
      );
    });
    test('error desconocido', () {
      expect(
        errorMessage(Exception('boom'), AppLocalizationsEs()),
        'Ocurrió un error inesperado.',
      );
      expect(
        errorMessage(Exception('boom'), AppLocalizationsEn()),
        'An unexpected error occurred.',
      );
    });
  });
}
