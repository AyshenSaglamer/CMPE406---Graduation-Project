import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/ai_store.dart';
import 'package:gradia/screens/ai_assistant_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A small stand-in for POST /ai/parse and POST /patients/{id}/ai-entries.
/// The parser only knows a few words, enough for the tests.
class FakeBackend {
  final requests = <http.Request>[];

  /// Bodies of the ai-entries requests.
  final saves = <Map<String, dynamic>>[];

  /// clientUuids saved so far: a resent entry is not saved twice.
  final savedUuids = <String>{};

  bool aiServiceDown = false;

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;

    if (request.headers['Authorization'] != 'Bearer test-token') {
      return _problem(401, 'Authentication required');
    }

    if (path == '/api/v1/ai/parse' && request.method == 'POST') {
      if (aiServiceDown) {
        return _problem(503, 'The AI service is currently unavailable');
      }
      final text = ((jsonDecode(request.body) as Map)['text'] as String).toLowerCase();
      return _json(200, _parse(text));
    }

    if (path == '/api/v1/patients/7/ai-entries' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      saves.add(body);
      final entries = body['entries'] as List<dynamic>;
      var anyCreated = false;
      final saved = [
        for (final (i, e) in entries.indexed)
          {
            'intent': e['intent'],
            'id': 500 + i,
            'created': savedUuids.add(e['clientUuid'] as String)
                ? (anyCreated = true)
                : false,
            'log': <String, dynamic>{},
          },
      ];
      return _json(anyCreated ? 201 : 200, {'savedCount': saved.length, 'saved': saved});
    }

    return _problem(404, 'Resource not found');
  });

  static Map<String, dynamic> _parse(String text) {
    final results = <Map<String, dynamic>>[];

    final glucose = RegExp(r'glucose is (\d+)').firstMatch(text);
    if (glucose != null) {
      results.add(_entry('LOG_GLUCOSE', double.parse(glucose.group(1)!), 'mg/dL'));
    }

    final insulin = RegExp(r'(\d+) units').firstMatch(text);
    if (insulin != null) {
      results.add(_entry('LOG_INSULIN', double.parse(insulin.group(1)!), 'units'));
    } else if (text.contains('insulin')) {
      results.add({
        'intent': 'LOG_INSULIN',
        'status': 'MISSING_VALUE',
        'value': null,
        'unit': null,
        'activity': null,
        'message': 'How many units of insulin?',
      });
    }

    final walked = RegExp(r'walked for (\d+) minutes').firstMatch(text);
    if (walked != null) {
      results.add({..._entry('LOG_ACTIVITY', double.parse(walked.group(1)!), 'minutes'), 'activity': 'walked'});
    }

    if (results.isEmpty) {
      return {'status': 'UNKNOWN', 'resultCount': 0, 'results': [], 'message': 'I could not understand that.'};
    }
    return {'status': 'SUCCESS', 'resultCount': results.length, 'results': results, 'message': null};
  }

  static Map<String, dynamic> _entry(String intent, double value, String unit) => {
        'intent': intent,
        'status': 'SUCCESS',
        'value': value,
        'unit': unit,
        'activity': null,
        'message': null,
      };

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );

  static http.Response _problem(int status, String detail) =>
      _json(status, {'detail': detail, 'status': status});
}

