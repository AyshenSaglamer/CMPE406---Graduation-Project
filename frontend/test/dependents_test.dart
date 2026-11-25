import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/ai_insights_store.dart';
import 'package:gradia/data/care_patients_store.dart';
import 'package:gradia/data/dependent_store.dart';
import 'package:gradia/data/glucose_store.dart';
import 'package:gradia/data/log_store.dart';
import 'package:gradia/data/offline_queue.dart';
import 'package:gradia/screens/add_family_member_screen.dart';
import 'package:gradia/screens/care_patient_detail_screen.dart';
import 'package:gradia/screens/caregiver_dashboard_screen.dart';
import 'package:gradia/screens/glucose_entry_screen.dart';
import 'package:gradia/screens/pdf_report_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Test-only stand-in for /care-team/dependents and /care-team/patients,
/// mirroring Melih's DependentService: a new dependent joins the caregiver's
/// list with managed = true.
class FakeBackend {
  final requests = <http.Request>[];

  /// CareTeamPatientResponse JSON.
  final members = <Map<String, dynamic>>[];

  /// patientId -> the details last saved (DependentResponse JSON).
  final dependents = <int, Map<String, dynamic>>{};

  /// Answer the next POST/PUT with this 400 field error instead.
  Map<String, String>? rejectWith;

  /// patientId -> glucose logs (GlucoseLogResponse JSON), newest first.
  final glucose = <int, List<Map<String, dynamic>>>{};

  /// Patients whose logs the caller may not write (403 like the backend).
  final noWrite = <int>{};

  var _nextId = 50;

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;

    if (request.headers['Authorization'] != 'Bearer test-token') {
      return _json(401, {'detail': 'Authentication required'});
    }

    if (path == '/api/v1/care-team/patients' && request.method == 'GET') {
      return _json(200, members);
    }

    final edit =
        RegExp(r'^/api/v1/care-team/dependents/(\d+)$').firstMatch(path);
    final isAdd = path == '/api/v1/care-team/dependents' &&
        request.method == 'POST';
    final isEdit = edit != null && request.method == 'PUT';

    if (isAdd || isEdit) {
      final errors = rejectWith;
      if (errors != null) {
        rejectWith = null;
        return _json(400, {'detail': 'Validation failed', 'errors': errors});
      }

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final int id;
      if (isAdd) {
        id = _nextId++;
      } else {
        id = int.parse(edit!.group(1)!);
        if (!dependents.containsKey(id)) {
          return _json(404, {'detail': 'Dependent not found'});
        }
      }

      final saved = {
        'patientId': id,
        'firstName': body['firstName'],
        'lastName': body['lastName'],
        'dateOfBirth': body['dateOfBirth'],
        'gender': body['gender'],
        'diabetesType': body['diabetesType'] ?? 'OTHER',
        'relationshipId': id + 100,
      };
      dependents[id] = saved;
      members.removeWhere((m) => m['patientId'] == id);
      members.add(managedMember(id, '${body['firstName']}',
          '${body['lastName']}'));
      return _json(isAdd ? 201 : 200, saved);
    }

    final logs =
        RegExp(r'^/api/v1/patients/(\d+)/glucose-logs$').firstMatch(path);
    if (logs != null) {
      final id = int.parse(logs.group(1)!);
      final list = glucose[id] ??= [];

      if (request.method == 'POST') {
        if (noWrite.contains(id)) {
          return _json(403, {'detail': 'You cannot add logs for this patient'});
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final saved = {
          'id': 900 + list.length,
          'glucoseValue': body['glucoseValue'],
          'measurementTime': body['measurementTime'],
          'mealContext': body['mealContext'],
          'notes': body['notes'],
        };
        list.insert(0, saved);
        return _json(201, saved);
      }

      return _json(200, {
        'items': list,
        'page': 0,
        'size': 200,
        'totalItems': list.length,
        'totalPages': 1,
      });
    }

    // No overview in these tests: the list shows names only.
    return _json(404, {'detail': 'Resource not found'});
  });

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

