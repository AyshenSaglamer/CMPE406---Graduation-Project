import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/config/api_config.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A backend that answers after [delay], like speech recognition does.
MockClient slowBackend(Duration delay) => MockClient((request) async {
      await Future<void>.delayed(delay);
      return http.Response.bytes(
        utf8.encode(jsonEncode({'ok': true})),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

void main() {
  test('uploads wait longer than ordinary requests', () {
    // The backend waits up to 60 s for speech recognition.
    expect(ApiConfig.uploadTimeout, greaterThan(const Duration(seconds: 60)));
    expect(ApiConfig.uploadTimeout, greaterThan(ApiConfig.timeout));
  });

  group('a slow answer', () {
    late ApiClient api;

    setUp(() {
      api = ApiClient(
        httpClient: slowBackend(const Duration(milliseconds: 300)),
        timeout: const Duration(milliseconds: 50),
        uploadTimeout: const Duration(seconds: 5),
      );
    });

    test('ends an ordinary request with "not responding"', () async {
      await expectLater(
        api.post('/ai/parse', body: {'text': 'x'}, auth: false),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 0)
            .having((e) => e.message, 'message', contains('not responding'))),
      );
    });

    test('still arrives for a voice message or photo', () async {
      final answer = await api.postFile(
        '/ai/voice',
        field: 'audio',
        bytes: const [1, 2, 3],
        filename: 'voice.wav',
        auth: false,
      );

      expect(answer, {'ok': true});
    });
  });
}
