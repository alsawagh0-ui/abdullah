import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/engines/obligation_engine.dart';
import 'package:wajb/engines/prayer_times.dart';
import 'package:wajb/models/obligation.dart';
import 'package:wajb/models/occasion.dart';
import 'package:wajb/models/person.dart';
import 'package:wajb/services/notification_planner.dart';

final DateTime now = DateTime(2026, 5, 10, 7);
const ObligationEngine engine = ObligationEngine();

Person person({int closeness = 95, String id = 'p1'}) => Person(
      id: id,
      displayName: 'شخص $id',
      circle: SocialCircle.family,
      closeness: closeness,
    );

Obligation obligation({
  OccasionType type = OccasionType.condolence,
  int closeness = 95,
  DateTime? startsAt,
  String id = 'o1',
  int? durationDays,
  bool done = false,
  bool dismissed = false,
}) {
  final occasion = Occasion(
    id: id,
    personId: 'p1',
    type: type,
    title: 'مناسبة',
    startsAt: startsAt ?? now.add(const Duration(hours: 10)),
    durationDays: durationDays,
    done: done,
    dismissed: dismissed,
    menVenue: const Venue(title: 'ديوان', area: 'الرميثية'),
  );
  return engine.evaluate(
    occasion: occasion,
    person: person(closeness: closeness),
    now: now,
  );
}

