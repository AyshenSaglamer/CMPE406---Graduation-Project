import 'package:flutter/material.dart';

import 'data/activity_store.dart';
import 'data/glucose_store.dart';
import 'data/insulin_store.dart';
import 'data/meal_store.dart';
import 'data/offline_queue.dart';
import 'models/app_user.dart';
import 'models/user_role.dart';
import 'navigation/session_navigation.dart';
import 'screens/role_selection_screen.dart';
import 'services/api_client.dart';
import 'services/api_exception.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final user = await authService.restoreSession();

  // Logs made without internet: once sent, reload the lists so they show.
  await offlineQueue.restore();
  offlineQueue.onSynced = () async {
    try {
      await Future.wait([
        glucoseStore.load(),
        insulinStore.load(),
        mealStore.load(),
        activityStore.load(),
      ]);
    } on ApiException {
      // Shown on the next successful load.
    }
  };
  offlineQueue.startAutoSync(() {
    final current = authService.currentUser;
    return current != null && current.role == UserRole.patient
        ? current.id
        : null;
  });

  ApiClient.onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const RoleSelectionScreen(),
      ),
      (route) => false,
    );
  };

  runApp(
    DiaMateApp(
      initialUser: user,
    ),
  );
}

class DiaMateApp extends StatelessWidget {
  final AppUser? initialUser;

  const DiaMateApp({
    super.key,
    this.initialUser,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'DiaMate',
      theme: DiaMateTheme.lightTheme,
      home: initialUser == null
          ? const RoleSelectionScreen()
          : homeScreenFor(initialUser!.role),
    );
  }
}