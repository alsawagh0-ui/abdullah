import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/engines/reciprocity_ledger.dart';
import 'package:wajb/models/ledger_entry.dart';
import 'package:wajb/models/occasion.dart';

LedgerEntry entry({
  required String id,
  required String personId,
  required LedgerDirection direction,
  LedgerAction action = LedgerAction.attended,
  DateTime? date,
}) {
  return LedgerEntry(
    id: id,
    personId: personId,
    direction: direction,
    action: action,
    occasionType: OccasionType.condolence,
    date: date ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('ReciprocityLedger', () {
    test('لا سجل يعني درجة محايدة 50', () {
      final ledger = ReciprocityLedger();
      expect(ledger.reciprocityScore('p1'), 50);
    });

    test('واجب لهم غير مردود يرفع الدرجة', () {
      final ledger = ReciprocityLedger([
        entry(id: '1', personId: 'p1', direction: LedgerDirection.theyDidForMe),
      ]);
      expect(ledger.reciprocityScore('p1'), greaterThan(60));
    });

    test('مبادرة المستخدم تخفض الدرجة دون أن تهبط تحت الحد الأدنى', () {
      final ledger = ReciprocityLedger([
        for (var i = 0; i < 10; i++)
          entry(
            id: 'i$i',
            personId: 'p1',
            direction: LedgerDirection.iDidForThem,
          ),
      ]);
      expect(ledger.reciprocityScore('p1'), 25);
    });

    test('الدرجة لا تتجاوز 100 مهما كثرت الواجبات', () {
      final ledger = ReciprocityLedger([
        for (var i = 0; i < 20; i++)
          entry(
            id: 't$i',
            personId: 'p1',
            direction: LedgerDirection.theyDidForMe,
          ),
      ]);
      expect(ledger.reciprocityScore('p1'), 100);
    });

    test('الحضور أثقل من الرسالة في حساب الرصيد', () {
      final attended = ReciprocityLedger([
        entry(id: '1', personId: 'p1', direction: LedgerDirection.theyDidForMe),
      ]);
      final messaged = ReciprocityLedger([
        entry(
          id: '1',
          personId: 'p1',
          direction: LedgerDirection.theyDidForMe,
          action: LedgerAction.message,
        ),
      ]);
      expect(
        attended.reciprocityScore('p1'),
        greaterThan(messaged.reciprocityScore('p1')),
      );
    });

    test('قائمة «لم يُرَدّ بعد» مرتبة بالأقدم أولاً لا بترتيب تفاضلي', () {
      final ledger = ReciprocityLedger([
        entry(
          id: '1',
          personId: 'old',
          direction: LedgerDirection.theyDidForMe,
          date: DateTime(2020, 1, 1),
        ),
        entry(
          id: '2',
          personId: 'new',
          direction: LedgerDirection.theyDidForMe,
          date: DateTime(2026, 1, 1),
        ),
      ]);
      final outstanding = ledger.outstanding();
      expect(outstanding.map((b) => b.personId).toList(), ['old', 'new']);
    });

    test('نص التذكير لا يحمل أي صيغة اتهامية تجاه الآخرين', () {
      final ledger = ReciprocityLedger([
        entry(id: '1', personId: 'p1', direction: LedgerDirection.theyDidForMe),
      ]);
      final text = ledger.balanceFor('p1').reminderText;
      for (final banned in ['قصّر', 'قصر', 'تجاهل', 'أهمل', 'ما حضر']) {
        expect(text.contains(banned), isFalse, reason: 'ظهرت كلمة: $banned');
      }
    });

    test('الرصيد المتوازن لا يظهر في قائمة ما لم يُرَدّ', () {
      final ledger = ReciprocityLedger([
        entry(id: '1', personId: 'p1', direction: LedgerDirection.theyDidForMe),
        entry(id: '2', personId: 'p1', direction: LedgerDirection.iDidForThem),
      ]);
      expect(ledger.outstanding(), isEmpty);
    });

    test('الحفظ والاسترجاع من JSON يحافظ على القيود', () {
      final ledger = ReciprocityLedger([
        entry(id: '1', personId: 'p1', direction: LedgerDirection.theyDidForMe),
      ]);
      final restored = ReciprocityLedger.fromJson(ledger.toJson());
      expect(restored.entries.length, 1);
      expect(restored.reciprocityScore('p1'),
          ledger.reciprocityScore('p1'));
    });
  });
}
