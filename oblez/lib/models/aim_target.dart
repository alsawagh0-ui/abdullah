/// هدف واحد داخل الـ Aim Trainer: موضع نسبي (0.0-1.0) داخل منطقة اللعب.
class AimTarget {
  final int id;
  final double x;
  final double y;
  final DateTime spawnedAt;
  final Duration lifetime;

  const AimTarget({
    required this.id,
    required this.x,
    required this.y,
    required this.spawnedAt,
    required this.lifetime,
  });

  bool isExpired(DateTime now) => now.difference(spawnedAt) >= lifetime;
}
