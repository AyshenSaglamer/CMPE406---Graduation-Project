import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/glucose_csv.dart';
import 'package:gradia/data/glucose_store.dart';
import 'package:gradia/data/log_store.dart';
import 'package:gradia/data/offline_queue.dart';
import 'package:gradia/screens/csv_import_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/auth_service.dart';
import 'package:gradia/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Test-only stand-in for POST /patients/7/glucose-logs: keeps one log per
/// clientUuid like the backend (a repeat returns the saved log).
class FakeGlucoseBackend {
  final saved = <String, Map<String, dynamic>>{};
  var posts = 0;
  var _id = 900;

  /// Values the backend refuses with 400.
  final refuse = <int>{};

  late final client = MockClient((request) async {
    if (request.method != 'POST' ||
        request.url.path != '/api/v1/patients/7/glucose-logs') {
      return http.Response('{"message":"not found"}', 404);
    }
    posts++;
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (refuse.contains(body['glucoseValue'])) {
      return http.Response('{"detail":"Glucose value refused"}', 400);
    }
    final uuid = body['clientUuid'] as String;
    final log = saved[uuid] ??= {
      'id': _id++,
      'glucoseValue': body['glucoseValue'],
      'measurementTime': body['measurementTime'],
      'mealContext': body['mealContext'],
      'notes': body['notes'],
    };
    return http.Response(jsonEncode(log), 200,
        headers: {'content-type': 'application/json'});
  });
}

