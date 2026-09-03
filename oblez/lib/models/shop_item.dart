import 'package:flutter/widgets.dart';

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

  /// أيقونة العنصر بالمتجر.
  final IconData icon;

  /// وصف مختصر لأثر العنصر (يظهر تحت الاسم بالمتجر).
  final String description;

  const ShopItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.tier,
    required this.icon,
    required this.description,
  });
}
