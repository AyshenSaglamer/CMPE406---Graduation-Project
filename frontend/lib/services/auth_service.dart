import 'dart:convert';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../utils/api_enums.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'token_storage.dart';

class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  Future<AppUser> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required DateTime dateOfBirth,
    required String gender,
    required UserRole role,
  }) async {
    final json = await _api.post(
      '/auth/register',
      auth: false,
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'role': role.apiValue,
        'dateOfBirth': formatApiDate(dateOfBirth),
        'gender': gender,
      },
    );

    return AppUser.fromJson(
      json as Map<String, dynamic>,
    );
  }

  /// Registers and then logs in with the same credentials (register does not
  /// return a token). Every role, doctors included, can log in right away.
  Future<AppUser> registerAndLogin({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required DateTime dateOfBirth,
    required String gender,
    required UserRole role,
  }) async {
    await register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      dateOfBirth: dateOfBirth,
      gender: gender,
      role: role,
    );

    return login(email: email, password: password);
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.post(
      '/auth/login',
      auth: false,
      body: {
        'email': email,
        'password': password,
      },
    ) as Map<String, dynamic>;

    final userJson =
        json['user'] as Map<String, dynamic>;

    if (UserRoleApi.fromApi(
          userJson['role'] as String,
        ) ==
        null) {
      throw const ApiException(
        statusCode: 403,
        message:
            'This account type cannot use the mobile app.',
      );
    }

    final user = AppUser.fromJson(userJson);

    await TokenStorage.save(
      token: json['accessToken'] as String,
      expiresInSeconds:
          (json['expiresIn'] as num).toInt(),
      refreshToken: json['refreshToken'] as String?,
      userJson: jsonEncode(user.toJson()),
    );

    _currentUser = user;

    return user;
  }

  /// The saved user, if the session can still be used: the access token is
  /// valid, or the refresh token can replace it. Offline with an expired
  /// access token the user stays logged in (logs are queued on the phone).
  Future<AppUser?> restoreSession() async {
    var token =
        await TokenStorage.readValidToken();

    if (token == null &&
        await TokenStorage.readRefreshToken() != null) {
      await _api.refreshSession();
      token = await TokenStorage.readValidToken() ??
          await TokenStorage.readRefreshToken();
    }

    final userJson =
        await TokenStorage.readUserJson();

    if (token == null || userJson == null) {
      return null;
    }

    try {
      _currentUser = AppUser.fromJson(
        jsonDecode(userJson)
            as Map<String, dynamic>,
      );

      return _currentUser;
    } on FormatException {
      await TokenStorage.clear();
      return null;
    }
  }

  /// Ends the session on the backend too (POST /auth/logout), so the tokens
  /// stop working everywhere at once. Logging out works offline as well: the
  /// tokens on the phone are deleted whatever the answer.
  Future<void> logout() async {
    _currentUser = null;
    try {
      if (await TokenStorage.readValidToken() != null) {
        await _api.post('/auth/logout');
      }
    } on ApiException {
      // Offline or already ended: the session on the phone is cleared anyway.
    }
    await TokenStorage.clear();
  }
}

final authService = AuthService(apiClient);