import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/glucose_store.dart';
import 'package:gradia/data/log_store.dart';
import 'package:gradia/data/offline_queue.dart';
import 'package:gradia/screens/offline_mode_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:gradia/services/auth_service.dart';
import 'package:gradia/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Test-only stand-in for POST /patients/{id}/{kind}-logs that can be
/// switched offline. Like the real backend, a clientUuid that was already
/// saved answers 200 with the existing log instead of saving it again.
class FakeBackend {
  bool online = true;

  /// Status to answer instead of saving (e.g. 400), or null.
  int? rejectWith;

  /// Saved logs: clientUuid -> body (one per uuid, like the unique index).
  final saved = <String, Map<String, dynamic>>{};
  final posts = <String>[];

  late final client = MockClient((request) async {
    if (!online) {
      throw http.ClientException('Network is unreachable');
    }

    if (request.headers['Authorization'] != 'Bearer test-token') {
      return _json(401, {'detail': 'Authentication required'});
    }

    final match =
        RegExp(r'^/api/v1/patients/(\d+)/([a-z]+-logs)$').firstMatch(request.url.path);
    if (match != null && request.method == 'POST') {
      posts.add(request.url.path);
      if (rejectWith != null) {
        return _json(rejectWith!, {
          'detail': 'Some fields are invalid',
          'errors': {'measurementTime': 'Must not be in the future'},
        });
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final uuid = body['clientUuid'] as String;
      final existed = saved.containsKey(uuid);
      saved.putIfAbsent(uuid, () => body);
      return _json(existed ? 200 : 201, {
        'id': saved.keys.toList().indexOf(uuid) + 1,
        'glucoseValue': body['glucoseValue'],
        'measurementTime': body['measurementTime'],
        'mealContext': body['mealContext'],
        'notes': null,
      });
    }

    return _json(404, {'detail': 'Resource not found'});
  });

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

Map<String, dynamic> glucoseBody(String uuid, int value) => {
      'glucoseValue': value,
      'measurementTime': '2026-11-23T08:30:00Z',
      'mealContext': 'FASTING',
      'source': 'MANUAL',
      'clientUuid': uuid,
    };

void main() {
  late FakeBackend backend;
  late ApiClient api;
  late OfflineQueue queue;
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

    backend = FakeBackend();
    api = ApiClient(httpClient: backend.client);
    queue = OfflineQueue(api: api);
    store = LogStore<GlucoseRecord>(
      resource: 'glucose-logs',
      fromJson: GlucoseRecord.fromJson,
      api: api,
      queue: queue,
    );
  });

  group('saving without a connection', () {
    test('create keeps the log on the phone and returns null', () async {
      backend.online = false;

      final result = await store.create(glucoseBody('u-1', 125));

      expect(result, isNull);
      expect(store.value, isEmpty);
      final pending = queue.forPatient(7).single;
      expect(pending.resource, 'glucose-logs');
      expect(pending.clientUuid, 'u-1');
      expect(pending.kindLabel, 'Blood Glucose');
      expect(pending.valueLabel, '125 mg/dL');

      // Stored encrypted, so it survives closing the app.
      final raw = await const FlutterSecureStorage()
          .read(key: OfflineQueue.storageKey);
      expect(raw, contains('u-1'));
    });

    test('online, create saves directly and queues nothing', () async {
      final result = await store.create(glucoseBody('u-1', 125));

      expect(result!.value, 125);
      expect(queue.value, isEmpty);
    });

    test('a validation error is not queued', () async {
      backend.rejectWith = 400;

      expect(
        () => store.create(glucoseBody('u-1', 125)),
        throwsA(isA<ApiException>()),
      );
      expect(queue.value, isEmpty);
    });

    test('saving the same entry twice offline keeps it once', () async {
      backend.online = false;

      await store.create(glucoseBody('u-1', 125));
      await store.create(glucoseBody('u-1', 125));

      expect(queue.value, hasLength(1));
    });

    test('a new app start reads the waiting logs back', () async {
      backend.online = false;
      await store.create(glucoseBody('u-1', 125));

      final afterRestart = OfflineQueue(api: api);
      await afterRestart.restore();

      expect(afterRestart.forPatient(7).single.valueLabel, '125 mg/dL');
    });
  });

