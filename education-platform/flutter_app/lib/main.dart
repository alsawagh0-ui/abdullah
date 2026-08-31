import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() {
  runApp(const SmartEducationApp());
}

class SmartEducationApp extends StatelessWidget {
  const SmartEducationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'منصة التعليم الذكي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'KW'),
      supportedLocales: const [Locale('ar', 'KW'), Locale('en', 'US')],
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      home: const LoginScreen(),
    );
  }
}
