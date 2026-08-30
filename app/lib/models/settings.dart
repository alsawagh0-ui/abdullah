import 'person.dart';

enum SocialRole { headOfFamily, employee, student }

extension SocialRoleLabel on SocialRole {
  String get label => switch (this) {
        SocialRole.headOfFamily => 'رب أسرة',
        SocialRole.employee => 'موظف',
        SocialRole.student => 'طالب',
      };
}

/// إعدادات الخصوصية.
///
/// مبدأ الستر: القيم الافتراضية هي الأشد تحفّظاً دائماً، والانفتاح خيار
/// واعٍ لا وضع تلقائي. لا توجد في المنصة خاصية نشر عام ولا إعجابات ولا
/// متابعون ولا قوائم أوائل، ولذلك لا يوجد أصلاً أي مفتاح هنا يسمح بذلك.
class PrivacySettings {
  const PrivacySettings({
    this.shareLedger = false,
    this.allowFamilyCoordination = false,
    this.allowContactImport = false,
    this.allowAnonymousDiagnostics = false,
    this.autoSendMessages = false,
  })  : assert(autoSendMessages == false,
            'الإرسال الآلي ممنوع تصميمياً ولا يمكن تفعيله');

  /// مشاركة ملخص الدفتر مع أفراد العائلة المرتبطين (معطّلة افتراضياً).
  final bool shareLedger;

  /// السماح بتنسيق الواجبات مع أفراد الأسرة (معطّل افتراضياً).
  final bool allowFamilyCoordination;

  /// استيراد جهات الاتصال (اختياري تماماً ومعطّل افتراضياً).
  final bool allowContactImport;

  /// إحصاءات مجهولة الهوية لتحسين المنتج (معطّلة افتراضياً).
  final bool allowAnonymousDiagnostics;

  /// خط أحمر: لا إرسال آلي لأي رسالة تعزية أو تهنئة. هذا الحقل ثابت على
  /// false ويُستخدم للتوثيق ولاختبارات الامتثال فقط.
  final bool autoSendMessages;

  PrivacySettings copyWith({
    bool? shareLedger,
    bool? allowFamilyCoordination,
    bool? allowContactImport,
    bool? allowAnonymousDiagnostics,
  }) {
    return PrivacySettings(
      shareLedger: shareLedger ?? this.shareLedger,
      allowFamilyCoordination:
          allowFamilyCoordination ?? this.allowFamilyCoordination,
      allowContactImport: allowContactImport ?? this.allowContactImport,
      allowAnonymousDiagnostics:
          allowAnonymousDiagnostics ?? this.allowAnonymousDiagnostics,
    );
  }

  Map<String, dynamic> toJson() => {
        'shareLedger': shareLedger,
        'allowFamilyCoordination': allowFamilyCoordination,
        'allowContactImport': allowContactImport,
        'allowAnonymousDiagnostics': allowAnonymousDiagnostics,
      };

  static PrivacySettings fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        shareLedger: json['shareLedger'] as bool? ?? false,
        allowFamilyCoordination:
            json['allowFamilyCoordination'] as bool? ?? false,
        allowContactImport: json['allowContactImport'] as bool? ?? false,
        allowAnonymousDiagnostics:
            json['allowAnonymousDiagnostics'] as bool? ?? false,
      );
}

/// ملف المستخدم وتفضيلاته.
class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.gender,
    this.role = SocialRole.employee,
    this.phone,
    this.area = 'الكويت',
    this.elderMode = false,
    this.respectPrayerTimes = true,
    this.privacy = const PrivacySettings(),
    this.onboarded = false,
  });

  final String displayName;

  /// جنس المستخدم — يُستخدم حصراً لعرض المقر الصحيح (رجال/نساء) تلقائياً
  /// دون سؤال محرج عند كل مناسبة.
  final Gender gender;
  final SocialRole role;
  final String? phone;
  final String area;

  /// نمط كبار السن: خطوط أكبر وتباين أعلى وشاشة أبسط.
  final bool elderMode;

  /// كتم التنبيهات أثناء أوقات الصلاة.
  final bool respectPrayerTimes;
  final PrivacySettings privacy;
  final bool onboarded;

  UserProfile copyWith({
    String? displayName,
    Gender? gender,
    SocialRole? role,
    String? phone,
    String? area,
    bool? elderMode,
    bool? respectPrayerTimes,
    PrivacySettings? privacy,
    bool? onboarded,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      area: area ?? this.area,
      elderMode: elderMode ?? this.elderMode,
      respectPrayerTimes: respectPrayerTimes ?? this.respectPrayerTimes,
      privacy: privacy ?? this.privacy,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'gender': gender.name,
        'role': role.name,
        'phone': phone,
        'area': area,
        'elderMode': elderMode,
        'respectPrayerTimes': respectPrayerTimes,
        'privacy': privacy.toJson(),
        'onboarded': onboarded,
      };

  static UserProfile fromJson(Map<String, dynamic> json) => UserProfile(
        displayName: json['displayName'] as String,
        gender: Gender.values.byName(json['gender'] as String),
        role: SocialRole.values.byName(json['role'] as String? ?? 'employee'),
        phone: json['phone'] as String?,
        area: json['area'] as String? ?? 'الكويت',
        elderMode: json['elderMode'] as bool? ?? false,
        respectPrayerTimes: json['respectPrayerTimes'] as bool? ?? true,
        privacy: PrivacySettings.fromJson(
            (json['privacy'] as Map?)?.cast<String, dynamic>() ?? const {}),
        onboarded: json['onboarded'] as bool? ?? false,
      );
}
