import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/ai_insights_store.dart';
import 'package:gradia/data/care_patients_store.dart';
import 'package:gradia/data/glucose_store.dart';
import 'package:gradia/data/log_store.dart';
import 'package:gradia/screens/care_invitations_screen.dart';
import 'package:gradia/screens/care_patient_detail_screen.dart';
import 'package:gradia/screens/caregiver_dashboard_screen.dart';
import 'package:gradia/screens/doctor_dashboard_screen.dart';
import 'package:gradia/screens/pdf_report_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> member(int id, String first, String last,
        {bool glucose = true, bool reports = true}) =>
    {
      'patientId': id,
      'firstName': first,
      'lastName': last,
      'canViewGlucose': glucose,
      'canViewMeals': true,
      'canViewMedications': true,
      'canViewActivity': true,
      'canViewReports': reports,
      'canReceiveAlerts': true,
      'canAddRecommendations': false,
    };

/// Test-only stand-in for the care-team endpoints the doctor screens read.
class FakeBackend {
  final requests = <http.Request>[];

  List<Map<String, dynamic>> members = [];

  /// patientId -> overview; a missing id answers 404 (no patient profile).
  Map<int, Map<String, dynamic>> overviews = {};

  /// patientId -> glucose logs, newest first.
  Map<int, List<Map<String, dynamic>>> glucose = {};

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;

    if (request.headers['Authorization'] != 'Bearer test-token') {
      return _json(401, {'detail': 'Authentication required'});
    }

    if (path == '/api/v1/care-team/patients') {
      return _json(200, members);
    }

    final overview = RegExp(r'^/api/v1/patients/(\d+)/overview$').firstMatch(path);
    if (overview != null) {
      final o = overviews[int.parse(overview.group(1)!)];
      return o == null
          ? _json(404, {'detail': 'Patient not found'})
          : _json(200, o);
    }

    final logs =
        RegExp(r'^/api/v1/patients/(\d+)/glucose-logs$').firstMatch(path);
    if (logs != null) {
      final items = glucose[int.parse(logs.group(1)!)] ?? [];
      return _json(200, {
        'items': items,
        'page': 0,
        'size': 200,
        'totalItems': items.length,
        'totalPages': 1,
      });
    }

    final summary =
        RegExp(r'^/api/v1/ai/patients/(\d+)/summary$').firstMatch(path);
    if (summary != null) {
      return _json(422, {'detail': 'Not enough readings'});
    }

    return _json(404, {'detail': 'Resource not found'});
  });

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

Map<String, dynamic> overviewOf(int id, {int? glucose, int age = 34}) => {
      'patientId': id,
      'firstName': 'x',
      'lastName': 'y',
      'gender': null,
      'ageYears': age,
      'diabetesType': 'TYPE_1',
      'therapyType': 'MDI',
      'targetMinMgdl': 70,
      'targetMaxMgdl': 180,
      'lastGlucoseMgdl': glucose,
      'lastGlucoseAt': glucose == null ? null : '2026-11-22T08:30:00Z',
      'openAlerts': 2,
    };

