import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/alert_store.dart';
import 'package:gradia/screens/alerts_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A small in-memory copy of the backend: /care-team/patients and the
/// alerts API, with the same status rules as AlertService.
class FakeBackend {
  final requests = <http.Request>[];

  /// 19 allows alerts, 23 does not, 31 allows them on the list but removed
  /// access since (the alerts API answers 404).
  final patients = [
    {'patientId': 19, 'firstName': 'Ayşe', 'lastName': 'Kaya', 'canReceiveAlerts': true},
    {'patientId': 23, 'firstName': 'Mert', 'lastName': 'Demir', 'canReceiveAlerts': false},
    {'patientId': 31, 'firstName': 'Elif', 'lastName': 'Can', 'canReceiveAlerts': true},
  ];

  final alerts = <Map<String, dynamic>>[
    _alert(41, 19, 'HIGH', 'WARNING', 245.0, 'OPEN', '2026-10-13T06:40:00Z'),
    _alert(44, 19, 'URGENT_LOW', 'CRITICAL', 48.0, 'OPEN', '2026-10-13T08:12:00Z'),
    _alert(42, 19, 'LOW', 'WARNING', 62.0, 'ACKNOWLEDGED', '2026-10-13T07:35:00Z'),
    _alert(40, 19, 'HIGH', 'WARNING', 199.0, 'RESOLVED', '2026-10-12T21:00:00Z'),
    _alert(50, 23, 'URGENT_HIGH', 'CRITICAL', 320.0, 'OPEN', '2026-10-13T08:30:00Z'),
  ];

  static Map<String, dynamic> _alert(int id, int patientId, String type,
      String severity, double value, String status, String at) {
    return {
      'id': id,
      'patientId': patientId,
      'alertType': type,
      'severity': severity,
      'glucoseLogId': id + 60,
      'valueMgdl': value,
      'message': 'Glucose alert: ${value.toInt()} mg/dL',
      'status': status,
      'triggeredAt': at,
      'acknowledgedBy': status == 'OPEN' ? null : 7,
      'acknowledgedAt': status == 'OPEN' ? null : at,
      'resolvedAt': status == 'RESOLVED' ? at : null,
      // 7 is the logged-in user in the screen tests, 9 another care team member.
      'resolvedBy': status == 'RESOLVED' ? 9 : null,
    };
  }

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;

    if (request.headers['Authorization'] != 'Bearer test-token') {
      return _problem(401, 'Authentication required');
    }

    if (path == '/api/v1/care-team/patients') {
      return _json(200, patients);
    }

    // Like AlertService.careTeamAlerts: only patients who share alerts and
    // still have an ACTIVE relationship (31 removed access), newest first.
    if (path == '/api/v1/care-team/alerts') {
      final status = request.url.queryParameters['status'];
      final size = int.parse(request.url.queryParameters['size'] ?? '50');
      final page = int.parse(request.url.queryParameters['page'] ?? '0');
      final shared = patients
          .where((p) => p['canReceiveAlerts'] == true && p['patientId'] != 31)
          .toList();
      final filtered = alerts
          .where((a) => shared.any((p) => p['patientId'] == a['patientId']))
          .where((a) => status == null || a['status'] == status)
          .toList()
        ..sort((a, b) => (b['triggeredAt'] as String).compareTo(a['triggeredAt'] as String));
      final items = filtered.skip(page * size).take(size).map((a) {
        final p = shared.firstWhere((p) => p['patientId'] == a['patientId']);
        return {
          'patientId': p['patientId'],
          'patientFirstName': p['firstName'],
          'patientLastName': p['lastName'],
          'alert': a,
        };
      }).toList();
      return _json(200, {
        'items': items,
        'page': page,
        'size': size,
        'totalElements': filtered.length,
        'totalPages': (filtered.length / size).ceil(),
      });
    }

    final match =
        RegExp(r'^/api/v1/patients/(\d+)/alerts(?:/(\d+))?$').firstMatch(path);
    if (match == null) {
      return _problem(404, 'Resource not found');
    }

    final patientId = int.parse(match.group(1)!);
    final allowed = patients.any(
      (p) => p['patientId'] == patientId && p['canReceiveAlerts'] == true && patientId != 31,
    );
    if (!allowed) {
      return _problem(404, 'Patient not found');
    }

