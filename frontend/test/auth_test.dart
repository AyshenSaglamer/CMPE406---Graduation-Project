import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/models/app_user.dart';
import 'package:gradia/models/user_role.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:gradia/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// /auth/register and /auth/login as the backend answers them: every role
/// starts active, and a disabled account gets 403 at login.
class FakeAuthBackend {
  final requests = <http.Request>[];
  final users = <String, Map<String, dynamic>>{};

  late final client = MockClient((request) async {
    requests.add(request);
    final body = jsonDecode(request.body) as Map<String, dynamic>;

    if (request.url.path == '/api/v1/auth/register') {
      final user = {
        'id': users.length + 1,
        'firstName': body['firstName'],
        'lastName': body['lastName'],
        'email': body['email'],
        'role': body['role'],
        'password': body['password'],
        'active': true,
      };
      users[body['email'] as String] = user;
      return _json(201, {...user}..remove('password')..remove('active'));
    }

    if (request.url.path == '/api/v1/auth/login') {
      final user = users[body['email']];
      if (user == null || user['password'] != body['password']) {
        return _json(401, {'status': 401, 'detail': 'Invalid email or password'});
      }
      if (user['active'] != true) {
        return _json(403, {
          'status': 403,
          'detail': 'Account is disabled',
        });
      }
      return _json(200, {
        'accessToken': 'token-${user['id']}',
        'tokenType': 'Bearer',
        'expiresIn': 3600,
        'user': {...user}..remove('password')..remove('active'),
      });
    }

    return _json(404, {'status': 404, 'detail': 'Not found'});
  });

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

void main() {
  late FakeAuthBackend backend;
  late AuthService auth;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    backend = FakeAuthBackend();
    auth = AuthService(ApiClient(httpClient: backend.client));
  });

  Future<AppUser> register(UserRole role, String email) {
    return auth.registerAndLogin(
      firstName: 'Deniz',
      lastName: 'Yılmaz',
      email: email,
      password: 'correct-horse-1',
      dateOfBirth: DateTime(1990, 5, 1),
      gender: 'FEMALE',
      role: role,
    );
  }

  group('registerAndLogin', () {
    test('a patient is registered and logged in', () async {
      final user = await register(UserRole.patient, 'p@example.com');

      expect(user.role, UserRole.patient);
      expect(auth.currentUser, isNotNull);
      expect(backend.requests.map((r) => r.url.path),
          ['/api/v1/auth/register', '/api/v1/auth/login']);
    });

    test('a doctor is registered and logged in: no approval step', () async {
      final user = await register(UserRole.doctor, 'd@example.com');

      expect(user.role, UserRole.doctor);
      expect(auth.currentUser, isNotNull);
      expect(backend.requests.map((r) => r.url.path),
          ['/api/v1/auth/register', '/api/v1/auth/login']);
      expect(jsonDecode(backend.requests.first.body)['role'], 'CLINICIAN');
    });
  });

  group('login', () {
    test('a disabled account gets 403 with the backend message', () async {
      await register(UserRole.patient, 'p@example.com');
      backend.users['p@example.com']!['active'] = false;

      expect(
        () => auth.login(email: 'p@example.com', password: 'correct-horse-1'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'Account is disabled')),
      );
    });
  });
}
