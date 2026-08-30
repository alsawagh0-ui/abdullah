import 'package:flutter/foundation.dart';

import '../engines/action_layer.dart';
import '../engines/capture_engine.dart';
import '../engines/message_engine.dart';
import '../engines/obligation_engine.dart';
import '../engines/prayer_times.dart';
import '../engines/reciprocity_ledger.dart';
import '../models/ledger_entry.dart';
import '../models/obligation.dart';
import '../models/occasion.dart';
import '../models/person.dart';
import '../models/settings.dart';
import 'seed_data.dart';
import 'storage.dart';

/// حالة التطبيق: خريطة العلاقات، المناسبات، الدفتر، والإعدادات.
///
/// كل شيء محلي على الجهاز. لا توجد في هذا النموذج أي واجهة نشر عام،
/// ولا مزامنة تُظهر بيانات المستخدم لطرف آخر.
class WajbStore extends ChangeNotifier {
  WajbStore({
    WajbStorage? storage,
    DateTime Function()? clock,
  })  : _storage = storage ?? MemoryStorage(),
        _clock = clock ?? DateTime.now;

  final WajbStorage _storage;
  final DateTime Function() _clock;

  final CaptureEngine captureEngine = const CaptureEngine();
  final MessageEngine messageEngine = const MessageEngine();
  final MessageDispatcher dispatcher = const MessageDispatcher();
  final MoneySuggestion moneySuggestion = const MoneySuggestion();

  UserProfile _profile = const UserProfile(
    displayName: 'مستخدم واجِب',
    gender: Gender.male,
  );
  final Map<String, Person> _people = <String, Person>{};
  final List<Occasion> _occasions = <Occasion>[];
  final List<Delegation> _delegations = <Delegation>[];
  ReciprocityLedger _ledger = ReciprocityLedger();
  VendorCatalog _vendors = const VendorCatalog(<Vendor>[]);
  bool _loaded = false;

  DateTime get now => _clock();
  bool get isLoaded => _loaded;
  UserProfile get profile => _profile;
  List<Person> get people => List<Person>.unmodifiable(_people.values);
  Map<String, Person> get peopleById => Map<String, Person>.unmodifiable(_people);
  List<Occasion> get occasions => List<Occasion>.unmodifiable(_occasions);
  List<Delegation> get delegations => List<Delegation>.unmodifiable(_delegations);
  ReciprocityLedger get ledger => _ledger;
  VendorCatalog get vendors => _vendors;

  ObligationEngine get obligationEngine => ObligationEngine(ledger: _ledger);

  PrayerTimes get todayPrayerTimes => PrayerTimes.forDate(now);

  /// تحميل الحالة المحفوظة، أو تعبئة بيانات العرض التجريبية أول مرة.
  Future<void> load({bool seedIfEmpty = true}) async {
    final data = await _storage.read();
    if (data != null) {
      _restore(data);
    } else if (seedIfEmpty) {
      seed();
    }
    _loaded = true;
    notifyListeners();
  }

  void seed() {
    _people
      ..clear()
      ..addEntries(SeedData.people().map((p) => MapEntry(p.id, p)));
    _occasions
      ..clear()
      ..addAll(SeedData.occasions(now));
    _ledger = ReciprocityLedger(SeedData.ledger(now));
    _vendors = VendorCatalog(SeedData.vendors());
    _profile = _profile.copyWith(onboarded: true);
  }

  void _restore(Map<String, dynamic> data) {
    _profile = UserProfile.fromJson(
        (data['profile'] as Map).cast<String, dynamic>());
    _people
      ..clear()
      ..addEntries(
        (data['people'] as List)
            .map((e) => Person.fromJson((e as Map).cast<String, dynamic>()))
            .map((p) => MapEntry(p.id, p)),
      );
    _occasions
      ..clear()
      ..addAll((data['occasions'] as List)
          .map((e) => Occasion.fromJson((e as Map).cast<String, dynamic>())));
    _delegations
      ..clear()
      ..addAll((data['delegations'] as List? ?? const [])
          .map((e) => Delegation.fromJson((e as Map).cast<String, dynamic>())));
    _ledger = ReciprocityLedger.fromJson(data['ledger'] as List? ?? const []);
    _vendors = VendorCatalog(SeedData.vendors());
  }

