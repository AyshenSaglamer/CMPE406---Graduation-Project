import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/care_store.dart';
import 'package:gradia/screens/care_invitations_screen.dart';
import 'package:gradia/screens/care_team_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A test-only stand-in for /api/v1/care-relationships, answering like the
/// real backend (CareRelationshipService): unknown email 404, a second open
/// invitation 409, accept/decline only while PENDING.
class FakeBackend {
  final requests = <http.Request>[];

  /// Accounts that can be invited: email -> (id, first, last, role).
  final members = <String, (int, String, String, String)>{
    'dr.ayse@example.com': (21, 'Ayşe', 'Kaya', 'CLINICIAN'),
    'mom@example.com': (22, 'Elif', 'Demir', 'CAREGIVER'),
  };

  final rows = <Map<String, dynamic>>[];
  var _nextId = 100;

  Map<String, dynamic> row({
    required String email,
    String status = 'PENDING',
    bool hasAccess = false,
  }) {
    final m = members[email]!;
    final r = <String, dynamic>{
      'id': _nextId++,
      'patientId': 7,
      'patientFirstName': 'Nil',
      'patientLastName': 'Su',
      'memberId': m.$1,
      'memberFirstName': m.$2,
      'memberLastName': m.$3,
      'memberEmail': email,
      'memberRole': m.$4,
      'status': status,
      'canViewGlucose': true,
      'canViewMeals': true,
      'canViewMedications': true,
      'canViewActivity': true,
      'canViewReports': true,
      'canReceiveAlerts': true,
      'canAddRecommendations': false,
      'invitedAt': '2026-11-22T10:00:00Z',
      'respondedAt': null,
      'revokedAt': null,
      'expiresAt': null,
      'hasAccess': hasAccess,
    };
    rows.insert(0, r);
    return r;
  }

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    const base = '/api/v1/care-relationships';

    if (request.headers['Authorization'] != 'Bearer test-token') {
      return _json(401, {'detail': 'Authentication required'});
    }

    if (path == base && request.method == 'GET') {
      final status = request.url.queryParameters['status'];
      return _json(200, [
        for (final r in rows)
          if (status == null || r['status'] == status) r,
      ]);
    }

    if (path == base && request.method == 'POST') {
      final email = (jsonDecode(request.body) as Map)['memberEmail'] as String;
      if (!members.containsKey(email)) {
        return _json(404, {
          'detail': 'No active clinician or caregiver account with this email',
        });
      }
      final open = rows.any((r) =>
          r['memberEmail'] == email &&
          (r['status'] == 'PENDING' || r['status'] == 'ACTIVE'));
      if (open) {
        return _json(409, {
          'detail': 'This person already has a pending invitation or access',
        });
      }
      return _json(201, row(email: email));
    }

    final match = RegExp(r'^/api/v1/care-relationships/(\d+)(/accept|/decline)?$')
        .firstMatch(path);
    if (match != null) {
      final id = int.parse(match.group(1)!);
      final r = rows.where((r) => r['id'] == id).firstOrNull;
      if (r == null) {
        return _json(404, {'detail': 'Care relationship not found'});
      }
      final action = match.group(2);

      if (request.method == 'DELETE' && action == null) {
        r['status'] = 'REVOKED';
        r['hasAccess'] = false;
        return http.Response('', 204);
      }

      if (request.method == 'POST' && action != null) {
        if (r['status'] != 'PENDING') {
          return _json(409, {
            'detail':
                'Care relationship is already ${(r['status'] as String).toLowerCase()}',
          });
        }
        r['status'] = action == '/accept' ? 'ACTIVE' : 'DECLINED';
        r['hasAccess'] = action == '/accept';
        return _json(200, r);
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

void main() {
  late FakeBackend backend;
  late CareStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'access_token_expires_at':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    backend = FakeBackend();
    store = CareStore(api: ApiClient(httpClient: backend.client));
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  group('CareStore', () {
    test('invite sends the trimmed email and reads the PENDING answer',
        () async {
      final r = await store.invite('  dr.ayse@example.com ');

      expect(jsonDecode(backend.requests.single.body),
          {'memberEmail': 'dr.ayse@example.com'});
      expect(r.status, CareRelationship.pending);
      expect(r.memberName, 'Ayşe Kaya');
      expect(r.isClinician, isTrue);
      expect(r.roleLabel, 'Doctor');
      expect(r.statusLabel, 'Waiting for answer');
    });

    test('an unknown email gives the backend message', () async {
      expect(
        () => store.invite('nobody@example.com'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message',
                'No active clinician or caregiver account with this email')),
      );
    });

    test('pendingInvitations asks only for PENDING ones', () async {
      backend.row(email: 'dr.ayse@example.com');
      backend.row(email: 'mom@example.com', status: 'ACTIVE', hasAccess: true);

      final pending = await store.pendingInvitations();

      expect(backend.requests.single.url.queryParameters['status'], 'PENDING');
      expect(pending.single.memberEmail, 'dr.ayse@example.com');
    });

    test('an ACTIVE relationship past its end date reads as Expired', () {
      final r = CareRelationship.fromJson({
        'id': 1,
        'patientId': 7,
        'memberId': 21,
        'memberRole': 'CAREGIVER',
        'status': 'ACTIVE',
        'hasAccess': false,
      });

      expect(r.statusLabel, 'Expired');
      expect(r.isOpen, isTrue);
      expect(r.roleLabel, 'Caregiver');
    });
  });

  group('CareTeamScreen (patient)', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: CareTeamScreen(store: store)));
      await settle(tester);
    }

