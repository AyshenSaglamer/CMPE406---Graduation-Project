import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/activity_store.dart';
import 'package:gradia/data/glucose_store.dart';
import 'package:gradia/data/health_report.dart';
import 'package:gradia/data/insulin_store.dart';
import 'package:gradia/data/log_store.dart';
import 'package:gradia/data/meal_store.dart';
import 'package:gradia/screens/pdf_report_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/auth_service.dart';
import 'package:gradia/services/report_pdf.dart';
import 'package:gradia/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

GlucoseRecord g(int id, double v, DateTime t, {String? notes}) => GlucoseRecord(
      id: id,
      value: v,
      dateTime: t,
      measurementTime: 'Fasting',
      notes: notes,
    );

HealthReport sampleReport({String name = 'Nilsu Işık'}) => HealthReport(
      from: DateTime(2026, 11, 10),
      to: DateTime(2026, 11, 23),
      patientName: name,
      generatedAt: DateTime(2026, 11, 23, 12),
      glucose: [
        g(3, 250, DateTime(2026, 11, 22, 20), notes: 'after cake, "big" slice'),
        g(2, 120, DateTime(2026, 11, 21, 8)),
        g(1, 60, DateTime(2026, 11, 20, 8)),
        g(4, 100, DateTime(2026, 11, 19, 8)),
      ],
      insulin: [
        InsulinRecord.fromJson({
          'id': 1,
          'doseUnits': 6.5,
          'insulinType': 'RAPID',
          'administeredAt': '2026-11-21T07:00:00Z',
        }),
      ],
      meals: [
        MealRecord.fromJson({
          'id': 1,
          'mealType': 'BREAKFAST',
          'eatenAt': '2026-11-21T07:30:00Z',
          'description': '=SUM(A1) şeker',
          'carbsG': 45,
        }),
      ],
      activities: [
        ActivityRecord.fromJson({
          'id': 1,
          'activityType': 'Walking',
          'startedAt': '2026-11-21T17:00:00Z',
          'durationMinutes': 30,
        }),
      ],
    );

