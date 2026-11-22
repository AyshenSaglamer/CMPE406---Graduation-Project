import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/alert_store.dart';
import 'package:gradia/data/glucose_store.dart';
import 'package:gradia/data/log_store.dart';
import 'package:gradia/data/offline_queue.dart';
import 'package:gradia/screens/glucose_entry_screen.dart';
import 'package:gradia/screens/patient_alerts_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/auth_service.dart';
import 'package:gradia/services/token_storage.dart';
import 'package:gradia/widgets/glucose_alert_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Test-only stand-in for glucose-logs + alerts of patient 7. Like the
/// backend (GlucoseAlertService), saving a reading outside the patient's
/// thresholds creates an OPEN alert in the same request.
class FakeBackend {
  bool online = true;

  /// false = the patient has no profile, so no thresholds and no alerts.
  bool hasProfile = true;

  final alerts = <Map<String, dynamic>>[];
  final patches = <Map<String, dynamic>>[];
  var _logId = 500;
  var _alertId = 40;

  Map<String, dynamic> addAlert(String type, num value, {int? logId}) {
    final a = <String, dynamic>{
      'id': _alertId++,
      'patientId': 7,
      'alertType': type,
      'severity': type.startsWith('URGENT') ? 'CRITICAL' : 'WARNING',
      'glucoseLogId': logId,
      'valueMgdl': value,
      'message': '$type glucose: $value mg/dL',
      'status': 'OPEN',
      'triggeredAt': DateTime.now().toUtc().toIso8601String(),
      'acknowledgedBy': null,
      'acknowledgedAt': null,
      'resolvedAt': null,
      'resolvedBy': null,
    };
    alerts.insert(0, a);
    return a;
  }

  late final client = MockClient((request) async {
    if (!online) {
      throw http.ClientException('Network is unreachable');
    }
    final path = request.url.path;

    if (path == '/api/v1/patients/7/glucose-logs' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final value = body['glucoseValue'] as int;
      final id = _logId++;
      if (hasProfile) {
        final type = value <= 54
            ? 'URGENT_LOW'
            : value <= 70
                ? 'LOW'
                : value >= 250
                    ? 'URGENT_HIGH'
                    : value >= 180
                        ? 'HIGH'
                        : null;
        if (type != null) {
          addAlert(type, value, logId: id);
        }
      }
      return _json(201, {
        'id': id,
        'glucoseValue': value,
        'measurementTime': body['measurementTime'],
        'mealContext': body['mealContext'],
        'notes': null,
      });
    }

    if (path == '/api/v1/patients/7/alerts' && request.method == 'GET') {
      final status = request.url.queryParameters['status'];
      final items = [
        for (final a in alerts)
          if (status == null || a['status'] == status) a,
      ];
      final size = int.parse(request.url.queryParameters['size'] ?? '50');
      return _json(200, {
        'items': items.take(size).toList(),
        'page': 0,
        'size': size,
        'totalElements': items.length,
        'totalPages': 1,
      });
    }

    final patch = RegExp(r'^/api/v1/patients/7/alerts/(\d+)$').firstMatch(path);
    if (patch != null && request.method == 'PATCH') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      patches.add({'id': int.parse(patch.group(1)!), ...body});
      final a = alerts.firstWhere((a) => a['id'] == int.parse(patch.group(1)!));
      a['status'] = body['status'];
      return _json(200, a);
    }

    return _json(404, {'detail': 'Resource not found'});
  });

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

