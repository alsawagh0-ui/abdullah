import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/data/storage.dart';
import 'package:wajb/data/wajb_store.dart';
import 'package:wajb/models/ledger_entry.dart';
import 'package:wajb/models/obligation.dart';
import 'package:wajb/models/occasion.dart';
import 'package:wajb/models/person.dart';

final DateTime fixedNow = DateTime(2026, 5, 10, 14);

WajbStore buildStore([WajbStorage? storage]) => WajbStore(
      storage: storage ?? MemoryStorage(),
      clock: () => fixedNow,
    );

void main() {
  group('WajbStore', () {
    test('التحميل الأول يعبّئ بيانات العرض', () async {
      final store = buildStore();
      await store.load();
      expect(store.isLoaded, isTrue);
      expect(store.people, isNotEmpty);
      expect(store.occasions, isNotEmpty);
    });

    test('الشاشة الرئيسية لا تتجاوز ثلاث بطاقات', () async {
      final store = buildStore();
      await store.load();
      expect(store.rankedObligations().length, greaterThan(3));
      expect(store.todaysDuties().length, 3);
    });

    test('الواجبات مرتّبة تنازلياً بدرجة الوجوب', () async {
      final store = buildStore();
      await store.load();
      final scores = store.rankedObligations().map((o) => o.score).toList();
      final sorted = [...scores]..sort((a, b) => b.compareTo(a));
      expect(scores, sorted);
    });

    test('العزاء القريب يتصدر واجبات اليوم', () async {
      final store = buildStore();
      await store.load();
      final first = store.todaysDuties().first;
      expect(first.occasion.type, OccasionType.condolence);
      expect(first.tier, ObligationTier.confirmed);
    });

    test('تسجيل الحضور يقيّد في الدفتر ويرفع الواجب من القائمة', () async {
      final store = buildStore();
      await store.load();
      final duty = store.todaysDuties().first;
      final before = store.ledger.entries.length;

      store.markDone(duty.occasion, LedgerAction.attended);

      expect(store.ledger.entries.length, before + 1);
      expect(store.occasion(duty.occasion.id)!.done, isTrue);
      expect(
        store.rankedObligations().any((o) => o.occasion.id == duty.occasion.id),
        isFalse,
      );
      final entry = store.ledger.entries.last;
      expect(entry.direction, LedgerDirection.iDidForThem);
      expect(entry.personId, duty.person.id);
    });

    test('تعديل درجة القرب يغيّر ترتيب الواجب', () async {
      final store = buildStore();
      await store.load();
      final person = store.people.firstWhere((p) => p.closeness < 60);
      final occasionsOfPerson =
          store.occasions.where((o) => o.personId == person.id);
      if (occasionsOfPerson.isEmpty) return;

      int scoreOf() => store
          .rankedObligations()
          .firstWhere((o) => o.person.id == person.id)
          .score;

      final before = scoreOf();
      store.updateCloseness(person.id, 95);
      expect(scoreOf(), greaterThan(before));
    });

    test('درجة القرب محصورة بين 0 و 100', () async {
      final store = buildStore();
      await store.load();
      final person = store.people.first;
      store.updateCloseness(person.id, 500);
      expect(store.person(person.id)!.closeness, 100);
      store.updateCloseness(person.id, -20);
      expect(store.person(person.id)!.closeness, 0);
    });

    test('ملخص الأسبوع يحصي الواجبات والمؤكد منها', () async {
      final store = buildStore();
      await store.load();
      final summary = store.weekSummary();
      expect(summary.total, greaterThan(0));
      expect(summary.confirmed, lessThanOrEqualTo(summary.total));
    });

    test('الحالة تُحفظ وتُسترجع كاملة', () async {
      final storage = MemoryStorage();
      final store = buildStore(storage);
      await store.load();
      store.upsertPerson(Person(
        id: 'new',
        displayName: 'شخص جديد',
        circle: SocialCircle.neighbors,
        closeness: 33,
      ));
      await store.save();

      final restored = buildStore(storage);
      await restored.load();
      expect(restored.person('new')?.displayName, 'شخص جديد');
      expect(restored.person('new')?.closeness, 33);
      expect(restored.occasions.length, store.occasions.length);
      expect(restored.ledger.entries.length, store.ledger.entries.length);
    });

    test('إعادة الضبط تمحو كل شيء', () async {
      final store = buildStore();
      await store.load();
      await store.resetAll();
      expect(store.people, isEmpty);
      expect(store.occasions, isEmpty);
      expect(store.ledger.entries, isEmpty);
      expect(store.profile.onboarded, isFalse);
    });

    test('المناسبة المستبعَدة لا تعود في الترتيب', () async {
      final store = buildStore();
      await store.load();
      final duty = store.todaysDuties().first;
      store.dismissOccasion(duty.occasion);
      expect(
        store.rankedObligations().any((o) => o.occasion.id == duty.occasion.id),
        isFalse,
      );
    });

    test('المخزن يُخطر المستمعين عند التغيير', () async {
      final store = buildStore();
      await store.load();
      var notifications = 0;
      store.addListener(() => notifications++);
      store.setElderMode(true);
      expect(notifications, greaterThan(0));
      expect(store.profile.elderMode, isTrue);
    });
  });
}