void main() {
  // Monday 23 November 2026, 12:00 on the phone.
  final now = DateTime(2026, 11, 23, 12);

  group('GlucoseCsv.parse', () {
    test('date, time and glucose columns', () {
      final rows = GlucoseCsv.parse(
        'date,time,glucose\n2026-11-23,08:30,105\n2026-11-22,21:05,148\n',
        now: now,
      );

      expect(rows, hasLength(2));
      expect(rows.every((r) => r.isValid), isTrue);
      expect(rows.first.measuredAt, DateTime(2026, 11, 23, 8, 30));
      expect(rows.first.value, 105);
      expect(rows.first.line, 2);
    });

    test('semicolons, day-first dates, decimal comma, any column order', () {
      final rows = GlucoseCsv.parse(
        'Glucose (mg/dL);Saat;Tarih\n"105,4";08:30;23.11.2026\n',
        now: now,
      );

      expect(rows.single.isValid, isTrue);
      expect(rows.single.value, 105);
      expect(rows.single.measuredAt, DateTime(2026, 11, 23, 8, 30));
    });

    test('one datetime column, context and notes', () {
      final rows = GlucoseCsv.parse(
        'timestamp,value,context,notes\n'
        '2026-11-23 07:15,92,Fasting,"before breakfast, felt ok"\n'
        '2026-11-23T09:40:00,160,after_meal,\n',
        now: now,
      );

      expect(rows.map((r) => r.isValid), [true, true]);
      expect(rows[0].mealContext, 'FASTING');
      expect(rows[0].notes, 'before breakfast, felt ok');
      expect(rows[1].mealContext, 'AFTER_MEAL');
      expect(rows[1].measuredAt, DateTime(2026, 11, 23, 9, 40));
    });

    test('each kind of bad row says what is wrong', () {
      final rows = GlucoseCsv.parse(
        'date,time,glucose,context\n'
        '2026-11-23,08:10,abc,\n'
        '2026-11-23,08:20,5,\n'
        '2026-11-23,08:30,700,\n'
        '31.02.2026,08:40,100,\n'
        '2026-11-23,25:00,100,\n'
        '2026-11-24,08:00,100,\n'
        '2026-11-23,08:50,100,Lunch\n'
        '2026-11-23,09:00,120,\n'
        '2026-11-23,09:00,120,\n',
        now: now,
      );

      expect(rows.map((r) => r.problem), [
        'Glucose is not a number',
        'Glucose must be 10–600 mg/dL',
        'Glucose must be 10–600 mg/dL',
        'Unreadable date or time',
        'Unreadable date or time',
        'Date is in the future',
        'Unknown context "Lunch"',
        null,
        'Same reading twice in the file',
      ]);
    });

    test('a header without date or glucose is refused', () {
      expect(() => GlucoseCsv.parse('time,glucose\n08:30,105', now: now),
          throwsFormatException);
      expect(() => GlucoseCsv.parse('date,time\n2026-11-23,08:30', now: now),
          throwsFormatException);
      expect(() => GlucoseCsv.parse('', now: now), throwsFormatException);
    });

    test('the same reading always gets the same clientUuid', () {
      final at = DateTime(2026, 11, 23, 8, 30);
      final a = GlucoseCsv.clientUuidFor(at, 105);

      expect(a, GlucoseCsv.clientUuidFor(at, 105));
      expect(a, isNot(GlucoseCsv.clientUuidFor(at, 106)));
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(a),
        isTrue,
      );
    });

    test('request body matches GlucoseLogRequest', () {
      final row = GlucoseCsv.parse(
        'date,time,glucose,context\n2026-11-23,08:30,105,Fasting',
        now: now,
      ).single;

      expect(row.requestBody(), {
        'glucoseValue': 105,
        'measurementTime': DateTime(2026, 11, 23, 8, 30).toUtc().toIso8601String(),
        'mealContext': 'FASTING',
        'source': 'MANUAL',
        'clientUuid': GlucoseCsv.clientUuidFor(DateTime(2026, 11, 23, 8, 30), 105),
      });
    });
  });

  group('CsvImportScreen', () {
    late FakeGlucoseBackend backend;
    late LogStore<GlucoseRecord> store;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await TokenStorage.save(
        token: 'test-token',
        expiresInSeconds: 3600,
        userJson: jsonEncode({
          'id': 7,
          'firstName': 'Nil',
          'lastName': 'Su',
          'email': 'n@example.com',
          'role': 'PATIENT',
        }),
      );
      await authService.restoreSession();

      backend = FakeGlucoseBackend();
      final api = ApiClient(httpClient: backend.client);
      store = LogStore<GlucoseRecord>(
        resource: 'glucose-logs',
        fromJson: GlucoseRecord.fromJson,
        api: api,
        queue: OfflineQueue(api: api),
      );
    });

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    Future<void> pump(WidgetTester tester, String csv) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: CsvImportScreen(
          store: store,
          pickFile: () async => (
            name: 'my_meter.csv',
            bytes: Uint8List.fromList(utf8.encode(csv)),
          ),
        ),
      ));
    }

    Future<void> chooseFile(WidgetTester tester) async {
      await tester.tap(find.text('Choose File'));
      await settle(tester);
    }

    testWidgets('no sample data before a file is picked', (tester) async {
      await pump(tester, 'date,time,glucose\n2026-11-20,08:30,105\n');

      expect(find.text('Data Preview'), findsNothing);
      expect(find.textContaining('blood_glucose_data'), findsNothing);
    });

    testWidgets('picked file is previewed and its valid rows are saved',
        (tester) async {
      await pump(
        tester,
        'date,time,glucose\n'
        '2026-11-20,08:30,105\n'
        '2026-11-20,13:00,abc\n'
        '2026-11-21,08:00,98\n',
      );
      await chooseFile(tester);

      expect(find.text('my_meter.csv'), findsOneWidget);
      expect(find.text('105 mg/dL'), findsOneWidget);
      expect(find.text('Line 3: Glucose is not a number'), findsOneWidget);
      expect(find.textContaining('1 of 3 rows have a problem'), findsOneWidget);

      await tester.tap(find.text('Import 2 readings'));
      await settle(tester);

      expect(backend.posts, 2);
      expect(backend.saved.values.map((l) => l['glucoseValue']), [105, 98]);
      expect(find.text('2 readings imported, 1 skipped.'), findsOneWidget);
    });

    testWidgets('importing the same file twice does not duplicate logs',
        (tester) async {
      await pump(tester, 'date,time,glucose\n2026-11-20,08:30,105\n');
      await chooseFile(tester);

      await tester.tap(find.text('Import 1 reading'));
      await settle(tester);
      await tester.tap(find.text('Import 1 reading'));
      await settle(tester);

      expect(backend.posts, 2);
      expect(backend.saved, hasLength(1));
    });

    testWidgets('a reading the backend refuses is listed', (tester) async {
      backend.refuse.add(98);
      await pump(
        tester,
        'date,time,glucose\n2026-11-20,08:30,105\n2026-11-21,08:00,98\n',
      );
      await chooseFile(tester);

      await tester.tap(find.text('Import 2 readings'));
      await settle(tester);

      expect(find.text('Some readings were not saved'), findsOneWidget);
      expect(find.textContaining('Line 3: Glucose value refused'), findsOneWidget);
      expect(backend.saved, hasLength(1));
    });

    testWidgets('a file without a glucose column explains the format',
        (tester) async {
      await pump(tester, 'day,hour,sugar\n2026-11-20,08:30,105\n');
      await chooseFile(tester);

      expect(find.text('This file cannot be read'), findsOneWidget);
      expect(find.textContaining('No glucose column'), findsOneWidget);
      expect(find.text('Data Preview'), findsNothing);
    });
  });
}