    final own = alerts.where((a) => a['patientId'] == patientId).toList();

    if (request.method == 'GET') {
      final status = request.url.queryParameters['status'];
      final size = int.parse(request.url.queryParameters['size'] ?? '50');
      final page = int.parse(request.url.queryParameters['page'] ?? '0');
      final filtered = own.where((a) => status == null || a['status'] == status).toList()
        ..sort((a, b) => (b['triggeredAt'] as String).compareTo(a['triggeredAt'] as String));
      final items = filtered.skip(page * size).take(size).toList();
      return _json(200, {
        'items': items,
        'page': page,
        'size': size,
        'totalElements': filtered.length,
        'totalPages': (filtered.length / size).ceil(),
      });
    }

    if (request.method == 'PATCH') {
      final alertId = int.parse(match.group(2)!);
      final wanted = (jsonDecode(request.body) as Map)['status'];
      final alert = own.where((a) => a['id'] == alertId).firstOrNull;
      if (alert == null) {
        return _problem(404, 'Alert not found');
      }
      final current = alert['status'];
      if (current == wanted) {
        return _json(200, alert);
      }
      if (current == 'RESOLVED' || current == 'DISMISSED') {
        return _problem(409, 'Alert is already ${(current as String).toLowerCase()}');
      }
      alert['status'] = wanted;
      alert['acknowledgedBy'] ??= 7;
      alert['acknowledgedAt'] ??= '2026-10-13T09:00:00Z';
      if (wanted == 'RESOLVED') {
        alert['resolvedAt'] = '2026-10-13T09:00:00Z';
        alert['resolvedBy'] = 7;
      }
      return _json(200, alert);
    }