void main() {
  const planner = NotificationPlanner();

  group('ماذا يستحق تنبيهاً', () {
    test('الواجب المؤكد يأخذ تذكيراً صباحياً وآخر قبل الموعد', () {
      final plans = planner.plan(
        obligations: [obligation()],
        now: now,
        viewerGender: Gender.male,
      );
      final kinds = plans.map((p) => p.kind).toSet();
      expect(kinds, contains(ReminderKind.morning));
      expect(kinds, contains(ReminderKind.beforeStart));
    });

    test('الواجب المستحسن يأخذ التذكير الصباحي فقط', () {
      final target = obligation(type: OccasionType.diwaniya, closeness: 70);
      expect(target.tier, ObligationTier.recommended);
      final plans = planner.plan(
        obligations: [target],
        now: now,
        viewerGender: Gender.male,
      );
      expect(plans.map((p) => p.kind).toSet(), {ReminderKind.morning});
    });

    test('الاختياري لا يُنبَّه عليه إطلاقاً — لا ملاحقة للمستخدم', () {
      final target = obligation(type: OccasionType.travel, closeness: 15);
      expect(target.tier, ObligationTier.optional);
      expect(
        planner.plan(
          obligations: [target],
          now: now,
          viewerGender: Gender.male,
        ),
        isEmpty,
      );
    });

    test('الواجب المؤدَّى أو المستبعَد لا يُنبَّه عليه', () {
      expect(
        planner.plan(
          obligations: [obligation(done: true)],
          now: now,
          viewerGender: Gender.male,
        ),
        isEmpty,
      );
      expect(
        planner.plan(
          obligations: [obligation(dismissed: true)],
          now: now,
          viewerGender: Gender.male,
        ),
        isEmpty,
      );
    });

    test('العزاء متعدد الأيام يأخذ تنبيه «آخر يوم»', () {
      final plans = planner.plan(
        obligations: [obligation(durationDays: 3)],
        now: now,
        viewerGender: Gender.male,
      );
      expect(
        plans.any((p) => p.kind == ReminderKind.lastDay),
        isTrue,
      );
      final lastDay =
          plans.firstWhere((p) => p.kind == ReminderKind.lastDay);
      expect(lastDay.title, contains('آخر يوم'));
    });
  });

  group('حدود الزمن', () {
    test('الأوقات الماضية تُسقَط', () {
      final plans = planner.plan(
        obligations: [
          obligation(startsAt: now.subtract(const Duration(hours: 5))),
        ],
        now: now,
        viewerGender: Gender.male,
      );
      for (final plan in plans) {
        expect(plan.at.isAfter(now), isTrue);
      }
    });

    test('ما بعد الأفق الزمني لا يُجدول', () {
      final plans = planner.plan(
        obligations: [obligation(startsAt: now.add(const Duration(days: 30)))],
        now: now,
        viewerGender: Gender.male,
      );
      expect(plans, isEmpty);
    });

    test('كل التنبيهات مرتّبة زمنياً تصاعدياً', () {
      final plans = planner.plan(
        obligations: [
          obligation(id: 'a', startsAt: now.add(const Duration(days: 3))),
          obligation(id: 'b', startsAt: now.add(const Duration(days: 1))),
          obligation(id: 'c', startsAt: now.add(const Duration(days: 2))),
        ],
        now: now,
        viewerGender: Gender.male,
      );
      for (var i = 1; i < plans.length; i++) {
        expect(plans[i].at.isBefore(plans[i - 1].at), isFalse);
      }
    });
  });

  group('احترام مواقيت الصلاة', () {
    test('التنبيه لا يقع داخل نافذة صلاة', () {
      final plans = planner.plan(
        obligations: [
          for (var i = 0; i < 6; i++)
            obligation(
              id: 'o$i',
              startsAt: now.add(Duration(hours: 6 + i * 5)),
            ),
        ],
        now: now,
        viewerGender: Gender.male,
      );
      expect(plans, isNotEmpty);
      for (final plan in plans) {
        final times = PrayerTimes.forDate(plan.at);
        expect(
          times.isQuietAt(plan.at),
          isFalse,
          reason: 'تنبيه وقع أثناء الصلاة: ${plan.at}',
        );
      }
    });

    test('تعطيل الاحترام يترك الوقت كما هو', () {
      const noon = NotificationPlanner(morningHour: 12, morningMinute: 0);
      final plans = noon.plan(
        obligations: [obligation()],
        now: now,
        viewerGender: Gender.male,
        respectPrayerTimes: false,
      );
      final morning =
          plans.firstWhere((p) => p.kind == ReminderKind.morning);
      expect(morning.at.hour, 12);
      expect(morning.at.minute, 0);
    });
  });

  group('السقف اليومي', () {
    test('لا يتجاوز الحد الأقصى في اليوم الواحد', () {
      const capped = NotificationPlanner(maxPerDay: 2);
      final sameDay = [
        for (var i = 0; i < 6; i++)
          obligation(id: 'o$i', startsAt: now.add(const Duration(hours: 9))),
      ];
      final plans = capped.plan(
        obligations: sameDay,
        now: now,
        viewerGender: Gender.male,
      );
      final counts = <String, int>{};
      for (final plan in plans) {
        final key = '${plan.at.year}-${plan.at.month}-${plan.at.day}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      for (final count in counts.values) {
        expect(count, lessThanOrEqualTo(2));
      }
    });
  });

  group('معرّفات التنبيهات', () {
    test('ثابتة لنفس المناسبة ونوع التنبيه', () {
      expect(
        NotificationPlanner.notificationId('o1', ReminderKind.morning),
        NotificationPlanner.notificationId('o1', ReminderKind.morning),
      );
    });

    test('مختلفة باختلاف نوع التنبيه', () {
      expect(
        NotificationPlanner.notificationId('o1', ReminderKind.morning),
        isNot(NotificationPlanner.notificationId('o1', ReminderKind.lastDay)),
      );
    });

    test('موجبة وضمن مدى العدد الصحيح 32-بت', () {
      for (final id in ['o1', 'مناسبة-طويلة-جداً', 'x' * 200]) {
        for (final kind in ReminderKind.values) {
          final value = NotificationPlanner.notificationId(id, kind);
          expect(value, greaterThanOrEqualTo(0));
          expect(value, lessThan(1 << 31));
        }
      }
    });
  });

  group('بوابة الجدولة الصورية', () {
    test('المزامنة تستبدل الخطة السابقة بالكامل', () async {
      final notifications = RecordingNotifications();
      await notifications.sync([
        ReminderPlan(
          id: 1,
          occasionId: 'o1',
          at: DateTime(2026, 5, 11, 8, 30),
          title: 'تذكير',
          body: 'واجب اليوم',
          kind: ReminderKind.morning,
        ),
      ]);
      expect(notifications.scheduled.length, 1);
      await notifications.sync(const []);
      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelCount, 2);
    });
  });
}
