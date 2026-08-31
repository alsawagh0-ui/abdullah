import 'hijri_date.dart';
import 'person.dart';

/// أنواع المناسبات التي تتعامل معها المنصة.
enum OccasionType {
  condolence, // عزاء
  wedding, // زواج
  newborn, // مولود
  illness, // مرض / عيادة مريض
  graduation, // تخرج
  promotion, // ترقية
  travel, // سفر أو عودة من سفر
  eid, // معايدة
  diwaniya, // ديوانية أو عزيمة
}

extension OccasionTypeLabel on OccasionType {
  String get label => switch (this) {
        OccasionType.condolence => 'عزاء',
        OccasionType.wedding => 'زواج',
        OccasionType.newborn => 'مولود',
        OccasionType.illness => 'مرض',
        OccasionType.graduation => 'تخرج',
        OccasionType.promotion => 'ترقية',
        OccasionType.travel => 'سفر',
        OccasionType.eid => 'معايدة',
        OccasionType.diwaniya => 'ديوانية',
      };

  /// وزن نوع المناسبة (0..100) داخل محرك درجة الوجوب.
  /// العزاء أثقل الواجبات في العرف الكويتي، والديوانية أخفّها إلزاماً.
  int get weight => switch (this) {
        OccasionType.condolence => 100,
        OccasionType.illness => 85,
        OccasionType.wedding => 75,
        OccasionType.newborn => 60,
        OccasionType.eid => 55,
        OccasionType.graduation => 45,
        OccasionType.promotion => 40,
        OccasionType.travel => 30,
        OccasionType.diwaniya => 25,
      };

  /// المناسبات التي تُعرض بواجهة الحزن: بلا ألوان صارخة ولا حركة ولا أي
  /// محتوى تجاري ترويجي.
  bool get isSolemn =>
      this == OccasionType.condolence || this == OccasionType.illness;

  /// عدد الأيام التي يظل فيها الواجب قائماً افتراضياً.
  /// أيام العزاء ثلاثة بحسب العرف.
  int get defaultDurationDays => switch (this) {
        OccasionType.condolence => 3,
        OccasionType.wedding => 1,
        OccasionType.newborn => 7,
        OccasionType.illness => 5,
        OccasionType.eid => 3,
        _ => 1,
      };
}

/// أوقات الصلاة المستخدمة كمرساة زمنية في إعلانات المناسبات
/// («العزاء بعد صلاة العصر»).
enum PrayerAnchor {
  fajr,
  dhuhr,
  asr,
  maghrib,
  isha;

  /// التقاط اسم الصلاة من نص عربي حر («بعد صلاة العصر»).
  static PrayerAnchor? tryParse(String arabicName) {
    for (final anchor in PrayerAnchor.values) {
      if (arabicName.contains(anchor.label)) return anchor;
    }
    if (arabicName.contains('العشا')) return PrayerAnchor.isha;
    return null;
  }
}

extension PrayerAnchorLabel on PrayerAnchor {
  String get label => switch (this) {
        PrayerAnchor.fajr => 'الفجر',
        PrayerAnchor.dhuhr => 'الظهر',
        PrayerAnchor.asr => 'العصر',
        PrayerAnchor.maghrib => 'المغرب',
        PrayerAnchor.isha => 'العشاء',
      };
}

/// مقر المناسبة. المقران — الرجال والنساء — حقلان منفصلان إلزاميان في
/// النموذج، لكل منهما موقعه وتوقيته المستقل.
class Venue {
  const Venue({
    required this.title,
    this.area,
    this.address,
    this.latitude,
    this.longitude,
    this.prayerAnchor,
    this.startTime,
    this.endTime,
  });

  final String title;
  final String? area;
  final String? address;
  final double? latitude;
  final double? longitude;
  final PrayerAnchor? prayerAnchor;
  final DateTime? startTime;
  final DateTime? endTime;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get timingLabel {
    if (prayerAnchor != null) return 'بعد صلاة ${prayerAnchor!.label}';
    if (startTime != null) {
      final h = startTime!.hour.toString().padLeft(2, '0');
      final m = startTime!.minute.toString().padLeft(2, '0');
      return 'الساعة $h:$m';
    }
    return 'التوقيت غير محدد';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'area': area,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'prayerAnchor': prayerAnchor?.name,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
      };

  static Venue fromJson(Map<String, dynamic> json) => Venue(
        title: json['title'] as String,
        area: json['area'] as String?,
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        prayerAnchor: json['prayerAnchor'] == null
            ? null
            : PrayerAnchor.values.byName(json['prayerAnchor'] as String),
        startTime: json['startTime'] == null
            ? null
            : DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] == null
            ? null
            : DateTime.parse(json['endTime'] as String),
      );
}

