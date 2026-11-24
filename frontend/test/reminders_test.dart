import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/reminder_store.dart';
import 'package:gradia/screens/reminder_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/reminder_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Test-only stand-in for the reminders API of patient 7, answering like
/// ReminderController (scheduledTime comes back as "HH:mm:ss").
class FakeBackend {
  final requests = <http.Request>[];
  final reminders = <Map<String, dynamic>>[];
  final events = <Map<String, dynamic>>[];
  bool failList = false;
  var _id = 60;

  Map<String, dynamic> add({
    String type = 'MEDICATION',
    String? name = 'Metformin',
    String? dosage = '500 mg',
    String time = '08:00:00',
    List<String> days = Reminder.dayNames,
    bool active = true,
  }) {
    final r = <String, dynamic>{
      'id': _id++,
      'patientId': 7,
      'reminderType': type,
      'medicationName': name,
      'dosage': dosage,
      'message': null,
      'scheduledTime': time,
      'daysOfWeek': days,
      'timezone': 'Europe/Istanbul',
      'active': active,
      'missedCount': 0,
      'lastTriggeredAt': null,
      'createdAt': '2026-11-23T09:00:00Z',
      'updatedAt': '2026-11-23T09:00:00Z',
    };
    reminders.add(r);
    return r;
  }

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    const base = '/api/v1/patients/7';

    if (path == '$base/reminders' && request.method == 'GET') {
      if (failList) {
        return _json(503, {'detail': 'Service unavailable'});
      }
      return _json(200, reminders);
    }
    if (path == '$base/reminders' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final r = add(
        type: body['reminderType'] as String,
        name: body['medicationName'] as String?,
        dosage: body['dosage'] as String?,
        time: '${body['scheduledTime']}:00',
        days: List<String>.from(body['daysOfWeek'] as List),
      );
      return _json(201, r);
    }
    if (path == '$base/reminder-events' && request.method == 'GET') {
      return _json(200, {'items': events, 'totalPages': 1});
    }

    final one = RegExp(r'^/api/v1/patients/7/reminders/(\d+)(/events)?$').firstMatch(path);
    if (one != null) {
      final id = int.parse(one.group(1)!);
      final r = reminders.where((r) => r['id'] == id).firstOrNull;
      if (r == null) {
        return _json(404, {'detail': 'Reminder not found'});
      }
      if (one.group(2) != null && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final e = {
          'id': 900 + events.length,
          'reminderId': id,
          'patientId': 7,
          'scheduledFor': body['scheduledFor'],
          'status': body['status'],
          'acknowledgedAt': body['scheduledFor'],
        };
        events.add(e);
        return _json(201, e);
      }
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        r['active'] = body['active'];
        return _json(200, r);
      }
      if (request.method == 'DELETE') {
        reminders.remove(r);
        return http.Response('', 204);
      }
    }
    return _json(404, {'detail': 'Resource not found'});
  });

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

/// Records what would be put on the phone instead of scheduling it.
class FakeNotifier implements ReminderNotifier {
  List<Reminder>? scheduled;
  int scheduleCalls = 0;
  bool permission = true;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    scheduleCalls++;
    scheduled = reminders;
  }

  @override
  Future<String?> timezone() async => 'Europe/Istanbul';
}

