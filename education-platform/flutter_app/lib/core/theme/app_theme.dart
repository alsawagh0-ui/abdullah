import 'package:flutter/material.dart';

/// تعريف مركزي لهوية التطبيق البصرية (الألوان والخطوط والأشكال)
/// حتى لا تتكرر قيم التصميم داخل الشاشات المختلفة.
class AppTheme {
  AppTheme._();

  static const Color primaryColor = Color(0xFF4F46E5); // إنديجو حديث
  static const Color backgroundColor = Color(0xFFF7F7FB);
  static const Color errorColor = Color(0xFFDC2626);

  /// الثيم الرئيسي المستخدم في MaterialApp.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'Cairo',
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
