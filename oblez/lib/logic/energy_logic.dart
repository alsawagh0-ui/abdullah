/// منطق استنزاف/استرجاع الطاقة، بمعزل عن PlayerState عشان يسهل اختباره.
class EnergyLogic {
  /// استنزاف الطاقة بالساعة أثناء السهر (يقل مع ترقية الكرسي/العتاد).
  static int hourlyDrain(int gearLevel) {
    const baseDrain = [6, 4, 2];
    final level = gearLevel.clamp(0, baseDrain.length - 1).toInt();
    return baseDrain[level];
  }

  /// هل الطاقة منخفضة بدرجة تأثر على الأداء (اهتزاز مؤشر، تأخر استجابة)؟
  static bool isLow(int energy) => energy <= 30;
}
