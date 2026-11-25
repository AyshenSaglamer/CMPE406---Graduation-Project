import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The login session on the phone (secure storage): the short-lived access
/// token, the refresh token that gets new ones (POST /auth/refresh), and the
/// user.
class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _expiresAtKey = 'access_token_expires_at';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'current_user';

  /// Treat the access token as expired this much early, so a request does not
  /// leave with a token that runs out on the way.
  static const _expirySkew = Duration(seconds: 30);

  static Future<void> save({
    required String token,
    required int expiresInSeconds,
    required String userJson,
    String? refreshToken,
  }) async {
    final expiresAt = DateTime.now().add(
      Duration(seconds: expiresInSeconds),
    );

    await _storage.write(
      key: _tokenKey,
      value: token,
    );

    await _storage.write(
      key: _expiresAtKey,
      value: expiresAt.toIso8601String(),
    );

    await _storage.write(
      key: _userKey,
      value: userJson,
    );

    if (refreshToken != null) {
      await _storage.write(
        key: _refreshTokenKey,
        value: refreshToken,
      );
    }
  }

  /// The access token if it has not expired yet. An expired one is not
  /// deleted: the refresh token can still replace it.
  static Future<String?> readValidToken() async {
    final token = await _storage.read(key: _tokenKey);
    final expiresAtRaw =
        await _storage.read(key: _expiresAtKey);

    if (token == null || expiresAtRaw == null) {
      return null;
    }

    final expiresAt = DateTime.tryParse(expiresAtRaw);

    if (expiresAt == null ||
        DateTime.now().isAfter(expiresAt.subtract(_expirySkew))) {
      return null;
    }

    return token;
  }

  static Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  static Future<String?> readUserJson() {
    return _storage.read(key: _userKey);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}
