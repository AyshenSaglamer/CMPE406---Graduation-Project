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
      userJson: jsonEncode(user.toJson()),
    );

    _currentUser = user;

    return user;
  }

  Future<AppUser?> restoreSession() async {
    final token =
        await TokenStorage.readValidToken();

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

  Future<void> logout() async {
    _currentUser = null;
    await TokenStorage.clear();
  }
}

final authService = AuthService(apiClient);