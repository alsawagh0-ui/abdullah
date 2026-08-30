import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/engines/prayer_times.dart';
import 'package:wajb/models/occasion.dart';

void main() {
  group('PrayerTimes — الكويت', () {
    final times = PrayerTimes.forDate(DateTime(2026, 6, 21));

    test('ترتيب المواقيت تصاعدي خلال اليوم', () {
      final ordered = [
        times[PrayerAnchor.fajr],
        times.sunrise,
        times[PrayerAnchor.dhuhr],
        times[PrayerAnchor.asr],
        times[PrayerAnchor.maghrib],
        times[PrayerAnchor.isha],
      ];
      for (var i = 1; i < ordered.length; i++) {
        expect(
          ordered[i].isAfter(ordered[i - 1]),
          isTrue,
          reason: 'الترتيب مكسور عند الموضع $i',
        );
      }
    });

    test('الظهر في الكويت قرب منتصف النهار', () {
      final dhuhr = times[PrayerAnchor.dhuhr];
      expect(dhuhr.hour, inInclusiveRange(11, 12));
    });

    test('المغرب صيفاً بعد السادسة مساءً', () {
      expect(times[PrayerAnchor.maghrib].hour, inInclusiveRange(18, 19));
    });

    test('العشاء بعد المغرب بتسعين دقيقة (طريقة أم القرى)', () {
      final gap = times[PrayerAnchor.isha]
          .difference(times[PrayerAnchor.maghrib])
          .inMinutes;
      expect(gap, 90);
    });

    test('المواقيت تتغير عبر فصول السنة', () {
      final winter = PrayerTimes.forDate(DateTime(2026, 12, 21));
      final summer = PrayerTimes.forDate(DateTime(2026, 6, 21));
      expect(
        summer[PrayerAnchor.maghrib].hour,
        greaterThan(winter[PrayerAnchor.maghrib].hour),
      );
    });

    test('كل يوم من السنة يُحسب بلا استثناءات', () {
      var date = DateTime(2026, 1, 1);
      for (var i = 0; i < 365; i++) {
        final t = PrayerTimes.forDate(date);
        expect(t.all.length, 5);
        date = date.add(const Duration(days: 1));
      }
    });
  });

  group('كتم التنبيهات أثناء الصلاة', () {
    final times = PrayerTimes.forDate(DateTime(2026, 6, 21));

    test('اللحظة داخل نافذة الصلاة تُعدّ وقت كتم', () {
      final asr = times[PrayerAnchor.asr];
      expect(times.isQuietAt(asr.add(const Duration(minutes: 5))), isTrue);
      expect(times.isQuietAt(asr.subtract(const Duration(minutes: 5))),
          isFalse);
    });

    test('التنبيه يُؤجَّل إلى ما بعد نافذة الصلاة', () {
      final asr = times[PrayerAnchor.asr];
      final moment = asr.add(const Duration(minutes: 3));
      final next = times.nextAllowedNotification(moment);
      expect(next.isAfter(moment), isTrue);
      expect(times.isQuietAt(next), isFalse);
    });

    test('التنبيه خارج أوقات الصلاة يُرسل فوراً', () {
      final quiet = times[PrayerAnchor.dhuhr]
          .subtract(const Duration(hours: 2));
      expect(times.nextAllowedNotification(quiet), quiet);
    });
  });

  group('ترجمة «بعد صلاة X» إلى وقت فعلي', () {
    final times = PrayerTimes.forDate(DateTime(2026, 6, 21));

    test('المرساة تعطي وقتاً بعد الصلاة بفاصل عرفي', () {
      final resolved = times.resolveAnchor(PrayerAnchor.asr);
      expect(resolved.isAfter(times[PrayerAnchor.asr]), isTrue);
      expect(
        resolved.difference(times[PrayerAnchor.asr]).inMinutes,
        30,
      );
    });

    test('قراءة اسم الصلاة من نص حر', () {
      expect(PrayerAnchor.tryParse('بعد صلاة العصر'), PrayerAnchor.asr);
      expect(PrayerAnchor.tryParse('بعد صلاة المغرب'), PrayerAnchor.maghrib);
      expect(PrayerAnchor.tryParse('بعد صلاة العشا'), PrayerAnchor.isha);
      expect(PrayerAnchor.tryParse('الساعة ثمان'), isNull);
    });
  });
}
