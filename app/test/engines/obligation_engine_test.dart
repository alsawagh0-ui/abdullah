import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/engines/obligation_engine.dart';
import 'package:wajb/engines/reciprocity_ledger.dart';
import 'package:wajb/models/ledger_entry.dart';
import 'package:wajb/models/obligation.dart';
import 'package:wajb/models/occasion.dart';
import 'package:wajb/models/person.dart';

final DateTime now = DateTime(2026, 5, 10, 12);

Person person({int closeness = 70, String id = 'p1'}) => Person(
      id: id,
      displayName: 'شخص $id',
      circle: SocialCircle.family,
      closeness: closeness,
      kinship: 'ابن العم',
    );

Occasion occasion({
  OccasionType type = OccasionType.condolence,
  DateTime? startsAt,
  String id = 'o1',
  String personId = 'p1',
  int? durationDays,
  Venue? menVenue,
}) =>
    Occasion(
      id: id,
      personId: personId,
      type: type,
      title: 'مناسبة',
      startsAt: startsAt ?? now.subtract(const Duration(hours: 2)),
      durationDays: durationDays,
      menVenue: menVenue ?? const Venue(title: 'ديوان', area: 'الرميثية'),
    );

void main() {
  const engine = ObligationEngine();

  group('درجة الوجوب', () {
    test('عزاء قريب جداً = واجب مؤكد', () {
      final result = engine.evaluate(
        occasion: occasion(),
        person: person(closeness: 95),
        now: now,
      );
      expect(result.tier, ObligationTier.confirmed);
      expect(result.score, greaterThanOrEqualTo(70));
    });

    test('ديوانية معرفة عامة = اختياري', () {
      final result = engine.evaluate(
        occasion: occasion(type: OccasionType.diwaniya),
        person: person(closeness: 20),
        now: now,
      );
      expect(result.tier, ObligationTier.optional);
    });

    test('الدرجة محصورة بين 0 و 100 مهما تطرفت المدخلات', () {
      final high = engine.evaluate(
        occasion: occasion(),
        person: person(closeness: 100),
        now: now,
      );
      final low = engine.evaluate(
        occasion: occasion(type: OccasionType.travel),
        person: person(closeness: 0),
        now: now,
      );
      expect(high.score, inInclusiveRange(0, 100));
      expect(low.score, inInclusiveRange(0, 100));
    });

    test('العزاء أثقل من الديوانية عند تساوي بقية العوامل', () {
      final condolence = engine.evaluate(
        occasion: occasion(),
        person: person(),
        now: now,
      );
      final diwaniya = engine.evaluate(
        occasion: occasion(type: OccasionType.diwaniya),
        person: person(),
        now: now,
      );
      expect(condolence.score, greaterThan(diwaniya.score));
    });

    test('كلما قرُبت العلاقة ارتفعت الدرجة', () {
      var previous = -1;
      for (final closeness in [10, 30, 50, 70, 90]) {
        final score = engine
            .evaluate(
              occasion: occasion(),
              person: person(closeness: closeness),
              now: now,
            )
            .score;
        expect(score, greaterThan(previous));
        previous = score;
      }
    });

    test('اليوم الأخير للعزاء يرفع الإلحاح ويُذكر كسبب', () {
      final lastDay = engine.evaluate(
        occasion: occasion(
          startsAt: now.subtract(const Duration(days: 2)),
          durationDays: 3,
        ),
        person: person(),
        now: now,
      );
      expect(lastDay.factors.urgency, 100);
      expect(lastDay.reasons.any((r) => r.contains('آخر يوم')), isTrue);
    });

    test('مناسبة بعيدة زمنياً أقل إلحاحاً من مناسبة الغد', () {
      final soon = engine.evaluate(
        occasion: occasion(startsAt: now.add(const Duration(hours: 10))),
        person: person(),
        now: now,
      );
      final later = engine.evaluate(
        occasion: occasion(startsAt: now.add(const Duration(days: 10))),
        person: person(),
        now: now,
      );
      expect(soon.factors.urgency, greaterThan(later.factors.urgency));
    });

    test('واجب لهم لم يُرَدّ يرفع الدرجة ويظهر كسبب', () {
      final ledger = ReciprocityLedger([
        LedgerEntry(
          id: 'l1',
          personId: 'p1',
          direction: LedgerDirection.theyDidForMe,
          action: LedgerAction.attended,
          occasionType: OccasionType.condolence,
          date: now.subtract(const Duration(days: 200)),
        ),
      ]);
      final withLedger = ObligationEngine(ledger: ledger).evaluate(
        occasion: occasion(type: OccasionType.wedding),
        person: person(closeness: 55),
        now: now,
      );
      final without = engine.evaluate(
        occasion: occasion(type: OccasionType.wedding),
        person: person(closeness: 55),
        now: now,
      );
      expect(withLedger.score, greaterThan(without.score));
      expect(
        withLedger.reasons.any((r) => r.contains('لم يُرَدّ')),
        isTrue,
      );
    });

    test('التعارض مع واجب أثقل في اليوم نفسه يخفض إمكانية الحضور', () {
      final result = engine.evaluate(
        occasion: occasion(type: OccasionType.diwaniya),
        person: person(),
        now: now,
        sameDayOccasions: [occasion(id: 'o2', personId: 'p2')],
      );
      expect(result.factors.feasibility, lessThan(100));
      expect(result.reasons.any((r) => r.contains('يتعارض')), isTrue);
    });

    test('أوزان العوامل مجموعها 1', () {
      const sum = ObligationFactors.closenessWeight +
          ObligationFactors.occasionWeightWeight +
          ObligationFactors.reciprocityWeight +
          ObligationFactors.urgencyWeight +
          ObligationFactors.feasibilityWeight;
      expect(sum, closeTo(1.0, 1e-9));
    });
  });

  group('الترتيب', () {
    test('يرتّب تنازلياً ويستبعد المنتهي والمؤدّى والمستبعَد', () {
      final people = {
        'p1': person(closeness: 95, id: 'p1'),
        'p2': person(closeness: 30, id: 'p2'),
        'p3': person(closeness: 90, id: 'p3'),
      };
      final occasions = [
        occasion(id: 'a', personId: 'p2', type: OccasionType.diwaniya),
        occasion(id: 'b', personId: 'p1'),
        occasion(id: 'c', personId: 'p3').copyWith(done: true),
        occasion(
          id: 'd',
          personId: 'p3',
          startsAt: now.subtract(const Duration(days: 30)),
        ),
      ];
      final ranked = engine.rank(
        occasions: occasions,
        people: people,
        now: now,
      );
      expect(ranked.map((o) => o.occasion.id).toList(), ['b', 'a']);
      expect(ranked.first.score, greaterThan(ranked.last.score));
    });

    test('مناسبة بلا شخص معروف تُستبعد بلا انهيار', () {
      final ranked = engine.rank(
        occasions: [occasion(personId: 'مجهول')],
        people: const {},
        now: now,
      );
      expect(ranked, isEmpty);
    });
  });
}
