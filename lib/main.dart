import 'package:flutter/material.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/auth/presentation/login_page.dart';
import 'src/features/dashboard/home/pharmacy_home_screen.dart';

void main() {
  runApp(const MedShakthiApp());
}

class MedShakthiApp extends StatelessWidget {
  const MedShakthiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Med Shakthi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const LoginPage(),
    );
  }
}
