import '../engines/prayer_times.dart';
import '../models/obligation.dart';
import '../models/occasion.dart';
import '../models/person.dart';

enum ReminderKind {
  /// تذكير صباحي بواجبات اليوم.
  morning,

  /// تذكير قبل موعد الحضور بوقت كافٍ للتجهّز والوصول.
  beforeStart,

  /// اليوم الأخير للمناسبة — الفرصة الأخيرة.
  lastDay,
}

class ReminderPlan {
  const ReminderPlan({
    required this.id,
    required this.occasionId,
    required this.at,
    required this.title,
    required this.body,
    required this.kind,
  });

  final int id;
  final String occasionId;
  final DateTime at;
  final String title;
  final String body;
  final ReminderKind kind;

  @override
  String toString() => 'ReminderPlan($occasionId, $kind, $at)';
}

/// يحسب متى يُنبَّه المستخدم — منطق خالص بلا أي اعتماد على المنصة، كي
/// يكون قابلاً للاختبار بالكامل.
///
/// قواعده مستمدة من الوثيقة:
/// - التنبيهات تحترم مواقيت الصلاة ولا تُرسل أثناءها.
/// - لا إزعاج: الواجب الاختياري لا يُنبَّه عليه إطلاقاً.
/// - سقف يومي حتى لا تتحول الأداة إلى مصدر ضغط جديد.
class NotificationPlanner {
  const NotificationPlanner({
    this.morningHour = 8,
    this.morningMinute = 30,
    this.leadTime = const Duration(minutes: 90),
    this.maxPerDay = 3,
  });

  final int morningHour;
  final int morningMinute;

  /// المهلة قبل موعد الحضور.
  final Duration leadTime;

  /// أقصى عدد تنبيهات في اليوم الواحد.
  final int maxPerDay;

  List<ReminderPlan> plan({
    required List<Obligation> obligations,
    required DateTime now,
    required Gender viewerGender,
    bool respectPrayerTimes = true,
    Duration horizon = const Duration(days: 7),
  }) {
    final deadline = now.add(horizon);
    final candidates = <ReminderPlan>[];

    for (final obligation in obligations) {
      final occasion = obligation.occasion;
      if (occasion.done || occasion.dismissed) continue;

      // الاختياري لا يُنبَّه عليه: التطبيق يذكّر بالواجب لا يلاحق المستخدم.
      if (obligation.tier == ObligationTier.optional) continue;

      final startDay = DateTime(
        occasion.startsAt.year,
        occasion.startsAt.month,
        occasion.startsAt.day,
      );
      final morning = DateTime(
        startDay.year,
        startDay.month,
        startDay.day,
        morningHour,
        morningMinute,
      );

      candidates.add(_build(
        obligation: obligation,
        at: morning,
        kind: ReminderKind.morning,
        title: '${occasion.type.label}: ${obligation.person.displayName}',
        body: '${obligation.tier.label} اليوم — '
            '${occasion.venueFor(viewerGender)?.title ?? 'راجع التفاصيل'}',
      ));

      if (obligation.tier == ObligationTier.confirmed) {
        candidates.add(_build(
          obligation: obligation,
          at: occasion.startsAt.subtract(leadTime),
          kind: ReminderKind.beforeStart,
          title: 'قرب موعد ${occasion.type.label}',
          body: '${obligation.person.displayName} — '
              'يبدأ بعد ${leadTime.inMinutes} دقيقة',
        ));

        if (occasion.effectiveDurationDays > 1) {
          final lastDay = startDay
              .add(Duration(days: occasion.effectiveDurationDays - 1));
          candidates.add(_build(
            obligation: obligation,
            at: DateTime(lastDay.year, lastDay.month, lastDay.day,
                morningHour, morningMinute),
            kind: ReminderKind.lastDay,
            title: 'آخر يوم: ${occasion.type.label}',
            body: '${obligation.person.displayName} — '
                'اليوم آخر فرصة لأداء الواجب',
          ));
        }
      }
    }

    final adjusted = <ReminderPlan>[];
    for (final candidate in candidates) {
      var at = candidate.at;
      if (!at.isAfter(now) || at.isAfter(deadline)) continue;

      if (respectPrayerTimes) {
        at = PrayerTimes.forDate(at).nextAllowedNotification(at);
        // قد يدفع التأجيل التنبيه خارج الأفق الزمني.
        if (at.isAfter(deadline)) continue;
      }

      adjusted.add(ReminderPlan(
        id: candidate.id,
        occasionId: candidate.occasionId,
        at: at,
        title: candidate.title,
        body: candidate.body,
        kind: candidate.kind,
      ));
    }

    adjusted.sort((a, b) => a.at.compareTo(b.at));
    return _capPerDay(adjusted);
  }

  ReminderPlan _build({
    required Obligation obligation,
    required DateTime at,
    required ReminderKind kind,
    required String title,
    required String body,
  }) {
    return ReminderPlan(
      id: notificationId(obligation.occasion.id, kind),
      occasionId: obligation.occasion.id,
      at: at,
      title: title,
      body: body,
      kind: kind,
    );
  }

  /// معرّف ثابت لكل (مناسبة، نوع تنبيه) حتى تُستبدل الجدولة السابقة بدل
  /// أن تتكرر عند كل مزامنة.
  static int notificationId(String occasionId, ReminderKind kind) {
    final hash = occasionId.hashCode.abs() % 100000;
    return hash * 10 + kind.index;
  }

  List<ReminderPlan> _capPerDay(List<ReminderPlan> plans) {
    final perDay = <String, int>{};
    final result = <ReminderPlan>[];
    for (final plan in plans) {
      final key = '${plan.at.year}-${plan.at.month}-${plan.at.day}';
      final count = perDay[key] ?? 0;
      if (count >= maxPerDay) continue;
      perDay[key] = count + 1;
      result.add(plan);
    }
    return result;
  }
}

/// بوابة جدولة التنبيهات على المنصة.
abstract class WajbNotifications {
  Future<void> initialize();
  Future<bool> requestPermission();

  /// تستبدل الجدولة القائمة بالخطة الجديدة.
  Future<void> sync(List<ReminderPlan> plans);
  Future<void> cancelAll();
}

/// تنفيذ صوري للاختبارات وللمنصات غير المدعومة.
class RecordingNotifications implements WajbNotifications {
  RecordingNotifications({this.permissionGranted = true});

  final bool permissionGranted;
  final List<ReminderPlan> scheduled = <ReminderPlan>[];
  int cancelCount = 0;
  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> sync(List<ReminderPlan> plans) async {
    cancelCount++;
    scheduled
      ..clear()
      ..addAll(plans);
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
    scheduled.clear();
  }
}
