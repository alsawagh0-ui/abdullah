import '../models/occasion.dart';
import '../models/person.dart';

/// نطاق مالي استرشادي للنقوط.
///
/// خاص وسري بالكامل: لا يُعرض لأي طرف آخر، ولا يُسجَّل ما دفعه غيرك،
/// ولا يُبنى منه أي ترتيب أو مقارنة بين الأشخاص.
class MoneyRange {
  const MoneyRange(this.minKwd, this.maxKwd, {required this.note});

  final int minKwd;
  final int maxKwd;
  final String note;

  /// ثابت توثيقي: هذا الاقتراح لا يغادر جهاز المستخدم ولا يظهر لغيره.
  bool get isPrivate => true;

  String get label => '$minKwd – $maxKwd د.ك';
}

/// اقتراح النقوط بحسب العرف ودرجة القرب.
class MoneySuggestion {
  const MoneySuggestion();

  MoneyRange? suggest({
    required OccasionType type,
    required ClosenessTier tier,
  }) {
    // لا نقوط في العزاء بحسب العرف؛ المواساة تكون بالحضور أو بالمساعدة
    // العملية (ضيافة، قهوجية) لا بالمال.
    if (type == OccasionType.condolence || type == OccasionType.illness) {
      return null;
    }

    final base = switch (type) {
      OccasionType.wedding => const [10, 20, 30, 50],
      OccasionType.newborn => const [5, 10, 20, 30],
      OccasionType.graduation => const [5, 10, 15, 25],
      OccasionType.promotion => const [5, 10, 15, 20],
      OccasionType.eid => const [5, 10, 10, 20],
      _ => const [0, 0, 0, 0],
    };

    final index = switch (tier) {
      ClosenessTier.acquaintance => 0,
      ClosenessTier.wide => 1,
      ClosenessTier.close => 2,
      ClosenessTier.inner => 3,
    };

    final low = base[index];
    if (low == 0) return null;
    final high = index == base.length - 1 ? low * 2 : base[index + 1];
    return MoneyRange(
      low,
      high,
      note: 'اقتراح استرشادي خاص بك وحدك، مبني على العرف ودرجة القرب.',
    );
  }
}

enum VendorCategory {
  flowers,
  hospitality,
  coffeeServer,
  dates,
  condolenceTent,
  gift,
  invitationPrint,
}

extension VendorCategoryLabel on VendorCategory {
  String get label => switch (this) {
        VendorCategory.flowers => 'ورد',
        VendorCategory.hospitality => 'ضيافة',
        VendorCategory.coffeeServer => 'قهوجية',
        VendorCategory.dates => 'تمور',
        VendorCategory.condolenceTent => 'خيمة عزاء',
        VendorCategory.gift => 'هدية',
        VendorCategory.invitationPrint => 'مطابع دعوات',
      };
}

class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    this.verified = true,
  });

  final String id;
  final String name;
  final VendorCategory category;
  final String area;
  final bool verified;
}

/// سوق الموردين المعتمدين.
///
/// خط أحمر: لا إعلانات تجارية على محتوى العزاء. المورّدون في المناسبات
/// الحزينة لا يُعرضون إعلانياً أبداً، ولا يظهرون إلا حين يطلب المستخدم
/// خدمة بنفسه، ومقصورين على ما يليق بالمقام.
class VendorCatalog {
  const VendorCatalog(this.vendors);

  final List<Vendor> vendors;

  static const List<VendorCategory> _condolenceAppropriate = [
    VendorCategory.coffeeServer,
    VendorCategory.dates,
    VendorCategory.hospitality,
    VendorCategory.condolenceTent,
  ];

  /// المحتوى الترويجي المسموح عرضه تلقائياً داخل بطاقة المناسبة.
  /// يعود فارغاً دائماً في مناسبات العزاء والمرض — قاعدة غير قابلة
  /// للتفاوض تجارياً.
  List<Vendor> promotionsFor(Occasion occasion) {
    if (occasion.type.isSolemn) return const <Vendor>[];
    return vendors.where((v) => v.verified).toList();
  }

  /// الخدمات التي تظهر بعد أن يفتح المستخدم سوق الخدمات بنفسه.
  List<Vendor> servicesFor(Occasion occasion) {
    if (occasion.type.isSolemn) {
      return vendors
          .where((v) =>
              v.verified && _condolenceAppropriate.contains(v.category))
          .toList();
    }
    return vendors.where((v) => v.verified).toList();
  }
}

enum DelegationStatus { pending, accepted, completed, declined }

extension DelegationStatusLabel on DelegationStatus {
  String get label => switch (this) {
        DelegationStatus.pending => 'بانتظار الرد',
        DelegationStatus.accepted => 'تم القبول',
        DelegationStatus.completed => 'تم الأداء',
        DelegationStatus.declined => 'اعتذر',
      };
}

/// إنابة: «وكّل أحد عني» لتكليف قريب بأداء الواجب نيابةً.
class Delegation {
  const Delegation({
    required this.id,
    required this.occasionId,
    required this.delegateName,
    required this.status,
    this.note,
  });

  final String id;
  final String occasionId;
  final String delegateName;
  final DelegationStatus status;
  final String? note;

  Delegation copyWith({DelegationStatus? status, String? note}) => Delegation(
        id: id,
        occasionId: occasionId,
        delegateName: delegateName,
        status: status ?? this.status,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'occasionId': occasionId,
        'delegateName': delegateName,
        'status': status.name,
        'note': note,
      };

  static Delegation fromJson(Map<String, dynamic> json) => Delegation(
        id: json['id'] as String,
        occasionId: json['occasionId'] as String,
        delegateName: json['delegateName'] as String,
        status: DelegationStatus.values.byName(json['status'] as String),
        note: json['note'] as String?,
      );
}
