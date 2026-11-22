import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/screens/caregiver_dashboard_screen.dart';
import 'package:gradia/screens/doctor_dashboard_screen.dart';
import 'package:gradia/screens/role_selection_screen.dart';
import 'package:gradia/services/auth_service.dart';
import 'package:gradia/services/token_storage.dart';

/// Log Out on the doctor and caregiver screens must end the session,
/// not only go back to the start screen. Otherwise the saved token
/// logs the same user back in the next time the app is opened.
void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStorage.save(
      token: 'token-7',
      expiresInSeconds: 3600,
      userJson: jsonEncode({
        'id': 7,
        'firstName': 'Deniz',
        'lastName': 'Yılmaz',
        'email': 'd@example.com',
        'role': 'CLINICIAN',
      }),
    );
  });

  Future<void> logOutFrom(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    final tile = find.text('Log Out');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
    await tester.pumpAndSettle();
  }

  Future<void> expectSessionEnded() async {
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(await TokenStorage.readValidToken(), isNull);
    expect(authService.currentUser, isNull);
    // What main.dart does on the next app start.
    expect(await authService.restoreSession(), isNull);
  }

  testWidgets('doctor Log Out clears the saved session', (tester) async {
    expect(await authService.restoreSession(), isNotNull);

    await logOutFrom(tester, const DoctorDashboardScreen());
    await expectSessionEnded();
  });

  testWidgets('caregiver Log Out clears the saved session', (tester) async {
    expect(await authService.restoreSession(), isNotNull);

    await logOutFrom(tester, const CaregiverDashboardScreen());
    await expectSessionEnded();
  });
}