void main() {
  late FakeBackend backend;
  late ReminderStore store;
  late FakeNotifier notifier;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'access_token_expires_at':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    backend = FakeBackend();
    store = ReminderStore(api: ApiClient(httpClient: backend.client), patientId: 7);
    notifier = FakeNotifier();
  });

  group('Reminder model', () {
    test('reads the API answer and writes a request', () {
      final r = Reminder.fromJson(FakeBackend().add(days: ['FRIDAY', 'MONDAY']));

      expect(r.hour, 8);
      expect(r.minute, 0);
      expect(r.timeText, '08:00');
      expect(r.days, {1, 5});
      expect(r.daysText, 'Mon, Fri');
      expect(r.title, 'Metformin');
      expect(r.toRequestJson(), {
        'reminderType': 'MEDICATION',
        'medicationName': 'Metformin',
        'dosage': '500 mg',
        'scheduledTime': '08:00',
        'daysOfWeek': ['MONDAY', 'FRIDAY'],
        'timezone': 'Europe/Istanbul',
        'active': true,
      });
    });

    test('day summaries', () {
      Reminder withDays(Set<int> d) =>
          Reminder(type: Reminder.other, hour: 9, minute: 5, days: d);

      expect(withDays({1, 2, 3, 4, 5, 6, 7}).daysText, 'Every day');
      expect(withDays({1, 2, 3, 4, 5}).daysText, 'Weekdays');
      expect(withDays({6, 7}).daysText, 'Weekends');
      expect(withDays({1}).timeText, '09:05');
    });

    test('a paused reminder or another day has no occurrence', () {
      final monday = DateTime(2026, 11, 23); // a Monday
      final r = Reminder(type: Reminder.medication, hour: 8, minute: 30, days: {1});

      expect(r.occurrenceOn(monday), DateTime(2026, 11, 23, 8, 30));
      expect(r.occurrenceOn(monday.add(const Duration(days: 1))), isNull);
      expect(r.copyWith(active: false).occurrenceOn(monday), isNull);
    });
  });

  group('notifications', () {
    test('next occurrence is the coming weekday at that time', () {
      tz_data.initializeTimeZones();
      final now = tz.TZDateTime(tz.UTC, 2026, 11, 23, 10); // Monday 10:00

      expect(LocalReminderNotifier.nextOccurrence(now, DateTime.monday, 9, 0),
          tz.TZDateTime(tz.UTC, 2026, 11, 30, 9)); // today 09:00 passed
      expect(LocalReminderNotifier.nextOccurrence(now, DateTime.monday, 11, 0),
          tz.TZDateTime(tz.UTC, 2026, 11, 23, 11));
      expect(LocalReminderNotifier.nextOccurrence(now, DateTime.wednesday, 8, 0),
          tz.TZDateTime(tz.UTC, 2026, 11, 25, 8));
    });

    test('one id per reminder and weekday', () {
      final ids = {
        for (var day = 1; day <= 7; day++) LocalReminderNotifier.notificationId(60, day),
        for (var day = 1; day <= 7; day++) LocalReminderNotifier.notificationId(61, day),
      };
      expect(ids, hasLength(14));
    });

    test('texts', () {
      final pill = Reminder.fromJson(FakeBackend().add());
      expect(notificationTitle(pill), 'Time for Metformin');
      expect(notificationBody(pill), '500 mg. Open DiaMate to mark it as taken.');

      final check = Reminder(type: Reminder.glucoseCheck, hour: 7, minute: 0, days: {1});
      expect(notificationTitle(check), 'Check your blood glucose');
    });
  });

  group('ReminderStore', () {
    test('answer sends the occurrence time in UTC and the status', () async {
      backend.add();
      final at = DateTime.utc(2026, 11, 23, 5);

      final answer = await store.answer(60, at, ReminderAnswer.taken);

      final body = jsonDecode(backend.requests.last.body) as Map<String, dynamic>;
      expect(backend.requests.last.url.path, '/api/v1/patients/7/reminders/60/events');
      expect(body, {'scheduledFor': '2026-11-23T05:00:00.000Z', 'status': 'TAKEN'});
      expect(answer.status, ReminderAnswer.taken);
    });
  });

  group('ReminderScreen', () {
    // Monday 23 November 2026, 09:00 on the phone.
    DateTime now() => DateTime(2026, 11, 23, 9);

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: ReminderScreen(store: store, notifier: notifier, now: now),
      ));
      await settle(tester);
    }

    testWidgets('no reminders: the empty state, nothing scheduled', (tester) async {
      await pump(tester);

      expect(find.text('No reminders yet'), findsOneWidget);
      expect(notifier.scheduled, isEmpty);
      // One add button only: Create Reminder, not also the header's Add.
      expect(find.text('Create Reminder'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Add'), findsNothing);
    });

    testWidgets('lists saved reminders and puts them on the phone', (tester) async {
      backend.add();
      backend.add(type: 'GLUCOSE_CHECK', name: null, dosage: null, time: '20:00:00',
          days: ['SATURDAY', 'SUNDAY']);

      await pump(tester);

      expect(find.text('Metformin'), findsWidgets);
      expect(find.text('Every day • 500 mg'), findsOneWidget);
      expect(find.text('Blood Glucose'), findsOneWidget);
      expect(find.text('Weekends'), findsOneWidget);
      expect(find.text('2 active'), findsOneWidget);
      expect(notifier.scheduled, hasLength(2));
      expect(find.widgetWithText(TextButton, 'Add'), findsOneWidget);
    });

    testWidgets('a due dose is marked as taken', (tester) async {
      backend.add(); // every day 08:00, now is 09:00

      await pump(tester);
      expect(find.text('Today'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Taken'));
      await settle(tester);

      final body = jsonDecode(backend.requests.last.body) as Map<String, dynamic>;
      expect(body['status'], 'TAKEN');
      expect(DateTime.parse(body['scheduledFor'] as String),
          DateTime(2026, 11, 23, 8).toUtc());
      expect(find.widgetWithText(FilledButton, 'Taken'), findsNothing);
      expect(find.text('Taken'), findsOneWidget); // the status chip
    });

    testWidgets('a later dose is upcoming, without buttons', (tester) async {
      backend.add(time: '21:00:00');

      await pump(tester);

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Taken'), findsNothing);
    });

    testWidgets('an answer given earlier today is shown', (tester) async {
      backend.add();
      backend.events.add({
        'id': 1,
        'reminderId': 60,
        'patientId': 7,
        'scheduledFor': DateTime(2026, 11, 23, 8).toUtc().toIso8601String(),
        'status': 'MISSED',
        'acknowledgedAt': null,
      });

      await pump(tester);

      expect(find.text('Missed'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Taken'), findsNothing);
    });

    testWidgets('turning a reminder off saves it and reschedules', (tester) async {
      backend.add();
      await pump(tester);
      final callsBefore = notifier.scheduleCalls;

      await tester.tap(find.byType(Switch));
      await settle(tester);

      expect(backend.reminders.single['active'], false);
      expect(notifier.scheduleCalls, callsBefore + 1);
      expect(find.text('0 active'), findsOneWidget);
    });

    testWidgets('adding a medication reminder', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Create Reminder'));
      await tester.pumpAndSettle();

      // Missing name is caught in the form.
      await tester.tap(find.text('Add Reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter the medicine name.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('reminder_name')), 'Metformin');
      await tester.enterText(find.byKey(const ValueKey('reminder_dosage')), '500 mg');
      await tester.tap(find.text('Select time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // Only weekdays.
      await tester.tap(find.byTooltip('SATURDAY'));
      await tester.tap(find.byTooltip('SUNDAY'));
      await tester.pump();

      await tester.tap(find.text('Add Reminder'));
      await settle(tester);

      final post = backend.requests.lastWhere((r) => r.method == 'POST');
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(body['medicationName'], 'Metformin');
      expect(body['dosage'], '500 mg');
      expect(body['scheduledTime'], '08:00');
      expect(body['daysOfWeek'], ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY']);
      expect(body['timezone'], 'Europe/Istanbul');
      expect(find.textContaining('You will get a notification at 08:00'), findsOneWidget);
      expect(notifier.scheduled!.single.title, 'Metformin');
    });

    testWidgets('a load error offers a retry', (tester) async {
      backend.failList = true;
      await pump(tester);

      expect(find.text('Service unavailable'), findsOneWidget);
      backend.failList = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('No reminders yet'), findsOneWidget);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}
