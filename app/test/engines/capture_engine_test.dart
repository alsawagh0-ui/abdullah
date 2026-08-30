import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/engines/capture_engine.dart';
import 'package:wajb/models/occasion.dart';

const CaptureEngine engine = CaptureEngine();

const String condolenceCard = '''
إنا لله وإنا إليه راجعون
انتقل إلى رحمة الله تعالى: سالم عبدالله المطيري
الصلاة عليه بعد صلاة العصر في مسجد بلال بن رباح
العزاء للرجال في ديوان المطيري - الرميثية قطعة 5 بعد صلاة العصر
مقر النساء: منزل الفقيد - الرميثية قطعة 3
لمدة ثلاثة أيام
الموافق 3/9/2026
للتواصل: 99887766
''';

const String weddingCard = '''
دعوة زفاف
يتشرف آل العنزي بدعوتكم لحضور حفل زفاف ولدهم فهد ناصر العنزي
مقر الرجال: قاعة الفروسية - قرطبة
مقر النساء: قاعة الفروسية الجناح الثاني - قرطبة
التاريخ: 12/9/2026
''';

const String newbornCard = '''
بشارة خير
رزق أخونا مشاري الرشيد بمولودة
مقر الرجال: ديوان الرشيد - الشرق
مقر النساء: منزل الأسرة - الشرق
''';

void main() {
  group('CaptureEngine — بطاقة نعي', () {
    final result = engine.parse(condolenceCard);

    test('يتعرف على العزاء كنوع للمناسبة', () {
      expect(result.type?.value, OccasionType.condolence);
    });

    test('يستخلص اسم الفقيد بلا ألقاب', () {
      expect(result.subjectName?.value, contains('سالم'));
      expect(result.subjectName?.value, contains('المطيري'));
      expect(result.subjectName?.value, isNot(contains('المرحوم')));
    });

    test('يفصل مقر الرجال عن مقر النساء', () {
      expect(result.menVenue, isNotNull);
      expect(result.womenVenue, isNotNull);
      expect(result.menVenue!.value.title, contains('ديوان'));
      expect(result.womenVenue!.value.title, contains('منزل'));
    });

    test('يلتقط المنطقة الكويتية في كلا المقرين', () {
      expect(result.menVenue?.value.area, 'الرميثية');
      expect(result.womenVenue?.value.area, 'الرميثية');
    });

    test('يترجم «بعد صلاة العصر» إلى مرساة زمنية', () {
      expect(result.menVenue?.value.prayerAnchor, PrayerAnchor.asr);
    });

    test('يستخلص رقم التواصل الكويتي', () {
      expect(result.contactPhone?.value, '99887766');
    });

    test('يستخلص مدة العزاء المصرّح بها', () {
      expect(result.durationDays?.value, 3);
    });

    test('نسبة الاكتمال عالية لبطاقة كاملة', () {
      expect(result.confidence, greaterThan(0.8));
    });
  });

  group('CaptureEngine — دعوة زواج', () {
    final result = engine.parse(weddingCard);

    test('يتعرف على الزواج', () {
      expect(result.type?.value, OccasionType.wedding);
    });

    test('يستخلص التاريخ الميلادي', () {
      expect(result.gregorianDate?.value, DateTime(2026, 9, 12));
    });

    test('يفصل المقرين', () {
      expect(result.menVenue?.value.area, 'قرطبة');
      expect(result.womenVenue?.value.area, 'قرطبة');
    });
  });

  group('CaptureEngine — بشارة مولود', () {
    final result = engine.parse(newbornCard);

    test('يتعرف على المولود', () {
      expect(result.type?.value, OccasionType.newborn);
    });

    test('يطالب بمراجعة بشرية عند نقص التاريخ', () {
      expect(result.missingFields, contains('التاريخ'));
      expect(result.needsReview, isTrue);
    });
  });

  group('CaptureEngine — الحالات الصعبة', () {
    test('يحوّل الأرقام العربية الهندية', () {
      final result = engine.parse('عزاء المرحوم فهد الفهد\nهاتف ٩٩٥٥٤٤٣٣');
      expect(result.contactPhone?.value, '99554433');
    });

    test('يتجاهل التشكيل والتطويل', () {
      final result = engine.parse('انتقلَ إلى رحمةِ اللهِ تعالى: خالــد الخالد');
      expect(result.type?.value, OccasionType.condolence);
      expect(result.subjectName?.value, contains('خالد'));
    });

    test('يقرأ التاريخ الهجري المكتوب بالحروف', () {
      final result = engine.parse('العزاء يوم 15 رمضان 1447 هـ');
      expect(result.hijriDate?.value.month, 9);
      expect(result.hijriDate?.value.day, 15);
      expect(result.hijriDate?.value.year, 1447);
    });

    test('يقرأ التاريخ الهجري الرقمي', () {
      final result = engine.parse('بتاريخ 1447/3/15 هـ');
      expect(result.hijriDate?.value.month, 3);
      expect(result.hijriDate?.value.day, 15);
    });

    test('يحذّر عند غياب أحد المقرين', () {
      final result = engine.parse(
        'انتقل إلى رحمة الله تعالى: علي العلي\n'
        'العزاء للرجال في ديوان العلي - كيفان',
      );
      expect(result.womenVenue, isNull);
      expect(result.missingFields, contains('مقر النساء'));
      expect(
        result.warnings.any((w) => w.contains('إلزامي')),
        isTrue,
      );
    });

    test('النص الفارغ لا يسبب انهياراً ويعيد نتيجة تحتاج مراجعة', () {
      final result = engine.parse('   ');
      expect(result.type, isNull);
      expect(result.needsReview, isTrue);
      expect(result.confidence, 0);
      expect(result.missingFields.length, greaterThanOrEqualTo(4));
    });

    test('نص غير متصل بالمناسبات لا يُفسَّر قسراً', () {
      final result = engine.parse('اجتماع العمل الساعة 10 صباحاً');
      expect(result.type, isNull);
    });

    test('يرجّح العزاء حين تتداخل الكلمات المفتاحية', () {
      final result = engine.parse(
        'انتقل إلى رحمة الله تعالى: بدر البدر\n'
        'وقد كان قد استقبل مولوداً قبل شهر',
      );
      expect(result.type?.value, OccasionType.condolence);
    });

    test('«اليوم» و«بكرة» تُترجَمان إلى تاريخ فعلي', () {
      final reference = DateTime(2026, 5, 10);
      final today = engine.parse('العزاء اليوم', referenceDate: reference);
      final tomorrow = engine.parse('العزاء بكرة', referenceDate: reference);
      expect(today.gregorianDate?.value, DateTime(2026, 5, 10));
      expect(tomorrow.gregorianDate?.value, DateTime(2026, 5, 11));
    });

    test('العزاء بلا مدة مصرّحة يفترض ثلاثة أيام حسب العرف', () {
      final result = engine.parse('انتقل إلى رحمة الله تعالى: سعد السعد');
      expect(result.durationDays?.value, 3);
    });
  });
}