void main() {
  late FakeBackend backend;
  late AiStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'access_token_expires_at':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    backend = FakeBackend();
    store = AiStore(api: ApiClient(httpClient: backend.client));
  });

  group('AiStore', () {
    test('parse sends the text and reads every entry', () async {
      final result = await store.parse('  My glucose is 125 and I took 5 units of insulin ');

      final request = backend.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/ai/parse');
      expect(jsonDecode(request.body), {'text': 'My glucose is 125 and I took 5 units of insulin'});

      expect(result.status, 'SUCCESS');
      expect(result.entries.map((e) => e.intent), ['LOG_GLUCOSE', 'LOG_INSULIN']);
      expect(result.entries.first.value, 125);
      expect(result.entries.first.unit, 'mg/dL');
      expect(result.entries.first.title, 'Glucose');
      expect(result.savable, hasLength(2));
    });

    test('an entry without a value cannot be saved', () async {
      final result = await store.parse('I took insulin');

      final entry = result.entries.single;
      expect(entry.status, 'MISSING_VALUE');
      expect(entry.canSave, isFalse);
      expect(entry.message, 'How many units of insulin?');
      expect(result.savable, isEmpty);
    });

    test('nothing understood gives UNKNOWN and the message', () async {
      final result = await store.parse('hello');

      expect(result.status, 'UNKNOWN');
      expect(result.entries, isEmpty);
      expect(result.message, 'I could not understand that.');
    });

    test('save sends the confirmed entries with a clientUuid each', () async {
      final result = await store.parse('I walked for 30 minutes and my glucose is 110');

      final saved = await store.save(result.savable, patientId: 7);

      expect(saved, 2);
      final entries = backend.saves.single['entries'] as List<dynamic>;
      expect(entries[0], {
        'intent': 'LOG_GLUCOSE',
        'value': 110.0,
        'unit': 'mg/dL',
        'clientUuid': result.entries[0].clientUuid,
      });
      expect(entries[1]['intent'], 'LOG_ACTIVITY');
      expect(entries[1]['activity'], 'walked');
      expect(entries[1]['unit'], 'minutes');
    });

    test('saving the same entries again does not store them twice', () async {
      final result = await store.parse('My glucose is 125');

      await store.save(result.savable, patientId: 7);
      await store.save(result.savable, patientId: 7);

      expect(backend.savedUuids, hasLength(1));
    });

    test('more than 10 entries are saved in requests of at most 10', () async {
      final entries = [
        for (var i = 0; i < 12; i++)
          AiEntry(intent: AiEntry.glucose, status: 'SUCCESS', value: 100.0 + i, unit: 'mg/dL'),
      ];

      expect(await store.save(entries, patientId: 7), 12);
      expect(backend.saves.map((s) => (s['entries'] as List).length), [10, 2]);
    });

    test('the AI service being down gives the backend message', () async {
      backend.aiServiceDown = true;

      expect(
        () => store.parse('My glucose is 125'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.message, 'message', 'The AI service is currently unavailable')),
      );
    });

    test('newUuid gives version 4 UUIDs', () {
      final a = newUuid();
      expect(
        a,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
      expect(newUuid(), isNot(a));
    });
  });

  group('AiAssistantScreen', () {
    late int reloads;

    /// Saves go to patient 7, as if patient 7 were logged in.
    Future<void> pumpScreen(WidgetTester tester) async {
      reloads = 0;
      // Tall enough that every chat row is built (ListView is lazy).
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final patientStore = _PatientStore(store);
      await tester.pumpWidget(MaterialApp(
        home: AiAssistantScreen(
          store: patientStore,
          onSaved: () async => reloads++,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> send(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows what was understood and saves it after Save', (tester) async {
      await pumpScreen(tester);

      await send(tester, 'My glucose is 125 and I took 5 units of insulin');

      expect(find.text('Here is what I understood. Shall I save it?'), findsOneWidget);
      expect(find.text('Glucose'), findsNWidgets(2)); // quick prompt + entry
      expect(find.text('125 mg/dL'), findsOneWidget);
      expect(find.text('Insulin'), findsNWidgets(2));
      expect(find.text('5 units'), findsOneWidget);
      // Nothing is saved before the patient confirms.
      expect(backend.saves, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(backend.saves.single['entries'], hasLength(2));
      expect(find.text('Saved 2 entries to your logs.'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(reloads, 1);
    });

    testWidgets('Cancel saves nothing', (tester) async {
      await pumpScreen(tester);

      await send(tester, 'My glucose is 125');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(backend.saves, isEmpty);
      expect(find.text('Okay, nothing was saved.'), findsOneWidget);
      expect(find.text('Not saved'), findsOneWidget);
      expect(reloads, 0);
    });

    testWidgets('a missing value is explained and cannot be saved', (tester) async {
      await pumpScreen(tester);

      await send(tester, 'I took insulin');

      expect(find.text('I understood this, but something is missing:'), findsOneWidget);
      expect(find.text('How many units of insulin?'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    });

    testWidgets('nothing understood shows the backend message', (tester) async {
      await pumpScreen(tester);

      await send(tester, 'hello');

      expect(find.text('I could not understand that.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    });

    testWidgets('the AI service being down is shown in the chat', (tester) async {
      backend.aiServiceDown = true;
      await pumpScreen(tester);

      await send(tester, 'My glucose is 125');

      expect(find.text('The AI service is currently unavailable'), findsOneWidget);
    });

    testWidgets('a quick prompt fills the text field without sending', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'I walked for 30 minutes');
      expect(backend.requests, isEmpty);
    });
  });
}

/// The screen saves for the logged-in patient; in tests nobody is logged in,
/// so this passes patient 7 explicitly.
class _PatientStore extends AiStore {
  _PatientStore(this._inner);

  final AiStore _inner;

  @override
  Future<AiParseResult> parse(String text) => _inner.parse(text);

  @override
  Future<int> save(List<AiEntry> entries, {int? patientId}) =>
      _inner.save(entries, patientId: patientId ?? 7);
}
