import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/login_screen.dart';

class BeemViewApp extends StatelessWidget {
  const BeemViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beem View 360',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