Map<String, dynamic> managedMember(int id, String first, String last,
        {bool managed = true}) =>
    {
      'patientId': id,
      'firstName': first,
      'lastName': last,
      'canViewGlucose': false,
      'canViewMeals': true,
      'canViewMedications': true,
      'canViewActivity': true,
      'canViewReports': true,
      'canReceiveAlerts': true,
      'canAddRecommendations': false,
      'managed': managed,
    };

void main() {
  late FakeBackend backend;
  late ApiClient api;

  // Wednesday 25 November 2026 on the phone.
  DateTime today() => DateTime(2026, 11, 25, 10);

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

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Opens the date picker (it starts 8 years back: November 2018) and
  /// picks the 15th.
  Future<void> pickBirthday(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('dateOfBirthField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
  }

  Future<void> pickGender(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('genderField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  group('DependentStore', () {
    test('sends the date of birth as a plain date and leaves out an '
        'unknown diabetes type', () {
      final json = DependentDetails(
        firstName: '  Deniz ',
        lastName: 'Kaya',
        dateOfBirth: DateTime(2018, 3, 7),
        gender: 'FEMALE',
      ).toJson();

      expect(json, {
        'firstName': 'Deniz',
        'lastName': 'Kaya',
        'dateOfBirth': '2018-03-07',
        'gender': 'FEMALE',
      });
    });

    test('adds with POST and corrects with PUT', () async {
      final store = DependentStore(api: api);
      final details = DependentDetails(
        firstName: 'Deniz',
        lastName: 'Kaya',
        dateOfBirth: DateTime(2018, 3, 7),
        gender: 'FEMALE',
        diabetesType: 'TYPE_1',
      );

      final added = await store.add(details);
      expect(added.patientId, 50);
      expect(added.diabetesType, 'TYPE_1');
      expect(added.dateOfBirth, DateTime(2018, 3, 7));
      expect(backend.requests.last.method, 'POST');
      expect(backend.requests.last.url.path, '/api/v1/care-team/dependents');

      final edited = await store.update(
        50,
        DependentDetails(
          firstName: 'Deniz Su',
          lastName: 'Kaya',
          dateOfBirth: DateTime(2018, 3, 8),
          gender: 'FEMALE',
        ),
      );
      expect(edited.name, 'Deniz Su Kaya');
      expect(edited.diabetesType, 'OTHER');
      expect(backend.requests.last.method, 'PUT');
      expect(
        backend.requests.last.url.path,
        '/api/v1/care-team/dependents/50',
      );
    });
  });

  group('AddFamilyMemberScreen', () {
    Dependent? popped;

    Future<void> pump(WidgetTester tester, {CarePatient? existing}) async {
      bigScreen(tester);
      popped = null;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.push<Dependent>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddFamilyMemberScreen(
                        existing: existing,
                        store: DependentStore(api: api),
                        today: today,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('saves a child without an account to the backend',
        (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Deniz');
      await tester.enterText(find.byType(TextField).at(1), 'Kaya');
      await pickBirthday(tester);
      await pickGender(tester, 'Female');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Family Member'));
      await settle(tester);

      final post = backend.requests.single;
      expect(post.method, 'POST');
      expect(jsonDecode(post.body), {
        'firstName': 'Deniz',
        'lastName': 'Kaya',
        'dateOfBirth': '2018-11-15',
        'gender': 'FEMALE',
      });
      expect(popped?.patientId, 50);
      expect(find.byType(AddFamilyMemberScreen), findsNothing);
    });

    testWidgets('a missing last name is asked for before anything is sent',
        (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Deniz');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Family Member'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter the last name.'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('a field the backend rejects is shown under that field',
        (tester) async {
      backend.rejectWith = {
        'firstName': 'First name may only contain letters, spaces, '
            'apostrophes, hyphens and dots',
      };
      await pump(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Deniz2');
      await tester.enterText(find.byType(TextField).at(1), 'Kaya');
      await pickBirthday(tester);
      await pickGender(tester, 'Male');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Family Member'));
      await settle(tester);

      expect(find.textContaining('may only contain letters'), findsOneWidget);
      expect(find.byType(AddFamilyMemberScreen), findsOneWidget);
      expect(popped, isNull);
    });

    testWidgets('editing prefills what is known and saves with PUT',
        (tester) async {
      backend.dependents[50] = {'patientId': 50};
      final existing = CarePatient.fromJson(
        managedMember(50, 'Deniz', 'Kaya'),
        {
          'gender': 'FEMALE',
          'ageYears': 8,
          'diabetesType': 'TYPE_1',
          'targetMinMgdl': 70,
          'targetMaxMgdl': 180,
        },
      );
      await pump(tester, existing: existing);

      expect(find.text('Edit Family Member'), findsOneWidget);
      expect(find.text('Deniz'), findsOneWidget);
      expect(find.text('Kaya'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Type 1'), findsOneWidget);

      // The backend does not send the date of birth back: it must be
      // picked again before the full update is sent.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Please select the date of birth.'), findsOneWidget);
      expect(backend.requests, isEmpty);

      await tester.enterText(find.byType(TextField).at(0), 'Deniz Su');
      await pickBirthday(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await settle(tester);

      final put = backend.requests.single;
      expect(put.method, 'PUT');
      expect(put.url.path, '/api/v1/care-team/dependents/50');
      expect(jsonDecode(put.body), {
        'firstName': 'Deniz Su',
        'lastName': 'Kaya',
        'dateOfBirth': '2018-11-15',
        'gender': 'FEMALE',
        'diabetesType': 'TYPE_1',
      });
      expect(popped?.name, 'Deniz Su Kaya');
    });
  });

  group('logging for a family member', () {
    LogStore<GlucoseRecord> glucoseStoreWith(ApiClient api,
            {OfflineQueue? queue}) =>
        LogStore<GlucoseRecord>(
          resource: 'glucose-logs',
          fromJson: GlucoseRecord.fromJson,
          api: api,
          queue: queue,
        );

    Map<String, dynamic> body(int value) => GlucoseRecord.requestBody(
          glucoseValue: value,
          measuredAt: DateTime(2026, 11, 25, 8),
          mealContextLabel: 'Fasting',
          clientUuid: 'uuid-$value',
          notes: '',
        );

    test('saves to the family member, not to the caregiver\'s own list',
        () async {
      final store = glucoseStoreWith(api);

      final saved = await store.create(body(132), patientId: 50);

      expect(saved?.value, 132);
      expect(backend.requests.single.url.path,
          '/api/v1/patients/50/glucose-logs');
      expect(store.value, isEmpty);
    });

    test('without a connection it is not queued for later', () async {
      final queue = OfflineQueue(api: api);
      final offline = ApiClient(
        httpClient: MockClient((_) => throw http.ClientException('offline')),
      );
      final store = glucoseStoreWith(offline, queue: queue);

      await expectLater(
        store.create(body(132), patientId: 50),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', familyEntryOfflineMessage)),
      );
      expect(queue.value, isEmpty);
    });

    CarePatient patient({required bool managed}) => CarePatient.fromJson(
          managedMember(50, 'Deniz', 'Kaya', managed: managed)
            ..['canViewGlucose'] = true,
          {
            'ageYears': 8,
            'diabetesType': 'TYPE_1',
            'targetMinMgdl': 70,
            'targetMaxMgdl': 180,
            'lastGlucoseMgdl': 250,
            'lastGlucoseAt': '2026-11-20T08:00:00Z',
          },
        );

    Future<void> pumpDetail(WidgetTester tester, CarePatient p) async {
      bigScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: CarePatientDetailScreen(
          patient: p,
          glucose: glucoseStoreWith(api),
          insightsStore: AiInsightsStore(api: api),
        ),
      ));
      await settle(tester);
    }

    testWidgets('only a managed family member offers Add Entry',
        (tester) async {
      await pumpDetail(tester, patient(managed: false));
      expect(find.text('Add Entry'), findsNothing);
      expect(find.text('Reminders'), findsNothing);
      expect(find.text('DiaMate Assistant'), findsNothing);

      await pumpDetail(tester, patient(managed: true));
      expect(find.text('Add Entry'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('DiaMate Assistant'), findsOneWidget);
      for (final label in ['Glucose', 'Insulin', 'Meal', 'Activity']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('a reading the caregiver adds lands in the history',
        (tester) async {
      await pumpDetail(tester, patient(managed: true));
      expect(find.text('No readings in the last 14 days.'), findsOneWidget);

      await tester.tap(find.text('Glucose'));
      await tester.pumpAndSettle();
      expect(find.byType(GlucoseEntryScreen), findsOneWidget);
      expect(find.text('For Deniz Kaya'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '132');
      await tester.tap(find.text('Save Measurement'));
      await settle(tester);

      expect(find.byType(GlucoseEntryScreen), findsNothing);
      final post =
          backend.requests.firstWhere((r) => r.method == 'POST');
      expect(post.url.path, '/api/v1/patients/50/glucose-logs');
      expect(jsonDecode(post.body)['glucoseValue'], 132);

      // The latest card follows the new reading, not the older overview.
      expect(find.text('132 mg/dL'), findsOneWidget);
      expect(find.text('132'), findsOneWidget);
      expect(find.text('250'), findsNothing);
    });

    testWidgets('a refused entry shows the backend message and stays open',
        (tester) async {
      backend.noWrite.add(50);
      await pumpDetail(tester, patient(managed: true));

      await tester.tap(find.text('Glucose'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '132');
      await tester.tap(find.text('Save Measurement'));
      await settle(tester);

      expect(find.byType(GlucoseEntryScreen), findsOneWidget);
      expect(find.text('You cannot add logs for this patient'), findsOneWidget);
    });
  });

  group('CaregiverDashboardScreen', () {
    Future<void> pump(WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: CaregiverDashboardScreen(
          patientsStore: CarePatientsStore(api: api),
          dependentStore: DependentStore(api: api),
        ),
      ));
      await settle(tester);
    }

    testWidgets('only a family member the caregiver manages can be edited',
        (tester) async {
      backend.members.addAll([
        managedMember(50, 'Deniz', 'Kaya'),
        managedMember(7, 'Ayşe', 'Kaya', managed: false),
      ]);

      await pump(tester);

      expect(find.text('Managed by you'), findsOneWidget);
      expect(find.byTooltip('Edit details'), findsOneWidget);
    });

    testWidgets('the Reports tab opens a family member\'s health report',
        (tester) async {
      backend.members.add(managedMember(50, 'Deniz', 'Kaya'));
      await pump(tester);

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('Deniz Kaya'), findsOneWidget);

      await tester.tap(find.text('Deniz Kaya'));
      await tester.pumpAndSettle();
      expect(find.byType(PdfReportScreen), findsOneWidget);
      expect(find.text('For Deniz Kaya'), findsOneWidget);
    });

    testWidgets('More no longer repeats Family Members and Invitations',
        (tester) async {
      await pump(tester);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      expect(find.text('Family Members'), findsNothing);
      expect(find.text('Invitations'), findsNothing);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('a family member added on the Family tab joins the list',
        (tester) async {
      await pump(tester);
      expect(find.text('No family members yet'), findsOneWidget);

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Family Member'));
      await tester.pumpAndSettle();
      expect(find.byType(AddFamilyMemberScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Deniz');
      await tester.enterText(find.byType(TextField).at(1), 'Kaya');
      // The real date: the 15th of the month 8 years ago.
      await tester.tap(find.byKey(const Key('dateOfBirthField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await pickGender(tester, 'Female');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Family Member'));
      await settle(tester);

      expect(find.byType(AddFamilyMemberScreen), findsNothing);
      expect(find.text('Deniz Kaya'), findsOneWidget);
      expect(find.text('Managed by you'), findsOneWidget);
      expect(
        backend.requests.where((r) => r.url.path == '/api/v1/care-team/patients'),
        hasLength(2),
      );
    });
  });
}
