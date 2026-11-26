import 'package:calendar_check/l10n/app_localizations.dart';
import 'package:calendar_check/screens/auth_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  test('un fallo del plugin muestra el código para poder diagnosticarlo', () {
    final text = googleErrorText(
      PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 10: ',
      ),
      l,
    );
    expect(
      text,
      startsWith('No se pudo iniciar sesión con Google. (sign_in_failed'),
    );
    expect(text, contains('ApiException: 10'));
  });

  test('sin mensaje solo muestra el código', () {
    expect(
      googleErrorText(PlatformException(code: 'network_error'), l),
      'No se pudo iniciar sesión con Google. (network_error)',
    );
  });

  test('un mensaje muy largo se recorta', () {
    final text = googleErrorText(
      PlatformException(code: 'x', message: 'a' * 500),
      l,
    );
    expect(text.length, lessThan(200));
    expect(text, endsWith('…)'));
  });

  test('errores del servidor usan su mensaje y lo demás el genérico', () {
    final request = RequestOptions(path: '/google');
    final server = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 422,
        data: {'message': 'Token inválido'},
      ),
    );
    expect(googleErrorText(server, l), 'Token inválido');
    expect(
      googleErrorText(StateError('x'), l),
      'No se pudo iniciar sesión con Google.',
    );
  });
}
