import 'package:flutter/material.dart';

import 'screens/role_selection_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const DiaMateApp());
}

class DiaMateApp extends StatelessWidget {
  const DiaMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DiaMate',
      theme: DiaMateTheme.lightTheme,
      home: const RoleSelectionScreen(),
    );
  }
}