  group('sync', () {
    test('sends the waiting logs oldest first and empties the queue',
        () async {
      backend.online = false;
      await store.create(glucoseBody('u-1', 110));
      await store.create(glucoseBody('u-2', 150));
      var reloads = 0;
      queue.onSynced = () async => reloads++;

      backend.online = true;
      final result = await queue.sync(7);

      expect(result.sent, 2);
      expect(result.stopped, isFalse);
      expect(backend.saved.keys, ['u-1', 'u-2']);
      expect(backend.posts.first, '/api/v1/patients/7/glucose-logs');
      expect(queue.value, isEmpty);
      expect(reloads, 1);
      expect(
        await const FlutterSecureStorage().read(key: OfflineQueue.storageKey),
        isNull,
      );
    });

    test('still offline: nothing is lost and it stops', () async {
      backend.online = false;
      await store.create(glucoseBody('u-1', 110));

      final result = await queue.sync(7);

      expect(result.stopped, isTrue);
      expect(result.sent, 0);
      expect(queue.value, hasLength(1));
    });

    test('a log that already reached the backend is not saved twice',
        () async {
      // The first try timed out after the backend had saved it.
      backend.saved['u-1'] = glucoseBody('u-1', 110);
      backend.online = false;
      await store.create(glucoseBody('u-1', 110));

      backend.online = true;
      final result = await queue.sync(7);

      expect(result.sent, 1);
      expect(backend.saved, hasLength(1));
      expect(queue.value, isEmpty);
    });

    test('a refused log keeps the reason, is skipped, and can be discarded',
        () async {
      backend.online = false;
      await store.create(glucoseBody('u-1', 110));

      backend.online = true;
      backend.rejectWith = 400;
      final result = await queue.sync(7);

      expect(result.rejected, 1);
      final log = queue.value.single;
      expect(log.error, 'Must not be in the future');

      backend.posts.clear();
      await queue.sync(7);
      expect(backend.posts, isEmpty);

      await queue.discard(log);
      expect(queue.value, isEmpty);
    });

    test('only the given patient logs are sent', () async {
      await queue.add(
        resource: 'glucose-logs',
        patientId: 8,
        body: glucoseBody('other', 99),
      );
      backend.online = false;
      await store.create(glucoseBody('mine', 120));

      backend.online = true;
      await queue.sync(7);

      expect(backend.saved.keys, ['mine']);
      expect(queue.value.single.patientId, 8);
    });

    test('an expired session stops the sync and keeps the logs', () async {
      backend.online = false;
      await store.create(glucoseBody('u-1', 110));
      FlutterSecureStorage.setMockInitialValues({});
      await const FlutterSecureStorage().write(
        key: OfflineQueue.storageKey,
        value: jsonEncode([queue.value.single.toJson()]),
      );

      backend.online = true;
      final result = await queue.sync(7);

      expect(result.stopped, isTrue);
      expect(queue.value, hasLength(1));
    });
  });

  group('OfflineModeScreen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: OfflineModeScreen(queue: queue, patientId: 7),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    testWidgets('nothing waiting', (tester) async {
      await pump(tester);

      expect(find.text('Everything is synced'), findsOneWidget);
      expect(find.text('Everything you logged has reached your account.'),
          findsOneWidget);
    });

    testWidgets('lists waiting logs and Sync sends them', (tester) async {
      await tester.runAsync(() async {
        backend.online = false;
        await store.create(glucoseBody('u-1', 125));
        backend.online = true;
      });
      await pump(tester);

      expect(find.text('1 entry waiting to sync'), findsOneWidget);
      expect(find.text('Blood Glucose • 125 mg/dL'), findsOneWidget);

      await tester.tap(find.text('Sync'));
      await settle(tester);

      expect(find.text('1 entry sent to your account.'), findsOneWidget);
      expect(find.text('Everything is synced'), findsOneWidget);
      expect(backend.saved.keys, ['u-1']);
    });

    testWidgets('a refused log shows the reason and can be discarded',
        (tester) async {
      await tester.runAsync(() async {
        backend.online = false;
        await store.create(glucoseBody('u-1', 125));
        backend.online = true;
        backend.rejectWith = 400;
        await queue.sync(7);
      });
      await pump(tester);

      expect(find.text('Not saved: Must not be in the future'), findsOneWidget);

      await tester.tap(find.byTooltip('Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await settle(tester);

      expect(find.text('Everything is synced'), findsOneWidget);
    });
  });
}
