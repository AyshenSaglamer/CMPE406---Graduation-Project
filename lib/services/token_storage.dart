import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _expiresAtKey = 'access_token_expires_at';
  static const _userKey = 'current_user';

  static Future<void> save({
    required String token,
    required int expiresInSeconds,
    required String userJson,
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
  }

  static Future<String?> readValidToken() async {
    final token = await _storage.read(key: _tokenKey);
    final expiresAtRaw =
        await _storage.read(key: _expiresAtKey);

    if (token == null || expiresAtRaw == null) {
      return null;
    }

    final expiresAt = DateTime.tryParse(expiresAtRaw);

    if (expiresAt == null ||
        DateTime.now().isAfter(expiresAt)) {
      await clear();
      return null;
    }

    return token;
  }

  static Future<String?> readUserJson() {
    return _storage.read(key: _userKey);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _userKey);
  }
}