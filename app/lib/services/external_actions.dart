import '../engines/prayer_times.dart';
import '../models/occasion.dart';
import '../models/person.dart';

/// مسودة حدث تقويم مبنية من مناسبة.
///
/// كل الحساب هنا خالص وقابل للاختبار؛ الإضافة الفعلية للتقويم تتم في
/// [ExternalActions] عبر واجهة النظام.
class CalendarEventDraft {
  const CalendarEventDraft({
    required this.title,
    required this.description,
    required this.location,
    required this.start,
    required this.end,
    required this.allDay,
  });

  final String title;
  final String description;
  final String location;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  Duration get duration => end.difference(start);
}

/// يبني حدث التقويم من المناسبة والمقر الذي يخص المستخدم.
class CalendarEventBuilder {
  const CalendarEventBuilder();

  /// مدة الحضور المعتادة بحسب نوع المناسبة.
  static Duration attendanceWindow(OccasionType type) => switch (type) {
        OccasionType.condolence => const Duration(hours: 2),
        OccasionType.wedding => const Duration(hours: 3),
        OccasionType.diwaniya => const Duration(hours: 2),
        OccasionType.newborn => const Duration(hours: 1, minutes: 30),
        _ => const Duration(hours: 1),
      };

  CalendarEventDraft build({
    required Occasion occasion,
    required Person person,
    required Gender viewerGender,
    PrayerTimes? prayerTimes,
  }) {
    final venue = occasion.venueFor(viewerGender);
    final start = resolveStart(
      occasion: occasion,
      viewerGender: viewerGender,
      prayerTimes: prayerTimes,
    );
    final allDay = start == null;
    final effectiveStart = start ??
        DateTime(occasion.startsAt.year, occasion.startsAt.month,
            occasion.startsAt.day);

    final venueLabel =
        viewerGender == Gender.male ? 'مقر الرجال' : 'مقر النساء';
    final location = venue == null
        ? ''
        : [venue.title, if (venue.area != null) venue.area!]
            .join(' — ');

    return CalendarEventDraft(
      title: '${occasion.type.label}: ${person.displayName}',
      description: [
        if (person.kinship != null) person.kinship!,
        '$venueLabel: ${venue?.title ?? 'غير محدد'}',
        if (venue?.timingLabel != null) venue!.timingLabel,
        if (occasion.contactPhone != null)
          'التواصل: ${occasion.contactPhone}',
      ].join('\n'),
      location: location,
      start: effectiveStart,
      end: allDay
          ? effectiveStart.add(const Duration(days: 1))
          : effectiveStart.add(attendanceWindow(occasion.type)),
      allDay: allDay,
    );
  }

  /// وقت البداية الفعلي: التوقيت المصرّح به، أو ترجمة «بعد صلاة كذا» إلى
  /// وقت حقيقي، أو null إذا لم يُذكر توقيت إطلاقاً.
  DateTime? resolveStart({
    required Occasion occasion,
    required Gender viewerGender,
    PrayerTimes? prayerTimes,
  }) {
    final venue = occasion.venueFor(viewerGender);
    if (venue == null) return null;
    if (venue.startTime != null) return venue.startTime;

    final anchor = venue.prayerAnchor;
    if (anchor == null) return null;

    final times = prayerTimes ?? PrayerTimes.forDate(occasion.startsAt);
    final anchorTime = times.resolveAnchor(anchor);
    return DateTime(
      occasion.startsAt.year,
      occasion.startsAt.month,
      occasion.startsAt.day,
      anchorTime.hour,
      anchorTime.minute,
    );
  }
}

/// يبني روابط الخرائط والاتصال. منطق خالص قابل للاختبار.
class ExternalLinks {
  const ExternalLinks._();

  static const String kuwaitDialCode = '965';

  /// رابط الملاحة إلى المقر — خرائط آبل على iOS وخرائط جوجل عداها.
  static Uri? mapsFor(Venue? venue, {required bool isIOS}) {
    if (venue == null) return null;

    if (venue.hasCoordinates) {
      final coordinates = '${venue.latitude},${venue.longitude}';
      return isIOS
          ? Uri.parse('https://maps.apple.com/?ll=$coordinates'
              '&q=${Uri.encodeComponent(venue.title)}')
          : Uri.parse('https://www.google.com/maps/search/?api=1'
              '&query=$coordinates');
    }

    final query = [
      venue.title,
      if (venue.area != null) venue.area!,
      if (venue.address != null) venue.address!,
      'الكويت',
    ].join('، ');

    return isIOS
        ? Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(query)}')
        : Uri.parse('https://www.google.com/maps/search/?api=1'
            '&query=${Uri.encodeComponent(query)}');
  }

  /// رابط الاتصال. الأرقام الكويتية المحلية (8 خانات) تُسبق برمز الدولة.
  static Uri? telFor(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('+')) return Uri.parse('tel:$digits');
    if (digits.length == 8) return Uri.parse('tel:+$kuwaitDialCode$digits');
    return Uri.parse('tel:$digits');
  }
}

/// بوابة الإجراءات التي تخرج من التطبيق إلى تطبيقات النظام.
///
/// واجهة مجرّدة كي تبقى الشاشات قابلة للاختبار بلا جهاز حقيقي.
abstract class ExternalActions {
  bool get isIOS;
  Future<bool> openMap(Venue venue);
  Future<bool> call(String phone);
  Future<bool> addToCalendar(CalendarEventDraft draft);
}

/// تنفيذ صوري يسجّل ما طُلب منه — يُستخدم في الاختبارات وعلى المنصات
/// التي لا تدعم هذه الإجراءات.
class RecordingExternalActions implements ExternalActions {
  RecordingExternalActions({this.isIOS = false, this.succeed = true});

  @override
  final bool isIOS;
  final bool succeed;

  final List<Venue> mapRequests = <Venue>[];
  final List<String> callRequests = <String>[];
  final List<CalendarEventDraft> calendarRequests = <CalendarEventDraft>[];

  @override
  Future<bool> openMap(Venue venue) async {
    mapRequests.add(venue);
    return succeed;
  }

  @override
  Future<bool> call(String phone) async {
    callRequests.add(phone);
    return succeed;
  }

  @override
  Future<bool> addToCalendar(CalendarEventDraft draft) async {
    calendarRequests.add(draft);
    return succeed;
  }
}