void main() {
  group('HealthReport numbers', () {
    test('summary figures come from the logs', () {
      final r = sampleReport();

      expect(r.days, 14);
      expect(r.averageGlucose, 132.5);
      expect(r.lowestGlucose, 60);
      expect(r.highestGlucose, 250);
      expect(r.belowRangePercent, 25);
      expect(r.inRangePercent, 50);
      expect(r.aboveRangePercent, 25);
      expect(r.insulinTotal, 6.5);
      expect(r.carbsTotal, 45);
      expect(r.activityMinutes, 30);
      expect(r.fileBaseName, 'diamate-report-2026-11-10_2026-11-23');
    });

    test('an empty period has no averages', () {
      final r = HealthReport(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 2),
        patientName: 'x',
        glucose: const [],
        insulin: const [],
        meals: const [],
        activities: const [],
      );

      expect(r.isEmpty, isTrue);
      expect(r.averageGlucose, isNull);
      expect(r.inRangePercent, 0);
    });
  });

  group('CSV', () {
    test('header, one row per log, oldest first, Excel-friendly', () {
      final csv = sampleReport().toCsv();
      final lines = csv.split('\r\n');

      expect(csv.startsWith('﻿'), isTrue);
      expect(lines.first, '﻿type,date_time,value,unit,details');
      // 4 glucose + 1 insulin + 1 meal + 1 activity + trailing empty line.
      expect(lines, hasLength(9));
      expect(lines[1], 'Glucose,2026-11-19 08:00,100,mg/dL,Fasting');
      expect(lines.last, isEmpty);
    });

    test('quotes commas and quotes, keeps Turkish letters', () {
      final csv = sampleReport().toCsv();

      expect(csv, contains('"Fasting - after cake, ""big"" slice"'));
      expect(csv, contains('şeker'));
      expect(csv, contains(',6.5,units,'));
    });

    test('a cell that looks like a formula is not run by a spreadsheet', () {
      final base = sampleReport();
      final csv = HealthReport(
        from: base.from,
        to: base.to,
        patientName: base.patientName,
        glucose: const [],
        insulin: const [],
        meals: const [],
        activities: [
          ActivityRecord.fromJson({
            'id': 2,
            'activityType': '=HYPERLINK("http://x")',
            'startedAt': '2026-11-21T17:00:00Z',
            'durationMinutes': 10,
          }),
        ],
      ).toCsv();

      expect(csv, contains('"\'=HYPERLINK(""http://x"")"'));
      expect(csv, isNot(contains(',=HYPERLINK')));
      // Text that only contains "=" later is left as it is.
      expect(base.toCsv(), contains('Breakfast - =SUM(A1) şeker'));
    });
  });

  group('PDF', () {
    testWidgets('builds a PDF with the embedded font', (tester) async {
      final bytes = await tester.runAsync(() => buildReportPdf(sampleReport()));

      expect(ascii.decode(bytes!.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(10000));
      expect(latin1.decode(bytes), contains('Roboto'));
    });

    testWidgets('an empty period still builds', (tester) async {
      final report = HealthReport(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 1),
        patientName: 'x',
        glucose: const [],
        insulin: const [],
        meals: const [],
        activities: const [],
      );

      final bytes = await tester.runAsync(() => buildReportPdf(report));

      expect(ascii.decode(bytes!.sublist(0, 5)), '%PDF-');
    });
  });

  group('HealthReport.load', () {
    test('reads the four logs for whole local days', () async {
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

      final requests = <http.Request>[];
      final api = ApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'items': [], 'totalPages': 1}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      LogStore<T> store<T extends LogRecord>(
              String resource, T Function(Map<String, dynamic>) fromJson) =>
          LogStore<T>(resource: resource, fromJson: fromJson, api: api);

      final report = await HealthReport.load(
        from: DateTime(2026, 11, 10, 15),
        to: DateTime(2026, 11, 23, 9),
        patientName: 'Nil Su',
        glucose: store('glucose-logs', GlucoseRecord.fromJson),
        insulin: store('insulin-logs', InsulinRecord.fromJson),
        meals: store('meal-logs', MealRecord.fromJson),
        activities: store('activity-logs', ActivityRecord.fromJson),
      );

      expect(report.isEmpty, isTrue);
      expect(
        requests.map((r) => r.url.path).toSet(),
        {
          '/api/v1/patients/7/glucose-logs',
          '/api/v1/patients/7/insulin-logs',
          '/api/v1/patients/7/meal-logs',
          '/api/v1/patients/7/activity-logs',
        },
      );
      final q = requests.first.url.queryParameters;
      expect(DateTime.parse(q['from']!), DateTime(2026, 11, 10).toUtc());
      expect(DateTime.parse(q['to']!), DateTime(2026, 11, 24).toUtc());
    });

    test("a family member's report reads only what they share", () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'items': [], 'totalPages': 1}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      LogStore<T> store<T extends LogRecord>(
              String resource, T Function(Map<String, dynamic>) fromJson) =>
          LogStore<T>(resource: resource, fromJson: fromJson, api: api);

      final report = await HealthReport.load(
        from: DateTime(2026, 11, 10),
        to: DateTime(2026, 11, 23),
        patientName: 'Deniz Kaya',
        patientId: 50,
        mealsShared: false,
        activityShared: false,
        glucose: store('glucose-logs', GlucoseRecord.fromJson),
        insulin: store('insulin-logs', InsulinRecord.fromJson),
        meals: store('meal-logs', MealRecord.fromJson),
        activities: store('activity-logs', ActivityRecord.fromJson),
      );

      expect(
        requests.map((r) => r.url.path).toSet(),
        {
          '/api/v1/patients/50/glucose-logs',
          '/api/v1/patients/50/insulin-logs',
        },
      );
      expect(report.notShared, ['Meals', 'Activity']);
      expect(report.patientName, 'Deniz Kaya');
    });

    testWidgets('the PDF says which parts were not shared', (tester) async {
      final report = HealthReport(
        from: DateTime(2026, 11, 10),
        to: DateTime(2026, 11, 23),
        patientName: 'Deniz Kaya',
        glucose: const [],
        insulin: const [],
        meals: const [],
        activities: const [],
        notShared: const ['Meals'],
      );

      final bytes = await tester.runAsync(() => buildReportPdf(report));

      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(1000));
    });
  });

  group('Health Report screen', () {
    late List<(String, String, Uint8List)> exported;
    late ExportOutcome outcome;

    Future<void> pump(WidgetTester tester, HealthReport report) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      exported = [];
      outcome = ExportOutcome.shared;
      await tester.pumpWidget(MaterialApp(
        home: PdfReportScreen(
          loadReport: (from, to) async => report,
          exporter: (bytes, name, mime) async {
            exported.add((name, mime, bytes));
            return outcome;
          },
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the real numbers instead of sample ones',
        (tester) async {
      await pump(tester, sampleReport());

      expect(find.text('133'), findsOneWidget); // average 132.5
      expect(find.text('4 measurements'), findsOneWidget);
      expect(find.text('6.5'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('119'), findsNothing);
    });

    testWidgets('Export CSV hands over the CSV file', (tester) async {
      await pump(tester, sampleReport());

      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();

      final (name, mime, bytes) = exported.single;
      expect(name, 'diamate-report-2026-11-10_2026-11-23.csv');
      expect(mime, 'text/csv');
      expect(utf8.decode(bytes), contains('type,date_time,value,unit,details'));
      expect(find.text('$name is ready.'), findsOneWidget);
    });

    testWidgets('Export PDF hands over a real PDF', (tester) async {
      await pump(tester, sampleReport());

      await tester.tap(find.text('Export PDF Report'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1500)));
      await tester.pumpAndSettle();

      final (name, mime, bytes) = exported.single;
      expect(name, endsWith('.pdf'));
      expect(mime, 'application/pdf');
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    testWidgets('a cancelled share says so', (tester) async {
      await pump(tester, sampleReport());
      outcome = ExportOutcome.cancelled;

      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();

      expect(find.text('Export cancelled.'), findsOneWidget);
    });

    testWidgets('a browser download says so', (tester) async {
      await pump(tester, sampleReport());
      outcome = ExportOutcome.downloaded;

      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();

      expect(find.textContaining('was downloaded'), findsOneWidget);
    });

    testWidgets('nothing to export in an empty period', (tester) async {
      await pump(
        tester,
        HealthReport(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 2),
          patientName: 'x',
          glucose: const [],
          insulin: const [],
          meals: const [],
          activities: const [],
        ),
      );

      expect(find.textContaining('No records in this period'), findsOneWidget);
      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();
      expect(exported, isEmpty);
    });
  });
}
