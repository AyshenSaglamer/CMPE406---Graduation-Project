import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:gradia/services/auth_service.dart';
import 'package:gradia/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Refresh tokens as the backend answers them: POST /auth/refresh gives a new
/// access AND refresh token, and a refresh token works only once.
class FakeTokenBackend {
  final requests = <http.Request>[];
  var validAccess = 'access-1';
  var validRefresh = 'refresh-1';
  var refreshCalls = 0;
  var offline = false;
  var logoutCalls = 0;

  late final client = MockClient((request) async {
    if (offline) {
      throw http.ClientException('offline');
    }
    requests.add(request);

    if (request.url.path == '/api/v1/auth/refresh') {
      refreshCalls++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['refreshToken'] != validRefresh) {
        return _json(401, {'status': 401, 'detail': 'invalid refresh token'});
      }
      validAccess = 'access-${refreshCalls + 1}';
      validRefresh = 'refresh-${refreshCalls + 1}';
      return _json(200, {
        'accessToken': validAccess,
        'tokenType': 'Bearer',
        'expiresIn': 900,
        'refreshToken': validRefresh,
        'refreshExpiresIn': 2592000,
        'user': _user,
      });
    }

    if (request.headers['Authorization'] != 'Bearer $validAccess') {
      return _json(401, {'status': 401, 'detail': 'Unauthorized'});
    }

    if (request.url.path == '/api/v1/auth/logout') {
      logoutCalls++;
      validAccess = '';
      validRefresh = '';
      return http.Response('', 204);
    }

    return _json(200, {'ok': true});
  });

  static const _user = {
    'id': 5,
    'firstName': 'Ayşe',
    'lastName': 'Kaya',
    'email': 'a@example.com',
    'role': 'PATIENT',
  };

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

void main() {
  late FakeTokenBackend backend;
  late ApiClient api;

  Future<void> saveSession({required String access, int expiresIn = 900}) {
    return TokenStorage.save(
      token: access,
      expiresInSeconds: expiresIn,
      refreshToken: 'refresh-1',
      userJson: jsonEncode(FakeTokenBackend._user),
    );
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    backend = FakeTokenBackend();
    api = ApiClient(httpClient: backend.client);
  });

  test('an expired access token is refreshed before the request', () async {
    await saveSession(access: 'access-1', expiresIn: 0);

    expect(await api.get('/users/me'), {'ok': true});

    expect(backend.refreshCalls, 1);
    expect(backend.requests.last.headers['Authorization'], 'Bearer access-2');
    expect(await TokenStorage.readRefreshToken(), 'refresh-2');
  });

  test('a 401 gets one refresh and the request is sent again', () async {
    // The access token looks valid on the phone but the backend no longer
    // takes it (e.g. a refresh on another screen replaced it).
    await saveSession(access: 'access-old');

    expect(await api.post('/patients/5/glucose-logs', body: {'x': 1}),
        {'ok': true});

    expect(backend.refreshCalls, 1);
    final sent = backend.requests
        .where((r) => r.url.path == '/api/v1/patients/5/glucose-logs')
        .toList();
    expect(sent, hasLength(2));
    expect(sent.last.body, '{"x":1}');
    expect(sent.last.headers['Authorization'], 'Bearer access-2');
  });

  test('parallel requests share one refresh', () async {
    await saveSession(access: 'access-1', expiresIn: 0);

    await Future.wait([
      api.get('/users/me'),
      api.get('/patients/5/alerts'),
      api.get('/patients/5/glucose-logs'),
    ]);

    // A second refresh with refresh-1 would end the session.
    expect(backend.refreshCalls, 1);
  });

  test('a refused refresh token ends the session', () async {
    await saveSession(access: 'access-1', expiresIn: 0);
    backend.validRefresh = 'something-else';

    await expectLater(
      api.get('/users/me'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)),
    );

    expect(await TokenStorage.readRefreshToken(), isNull);
    expect(await TokenStorage.readUserJson(), isNull);
  });

  test('offline, an expired session is kept for later', () async {
    await saveSession(access: 'access-1', expiresIn: 0);
    backend.offline = true;

    expect(await api.refreshSession(), isFalse);

    expect(await TokenStorage.readRefreshToken(), 'refresh-1');
    expect(await TokenStorage.readUserJson(), isNotNull);
  });

  test('logout ends the session on the backend and on the phone', () async {
    await saveSession(access: 'access-1');
    final auth = AuthService(api);
    await auth.restoreSession();

    await auth.logout();

    expect(backend.logoutCalls, 1);
    expect(await TokenStorage.readRefreshToken(), isNull);
    expect(await TokenStorage.readValidToken(), isNull);
    expect(auth.currentUser, isNull);
  });

  test('logout offline still clears the phone', () async {
    await saveSession(access: 'access-1');
    backend.offline = true;

    await AuthService(api).logout();

    expect(await TokenStorage.readRefreshToken(), isNull);
  });
}