void main() {
  late FakeBackend backend;
  late ApiClient api;
  late AlertStore alerts;
  late LogStore<GlucoseRecord> glucose;

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

    backend = FakeBackend();
    api = ApiClient(httpClient: backend.client);
    alerts = AlertStore(api: api);
    glucose = LogStore<GlucoseRecord>(
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

  group('thresholds and store', () {
    test('default thresholds match patient_profiles defaults', () {
      expect(defaultAlertTypeFor(54), 'URGENT_LOW');
      expect(defaultAlertTypeFor(55), 'LOW');
      expect(defaultAlertTypeFor(70), 'LOW');
      expect(defaultAlertTypeFor(71), isNull);
      expect(defaultAlertTypeFor(179), isNull);
      expect(defaultAlertTypeFor(180), 'HIGH');
      expect(defaultAlertTypeFor(250), 'URGENT_HIGH');
    });

    test('alertForReading finds the alert of that reading', () async {
      backend.addAlert('HIGH', 200, logId: 1);
      backend.addAlert('LOW', 65, logId: 2);

      final found = await alerts.alertForReading(7, 2);

      expect(found!.type, 'LOW');
      expect(found.glucoseLogId, 2);
      expect(await alerts.alertForReading(7, 3), isNull);
    });

    test('openAlertCount counts only OPEN alerts', () async {
      backend.addAlert('HIGH', 200);
      backend.addAlert('LOW', 65)['status'] = 'RESOLVED';

      expect(await alerts.openAlertCount(7), 1);
    });

    test('every alert type has guidance', () {
      for (final type in ['URGENT_LOW', 'LOW', 'HIGH', 'URGENT_HIGH']) {
        final (title, steps) = alertGuidance(type);
        expect(title, isNotEmpty);
        expect(steps, isNotEmpty);
      }
      expect(alertGuidance('URGENT_LOW').$2.last, contains('112'));
    });
  });

  group('saving a reading', () {
    Future<void> saveReading(WidgetTester tester, String value) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GlucoseEntryScreen(store: glucose, alerts: alerts),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, value);
      await tester.tap(find.text('Save Measurement'));
      await settle(tester);
    }

    testWidgets('a urgent low reading shows the steps and Got it marks it seen',
        (tester) async {
      await saveReading(tester, '48');

      expect(find.text('Urgent low glucose'), findsOneWidget);
      expect(find.text('48 mg/dL'), findsOneWidget);
      expect(find.textContaining('fast-acting sugar'), findsOneWidget);
      expect(find.textContaining('can see this one'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await settle(tester);

      expect(backend.patches.single['status'], 'ACKNOWLEDGED');
      expect(find.byType(GlucoseEntryScreen), findsNothing);
    });

    testWidgets('a high reading shows the high steps', (tester) async {
      await saveReading(tester, '210');

      expect(find.text('High glucose'), findsOneWidget);
    });

    testWidgets('an in-range reading shows no alert', (tester) async {
      await saveReading(tester, '120');

      expect(find.byType(GlucoseAlertSheet), findsNothing);
      expect(find.byType(GlucoseEntryScreen), findsNothing);
    });

    testWidgets('offline, the default thresholds still warn', (tester) async {
      backend.online = false;

      await saveReading(tester, '45');

      expect(find.text('Urgent low glucose'), findsOneWidget);
      expect(find.textContaining('can see this one'), findsNothing);

      await tester.tap(find.text('Got it'));
      await settle(tester);
      expect(backend.patches, isEmpty);
    });

    testWidgets('no backend alert (no profile): urgent values still warn',
        (tester) async {
      backend.hasProfile = false;

      await saveReading(tester, '300');

      expect(find.text('Very high glucose'), findsOneWidget);
    });

    testWidgets('no backend alert (no profile): a mild value does not',
        (tester) async {
      backend.hasProfile = false;

      await saveReading(tester, '200');

      expect(find.byType(GlucoseAlertSheet), findsNothing);
    });
  });

  group('PatientAlertsScreen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: PatientAlertsScreen(store: alerts, patientId: 7),
      ));
      await settle(tester);
    }

    testWidgets('no open alerts', (tester) async {
      await pump(tester);

      expect(find.textContaining('No open alerts'), findsOneWidget);
    });

    testWidgets('Seen and Resolved change the alert', (tester) async {
      backend.addAlert('LOW', 62, logId: 1);
      await pump(tester);

      expect(find.text('Low • 62 mg/dL'), findsOneWidget);
      expect(find.text('Open'), findsWidgets);

      await tester.tap(find.text('Seen'));
      await settle(tester);
      expect(backend.patches.last['status'], 'ACKNOWLEDGED');
      // Seen alerts leave the Open list.
      expect(find.text('Low • 62 mg/dL'), findsNothing);

      await tester.tap(find.text('All'));
      await settle(tester);
      expect(find.text('Low • 62 mg/dL'), findsOneWidget);

      await tester.tap(find.text('Resolved'));
      await settle(tester);
      expect(backend.patches.last['status'], 'RESOLVED');
      expect(find.widgetWithText(TextButton, 'Resolved'), findsNothing);
    });

    testWidgets('tapping an alert shows what to do', (tester) async {
      backend.addAlert('URGENT_HIGH', 320, logId: 1);
      await pump(tester);

      await tester.tap(find.text('Urgent high • 320 mg/dL'));
      await tester.pumpAndSettle();

      expect(find.text('Very high glucose'), findsOneWidget);
      expect(find.textContaining('ketones'), findsOneWidget);
    });
  });
}
