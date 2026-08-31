import '../engines/action_layer.dart';
import '../models/ledger_entry.dart';
import '../models/occasion.dart';
import '../models/person.dart';

/// بيانات تجريبية للعرض والاختبار. أسماء عامة غير مرتبطة بأشخاص حقيقيين.
class SeedData {
  const SeedData._();

  static List<Person> people() => [
        Person(
          id: 'p1',
          displayName: 'عبدالله المطيري',
          circle: SocialCircle.family,
          closeness: 92,
          kinship: 'ابن العم',
          areaHint: 'الرميثية',
        ),
        Person(
          id: 'p2',
          displayName: 'أم فيصل',
          circle: SocialCircle.family,
          closeness: 88,
          gender: Gender.female,
          kinship: 'الخالة',
          areaHint: 'السالمية',
        ),
        Person(
          id: 'p3',
          displayName: 'فهد العنزي',
          circle: SocialCircle.diwaniya,
          closeness: 64,
          kinship: 'صديق الديوانية',
          areaHint: 'قرطبة',
        ),
        Person(
          id: 'p4',
          displayName: 'مشاري الرشيد',
          circle: SocialCircle.work,
          closeness: 48,
          kinship: 'زميل العمل',
          areaHint: 'الشرق',
        ),
        Person(
          id: 'p5',
          displayName: 'نورة الصالح',
          circle: SocialCircle.inLaws,
          closeness: 74,
          gender: Gender.female,
          kinship: 'أخت الزوجة',
          areaHint: 'بيان',
        ),
        Person(
          id: 'p6',
          displayName: 'يوسف الدوسري',
          circle: SocialCircle.neighbors,
          closeness: 40,
          kinship: 'الجار',
          areaHint: 'الجابرية',
        ),
      ];

  static List<Occasion> occasions(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      Occasion(
        id: 'o1',
        personId: 'p1',
        type: OccasionType.condolence,
        title: 'عزاء والد عبدالله المطيري',
        startsAt: today.subtract(const Duration(days: 1)),
        source: OccasionSource.capture,
        menVenue: Venue(
          title: 'ديوان المطيري',
          area: 'الرميثية',
          address: 'قطعة 5، شارع 12',
          prayerAnchor: PrayerAnchor.asr,
          latitude: 29.3117,
          longitude: 48.0736,
        ),
        womenVenue: Venue(
          title: 'منزل الفقيد',
          area: 'الرميثية',
          address: 'قطعة 3، منزل 21',
          prayerAnchor: PrayerAnchor.asr,
        ),
        contactPhone: '99887766',
      ),
      Occasion(
        id: 'o2',
        personId: 'p3',
        type: OccasionType.wedding,
        title: 'زواج فهد العنزي',
        startsAt: today.add(const Duration(days: 2, hours: 20)),
        source: OccasionSource.capture,
        menVenue: Venue(
          title: 'قاعة الفروسية',
          area: 'قرطبة',
          startTime: today.add(const Duration(days: 2, hours: 20)),
        ),
        womenVenue: Venue(
          title: 'قاعة الفروسية — الجناح الثاني',
          area: 'قرطبة',
          startTime: today.add(const Duration(days: 2, hours: 20, minutes: 30)),
        ),
      ),
      Occasion(
        id: 'o3',
        personId: 'p5',
        type: OccasionType.newborn,
        title: 'مولودة نورة الصالح',
        startsAt: today,
        source: OccasionSource.manual,
        womenVenue: Venue(title: 'منزل الأسرة', area: 'بيان'),
        menVenue: Venue(title: 'ديوان الصالح', area: 'بيان'),
      ),
      Occasion(
        id: 'o4',
        personId: 'p4',
        type: OccasionType.promotion,
        title: 'ترقية مشاري الرشيد',
        startsAt: today,
        source: OccasionSource.manual,
      ),
      Occasion(
        id: 'o5',
        personId: 'p6',
        type: OccasionType.diwaniya,
        title: 'ديوانية الاثنين',
        startsAt: today.add(const Duration(days: 1, hours: 21)),
        source: OccasionSource.manual,
        menVenue: Venue(title: 'ديوان الدوسري', area: 'الجابرية'),
      ),
    ];
  }

  static List<LedgerEntry> ledger(DateTime now) => [
        LedgerEntry(
          id: 'l1',
          personId: 'p1',
          direction: LedgerDirection.theyDidForMe,
          action: LedgerAction.attended,
          occasionType: OccasionType.condolence,
          date: now.subtract(const Duration(days: 220)),
          note: 'حضر عزاء الوالدة',
        ),
        LedgerEntry(
          id: 'l2',
          personId: 'p3',
          direction: LedgerDirection.theyDidForMe,
          action: LedgerAction.attended,
          occasionType: OccasionType.wedding,
          date: now.subtract(const Duration(days: 400)),
        ),
        LedgerEntry(
          id: 'l3',
          personId: 'p3',
          direction: LedgerDirection.iDidForThem,
          action: LedgerAction.message,
          occasionType: OccasionType.eid,
          date: now.subtract(const Duration(days: 90)),
        ),
        LedgerEntry(
          id: 'l4',
          personId: 'p4',
          direction: LedgerDirection.iDidForThem,
          action: LedgerAction.attended,
          occasionType: OccasionType.condolence,
          date: now.subtract(const Duration(days: 30)),
        ),
      ];

  static List<Vendor> vendors() => const [
        Vendor(
          id: 'v1',
          name: 'قهوجية الديوان',
          category: VendorCategory.coffeeServer,
          area: 'حولي',
        ),
        Vendor(
          id: 'v2',
          name: 'تمور الخليج',
          category: VendorCategory.dates,
          area: 'الشويخ',
        ),
        Vendor(
          id: 'v3',
          name: 'ضيافة الأصايل',
          category: VendorCategory.hospitality,
          area: 'الفروانية',
        ),
        Vendor(
          id: 'v4',
          name: 'خيام العزاء المتنقلة',
          category: VendorCategory.condolenceTent,
          area: 'الري',
        ),
        Vendor(
          id: 'v5',
          name: 'زهور السالمية',
          category: VendorCategory.flowers,
          area: 'السالمية',
        ),
        Vendor(
          id: 'v6',
          name: 'هدايا لمسة',
          category: VendorCategory.gift,
          area: 'الجابرية',
        ),
        Vendor(
          id: 'v7',
          name: 'مطابع الدعوات الملكية',
          category: VendorCategory.invitationPrint,
          area: 'الشويخ',
        ),
      ];
}
