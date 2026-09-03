import 'package:flutter/foundation.dart';

/// مراحل التقدم بالقصة (تُستخدم لاحقاً لفتح محتوى/شاشات جديدة).
enum ProgressionTier { beginner, skilled, pro, ending }

/// حالة اللاعب المركزية: الطاقة، الوقت، الراتب، الشبكة، والإنذارات.
/// أي شاشة بالتطبيق تقرأ/تعدّل من خلال هالكلاس عبر Provider.
class PlayerState extends ChangeNotifier {
  /// طاقة اللاعب (0-100). تنخفض بالسهر والمجهود، تزيد بالنوم.
  int energy;

  /// الساعة الحالية بنظام 24 ساعة (0-23).
  int hour;

  /// رقم اليوم الحالي داخل اللعبة (يبدأ من 1).
  int day;

  /// رصيد اللاعب من الفلوس.
  int money;

  /// عدد اتصالات المدير المتجاهلة تراكمياً (3 = فصل من الشغل).
  int missedManagerCalls;

  /// مستوى ترقية الشبكة الحالي (0 = راوتر منزلي ضعيف).
  int networkLevel;

  /// مستوى ترقية العتاد الحالي (0 = كرسي عادي).
  int gearLevel;

  /// مرحلة التقدم الحالية بالقصة.
  ProgressionTier tier;

  /// هل اللاعب لسا موظف؟ يتحول false عند الفصل (Game Over).
  bool isEmployed;

  /// نقاط الرانك المتراكمة من الـ Aim Trainer (تُستخدم للتأهل للبطولات لاحقاً).
  int rankPoints;

  PlayerState({
    this.energy = 100,
    this.hour = 9,
    this.day = 1,
    this.money = 0,
    this.missedManagerCalls = 0,
    this.networkLevel = 0,
    this.gearLevel = 0,
    this.tier = ProgressionTier.beginner,
    this.isEmployed = true,
    this.rankPoints = 0,
  });

  bool get isFired => missedManagerCalls >= 3;

  void changeEnergy(int amount) {
    energy = (energy + amount).clamp(0, 100).toInt();
    notifyListeners();
  }

  void addMoney(int amount) {
    money = (money + amount) < 0 ? 0 : money + amount;
    notifyListeners();
  }

  void addRankPoints(int amount) {
    rankPoints += amount;
    notifyListeners();
  }

  /// اتصال مدير متجاهل: خصم من الراتب + إنذار يتراكم، وعند الثالث يُفصل اللاعب.
  void ignoreManagerCall({int salaryPenalty = 50}) {
    missedManagerCalls += 1;
    money = (money - salaryPenalty) < 0 ? 0 : money - salaryPenalty;
    if (isFired) {
      isEmployed = false;
    }
    notifyListeners();
  }

  void advanceHour([int hours = 1]) {
    hour = (hour + hours) % 24;
    notifyListeners();
  }

  void sleep() {
    energy = (energy + 40).clamp(0, 100).toInt();
    hour = 9;
    day += 1;
    notifyListeners();
  }
}
