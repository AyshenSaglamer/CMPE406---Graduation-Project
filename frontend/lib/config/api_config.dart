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

  /// For file uploads (voice message, meal photo). The backend waits up to
  /// 60 s for speech recognition (ai.voice-read-timeout) and 30 s for the
  /// photo model, and the first voice message after a restart also loads the
  /// Whisper model, so [timeout] would give up while the answer is still on
  /// its way and hide the real result ("no speech detected", the foods...).
  static const Duration uploadTimeout = Duration(seconds: 90);
}