/// مصدر المناسبة: التقاط ذكي من صورة/رسالة، أو إدخال يدوي، أو إدخال صوتي.
enum OccasionSource { capture, manual, voice }

extension OccasionSourceLabel on OccasionSource {
  String get label => switch (this) {
        OccasionSource.capture => 'التقاط ذكي',
        OccasionSource.manual => 'إدخال يدوي',
        OccasionSource.voice => 'إدخال صوتي',
      };
}

class Occasion {
  Occasion({
    required this.id,
    required this.personId,
    required this.type,
    required this.title,
    required this.startsAt,
    this.menVenue,
    this.womenVenue,
    this.contactPhone,
    this.notes,
    this.source = OccasionSource.manual,
    this.durationDays,
    this.done = false,
    this.dismissed = false,
  });

  final String id;

  /// الشخص صاحب العلاقة في خريطة المستخدم (وليّ المناسبة أو المُصاب).
  final String personId;
  final OccasionType type;
  final String title;
  final DateTime startsAt;

  /// مقر الرجال ومقر النساء منفصلان دائماً؛ الواجهة تعرض المقر الصحيح
  /// تلقائياً بحسب جنس المستخدم دون سؤال محرج.
  final Venue? menVenue;
  final Venue? womenVenue;

  final String? contactPhone;
  final String? notes;
  final OccasionSource source;
  final int? durationDays;
  final bool done;
  final bool dismissed;

  int get effectiveDurationDays => durationDays ?? type.defaultDurationDays;

  DateTime get endsAt =>
      startsAt.add(Duration(days: effectiveDurationDays)).subtract(
            const Duration(seconds: 1),
          );

  HijriDate get hijriDate => HijriDate.fromGregorian(startsAt);

  bool isActiveAt(DateTime now) => !now.isAfter(endsAt);

  /// اليوم الحالي من أيام المناسبة (1 = اليوم الأول)، أو null إذا انتهت.
  int? dayIndexAt(DateTime now) {
    final startDay = DateTime(startsAt.year, startsAt.month, startsAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(startDay).inDays;
    if (diff < 0) return null;
    if (diff >= effectiveDurationDays) return null;
    return diff + 1;
  }

  Venue? venueFor(Gender gender) =>
      gender == Gender.male ? menVenue ?? womenVenue : womenVenue ?? menVenue;

  Occasion copyWith({
    OccasionType? type,
    String? title,
    DateTime? startsAt,
    Venue? menVenue,
    Venue? womenVenue,
    String? contactPhone,
    String? notes,
    int? durationDays,
    bool? done,
    bool? dismissed,
  }) {
    return Occasion(
      id: id,
      personId: personId,
      type: type ?? this.type,
      title: title ?? this.title,
      startsAt: startsAt ?? this.startsAt,
      menVenue: menVenue ?? this.menVenue,
      womenVenue: womenVenue ?? this.womenVenue,
      contactPhone: contactPhone ?? this.contactPhone,
      notes: notes ?? this.notes,
      source: source,
      durationDays: durationDays ?? this.durationDays,
      done: done ?? this.done,
      dismissed: dismissed ?? this.dismissed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'type': type.name,
        'title': title,
        'startsAt': startsAt.toIso8601String(),
        'menVenue': menVenue?.toJson(),
        'womenVenue': womenVenue?.toJson(),
        'contactPhone': contactPhone,
        'notes': notes,
        'source': source.name,
        'durationDays': durationDays,
        'done': done,
        'dismissed': dismissed,
      };

  static Occasion fromJson(Map<String, dynamic> json) => Occasion(
        id: json['id'] as String,
        personId: json['personId'] as String,
        type: OccasionType.values.byName(json['type'] as String),
        title: json['title'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        menVenue: json['menVenue'] == null
            ? null
            : Venue.fromJson((json['menVenue'] as Map).cast<String, dynamic>()),
        womenVenue: json['womenVenue'] == null
            ? null
            : Venue.fromJson(
                (json['womenVenue'] as Map).cast<String, dynamic>()),
        contactPhone: json['contactPhone'] as String?,
        notes: json['notes'] as String?,
        source: OccasionSource.values.byName(json['source'] as String),
        durationDays: json['durationDays'] as int?,
        done: json['done'] as bool? ?? false,
        dismissed: json['dismissed'] as bool? ?? false,
      );
}
