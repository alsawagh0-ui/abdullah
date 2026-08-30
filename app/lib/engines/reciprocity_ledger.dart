import '../models/ledger_entry.dart';

/// ملخص رصيد شخص واحد في الدفتر.
class ReciprocityBalance {
  const ReciprocityBalance({
    required this.personId,
    required this.theyDidWeighted,
    required this.iDidWeighted,
    required this.outstandingCount,
    required this.lastTheyDid,
  });

  final String personId;
  final double theyDidWeighted;
  final double iDidWeighted;

  /// عدد واجباتهم التي لم يُقابلها بعد واجب من المستخدم.
  final int outstandingCount;
  final DateTime? lastTheyDid;

  /// موجب = لهم رصيد عندي. سالب = أنا سبقتهم.
  double get net => theyDidWeighted - iDidWeighted;

  /// صياغة تذكيرية لا اتهامية: الدفتر لا يقول إن أحداً «قصّر»، بل يذكّر
  /// المستخدم بما عليه هو فقط.
  String get reminderText {
    if (net > 0.5) return 'لهم عندك واجب لم يُرَدّ بعد';
    if (net < -0.5) return 'أنت مبادر معهم';
    return 'الرصيد متوازن';
  }
}

/// المحرك الرابع — دفتر المعاملة بالمثل.
///
/// خاص وصامت: لا يُشارك، ولا يُصدَّر، ولا يعرض تقصير الآخرين بصيغة
/// اتهامية، ولا يرتّب الأشخاص. كل ما يفعله أنه يذكّر المستخدم بما عليه.
class ReciprocityLedger {
  ReciprocityLedger([List<LedgerEntry>? entries])
      : _entries = List<LedgerEntry>.from(entries ?? const <LedgerEntry>[]);

  final List<LedgerEntry> _entries;

  List<LedgerEntry> get entries => List<LedgerEntry>.unmodifiable(_entries);

  void add(LedgerEntry entry) => _entries.add(entry);

  void addAll(Iterable<LedgerEntry> entries) => _entries.addAll(entries);

  void removeWhere(bool Function(LedgerEntry) test) =>
      _entries.removeWhere(test);

  List<LedgerEntry> forPerson(String personId) =>
      _entries.where((e) => e.personId == personId).toList();

  ReciprocityBalance balanceFor(String personId) {
    var theyDid = 0.0;
    var iDid = 0.0;
    DateTime? lastTheyDid;
    var theyCount = 0;
    var iCount = 0;

    for (final entry in _entries) {
      if (entry.personId != personId) continue;
      if (entry.direction == LedgerDirection.theyDidForMe) {
        theyDid += entry.action.weight;
        theyCount++;
        if (lastTheyDid == null || entry.date.isAfter(lastTheyDid)) {
          lastTheyDid = entry.date;
        }
      } else {
        iDid += entry.action.weight;
        iCount++;
      }
    }

    return ReciprocityBalance(
      personId: personId,
      theyDidWeighted: theyDid,
      iDidWeighted: iDid,
      outstandingCount: (theyCount - iCount).clamp(0, 1 << 30),
      lastTheyDid: lastTheyDid,
    );
  }

  /// درجة المعاملة بالمثل (0..100) كما يستهلكها محرك درجة الوجوب.
  /// 50 = لا سجل بعد (محايد). ترتفع كلما زاد ما لهم في ذمّتك.
  double reciprocityScore(String personId) {
    final balance = balanceFor(personId);
    if (_entries.every((e) => e.personId != personId)) return 50;
    const unit = 16.67; // كل واجب حضور غير مردود ≈ +17 نقطة
    return (50 + balance.net * unit).clamp(25.0, 100.0);
  }

  /// الأشخاص الذين لهم واجب لم يُرَدّ — للعرض في شاشة الدفتر.
  /// تُعاد مرتبة زمنياً بالأقدم أولاً، لا بترتيب تفاضلي بين الأشخاص.
  List<ReciprocityBalance> outstanding() {
    final ids = _entries.map((e) => e.personId).toSet();
    final result = ids
        .map(balanceFor)
        .where((b) => b.net > 0.5)
        .toList()
      ..sort((a, b) {
        final aDate = a.lastTheyDid;
        final bDate = b.lastTheyDid;
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });
    return result;
  }

  List<Map<String, dynamic>> toJson() =>
      _entries.map((e) => e.toJson()).toList();

  static ReciprocityLedger fromJson(List<dynamic> json) => ReciprocityLedger(
        json
            .map((e) => LedgerEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
