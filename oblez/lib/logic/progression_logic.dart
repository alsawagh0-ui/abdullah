import '../models/player_state.dart';

/// يحسب مرحلة التقدم الحالية بناءً على ترقيات العتاد/الشبكة ونقاط الرانك.
/// ما يرجّع أبداً [ProgressionTier.ending] — تلك تُفعّل فقط بشراء العقار
/// صراحة عبر [PlayerState.buyProperty]، مو بحساب تلقائي.
class ProgressionLogic {
  static ProgressionTier computeTier({
    required int gearLevel,
    required int networkLevel,
    required int rankPoints,
  }) {
    if (gearLevel >= 2 && networkLevel >= 2 && rankPoints >= 150) {
      return ProgressionTier.pro;
    }
    if (gearLevel >= 1 && networkLevel >= 1) {
      return ProgressionTier.skilled;
    }
    return ProgressionTier.beginner;
  }

  static String labelFor(ProgressionTier tier) {
    switch (tier) {
      case ProgressionTier.beginner:
        return 'المبتدئ';
      case ProgressionTier.skilled:
        return 'المتمكن';
      case ProgressionTier.pro:
        return 'المحترف';
      case ProgressionTier.ending:
        return 'الأسطورة';
    }
  }
}
