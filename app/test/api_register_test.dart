import 'dart:convert';
import 'dart:typed_data';

import 'package:calendar_check/core/api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador que guarda la última petición y responde con un JSON fijo.
class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? last;
  Map<String, dynamic> response = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokens extends TokenStorage {
  _MemoryTokens() : super();
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}

void main() {
  late _CaptureAdapter adapter;
  late Api api;

  setUp(() {
    adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
      ..httpClientAdapter = adapter;
    api = Api(dio: dio, tokens: _MemoryTokens());
  });

  test('register envía el código de invitación sin espacios', () async {
    adapter.response = {
      'user': {'id': 1, 'name': 'Ana', 'email': 'ana@example.com'},
      'token': 't',
    };
    await api.register(
      'Ana',
      'ana@example.com',
      'secreto123',
      'secreto123',
      inviteCode: '  PRUEBAS ',
    );
    final body = adapter.last!.data as Map;
    expect(body['invite_code'], 'PRUEBAS');
    expect(body['password_confirmation'], 'secreto123');
  });

  test('register no manda invite_code si está vacío o ausente', () async {
    adapter.response = {
      'user': {'id': 1, 'name': 'Ana', 'email': 'ana@example.com'},
      'token': 't',
    };
    await api.register('Ana', 'ana@example.com', 'secreto123', 'secreto123');
    expect((adapter.last!.data as Map).containsKey('invite_code'), isFalse);

    await api.register(
      'Ana',
      'ana@example.com',
      'secreto123',
      'secreto123',
      inviteCode: '   ',
    );
    expect((adapter.last!.data as Map).containsKey('invite_code'), isFalse);
  });

  test('fetchConfig lee la invitación y los client IDs de Google', () async {
    adapter.response = {
      'registration': {'requires_invite_code': true},
      'google': {
        'enabled': true,
        'web_client_id': 'web.apps.googleusercontent.com',
        'ios_client_id': 'ios.apps.googleusercontent.com',
      },
    };
    final config = await api.fetchConfig();
    expect(adapter.last!.path, '/config');
    expect(config.requiresInviteCode, isTrue);
    expect(config.googleEnabled, isTrue);
    expect(config.googleWebClientId, 'web.apps.googleusercontent.com');
    expect(config.googleIosClientId, 'ios.apps.googleusercontent.com');
  });

  test('fetchConfig tolera respuestas sin Google o vacías', () async {
    adapter.response = {
      'registration': {'requires_invite_code': false},
      'google': {
        'enabled': false,
        'web_client_id': null,
        'ios_client_id': null,
      },
    };
    var config = await api.fetchConfig();
    expect(config.requiresInviteCode, isFalse);
    expect(config.googleEnabled, isFalse);

    adapter.response = {};
    config = await api.fetchConfig();
    expect(config.googleEnabled, isFalse);
    expect(config.googleWebClientId, isNull);
  });

  test(
    'googleLogin manda id_token (y la invitación sin espacios solo si hay)',
    () async {
      adapter.response = {
        'user': {'id': 1, 'name': 'Ana', 'email': 'ana@example.com'},
        'token': 't',
      };
      await api.googleLogin('tok');
      expect(adapter.last!.path, '/google');
      expect(adapter.last!.data, {'id_token': 'tok'});

      await api.googleLogin('tok', inviteCode: '  PRUEBAS ');
      expect(adapter.last!.data, {'id_token': 'tok', 'invite_code': 'PRUEBAS'});

      await api.googleLogin('tok', inviteCode: '   ');
      expect((adapter.last!.data as Map).containsKey('invite_code'), isFalse);
    },
  );
}