    testWidgets('empty team shows a hint', (tester) async {
      await pump(tester);

      expect(find.textContaining('Nobody can see your data yet'),
          findsOneWidget);
    });

    testWidgets('inviting adds the person as waiting', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextFormField), 'dr.ayse@example.com');
      await tester.tap(find.text('Send invitation'));
      await settle(tester);

      expect(find.text('Ayşe Kaya'), findsOneWidget);
      expect(find.text('Waiting for answer'), findsOneWidget);
      expect(find.text('Invitation sent to Ayşe Kaya.'), findsOneWidget);
    });

    testWidgets('a wrong email is caught before sending', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Send invitation'));
      await settle(tester);

      expect(find.text('Please enter a valid email.'), findsOneWidget);
      expect(backend.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('the backend reason is shown under the field', (tester) async {
      backend.row(email: 'dr.ayse@example.com');
      await pump(tester);

      await tester.enterText(find.byType(TextFormField), 'dr.ayse@example.com');
      await tester.tap(find.text('Send invitation'));
      await settle(tester);

      expect(
        find.text('This person already has a pending invitation or access'),
        findsOneWidget,
      );
    });

    testWidgets('stop sharing ends an active relationship after confirming',
        (tester) async {
      backend.row(email: 'mom@example.com', status: 'ACTIVE', hasAccess: true);
      await pump(tester);

      expect(find.text('Elif Demir'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      await tester.tap(find.byTooltip('Stop sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Elif Demir will no longer see your health data.'),
          findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Stop sharing'));
      await settle(tester);

      expect(backend.rows.single['status'], 'REVOKED');
      expect(find.text('Elif Demir'), findsNothing);
      expect(find.textContaining('Nobody can see your data yet'),
          findsOneWidget);
    });
  });

  group('CareInvitationsScreen (doctor / caregiver)', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester
          .pumpWidget(MaterialApp(home: CareInvitationsScreen(store: store)));
      await settle(tester);
    }

    testWidgets('no invitations explains how a patient invites',
        (tester) async {
      await pump(tester);

      expect(find.textContaining('No open invitations'), findsOneWidget);
    });

    testWidgets('accept makes the relationship active', (tester) async {
      backend.row(email: 'dr.ayse@example.com');
      await pump(tester);

      expect(find.text('Nil Su'), findsOneWidget);
      expect(find.textContaining('Shares: glucose, meals'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await settle(tester);

      expect(backend.rows.single['status'], 'ACTIVE');
      expect(find.text('You can now follow Nil Su.'), findsOneWidget);
      expect(find.textContaining('No open invitations'), findsOneWidget);
    });

    testWidgets('decline makes the relationship declined', (tester) async {
      backend.row(email: 'mom@example.com');
      await pump(tester);

      await tester.tap(find.text('Decline'));
      await settle(tester);

      expect(backend.rows.single['status'], 'DECLINED');
      expect(find.text('Invitation from Nil Su declined.'), findsOneWidget);
    });

    testWidgets('an invitation withdrawn meanwhile is removed on reload',
        (tester) async {
      final r = backend.row(email: 'dr.ayse@example.com');
      await pump(tester);

      // The patient withdraws it before the doctor answers.
      r['status'] = 'REVOKED';
      await tester.tap(find.text('Accept'));
      await settle(tester);

      expect(find.text('Care relationship is already revoked'), findsOneWidget);
      expect(find.text('Nil Su'), findsNothing);
    });
  });
}
