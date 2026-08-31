import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/engines/prayer_times.dart';
import 'package:wajb/models/occasion.dart';
import 'package:wajb/models/person.dart';
import 'package:wajb/services/external_actions.dart';

Person person({Gender gender = Gender.male}) => Person(
      id: 'p1',
      displayName: 'عبدالله المطيري',
      circle: SocialCircle.family,
      closeness: 90,
      kinship: 'ابن العم',
      gender: gender,
    );

Occasion occasion({
  Venue? menVenue,
  Venue? womenVenue,
  OccasionType type = OccasionType.condolence,
  String? phone,
}) =>
    Occasion(
      id: 'o1',
      personId: 'p1',
      type: type,
      title: 'مناسبة',
      startsAt: DateTime(2026, 5, 10, 9),
      menVenue: menVenue,
      womenVenue: womenVenue,
      contactPhone: phone,
    );

void main() {
  group('روابط الخرائط', () {
    const withCoordinates = Venue(
      title: 'ديوان المطيري',
      area: 'الرميثية',
      latitude: 29.3117,
      longitude: 48.0736,
    );
    const withoutCoordinates = Venue(
      title: 'ديوان المطيري',
      area: 'الرميثية',
      address: 'قطعة 5، شارع 12',
    );

    test('الإحداثيات تُستخدم مباشرة على أندرويد', () {
      final uri = ExternalLinks.mapsFor(withCoordinates, isIOS: false)!;
      expect(uri.host, contains('google'));
      expect(uri.toString(), contains('29.3117,48.0736'));
    });

    test('الإحداثيات تفتح خرائط آبل على iOS', () {
      final uri = ExternalLinks.mapsFor(withCoordinates, isIOS: true)!;
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['ll'], '29.3117,48.0736');
    });

    test('بلا إحداثيات يُبنى بحث نصي يشمل المنطقة والكويت', () {
      final uri = ExternalLinks.mapsFor(withoutCoordinates, isIOS: false)!;
      final decoded = Uri.decodeFull(uri.toString());
      expect(decoded, contains('ديوان المطيري'));
      expect(decoded, contains('الرميثية'));
      expect(decoded, contains('الكويت'));
    });

    test('العنوان العربي مُرمَّز بشكل صالح في الرابط', () {
      final uri = ExternalLinks.mapsFor(withoutCoordinates, isIOS: true)!;
      expect(() => Uri.parse(uri.toString()), returnsNormally);
      expect(uri.toString(), isNot(contains(' ')));
    });

    test('لا رابط بلا مقر', () {
      expect(ExternalLinks.mapsFor(null, isIOS: false), isNull);
    });
  });

  group('روابط الاتصال', () {
    test('الرقم الكويتي المحلي يُسبق برمز الدولة', () {
      expect(ExternalLinks.telFor('99887766').toString(), 'tel:+96599887766');
    });

    test('الرقم المكتوب بمسافات أو شرطات يُنظَّف', () {
      expect(ExternalLinks.telFor('9988 7766').toString(), 'tel:+96599887766');
      expect(ExternalLinks.telFor('9988-7766').toString(), 'tel:+96599887766');
    });

    test('الرقم الدولي يُترك كما هو', () {
      expect(
        ExternalLinks.telFor('+966501234567').toString(),
        'tel:+966501234567',
      );
    });

    test('لا رابط بلا رقم', () {
      expect(ExternalLinks.telFor(null), isNull);
      expect(ExternalLinks.telFor('بدون أرقام'), isNull);
    });
  });

  group('حدث التقويم', () {
    const builder = CalendarEventBuilder();

    test('يستخدم التوقيت المصرّح به إن وُجد', () {
      final start = DateTime(2026, 5, 10, 20);
      final draft = builder.build(
        occasion: occasion(
          type: OccasionType.wedding,
          menVenue: Venue(title: 'قاعة الفروسية', startTime: start),
        ),
        person: person(),
        viewerGender: Gender.male,
      );
      expect(draft.start, start);
      expect(draft.allDay, isFalse);
      expect(draft.duration, const Duration(hours: 3));
    });

    test('«بعد صلاة العصر» تتحول إلى وقت فعلي', () {
      final times = PrayerTimes.forDate(DateTime(2026, 5, 10));
      final draft = builder.build(
        occasion: occasion(
          menVenue: const Venue(
            title: 'ديوان المطيري',
            prayerAnchor: PrayerAnchor.asr,
          ),
        ),
        person: person(),
        viewerGender: Gender.male,
        prayerTimes: times,
      );
      expect(draft.allDay, isFalse);
      expect(draft.start.hour, times.resolveAnchor(PrayerAnchor.asr).hour);
      expect(draft.duration, const Duration(hours: 2));
    });

    test('بلا أي توقيت يصير الحدث ليوم كامل', () {
      final draft = builder.build(
        occasion: occasion(menVenue: const Venue(title: 'ديوان')),
        person: person(),
        viewerGender: Gender.male,
      );
      expect(draft.allDay, isTrue);
      expect(draft.duration, const Duration(days: 1));
    });

    test('يبني الحدث من مقر المستخدم هو لا من المقر الآخر', () {
      final target = occasion(
        menVenue: const Venue(title: 'ديوان الرجال', area: 'الرميثية'),
        womenVenue: const Venue(title: 'منزل النساء', area: 'بيان'),
      );
      final men = builder.build(
        occasion: target,
        person: person(),
        viewerGender: Gender.male,
      );
      final women = builder.build(
        occasion: target,
        person: person(),
        viewerGender: Gender.female,
      );
      expect(men.location, contains('ديوان الرجال'));
      expect(men.description, contains('مقر الرجال'));
      expect(women.location, contains('منزل النساء'));
      expect(women.description, contains('مقر النساء'));
    });

    test('العنوان والوصف يحملان نوع المناسبة والاسم وصلة القرابة', () {
      final draft = builder.build(
        occasion: occasion(
          menVenue: const Venue(title: 'ديوان'),
          phone: '99887766',
        ),
        person: person(),
        viewerGender: Gender.male,
      );
      expect(draft.title, contains('عزاء'));
      expect(draft.title, contains('عبدالله المطيري'));
      expect(draft.description, contains('ابن العم'));
      expect(draft.description, contains('99887766'));
    });
  });

  group('البوابة الصورية', () {
    test('تسجّل الطلبات بدل تنفيذها', () async {
      final actions = RecordingExternalActions();
      await actions.openMap(const Venue(title: 'ديوان'));
      await actions.call('99887766');
      expect(actions.mapRequests.single.title, 'ديوان');
      expect(actions.callRequests.single, '99887766');
      expect(actions.calendarRequests, isEmpty);
    });
  });
}
