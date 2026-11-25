import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/screens/ai_assistant_screen.dart';
import 'package:gradia/widgets/ai_chat_button.dart';

void main() {
  testWidgets('the assistant button opens the assistant', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Text('Home'),
        floatingActionButton: AiChatButton(),
      ),
    ));

    expect(find.byTooltip('DiaMate Assistant'), findsOneWidget);

    await tester.tap(find.byType(AiChatButton));
    await tester.pumpAndSettle();

    expect(find.byType(AiAssistantScreen), findsOneWidget);
  });

  // The button is on the patient's screens, not on the entry forms (Save
  // sits at the bottom there), the assistant itself or other roles' screens.
  test('only the patient screens show the assistant button', () {
    const withButton = [
      'dashboard_screen.dart',
      'patient_alerts_screen.dart',
      'offline_mode_screen.dart',
      'care_team_screen.dart',
      'pdf_report_screen.dart',
      'csv_import_screen.dart',
    ];
    const withoutButton = [
      'ai_assistant_screen.dart',
      'glucose_entry_screen.dart',
      'insulin_entry_screen.dart',
      'meal_entry_screen.dart',
      'activity_entry_screen.dart',
      'reminder_screen.dart',
      'doctor_dashboard_screen.dart',
      'caregiver_dashboard_screen.dart',
      'login_screen.dart',
      'register_screen.dart',
      'role_selection_screen.dart',
    ];

    String source(String name) =>
        File('lib/screens/$name').readAsStringSync();

    // The report screen shows it only for the patient's own report (not on a
    // family member's), so a condition may stand between the two.
    for (final name in withButton) {
      expect(
        source(name),
        contains(RegExp(r'floatingActionButton:[^;]{0,80}const AiChatButton\(\)')),
        reason: name,
      );
    }
    for (final name in withoutButton) {
      expect(source(name), isNot(contains('AiChatButton')), reason: name);
    }
  });
}
