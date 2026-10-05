import 'package:flutter/material.dart';

import 'models/app_user.dart';
import 'navigation/session_navigation.dart';
import 'screens/role_selection_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final user = await authService.restoreSession();

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