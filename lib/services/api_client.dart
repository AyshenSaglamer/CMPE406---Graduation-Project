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

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    required bool auth,
  }) async {
    final headers = <String, String>{
      'Accept':
          'application/json, application/problem+json',
    };

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    if (auth) {
      final token = await TokenStorage.readValidToken();

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

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}$path',
    );

    final request = http.Request(
      method,
      uri,
    )..headers.addAll(headers);

    if (body != null) {
      request.body = jsonEncode(body);
    }

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