

/// الدوائر الاجتماعية التي ينتمي إليها الشخص.
///
/// خط أحمر تصميمي: لا يوجد — ولن يوجد — أي حقل للقبيلة أو الطائفة أو
/// المنطقة في بنية البيانات. الدوائر هنا وظيفية بحتة (علاقة المستخدم بالشخص)
/// ولا تحمل أي تصنيف هوياتي.
enum SocialCircle { family, inLaws, diwaniya, work, neighbors, study }

extension SocialCircleLabel on SocialCircle {
  String get label => switch (this) {
        SocialCircle.family => 'العائلة',
        SocialCircle.inLaws => 'الأصهار',
        SocialCircle.diwaniya => 'الديوانية',
        SocialCircle.work => 'الزمالة',
        SocialCircle.neighbors => 'الجيرة',
        SocialCircle.study => 'الدراسة',
      };

  /// وزن ابتدائي للقرب يُقترح على المستخدم عند التصنيف السريع،
  /// ويظل قابلاً للتعديل يدوياً في كل الأحوال.
  int get suggestedCloseness => switch (this) {
        SocialCircle.family => 85,
        SocialCircle.inLaws => 70,
        SocialCircle.diwaniya => 60,
        SocialCircle.work => 50,
        SocialCircle.neighbors => 45,
        SocialCircle.study => 40,
      };
}

enum Gender { male, female }

extension GenderLabel on Gender {
  String get label => this == Gender.male ? 'رجل' : 'امرأة';
}

/// عقدة في خريطة العلاقات. بيانات خاصة بالمستخدم وحده، لا تُشارك ولا تُعرض
/// لأي طرف آخر، ولا تُستخدم في أي ترتيب ظاهر يقارن بين الأشخاص.
class Person {
  Person({
    required this.id,
    required this.displayName,
    required this.circle,
    required this.closeness,
    this.gender = Gender.male,
    this.kinship,
    this.phone,
    this.areaHint,
    this.lastInteraction,
  }) : assert(closeness >= 0 && closeness <= 100,
            'درجة القرب يجب أن تكون بين 0 و 100');

  final String id;
  final String displayName;
  final SocialCircle circle;

  /// درجة القرب 0..100 — يحدّدها المستخدم ويقترح النظام تعديلها بناءً على
  /// التفاعل الفعلي، ولا تُعرض لأي شخص آخر أبداً.
  final int closeness;
  final Gender gender;

  /// صلة القرابة كما يكتبها المستخدم بحرّية (ابن العم، زميل، جار...).
  final String? kinship;
  final String? phone;
  final String? areaHint;
  final DateTime? lastInteraction;

  ClosenessTier get tier => ClosenessTier.of(closeness);

  Person copyWith({
    String? displayName,
    SocialCircle? circle,
    int? closeness,
    Gender? gender,
    String? kinship,
    String? phone,
    String? areaHint,
    DateTime? lastInteraction,
  }) {
    return Person(
      id: id,
      displayName: displayName ?? this.displayName,
      circle: circle ?? this.circle,
      closeness: closeness ?? this.closeness,
      gender: gender ?? this.gender,
      kinship: kinship ?? this.kinship,
      phone: phone ?? this.phone,
      areaHint: areaHint ?? this.areaHint,
      lastInteraction: lastInteraction ?? this.lastInteraction,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'circle': circle.name,
        'closeness': closeness,
        'gender': gender.name,
        'kinship': kinship,
        'phone': phone,
        'areaHint': areaHint,
        'lastInteraction': lastInteraction?.toIso8601String(),
      };

  static Person fromJson(Map<String, dynamic> json) => Person(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        circle: SocialCircle.values.byName(json['circle'] as String),
        closeness: json['closeness'] as int,
        gender: Gender.values.byName(json['gender'] as String? ?? 'male'),
        kinship: json['kinship'] as String?,
        phone: json['phone'] as String?,
        areaHint: json['areaHint'] as String?,
        lastInteraction: json['lastInteraction'] == null
            ? null
            : DateTime.parse(json['lastInteraction'] as String),
      );
}

/// شرائح القرب المستخدمة في اختيار صياغة الرسالة ونطاق النقوط.
enum ClosenessTier { inner, close, wide, acquaintance;

  static ClosenessTier of(int closeness) {
    if (closeness >= 80) return ClosenessTier.inner;
    if (closeness >= 60) return ClosenessTier.close;
    if (closeness >= 35) return ClosenessTier.wide;
    return ClosenessTier.acquaintance;
  }
}

extension ClosenessTierLabel on ClosenessTier {
  String get label => switch (this) {
        ClosenessTier.inner => 'الدائرة الأقرب',
        ClosenessTier.close => 'دائرة قريبة',
        ClosenessTier.wide => 'دائرة واسعة',
        ClosenessTier.acquaintance => 'معرفة عامة',
      };
}
