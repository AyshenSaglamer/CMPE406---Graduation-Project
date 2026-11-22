import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/ai_store.dart';
import 'package:gradia/screens/ai_assistant_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:gradia/services/voice_recorder.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A stand-in for POST /ai/voice (multipart field "audio") and
/// POST /patients/7/ai-entries.
class FakeBackend {
  final requests = <http.Request>[];
  final saves = <Map<String, dynamic>>[];

  int voiceStatus = 200;
  String transcript = 'My glucose is 140';
  List<Map<String, dynamic>> results = [
    {
      'intent': 'LOG_GLUCOSE',
      'status': 'SUCCESS',
      'value': 140.0,
      'unit': 'mg/dL',
      'activity': null,
      'message': null,
    },
  ];

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;

    if (request.headers['Authorization'] != 'Bearer test-token') {
      return _json(401, {'detail': 'Authentication required'});
    }

    if (path == '/api/v1/ai/voice' && request.method == 'POST') {
      if (voiceStatus != 200) {
        return _json(voiceStatus, {'detail': 'Voice failed ($voiceStatus)'});
      }
      return _json(200, {
        'status': results.isEmpty ? 'UNKNOWN' : 'SUCCESS',
        'transcript': transcript,
        'resultCount': results.length,
        'results': results,
        'message': results.isEmpty ? 'I could not understand that.' : null,
      });
    }

    if (path == '/api/v1/patients/7/ai-entries' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      saves.add(body);
      final count = (body['entries'] as List).length;
      return _json(201, {'savedCount': count, 'saved': []});
    }

    return _json(404, {'detail': 'Resource not found'});
  });

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

/// A microphone that "records" fixed bytes.
class FakeRecorder implements VoiceRecorder {
  bool permission = true;
  bool throwOnStart = false;
  Uint8List? recording = Uint8List.fromList(
    wavFromPcm16(Uint8List(3200), sampleRate: 16000, channels: 1),
  );

  int starts = 0;
  int stops = 0;
  int cancels = 0;

  @override
  Future<bool> start() async {
    if (throwOnStart) {
      throw Exception('no microphone');
    }
    starts++;
    return permission;
  }

  @override
  Future<RecordedAudio?> stop() async {
    stops++;
    final bytes = recording;
    return bytes == null
        ? null
        : RecordedAudio(
            bytes: bytes,
            filename: 'recording.wav',
            duration: const Duration(seconds: 4),
          );
  }

  @override
  Future<void> cancel() async => cancels++;

  @override
  void dispose() {}
}

class _PatientStore extends AiStore {
  _PatientStore(ApiClient api) : super(api: api);

  @override
  Future<int> save(List<AiEntry> entries, {int? patientId}) =>
      super.save(entries, patientId: patientId ?? 7);
}

