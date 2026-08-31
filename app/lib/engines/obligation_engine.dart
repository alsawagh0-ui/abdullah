import '../models/obligation.dart';
import '../models/occasion.dart';
import '../models/person.dart';
import 'reciprocity_ledger.dart';

/// المحرك الثالث — درجة الوجوب.
///
/// يحسب لكل مناسبة درجة من 100 اعتماداً على خمسة عوامل مرجّحة:
/// قرب العلاقة (40%)، نوع المناسبة (25%)، رصيد المعاملة بالمثل (15%)،
/// إلحاح النافذة الزمنية (10%)، وإمكانية الحضور فعلياً (10%).
///
/// المخرج المعروض للمستخدم ثلاث حالات فقط: واجب مؤكد / يُستحسن / اختياري.
class ObligationEngine {
  const ObligationEngine({this.ledger});

  final ReciprocityLedger? ledger;

  Obligation evaluate({
    required Occasion occasion,
    required Person person,
    required DateTime now,
    List<Occasion> sameDayOccasions = const <Occasion>[],
    String? userArea,
  }) {
    final reasons = <String>[];

    final closeness = person.closeness.toDouble();
    if (closeness >= 80) {
      reasons.add('${person.kinship ?? person.circle.label} من دائرتك الأقرب');
    } else if (closeness < 35) {
      reasons.add('العلاقة في دائرة معرفة عامة');
    }

    final occasionWeight = occasion.type.weight.toDouble();
    if (occasion.type == OccasionType.condolence) {
      reasons.add('العزاء أثقل الواجبات في العرف');
    }

    final reciprocity = ledger?.reciprocityScore(person.id) ?? 50.0;
    if (reciprocity > 65) {
      reasons.add('لهم عندك واجب سابق لم يُرَدّ');
    }

    final urgency = _urgency(occasion, now, reasons);
    final feasibility =
        _feasibility(occasion, person, sameDayOccasions, userArea, reasons);

    final factors = ObligationFactors(
      closeness: closeness,
      occasionWeight: occasionWeight,
      reciprocity: reciprocity,
      urgency: urgency,
      feasibility: feasibility,
    );

    return Obligation(
      occasion: occasion,
      person: person,
      factors: factors,
      reasons: reasons,
    );
  }

  /// ترتيب مناسبات اليوم بدرجة الوجوب تنازلياً.
  ///
  /// هذا ترتيب للواجبات لا للأشخاص: لا يُعرض أي مقياس يقارن بين الناس.
  List<Obligation> rank({
    required List<Occasion> occasions,
    required Map<String, Person> people,
    required DateTime now,
    String? userArea,
  }) {
    final active = occasions
        .where((o) => !o.done && !o.dismissed && o.isActiveAt(now))
        .toList();

    final result = <Obligation>[];
    for (final occasion in active) {
      final person = people[occasion.personId];
      if (person == null) continue;
      final sameDay = active
          .where((o) =>
              o.id != occasion.id &&
              _isSameDay(o.startsAt, occasion.startsAt))
          .toList();
      result.add(evaluate(
        occasion: occasion,
        person: person,
        now: now,
        sameDayOccasions: sameDay,
        userArea: userArea,
      ));
    }

    result.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.occasion.startsAt.compareTo(b.occasion.startsAt);
    });
    return result;
  }

  double _urgency(Occasion occasion, DateTime now, List<String> reasons) {
    if (now.isBefore(occasion.startsAt)) {
      final hoursUntil = occasion.startsAt.difference(now).inMinutes / 60.0;
      if (hoursUntil <= 24) {
        reasons.add('يبدأ خلال أقل من يوم');
        return 85;
      }
      if (hoursUntil <= 72) return 60;
      return 35;
    }

    final total = occasion.endsAt.difference(occasion.startsAt).inMinutes;
    if (total <= 0) return 100;
    final remaining = occasion.endsAt.difference(now).inMinutes;
    if (remaining <= 0) return 0;
    final elapsedRatio = 1 - (remaining / total);
    final dayIndex = occasion.dayIndexAt(now);
    if (dayIndex == occasion.effectiveDurationDays &&
        occasion.effectiveDurationDays > 1) {
      reasons.add('آخر يوم — الفرصة الأخيرة');
      return 100;
    }
    if (dayIndex == 1) {
      reasons.add('اليوم الأول للمناسبة');
    }
    return (60 + 40 * elapsedRatio).clamp(0.0, 100.0);
  }

  double _feasibility(
    Occasion occasion,
    Person person,
    List<Occasion> sameDayOccasions,
    String? userArea,
    List<String> reasons,
  ) {
    var score = 100.0;

    final heavier = sameDayOccasions
        .where((o) => o.type.weight > occasion.type.weight)
        .length;
    if (heavier > 0) {
      score -= (15.0 * heavier).clamp(0.0, 30.0);
      reasons.add('يتعارض مع $heavier واجب أثقل في اليوم نفسه');
    }

    final venue = occasion.menVenue ?? occasion.womenVenue;
    if (userArea != null && venue?.area != null && venue!.area != userArea) {
      score -= 10;
    }
    if (venue == null || (venue.area == null && venue.address == null)) {
      score -= 5;
    }

    return score.clamp(30.0, 100.0);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
