import 'package:flutter/material.dart';

/// نظام التصميم.
///
/// قاعدتان تحكمان اللون هنا:
/// 1) واجهة العزاء هادئة تماماً — رمادي وقور بلا ألوان صارخة ولا حركة.
/// 2) نمط كبار السن يكبّر الخط ويرفع التباين دون تغيير بنية الشاشة.
class WajbTheme {
  const WajbTheme._();

  /// الخط المدمج. تضمينه — بدل الاعتماد على خط النظام — يوحّد شكل
  /// النص العربي بين iOS وإصدارات Android المختلفة، ويحفظ اتساق
  /// التشكيل والأرقام.
  static const String fontFamily = 'Cairo';

  static const Color primary = Color(0xFF0B6E4F);
  static const Color solemn = Color(0xFF37474F);
  static const Color sand = Color(0xFFF6F3EC);

  static ThemeData light({bool elderMode = false, bool solemnMode = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: solemnMode ? solemn : primary,
      brightness: Brightness.light,
    );
    return _build(scheme, elderMode: elderMode, solemnMode: solemnMode);
  }

  static ThemeData dark({bool elderMode = false, bool solemnMode = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: solemnMode ? solemn : primary,
      brightness: Brightness.dark,
    );
    return _build(scheme, elderMode: elderMode, solemnMode: solemnMode);
  }

  static ThemeData _build(
    ColorScheme scheme, {
    required bool elderMode,
    required bool solemnMode,
  }) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor:
          scheme.brightness == Brightness.light && !solemnMode
              ? sand
              : scheme.surface,
      visualDensity: elderMode
          ? const VisualDensity(horizontal: 0, vertical: 1)
          : VisualDensity.standard,
    );

    // تكبير الخط في نمط كبار السن يتم عبر textScaler على مستوى التطبيق
    // (انظر WajbApp) لا عبر تعديل أحجام النسق: بعض أنماط M3 بلا حجم صريح،
    // وتعديلها بمعامل ضرب يُسقط التطبيق.
    return base.copyWith(
      textTheme: elderMode
          ? base.textTheme.apply(bodyColor: scheme.onSurface)
          : base.textTheme,
      cardTheme: CardThemeData(
        elevation: solemnMode ? 0 : 1,
        margin: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: elderMode ? 10 : 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(elderMode ? 56 : 48),
          // مشتق من نسق النص كي يرث الخط المدمج؛ TextStyle مستقل هنا
          // يُسقط العائلة ويجعل نص الأزرار مختلفاً عن بقية الواجهة.
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontSize: elderMode ? 19 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(elderMode ? 56 : 48),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontSize: elderMode ? 19 : 16,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: elderMode ? 14 : 8,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: solemnMode ? scheme.surface : null,
      ),
    );
  }
}
