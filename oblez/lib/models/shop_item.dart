/// فئات عناصر متجر التطوير الثلاث.
enum ShopCategory { gear, network, cosmetic }

/// عنصر واحد في متجر التطوير (كرسي، راوتر، نظارة قيمنق...).
class ShopItem {
  final String id;
  final String name;
  final ShopCategory category;
  final int price;

  /// مستوى الترقية داخل فئته (0 = الأساسي/الافتراضي).
  final int tier;

  const ShopItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.tier,
  });
}
