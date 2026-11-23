import 'package:flutter/material.dart';

import '../data/activity_store.dart';
import '../data/glucose_store.dart';
import '../data/insulin_store.dart';
import '../data/meal_store.dart';
import '../models/user_role.dart';
import '../screens/caregiver_dashboard_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/doctor_dashboard_screen.dart';
import '../screens/role_selection_screen.dart';
import '../services/auth_service.dart';

Widget homeScreenFor(UserRole role) {
  switch (role) {
    case UserRole.patient:
      return const DashboardScreen();

    case UserRole.caregiver:
      return const CaregiverDashboardScreen();

    case UserRole.doctor:
      return const DoctorDashboardScreen();
  }
}

void goToHome(BuildContext context, UserRole role) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => homeScreenFor(role)),
    (route) => false,
  );
}

Future<void> logoutAndReturnToStart(BuildContext context) async {
  await authService.logout();
  glucoseStore.clear();
  insulinStore.clear();
  mealStore.clear();
  activityStore.clear();

  if (!context.mounted) {
    return;
  }

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    (route) => false,
  );
}
