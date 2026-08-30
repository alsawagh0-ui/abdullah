import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/models/hijri_date.dart';

void main() {
  group('HijriDate', () {
    test('التحويل ذهاباً وإياباً متطابق على مدى سنة كاملة', () {
      var date = DateTime(2026, 1, 1);
      for (var i = 0; i < 365; i++) {
        final hijri = HijriDate.fromGregorian(date);
        final back = hijri.toGregorian();
        expect(
          back,
          date,
          reason: 'فشل التحويل العكسي عند $date (${hijri.toString()})',
        );
        date = date.add(const Duration(days: 1));
      }
    });

    test('التاريخ الهجري ضمن الحدود المنطقية', () {
      var date = DateTime(2024, 1, 1);
      for (var i = 0; i < 400; i++) {
        final hijri = HijriDate.fromGregorian(date);
        expect(hijri.month, inInclusiveRange(1, 12));
        expect(hijri.day, inInclusiveRange(1, 30));
        expect(hijri.year, inInclusiveRange(1440, 1460));
        date = date.add(const Duration(days: 1));
      }
    });

    test('رأس السنة الهجرية 1445 يقع قرب 2023-07-19 (±يوم واحد)', () {
      // الخوارزمية الجدولية قد تفارق الرؤية الشرعية بيوم — الاختبار
      // يوثّق هذا الهامش بدل أن يدّعي دقة مطلقة.
      final gregorian = const HijriDate(1445, 1, 1).toGregorian();
      final expected = DateTime(2023, 7, 19);
      expect(gregorian.difference(expected).inDays.abs(), lessThanOrEqualTo(1));
    });

    test('أيام متتالية ميلادياً تعطي أياماً متتالية هجرياً', () {
      var date = DateTime(2026, 3, 1);
      var previous = HijriDate.fromGregorian(date);
      for (var i = 0; i < 60; i++) {
        date = date.add(const Duration(days: 1));
        final current = HijriDate.fromGregorian(date);
        final gap = current.jdn - previous.jdn;
        expect(gap, 1, reason: 'قفزة غير متوقعة عند $date');
        previous = current;
      }
    });

    test('كشف رمضان والعيد', () {
      expect(const HijriDate(1447, 9, 15).isRamadan, isTrue);
      expect(const HijriDate(1447, 8, 15).isRamadan, isFalse);
      expect(const HijriDate(1447, 10, 1).isEid, isTrue);
      expect(const HijriDate(1447, 12, 10).isEid, isTrue);
      expect(const HijriDate(1447, 10, 9).isEid, isFalse);
    });

    test('صياغة العرض تحمل اسم الشهر بالعربية', () {
      expect(const HijriDate(1447, 9, 3).format(), contains('رمضان'));
    });
  });
}
