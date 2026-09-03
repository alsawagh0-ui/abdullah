import 'dart:math';

/// منطق توليد الأهداف وحساب النقاط لـ Aim Trainer، بمعزل عن الواجهة عشان
/// يسهل اختباره بدون Widgets.
class AimTrainerLogic {
  final Random _random;

  AimTrainerLogic({Random? random}) : _random = random ?? Random();

  /// موضع عشوائي نسبي (0.0-1.0) داخل منطقة اللعب، بهامش أمان من الحواف.
  ({double x, double y}) randomPosition({double margin = 0.12}) {
    final x = margin + _random.nextDouble() * (1 - margin * 2);
    final y = margin + _random.nextDouble() * (1 - margin * 2);
    return (x: x, y: y);
  }

  /// عمر الهدف قبل ما يختفي؛ يقصر شوي كل ما زاد الكومبو (تحدي أعلى).
  Duration targetLifetime(int combo) {
    final ms = (1400 - combo * 20).clamp(500, 1400).toInt();
    return Duration(milliseconds: ms);
  }

  /// نقاط الإصابة الواحدة، تزيد مع الكومبو.
  int scoreForHit(int combo) => 10 + (combo ~/ 5) * 2;

  /// إزاحة عشوائية صغيرة (تهز الهدف) تُستخدم لما طاقة اللاعب تكون منخفضة.
  ({double dx, double dy}) jitterOffset({double magnitude = 0.03}) {
    final dx = (_random.nextDouble() * 2 - 1) * magnitude;
    final dy = (_random.nextDouble() * 2 - 1) * magnitude;
    return (dx: dx, dy: dy);
  }
}