void main() {
  late FakeBackend backend;
  late ApiClient api;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'access_token_expires_at':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    backend = FakeBackend();
    api = ApiClient(httpClient: backend.client);
  });

  group('wavFromPcm16', () {
    test('writes a 44-byte RIFF/WAVE header for 16 kHz mono 16-bit', () {
      final pcm = Uint8List.fromList(List.generate(10, (i) => i));
      final wav = wavFromPcm16(pcm, sampleRate: 16000, channels: 1);
      final data = ByteData.sublistView(wav);

      expect(wav.length, 54);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(data.getUint32(4, Endian.little), 36 + 10);
      expect(ascii.decode(wav.sublist(8, 16)), 'WAVEfmt ');
      expect(data.getUint16(20, Endian.little), 1); // PCM
      expect(data.getUint16(22, Endian.little), 1); // mono
      expect(data.getUint32(24, Endian.little), 16000);
      expect(data.getUint32(28, Endian.little), 32000); // byte rate
      expect(data.getUint16(32, Endian.little), 2); // block align
      expect(data.getUint16(34, Endian.little), 16);
      expect(ascii.decode(wav.sublist(36, 40)), 'data');
      expect(data.getUint32(40, Endian.little), 10);
      expect(wav.sublist(44), pcm);
    });
  });

  group('AiStore.parseVoice', () {
    test('sends the recording as multipart field "audio"', () async {
      final store = AiStore(api: api);
      final wav = wavFromPcm16(Uint8List(4), sampleRate: 16000, channels: 1);

      final result = await store.parseVoice(wav, 'recording.wav');

      final request = backend.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/ai/voice');
      expect(request.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="audio"; filename="recording.wav"'));
      expect(body, contains('RIFF'));

      expect(result.transcript, 'My glucose is 140');
      expect(result.parsed.savable.single.value, 140.0);
    });

    test('passes the backend error on', () async {
      backend.voiceStatus = 400;

      expect(
        () => AiStore(api: api).parseVoice([1, 2, 3], 'recording.wav'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', 'Voice failed (400)')),
      );
    });
  });

  group('voice logging in AiAssistantScreen', () {
    late FakeRecorder recorder;

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      recorder = FakeRecorder();
      await tester.pumpWidget(MaterialApp(
        home: AiAssistantScreen(
          store: _PatientStore(api),
          recorder: recorder,
          onSaved: () async {},
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    testWidgets('record, stop, see the transcript and save', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Speak'));
      await tester.pump();

      expect(find.text('Listening… 0:00'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Listening… 0:02'), findsOneWidget);

      await tester.tap(find.byTooltip('Stop and send'));
      await settle(tester);

      expect(recorder.stops, 1);
      expect(find.text('Voice message (0:04)'), findsOneWidget);
      expect(find.text('I heard: "My glucose is 140"'), findsOneWidget);
      expect(find.text('Here is what I understood. Shall I save it?'),
          findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text('Save'));
      await settle(tester);

      final saved = backend.saves.single['entries'] as List;
      expect(saved.single['intent'], 'LOG_GLUCOSE');
      expect(saved.single['value'], 140.0);
      expect(find.text('Saved 1 entry to your logs.'), findsOneWidget);
    });

    testWidgets('Cancel throws the recording away', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Speak'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(recorder.cancels, 1);
      expect(recorder.stops, 0);
      expect(backend.requests, isEmpty);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('stops by itself after the maximum length', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Speak'));
      await tester.pump();
      await tester.pump(AiAssistantScreen.maxRecording);
      await settle(tester);

      expect(recorder.stops, 1);
      expect(find.text('I heard: "My glucose is 140"'), findsOneWidget);
    });

    testWidgets('refused microphone permission is explained', (tester) async {
      await pumpScreen(tester);
      recorder.permission = false;

      await tester.tap(find.byTooltip('Speak'));
      await tester.pumpAndSettle();

      expect(find.textContaining('I need access to the microphone'),
          findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a microphone that fails to start is explained',
        (tester) async {
      await pumpScreen(tester);
      recorder.throwOnStart = true;

      await tester.tap(find.byTooltip('Speak'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be started'), findsOneWidget);
    });

    testWidgets('an empty recording is not sent', (tester) async {
      await pumpScreen(tester);
      recorder.recording = null;

      await tester.tap(find.byTooltip('Speak'));
      await tester.pump();
      await tester.tap(find.byTooltip('Stop and send'));
      await tester.pumpAndSettle();

      expect(find.textContaining('I did not hear anything'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('no words heard asks to try again', (tester) async {
      await pumpScreen(tester);
      backend.transcript = '';
      backend.results = [];

      await tester.tap(find.byTooltip('Speak'));
      await tester.pump();
      await tester.tap(find.byTooltip('Stop and send'));
      await settle(tester);

      expect(find.textContaining('could not make out any words'),
          findsOneWidget);
    });

    testWidgets('the AI service being down shows the backend message',
        (tester) async {
      await pumpScreen(tester);
      backend.voiceStatus = 503;

      await tester.tap(find.byTooltip('Speak'));
      await tester.pump();
      await tester.tap(find.byTooltip('Stop and send'));
      await settle(tester);

      expect(find.text('Voice failed (503)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
