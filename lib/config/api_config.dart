import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const String _override =
      String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) {
      return _override;
    }

    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }

    return 'http://localhost:8080';
  }

  static const String apiPrefix = '/api/v1';

  static const Duration timeout = Duration(seconds: 15);
}