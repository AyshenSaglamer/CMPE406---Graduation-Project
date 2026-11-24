import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/care_patients_store.dart';
import 'package:gradia/data/reminder_store.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/token_storage.dart';
import 'package:gradia/widgets/care_reminders_view.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Test-only stand-in for GET /patients/{id}/reminders and
/// /reminder-events, read by a caregiver.
class FakeBackend {
  /// patientId -> reminders (ReminderResponse JSON).
  final reminders = <int, List<Map<String, dynamic>>>{};

  /// patientId -> answers (ReminderEventResponse JSON).
  final events = <int, List<Map<String, dynamic>>>{};

  /// Patients whose reminders answer 403.
  final forbidden = <int>{};

  var _id = 1;

  void add(int patientId, {
    String type = 'MEDICATION',
    String? name = 'Metformin',
    String? dosage = '500 mg',
    String time = '08:00:00',
    List<String> days = Reminder.dayNames,
    bool active = true,
  }) {
    (reminders[patientId] ??= []).add({
      'id': _id++,
      'patientId': patientId,
      'reminderType': type,
      'medicationName': name,
      'dosage': dosage,
      'message': null,
      'scheduledTime': time,
      'daysOfWeek': days,
      'timezone': 'Europe/Istanbul',
      'active': active,
      'missedCount': 0,
    });
  }

  void answer(int patientId, int reminderId, DateTime at, String status) {
    (events[patientId] ??= []).add({
      'reminderId': reminderId,
      'scheduledFor': at.toUtc().toIso8601String(),
      'status': status,
    });
  }

  late final client = MockClient((request) async {
    final list = RegExp(r'^/api/v1/patients/(\d+)/reminders$')
        .firstMatch(request.url.path);
    final answers = RegExp(r'^/api/v1/patients/(\d+)/reminder-events$')
        .firstMatch(request.url.path);
    final id = int.parse((list ?? answers)!.group(1)!);
    if (forbidden.contains(id)) {
      return _json(403, {'detail': 'No access to this patient'});
    }
    if (list != null) {
      return _json(200, reminders[id] ?? []);
    }
    return _json(200, {'items': events[id] ?? [], 'totalPages': 1});
  });

  static http.Response _json(int status, Object body) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
}

CarePatient member(int id, String first, {bool medications = true}) =>
    CarePatient.fromJson({
      'patientId': id,
      'firstName': first,
      'lastName': 'Kaya',
      'canViewGlucose': true,
      'canViewMeals': true,
      'canViewMedications': medications,
      'canViewActivity': true,
      'canViewReports': true,
      'canReceiveAlerts': true,
    });

void main() {
  // Monday 23 November 2026, 12:00 on the phone.
  final now = DateTime(2026, 11, 23, 12);
  late FakeBackend backend;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStorage.save(
      token: 'test-token',
      expiresInSeconds: 3600,
      userJson: jsonEncode({
        'id': 3,
        'firstName': 'Care',
        'lastName': 'Giver',
        'email': 'c@example.com',
        'role': 'CAREGIVER',
      }),
    );
    backend = FakeBackend();
  });

  Future<void> pump(WidgetTester tester, List<CarePatient> members) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(httpClient: backend.client);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CareRemindersView(
          members: members,
          storeFor: (id) => ReminderStore(api: api, patientId: id),
          now: () => now,
        ),
      ),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets('no sample reminders: an empty family says so', (tester) async {
    await pump(tester, const []);

    expect(find.textContaining('No family members yet'), findsOneWidget);
    expect(find.text('Morning glucose check'), findsNothing);
    expect(find.text('Evening glucose check'), findsNothing);
  });

  testWidgets("today's reminders with what the patient answered",
      (tester) async {
    backend.add(7); // Metformin 08:00 every day -> id 1
    backend.add(7, type: 'GLUCOSE_CHECK', name: null, dosage: null,
        time: '10:00:00'); // id 2
    backend.add(7, name: 'Insulin', dosage: '6 units',
        time: '20:00:00'); // id 3
    backend.add(7, name: 'Vitamin D', time: '09:00:00',
        days: ['FRIDAY']); // id 4: not today
    backend.answer(7, 1, DateTime(2026, 11, 23, 8), ReminderAnswer.taken);

    await pump(tester, [member(7, 'Ali')]);

    final today = find.ancestor(
      of: find.text('Metformin'),
      matching: find.byType(Card),
    );
    expect(today, findsWidgets);
    expect(find.text('Taken'), findsOneWidget);
    expect(find.text('No answer yet'), findsOneWidget); // 10:00, now 12:00
    expect(find.text('Upcoming'), findsOneWidget); // 20:00
    expect(find.text('Vitamin D'), findsOneWidget); // only in the plan
    expect(find.text("Ali Kaya's plan"), findsOneWidget);
    expect(find.text('Every day • 500 mg'), findsOneWidget);
    // Today: type shown once (title "Blood Glucose" has no repeat).
    expect(find.text('Medication • 500 mg'), findsOneWidget);
    expect(find.text('Medication • 6 units'), findsOneWidget);
    expect(find.text('Fri • 500 mg'), findsOneWidget);
  });

  testWidgets('a member who does not share medications is not read',
      (tester) async {
    backend.add(8, name: 'Secret');

    await pump(tester, [member(8, 'Ayla', medications: false)]);

    expect(find.text('Secret'), findsNothing);
    expect(find.textContaining('do not share their medications'),
        findsOneWidget);
    expect(find.textContaining('Ayla Kaya does not share'), findsOneWidget);
  });

  testWidgets('several members: names on each reminder, an error stays local',
      (tester) async {
    backend.add(7, time: '08:00:00');
    backend.add(9, name: 'Insulin', time: '13:00:00');
    backend.forbidden.add(10);

    await pump(tester, [member(7, 'Ali'), member(9, 'Can'), member(10, 'Ece')]);

    expect(find.text('Ali Kaya • Medication • 500 mg'), findsOneWidget);
    expect(find.text('Can Kaya • Medication • 500 mg'), findsOneWidget);
    expect(find.textContaining('Could not load the reminders'), findsOneWidget);
  });
}
