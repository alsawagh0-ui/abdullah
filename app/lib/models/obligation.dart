import 'occasion.dart';
import 'person.dart';

/// مستوى الوجوب كما يُعرض للمستخدم — ثلاث حالات بسيطة بصرياً لا رقم خام.
enum ObligationTier { confirmed, recommended, optional }

extension ObligationTierLabel on ObligationTier {
  String get label => switch (this) {
        ObligationTier.confirmed => 'واجب مؤكد',
        ObligationTier.recommended => 'يُستحسن',
        ObligationTier.optional => 'اختياري',
      };
}

/// تفصيل العوامل الداخلة في حساب الدرجة — لأغراض الشفافية مع المستخدم
/// («ليش هذا واجب مؤكد؟») ولاختبار المحرك.
class ObligationFactors {
  const ObligationFactors({
    required this.closeness,
    required this.occasionWeight,
    required this.reciprocity,
    required this.urgency,
    required this.feasibility,
  });

  /// قرب العلاقة 0..100
  final double closeness;

  /// وزن نوع المناسبة 0..100
  final double occasionWeight;

  /// رصيد المعاملة بالمثل 0..100
  final double reciprocity;

  /// إلحاح النافذة الزمنية 0..100
  final double urgency;

  /// إمكانية الحضور فعلياً بعد خصم التعارض والمسافة 0..100
  final double feasibility;

  static const double closenessWeight = 0.40;
  static const double occasionWeightWeight = 0.25;
  static const double reciprocityWeight = 0.15;
  static const double urgencyWeight = 0.10;
  static const double feasibilityWeight = 0.10;

  double get score =>
      closeness * closenessWeight +
      occasionWeight * occasionWeightWeight +
      reciprocity * reciprocityWeight +
      urgency * urgencyWeight +
      feasibility * feasibilityWeight;
}

/// نتيجة محرك درجة الوجوب لمناسبة واحدة.
class Obligation {
  const Obligation({
    required this.occasion,
    required this.person,
    required this.factors,
    required this.reasons,
  });

  final Occasion occasion;
  final Person person;
  final ObligationFactors factors;

  /// أسباب مقروءة بالعربية تشرح الدرجة للمستخدم.
  final List<String> reasons;

  int get score => factors.score.round().clamp(0, 100);

  ObligationTier get tier {
    if (score >= 70) return ObligationTier.confirmed;
    if (score >= 45) return ObligationTier.recommended;
    return ObligationTier.optional;
  }
}
