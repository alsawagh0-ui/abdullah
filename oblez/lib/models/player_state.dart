import 'package:flutter/foundation.dart';

import '../logic/energy_logic.dart';
import '../logic/progression_logic.dart';
import 'game_day.dart';
import 'shop_item.dart';

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

  /// معرّفات عناصر الفلكس (التجميلية) المملوكة — بلا تأثير وظيفي.
  final Set<String> ownedCosmetics;

  /// عدد جولات الرانك المتتالية اللي خسرها اللاعب (تحت حد النجاح).
  int consecutiveRankLosses;

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
    this.consecutiveRankLosses = 0,
    Set<String>? ownedCosmetics,
  }) : ownedCosmetics = ownedCosmetics ?? {};

  /// سعر الهدف النهائي (عقار = بنق مستقر 0ms، شاشة الفوز).
  static const int propertyPrice = 5000;

  /// أي جولة Aim Trainer بنقاط أقل من هالحد تُحسب "خسارة رانك".
  static const int rankLossScoreThreshold = 50;

  /// عدد الخسائر المتتالية اللي تؤدي للطرد من الفريق.
  static const int maxConsecutiveRankLosses = 3;

  bool get isFired => missedManagerCalls >= 3;

  bool get isKickedFromTeam =>
      consecutiveRankLosses >= maxConsecutiveRankLosses;

  bool get canBuyProperty =>
      tier == ProgressionTier.pro && money >= propertyPrice;

  /// يعيد حساب مرحلة التقدم من الإحصائيات الحالية، بدون المساس بمرحلة
  /// النهاية بعد ما تتحقق (تُفعّل فقط عبر [buyProperty]).
  void _refreshTier() {
    if (tier == ProgressionTier.ending) return;
    tier = ProgressionLogic.computeTier(
      gearLevel: gearLevel,
      networkLevel: networkLevel,
      rankPoints: rankPoints,
    );
  }

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
    _refreshTier();
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

  /// تقدّم فعلي بالوقت أثناء اللعب: كل نبضة تمثّل ساعة، وتستنزف طاقة
  /// حسب مستوى العتاد (كرسي أفضل = استنزاف أقل).
  void tickHour() {
    hour = (hour + 1) % 24;
    energy = (energy - EnergyLogic.hourlyDrain(gearLevel)).clamp(0, 100).toInt();
    notifyListeners();
  }

  /// نتيجة جولة Aim Trainer: يحدّث الفلوس ونقاط الرانك، ويتابع سلسلة
  /// خسائر الرانك — 3 خسائر متتالية تطرد اللاعب من الفريق (Game Over).
  ({bool kicked, int reward}) recordAimTrainerResult(int score) {
    final reward = (score / 5).round();
    addMoney(reward);
    addRankPoints(score);

    if (score < rankLossScoreThreshold) {
      consecutiveRankLosses += 1;
    } else {
      consecutiveRankLosses = 0;
    }
    notifyListeners();

    return (kicked: isKickedFromTeam, reward: reward);
  }

  void sleep() {
    energy = (energy + 40).clamp(0, 100).toInt();
    hour = 9;
    day += 1;
    notifyListeners();
  }

  /// شراء ترقية عتاد: لازم تكون العنصر أول مستوى فوق الحالي وتوفر السعر.
  bool buyGearUpgrade(ShopItem item) {
    if (item.tier != gearLevel + 1 || money < item.price) return false;
    money -= item.price;
    gearLevel = item.tier;
    _refreshTier();
    notifyListeners();
    return true;
  }

  /// شراء ترقية شبكة: نفس منطق العتاد، بس على مستوى الشبكة.
  bool buyNetworkUpgrade(ShopItem item) {
    if (item.tier != networkLevel + 1 || money < item.price) return false;
    money -= item.price;
    networkLevel = item.tier;
    _refreshTier();
    notifyListeners();
    return true;
  }

  /// شراء الهدف النهائي: عقار = بنق مستقر 0ms. يتطلب مرحلة "المحترف".
  bool buyProperty() {
    if (!canBuyProperty) return false;
    money -= propertyPrice;
    tier = ProgressionTier.ending;
    notifyListeners();
    return true;
  }

  /// شراء عنصر فلكس/تجميلي: عناصر مستقلة بلا مستويات، تُملك مرة وحدة.
  bool buyCosmetic(ShopItem item) {
    if (ownedCosmetics.contains(item.id) || money < item.price) return false;
    money -= item.price;
    ownedCosmetics.add(item.id);
    notifyListeners();
    return true;
  }

  /// يطبّق أثر القرار اليومي المختار، ثم ينام/يمرّر لليوم التالي.
  void applyDailyChoice(DailyChoice choice) {
    switch (choice) {
      case DailyChoice.extraRank:
        changeEnergy(-15);
        addRankPoints(25);
        break;
      case DailyChoice.extraWork:
        addMoney(80);
        changeEnergy(-20);
        break;
      case DailyChoice.sleepEarly:
        if (missedManagerCalls > 0) missedManagerCalls -= 1;
        break;
    }
    sleep();
  }
}