Map<String, dynamic> reading(int id, int value, String at) => {
      'id': id,
      'glucoseValue': value,
      'measurementTime': at,
      'mealContext': 'FASTING',
      'notes': null,
    };

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

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  group('CarePatientsStore', () {
    test('joins each patient with their overview', () async {
      backend.members = [member(7, 'Nil', 'Su')];
      backend.overviews = {7: overviewOf(7, glucose: 245)};

      final p = (await CarePatientsStore(api: api).load()).single;

      expect(p.name, 'Nil Su');
      expect(p.subtitle, '34 years • Type 1 Diabetes');
      expect(p.lastGlucose, 245);
      expect(p.status, GlucoseStatus.high);
      expect(p.statusLabel, 'High');
      expect(p.openAlerts, 2);
      expect(p.canViewReports, isTrue);
    });

    test('a patient without a profile is listed with the name only',
        () async {
      backend.members = [member(8, 'Ali', 'Veli')];

      final p = (await CarePatientsStore(api: api).load()).single;

      expect(p.name, 'Ali Veli');
      expect(p.lastGlucose, isNull);
      expect(p.status, GlucoseStatus.noData);
      expect(p.diabetesLabel, 'Diabetes type not set');
    });

    test('no overview is asked for without the glucose permission',
        () async {
      backend.members = [member(9, 'Can', 'Ak', glucose: false)];
      backend.overviews = {9: overviewOf(9, glucose: 100)};

      final p = (await CarePatientsStore(api: api).load()).single;

      expect(p.lastGlucose, isNull);
      expect(
        backend.requests.map((r) => r.url.path),
        ['/api/v1/care-team/patients'],
      );
    });

    test('status follows the patient target range', () {
      CarePatient withGlucose(int g) => CarePatient.fromJson(
            member(1, 'a', 'b'),
            {...overviewOf(1, glucose: g), 'targetMinMgdl': 80, 'targetMaxMgdl': 160},
          );

      expect(withGlucose(75).status, GlucoseStatus.low);
      expect(withGlucose(80).status, GlucoseStatus.inRange);
      expect(withGlucose(160).status, GlucoseStatus.inRange);
      expect(withGlucose(161).status, GlucoseStatus.high);
    });
  });

  group('DoctorDashboardScreen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: DoctorDashboardScreen(
          patientsStore: CarePatientsStore(api: api),
        ),
      ));
      await settle(tester);
    }

    testWidgets('lists the real patients instead of sample data',
        (tester) async {
      backend.members = [member(7, 'Nil', 'Su'), member(8, 'Ali', 'Veli')];
      backend.overviews = {7: overviewOf(7, glucose: 245)};

      await pump(tester);

      expect(find.text('Nil Su'), findsOneWidget);
      expect(find.text('245 mg/dL'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('No readings yet'), findsOneWidget);
      expect(find.text('Emma Wilson'), findsNothing);
    });

    testWidgets('no patients points to Invitations', (tester) async {
      await pump(tester);

      expect(find.textContaining('No patients yet'), findsOneWidget);
      expect(find.text('Open Invitations'), findsOneWidget);
    });

    testWidgets('tapping a patient opens their real details',
        (tester) async {
      backend.members = [member(7, 'Nil', 'Su')];
      backend.overviews = {7: overviewOf(7, glucose: 245)};

      await pump(tester);
      await tester.tap(find.text('Nil Su'));
      await settle(tester);

      expect(find.byType(CarePatientDetailScreen), findsOneWidget);
      expect(find.text('2 open alerts'), findsOneWidget);
    });

    testWidgets('the Reports tab opens the patient\'s PDF / CSV report',
        (tester) async {
      backend.members = [
        member(7, 'Nil', 'Su'),
        // Shares nothing but alerts: no report to make.
        {
          ...member(8, 'Ali', 'Veli', glucose: false),
          'canViewMeals': false,
          'canViewMedications': false,
          'canViewActivity': false,
        },
      ];
      backend.overviews = {7: overviewOf(7, glucose: 245)};

      await pump(tester);
      await tester.tap(find.text('Reports'));
      await settle(tester);

      expect(find.text('Patient Reports'), findsOneWidget);
      expect(find.textContaining('Health report as PDF or CSV'),
          findsOneWidget);
      expect(find.text('Ali Veli'), findsNothing);

      await tester.tap(find.text('Nil Su'));
      await settle(tester);

      expect(find.byType(PdfReportScreen), findsOneWidget);
      expect(find.byType(CarePatientDetailScreen), findsNothing);
    });

    testWidgets('Reports explains when nobody shares logs', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Reports'));
      await settle(tester);

      expect(find.textContaining('No patients yet'), findsWidgets);
    });
  });

  group('CaregiverDashboardScreen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: CaregiverDashboardScreen(
          patientsStore: CarePatientsStore(api: api),
        ),
      ));
      await settle(tester);
    }

    testWidgets('lists the family members who share their data',
        (tester) async {
      backend.members = [member(7, 'Nil', 'Su')];
      backend.overviews = {7: overviewOf(7, glucose: 60)};

      await pump(tester);

      expect(find.text('Nil Su'), findsOneWidget);
      expect(find.text('34 years • Type 1 Diabetes'), findsOneWidget);
      expect(find.textContaining('60 mg/dL • Low'), findsOneWidget);
      expect(find.text('1 member'), findsOneWidget);
    });

    testWidgets('nobody yet explains the invitation flow', (tester) async {
      await pump(tester);

      expect(find.text('No family members yet'), findsOneWidget);
      expect(find.textContaining('More → Care Team'), findsOneWidget);
    });

    testWidgets('the Family tab offers Add Family Member and Invitations',
        (tester) async {
      await pump(tester);

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ElevatedButton, 'Add Family Member'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Invitations'));
      await settle(tester);

      expect(find.byType(CareInvitationsScreen), findsOneWidget);
    });

    testWidgets('tapping a family member opens their details',
        (tester) async {
      backend.members = [member(7, 'Nil', 'Su')];
      backend.overviews = {7: overviewOf(7, glucose: 60)};

      await pump(tester);
      await tester.tap(find.text('Nil Su'));
      await settle(tester);

      expect(find.byType(CarePatientDetailScreen), findsOneWidget);
    });
  });

  group('CarePatientDetailScreen', () {
    Future<void> pump(WidgetTester tester, CarePatient patient) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: CarePatientDetailScreen(
          patient: patient,
          glucose: LogStore<GlucoseRecord>(
            resource: 'glucose-logs',
            fromJson: GlucoseRecord.fromJson,
            api: api,
          ),
          insightsStore: AiInsightsStore(api: api),
        ),
      ));
      await settle(tester);
    }

    testWidgets('shows the patient glucose history from the backend',
        (tester) async {
      final now = DateTime.now().toUtc();
      backend.glucose = {
        7: [
          reading(2, 250, now.subtract(const Duration(hours: 1)).toIso8601String()),
          reading(1, 110, now.subtract(const Duration(hours: 5)).toIso8601String()),
        ],
      };

      await pump(
        tester,
        CarePatient.fromJson(member(7, 'Nil', 'Su'), overviewOf(7, glucose: 250)),
      );

      final logsRequest = backend.requests
          .firstWhere((r) => r.url.path.endsWith('/glucose-logs'));
      expect(logsRequest.url.path, '/api/v1/patients/7/glucose-logs');
      expect(logsRequest.url.queryParameters['from'], isNotNull);

      expect(find.text('250 mg/dL'), findsOneWidget);
      expect(find.text('110 mg/dL'), findsOneWidget);
      expect(find.textContaining('Target 70–180 mg/dL'), findsOneWidget);
      // The AI card is there (the fake answers "not enough data").
      expect(find.text('AI Insights'), findsOneWidget);
    });

    testWidgets('respects a patient who does not share glucose',
        (tester) async {
      await pump(tester, CarePatient.fromJson(member(9, 'Can', 'Ak', glucose: false)));

      expect(
        find.text('This patient does not share glucose readings with you.'),
        findsOneWidget,
      );
      expect(find.text('AI Insights'), findsNothing);
      expect(backend.requests, isEmpty);
    });

    testWidgets('no AI card without the reports permission', (tester) async {
      await pump(
        tester,
        CarePatient.fromJson(member(7, 'Nil', 'Su', reports: false),
            overviewOf(7, glucose: 120)),
      );

      expect(find.text('AI Insights'), findsNothing);
      expect(find.text('No readings in the last 14 days.'), findsOneWidget);
    });
  });
}
