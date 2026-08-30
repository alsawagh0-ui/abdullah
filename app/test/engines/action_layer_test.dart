import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/data/seed_data.dart';
import 'package:wajb/engines/action_layer.dart';
import 'package:wajb/models/occasion.dart';
import 'package:wajb/models/person.dart';

Occasion occasionOf(OccasionType type) => Occasion(
      id: 'o',
      personId: 'p',
      type: type,
      title: 'مناسبة',
      startsAt: DateTime(2026, 5, 10),
    );

void main() {
  group('اقتراح النقوط — خاص وسري', () {
    const suggestion = MoneySuggestion();

    test('لا اقتراح مالي في العزاء أو المرض', () {
      expect(
        suggestion.suggest(
          type: OccasionType.condolence,
          tier: ClosenessTier.inner,
        ),
        isNull,
      );
      expect(
        suggestion.suggest(
          type: OccasionType.illness,
          tier: ClosenessTier.inner,
        ),
        isNull,
      );
    });

    test('النطاق يرتفع كلما قرُبت العلاقة', () {
      var previous = 0;
      for (final tier in [
        ClosenessTier.acquaintance,
        ClosenessTier.wide,
        ClosenessTier.close,
        ClosenessTier.inner,
      ]) {
        final range =
            suggestion.suggest(type: OccasionType.wedding, tier: tier)!;
        expect(range.minKwd, greaterThanOrEqualTo(previous));
        expect(range.maxKwd, greaterThan(range.minKwd));
        previous = range.minKwd;
      }
    });

    test('كل نطاق مُعلَّم كخاص ومصحوب بتنبيه استرشادي', () {
      final range = suggestion.suggest(
        type: OccasionType.wedding,
        tier: ClosenessTier.close,
      )!;
      expect(range.isPrivate, isTrue);
      expect(range.note, contains('خاص'));
    });
  });

  group('سوق الموردين — لا إعلانات على العزاء', () {
    final catalog = VendorCatalog(SeedData.vendors());

    test('لا محتوى ترويجي إطلاقاً في العزاء أو المرض', () {
      expect(catalog.promotionsFor(occasionOf(OccasionType.condolence)),
          isEmpty);
      expect(
          catalog.promotionsFor(occasionOf(OccasionType.illness)), isEmpty);
    });

    test('الترويج مسموح في مناسبات الفرح', () {
      expect(
        catalog.promotionsFor(occasionOf(OccasionType.wedding)),
        isNotEmpty,
      );
    });

    test('خدمات العزاء مقصورة على ما يليق بالمقام', () {
      final services = catalog.servicesFor(occasionOf(OccasionType.condolence));
      expect(services, isNotEmpty);
      final categories = services.map((v) => v.category).toSet();
      expect(categories.contains(VendorCategory.flowers), isFalse);
      expect(categories.contains(VendorCategory.gift), isFalse);
      expect(categories.contains(VendorCategory.invitationPrint), isFalse);
      expect(categories.contains(VendorCategory.coffeeServer), isTrue);
    });

    test('كل مورد معروض معتمد', () {
      for (final vendor in catalog.servicesFor(
        occasionOf(OccasionType.wedding),
      )) {
        expect(vendor.verified, isTrue);
      }
    });
  });

  group('الإنابة', () {
    test('تبدأ بانتظار الرد وتتحول بالنسخ لا بالتعديل الصامت', () {
      const delegation = Delegation(
        id: 'd1',
        occasionId: 'o1',
        delegateName: 'سعود',
        status: DelegationStatus.pending,
      );
      final accepted =
          delegation.copyWith(status: DelegationStatus.accepted);
      expect(delegation.status, DelegationStatus.pending);
      expect(accepted.status, DelegationStatus.accepted);
      expect(accepted.delegateName, 'سعود');
    });

    test('التسلسل يحفظ ويُسترجع من JSON', () {
      const delegation = Delegation(
        id: 'd1',
        occasionId: 'o1',
        delegateName: 'سعود',
        status: DelegationStatus.accepted,
        note: 'يحضر بعد العصر',
      );
      final restored = Delegation.fromJson(delegation.toJson());
      expect(restored.delegateName, 'سعود');
      expect(restored.status, DelegationStatus.accepted);
      expect(restored.note, 'يحضر بعد العصر');
    });
  });
}
