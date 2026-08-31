import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/subjects_provider.dart';
import 'screens/login/login_screen.dart';

void main() {
  runApp(const SmartEducationApp());
}

/// نقطة انطلاق التطبيق: يسجّل كل الـ Providers (إدارة الحالة عبر
/// Provider) مرة واحدة في الأعلى، فتصبح متاحة لأي شاشة فرعية.
class SmartEducationApp extends StatelessWidget {
  const SmartEducationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SubjectsProvider()),
      ],
      child: MaterialApp(
        title: 'منصة التعليم الذكي',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'KW'),
        supportedLocales: const [Locale('ar', 'KW'), Locale('en', 'US')],
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