    return _problem(405, 'Method not allowed');
  });

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
  late AlertStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'access_token_expires_at':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    backend = FakeBackend();
    store = AlertStore(api: ApiClient(httpClient: backend.client));
  });

  group('AlertStore', () {
    test('lists alerts only of patients who allow them, newest first', () async {
      final items = await store.careTeamAlerts(status: PatientAlert.open);

      // Patient 23 does not allow alerts, 31 removed access: neither is listed.
      expect(items.map((i) => i.alert.id), [44, 41]);
      expect(items.first.patient.name, 'Ayşe Kaya');
      // One request for the whole care list, not one per patient.
      expect(backend.requests.map((r) => r.url.path), ['/api/v1/care-team/alerts']);

      final first = items.first.alert;
      expect(first.type, 'URGENT_LOW');
      expect(first.typeLabel, 'Urgent low');
      expect(first.isCritical, isTrue);
      expect(first.valueMgdl, 48);
      expect(first.status, PatientAlert.open);
      expect(first.acknowledgedAt, isNull);
      expect(backend.requests.last.url.queryParameters['status'], 'OPEN');
    });

    test('without a status filter every alert is listed', () async {
      final items = await store.careTeamAlerts();

      expect(items.map((i) => i.alert.id), [44, 42, 41, 40]);
      expect(items.last.alert.isClosed, isTrue);
      expect(items.last.alert.resolvedAt, isNotNull);
    });

    test('reads who saw and who resolved an alert', () async {
      final items = await store.careTeamAlerts();
      final resolved = items.last.alert;
      final open = items.first.alert;

      expect(resolved.acknowledgedBy, 7);
      expect(resolved.resolvedBy, 9);
      expect(open.acknowledgedBy, isNull);
      expect(open.resolvedBy, isNull);
    });

    test('reads every page', () async {
      for (var i = 0; i < 250; i++) {
        backend.alerts.add(FakeBackend._alert(
            1000 + i, 19, 'HIGH', 'WARNING', 190, 'OPEN', '2026-10-01T00:00:00Z'));
      }

      final alerts = await store.alertsOf(19, status: PatientAlert.open);

      expect(alerts, hasLength(252));
      expect(
        backend.requests.map((r) => r.url.queryParameters['page']),
        ['0', '1'],
      );
    });

    test('the care list reads every page too', () async {
      for (var i = 0; i < 250; i++) {
        backend.alerts.add(FakeBackend._alert(
            2000 + i, 19, 'HIGH', 'WARNING', 190, 'OPEN', '2026-10-01T00:00:00Z'));
      }

      final items = await store.careTeamAlerts(status: PatientAlert.open);

      expect(items, hasLength(252));
      expect(
        backend.requests.map((r) => r.url.queryParameters['page']),
        ['0', '1'],
      );
    });

    test('open count is one request for one item, read from totalElements', () async {
      expect(await store.openCareTeamAlertCount(), 2);

      expect(backend.requests, hasLength(1));
      final r = backend.requests.single;
      expect(r.url.path, '/api/v1/care-team/alerts');
      expect(r.url.queryParameters['status'], 'OPEN');
      expect(r.url.queryParameters['size'], '1');
    });

    test('changeStatus sends PATCH with the new status', () async {
      final updated = await store.changeStatus(19, 44, PatientAlert.resolved);

      final request = backend.requests.last;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/patients/19/alerts/44');
      expect(jsonDecode(request.body), {'status': 'RESOLVED'});
      expect(updated.status, PatientAlert.resolved);
      expect(updated.acknowledgedAt, isNotNull);
      expect(updated.resolvedAt, isNotNull);
    });

    test('a closed alert gives the backend 409 message', () async {
      expect(
        () => store.changeStatus(19, 40, PatientAlert.acknowledged),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', 'Alert is already resolved')),
      );
    });
  });

  group('AlertsScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      // Tall enough that every card of the "All" list is built (ListView is lazy).
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: AlertsScreen(store: store, currentUserId: 7)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> showAll(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
    }

    testWidgets('cards say who saw and who resolved the alert', (tester) async {
      await pumpScreen(tester);
      await showAll(tester);

      // Alert 40: seen by the logged-in user (7), resolved by someone else (9).
      expect(find.textContaining('Seen by you'), findsNWidgets(2)); // 40 and 42
      expect(
        find.textContaining('Resolved by another care team member'),
        findsOneWidget,
      );
    });

    testWidgets('resolving an alert shows it was resolved by you', (tester) async {
      await pumpScreen(tester);
      await showAll(tester);

      await tester.tap(find.text('Resolve').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Resolved by you'), findsOneWidget);
    });

    testWidgets('an alert resolved before resolvedBy existed shows only the time',
        (tester) async {
      backend.alerts.firstWhere((a) => a['id'] == 40)['resolvedBy'] = null;

      await pumpScreen(tester);
      await showAll(tester);

      expect(find.textContaining('Resolved by'), findsNothing);
      expect(find.textContaining('Resolved '), findsOneWidget);
    });

    testWidgets('shows open alerts with patient, value and status', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Ayşe Kaya'), findsNWidgets(2));
      expect(find.text('Urgent low • 48 mg/dL'), findsOneWidget);
      expect(find.text('High • 245 mg/dL'), findsOneWidget);
      expect(find.text('Seen'), findsNWidgets(3)); // filter chip + 2 buttons
      expect(find.text('Resolve'), findsNWidgets(2));
    });

    testWidgets('resolving removes the alert from the open list', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Resolve').first);
      await tester.pumpAndSettle();

      expect(backend.alerts.firstWhere((a) => a['id'] == 44)['status'], 'RESOLVED');
      expect(find.text('Urgent low • 48 mg/dL'), findsNothing);
      expect(find.text('High • 245 mg/dL'), findsOneWidget);
      expect(find.text('Alert resolved.'), findsOneWidget);
    });

    testWidgets('the Seen filter lists acknowledged alerts with only Resolve', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Seen'));
      await tester.pumpAndSettle();

      expect(find.text('Low • 62 mg/dL'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Seen'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Resolve'), findsOneWidget);
    });

    testWidgets('an empty open list says so', (tester) async {
      for (final a in backend.alerts) {
        a['status'] = 'RESOLVED';
      }

      await pumpScreen(tester);

      expect(find.text('No open alerts'), findsOneWidget);
    });

    testWidgets('a load error can be retried', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});

      await pumpScreen(tester);
      expect(find.text('Alerts could not be loaded'), findsOneWidget);

      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'test-token',
        'access_token_expires_at':
            DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      });
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Urgent low • 48 mg/dL'), findsOneWidget);
    });
  });
}