  Map<String, dynamic> toJson() => {
        'profile': _profile.toJson(),
        'people': _people.values.map((p) => p.toJson()).toList(),
        'occasions': _occasions.map((o) => o.toJson()).toList(),
        'delegations': _delegations.map((d) => d.toJson()).toList(),
        'ledger': _ledger.toJson(),
      };

  Future<void> save() => _storage.write(toJson());

  void _touch() {
    notifyListeners();
    save();
  }

  // ── خريطة العلاقات ─────────────────────────────────────────────────
  void upsertPerson(Person person) {
    _people[person.id] = person;
    _touch();
  }

  void updateCloseness(String personId, int closeness) {
    final person = _people[personId];
    if (person == null) return;
    _people[personId] = person.copyWith(closeness: closeness.clamp(0, 100));
    _touch();
  }

  Person? person(String id) => _people[id];

  // ── المناسبات ──────────────────────────────────────────────────────
  void addOccasion(Occasion occasion) {
    _occasions.add(occasion);
    _touch();
  }

  void updateOccasion(Occasion occasion) {
    final index = _occasions.indexWhere((o) => o.id == occasion.id);
    if (index < 0) return;
    _occasions[index] = occasion;
    _touch();
  }

  Occasion? occasion(String id) {
    for (final o in _occasions) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// تسجيل أداء الواجب: يُعلَّم على المناسبة ويُقيَّد في الدفتر.
  void markDone(Occasion occasion, LedgerAction action) {
    updateOccasion(occasion.copyWith(done: true));
    _ledger.add(LedgerEntry(
      id: 'e${DateTime.now().microsecondsSinceEpoch}',
      personId: occasion.personId,
      direction: LedgerDirection.iDidForThem,
      action: action,
      occasionType: occasion.type,
      date: now,
      occasionId: occasion.id,
    ));
    _touch();
  }

  void dismissOccasion(Occasion occasion) {
    updateOccasion(occasion.copyWith(dismissed: true));
  }

  void addDelegation(Delegation delegation) {
    _delegations.add(delegation);
    _touch();
  }

  Delegation? delegationFor(String occasionId) {
    for (final d in _delegations) {
      if (d.occasionId == occasionId) return d;
    }
    return null;
  }

  // ── درجة الوجوب ────────────────────────────────────────────────────
  List<Obligation> rankedObligations() => obligationEngine.rank(
        occasions: _occasions,
        people: _people,
        now: now,
        userArea: _profile.area,
      );

  /// «واجبات اليوم»: ثلاث بطاقات كحد أقصى — مبدأ الشاشة الرئيسية.
  List<Obligation> todaysDuties({int limit = 3}) =>
      rankedObligations().take(limit).toList();

  /// ملخص الأسبوع المعروض في الشريط العلوي.
  ({int total, int confirmed}) weekSummary() {
    final weekEnd = now.add(const Duration(days: 7));
    final ranked = rankedObligations()
        .where((o) => o.occasion.startsAt.isBefore(weekEnd))
        .toList();
    return (
      total: ranked.length,
      confirmed:
          ranked.where((o) => o.tier == ObligationTier.confirmed).length,
    );
  }

  // ── الإعدادات ──────────────────────────────────────────────────────
  void updateProfile(UserProfile profile) {
    _profile = profile;
    _touch();
  }

  void setElderMode(bool value) =>
      updateProfile(_profile.copyWith(elderMode: value));

  void setPrivacy(PrivacySettings privacy) =>
      updateProfile(_profile.copyWith(privacy: privacy));

  Future<void> resetAll() async {
    await _storage.clear();
    _people.clear();
    _occasions.clear();
    _delegations.clear();
    _ledger = ReciprocityLedger();
    _profile = const UserProfile(
      displayName: 'مستخدم واجِب',
      gender: Gender.male,
    );
    notifyListeners();
  }
}
