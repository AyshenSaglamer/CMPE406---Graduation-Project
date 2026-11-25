import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static void Function()? onUnauthorized;

  /// The refresh in progress, shared by every request that needs it: a
  /// refresh token works only once, so two parallel refreshes would end the
  /// session (the backend takes the second one for a stolen copy).
  Future<bool>? _refreshing;

  Future<dynamic> get(
    String path, {
    bool auth = true,
  }) {
    return _send(
      'GET',
      path,
      auth: auth,
    );
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    bool auth = true,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      auth: auth,
    );
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    bool auth = true,
  }) {
    return _send(
      'PUT',
      path,
      body: body,
      auth: auth,
    );
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    bool auth = true,
  }) {
    return _send(
      'PATCH',
      path,
      body: body,
      auth: auth,
    );
  }

  Future<dynamic> delete(
    String path, {
    bool auth = true,
  }) {
    return _send(
      'DELETE',
      path,
      auth: auth,
    );
  }

  /// POST multipart/form-data with one file in [field] (e.g. a voice
  /// recording). The file is sent as application/octet-stream; the backend
  /// decides its type by the extension of [filename].
  Future<dynamic> postFile(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
    bool auth = true,
  }) async {
    return _execute(
      () async => http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(await _headers(auth: auth))
        ..files.add(http.MultipartFile.fromBytes(
          field,
          bytes,
          filename: filename,
        )),
      auth: auth,
    );
  }

  /// Gets a new access token with the saved refresh token
  /// (POST /auth/refresh) and saves both new tokens. False when there is no
  /// refresh token, the backend refused it (the session is cleared), or the
  /// server cannot be reached (the session is kept, e.g. while offline).
  Future<bool> refreshSession() {
    return _refreshing ??=
        _refresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _refresh() async {
    final refreshToken = await TokenStorage.readRefreshToken();
    final userJson = await TokenStorage.readUserJson();

    if (refreshToken == null || userJson == null) {
      return false;
    }

    final http.Response response;

    try {
      response = await _http
          .post(
            _uri('/auth/refresh'),
            headers: {
              'Accept': 'application/json, application/problem+json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(ApiConfig.timeout);
    } on TimeoutException {
      return false;
    } on http.ClientException {
      return false;
    }

    final decoded = _decode(response);

    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      await TokenStorage.save(
        token: decoded['accessToken'] as String,
        expiresInSeconds: (decoded['expiresIn'] as num).toInt(),
        refreshToken: decoded['refreshToken'] as String?,
        userJson: userJson,
      );
      return true;
    }

    if (response.statusCode == 401 || response.statusCode == 400) {
      // Logged out, expired or already used: only a new login helps.
      await TokenStorage.clear();
    }

    return false;
  }

  Uri _uri(String path) =>
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.apiPrefix}$path');

  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = <String, String>{
      'Accept':
          'application/json, application/problem+json',
    };

    if (auth) {
      var token = await TokenStorage.readValidToken();

      if (token == null && await refreshSession()) {
        token = await TokenStorage.readValidToken();
      }

      if (token == null) {
        onUnauthorized?.call();

        throw const ApiException(
          statusCode: 401,
          message:
              'Your session has expired. Please log in again.',
        );
      }

      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    required bool auth,
  }) async {
    return _execute(
      () async {
        final headers = await _headers(auth: auth);

        if (body != null) {
          headers['Content-Type'] = 'application/json';
        }

        final request = http.Request(
          method,
          _uri(path),
        )..headers.addAll(headers);

        if (body != null) {
          request.body = jsonEncode(body);
        }

        return request;
      },
      auth: auth,
    );
  }

  /// Sends the request built by [build]. A 401 on an authenticated request
  /// (the access token was revoked or ran out on the way) gets one refresh
  /// and one retry with the new token; a request can be sent only once, so
  /// [build] makes a fresh one.
  Future<dynamic> _execute(
    Future<http.BaseRequest> Function() build, {
    required bool auth,
    bool retried = false,
  }) async {
    final request = await build();
    final http.Response response;

    try {
      final streamed = await _http
          .send(request)
          .timeout(ApiConfig.timeout);

      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        message:
            'The server is not responding. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        statusCode: 0,
        message:
            'Cannot reach the server. Check your internet connection.',
      );
    }

    final decoded = _decode(response);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401 && auth) {
      if (!retried && await refreshSession()) {
        return _execute(build, auth: auth, retried: true);
      }
      await TokenStorage.clear();
      onUnauthorized?.call();
    }

    throw _toApiException(
      response.statusCode,
      decoded,
    );
  }

  dynamic _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      );
    } on FormatException {
      return null;
    }
  }

  ApiException _toApiException(
    int statusCode,
    dynamic body,
  ) {
    var message = _defaultMessage(statusCode);

    final fieldErrors = <String, String>{};

    if (body is Map<String, dynamic>) {
      final detail = body['detail'];

      if (detail is String && detail.isNotEmpty) {
        message = detail;
      }

      final errors = body['errors'];

      if (errors is Map) {
        errors.forEach(
          (key, value) {
            fieldErrors['$key'] = '$value';
          },
        );
      }
    }

    return ApiException(
      statusCode: statusCode,
      message: message,
      fieldErrors: fieldErrors,
    );
  }

  String _defaultMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Some fields are invalid.';
      case 401:
        return 'Please log in again.';
      case 403:
        return 'You do not have permission to do this.';
      case 404:
        return 'The requested data was not found.';
      case 409:
        return 'This record already exists.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

final apiClient = ApiClient();