import 'package:flutter/material.dart';

import '../core/models/enums.dart';

/// Calm, minimal, high-contrast. One accent, one progress colour, one
/// success, one danger — the task state header does the talking.
abstract final class AppTheme {
  static const fontFamily = 'Cairo';

  static const accent = Color(0xFF1F5F8B);   // ownership / primary action
  static const progress = Color(0xFFB4690E); // in progress
  static const success = Color(0xFF1E7B4F);  // completed
  static const warning = Color(0xFF8A6D00);  // awaiting approval
  static const danger = Color(0xFFB3261E);   // overdue
  static const muted = Color(0xFF6B7280);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: fontFamily, brightness: b);
    return base.copyWith(
      scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF7F7F5) : const Color(0xFF111315),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accent, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), side: BorderSide.none),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface)),
      ),
    );
  }

  static Color statusColor(TaskStatus s, {bool overdue = false}) {
    if (overdue) return danger;
    return switch (s) {
      TaskStatus.newTask => accent,
      TaskStatus.inProgress => progress,
      TaskStatus.awaitingApproval => warning,
      TaskStatus.completed => success,
      TaskStatus.cancelled => muted,
    };
  }

  static Color priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.low => muted,
        TaskPriority.normal => accent,
        TaskPriority.high => progress,
        TaskPriority.urgent => danger,
      };
}
