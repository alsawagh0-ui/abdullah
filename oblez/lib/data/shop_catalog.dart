import '../models/shop_item.dart';

/// كتالوج عناصر متجر التطوير الثابت لمرحلة MVP.
/// كل فئة (عتاد/شبكة) مرتّبة بمستويات (tier) متتالية بدءاً من 0
/// (المستوى الافتراضي المجاني)، وفئة الفلكس عناصر مستقلة بلا مستويات.
class ShopCatalog {
  static const List<ShopItem> gear = [
    ShopItem(
      id: 'gear_basic',
      name: 'كرسي عادي',
      category: ShopCategory.gear,
      price: 0,
      tier: 0,
    ),
    ShopItem(
      id: 'gear_ergo',
      name: 'كرسي مريح',
      category: ShopCategory.gear,
      price: 150,
      tier: 1,
    ),
    ShopItem(
      id: 'gear_pro',
      name: 'كرسي قيمنق احترافي',
      category: ShopCategory.gear,
      price: 400,
      tier: 2,
    ),
  ];

  static const List<ShopItem> network = [
    ShopItem(
      id: 'net_home',
      name: 'راوتر منزلي ضعيف',
      category: ShopCategory.network,
      price: 0,
      tier: 0,
    ),
    ShopItem(
      id: 'net_upgraded',
      name: 'راوتر مطوّر',
      category: ShopCategory.network,
      price: 200,
      tier: 1,
    ),
    ShopItem(
      id: 'net_fiber',
      name: 'ألياف ضوئية',
      category: ShopCategory.network,
      price: 500,
      tier: 2,
    ),
    ShopItem(
      id: 'net_fiber_pro',
      name: 'ألياف ضوئية Pro',
      category: ShopCategory.network,
      price: 900,
      tier: 3,
    ),
  ];

  static const List<ShopItem> cosmetics = [
    ShopItem(
      id: 'cos_glasses',
      name: 'نظارة قيمنق',
      category: ShopCategory.cosmetic,
      price: 60,
      tier: 0,
    ),
    ShopItem(
      id: 'cos_headset',
      name: 'سماعة مميزة',
      category: ShopCategory.cosmetic,
      price: 90,
      tier: 0,
    ),
    ShopItem(
      id: 'cos_bg',
      name: 'خلفية غرفة نيون',
      category: ShopCategory.cosmetic,
      price: 120,
      tier: 0,
    ),
  ];
}
