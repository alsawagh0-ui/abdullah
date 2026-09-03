import 'dart:math';

/// منطق محاكاة البنق: كل ما زاد مستوى الشبكة، قلّت احتمالية ونسبة التقطيع.
/// MVP: نسبة عشوائية بسيطة بـ Dart، بدون أي حساب فيزيائي حقيقي للشبكة.
class PingLogic {
  final Random _random;

  PingLogic({Random? random}) : _random = random ?? Random();

  /// نسبة حدوث "لاق سبايك" بالثانية الواحدة حسب مستوى الشبكة (0-4).
  double lagChance(int networkLevel) {
    const baseChances = [0.35, 0.22, 0.12, 0.05, 0.01];
    final level = networkLevel.clamp(0, baseChances.length - 1).toInt();
    return baseChances[level];
  }

  /// يرجع true إذا صار تقطيع هالتك (يُستخدم بالـ Aim Trainer لتجاهل نقرة).
  bool rollLagSpike(int networkLevel) {
    return _random.nextDouble() < lagChance(networkLevel);
  }
}
