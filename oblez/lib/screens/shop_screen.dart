import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/shop_catalog.dart';
import '../models/player_state.dart';
import '../models/shop_item.dart';

/// متجر التطوير: عتاد وشبكة (مسارات مستويات) + فلكس (عناصر تجميلية مستقلة).
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handlePurchase(bool success) {
    final message =
        success ? 'تم الشراء! 🎉' : 'ما تكفي فلوسك، أو لازم تكمل الترقية اللي قبلها أول.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('المتجر — \$${player.money}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'عتاد'),
            Tab(text: 'شبكة'),
            Tab(text: 'فلكس'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LeveledCategoryList(
            items: ShopCatalog.gear,
            currentTier: player.gearLevel,
            onBuy: (item) => _handlePurchase(player.buyGearUpgrade(item)),
          ),
          _LeveledCategoryList(
            items: ShopCatalog.network,
            currentTier: player.networkLevel,
            onBuy: (item) => _handlePurchase(player.buyNetworkUpgrade(item)),
          ),
          _CosmeticCategoryList(
            items: ShopCatalog.cosmetics,
            ownedIds: player.ownedCosmetics,
            onBuy: (item) => _handlePurchase(player.buyCosmetic(item)),
          ),
        ],
      ),
    );
  }
}

/// قائمة عناصر مسار مُدرّج (عتاد/شبكة): مستوى واحد أعلى من الحالي فقط قابل للشراء.
class _LeveledCategoryList extends StatelessWidget {
  final List<ShopItem> items;
  final int currentTier;
  final ValueChanged<ShopItem> onBuy;

  const _LeveledCategoryList({
    required this.items,
    required this.currentTier,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final owned = item.tier <= currentTier;
        final buyable = item.tier == currentTier + 1;

        return Card(
          child: ListTile(
            title: Text(item.name),
            subtitle: Text(
              owned
                  ? 'مملوك حالياً'
                  : buyable
                      ? '\$${item.price}'
                      : 'يحتاج الترقية السابقة أول',
            ),
            trailing: owned
                ? const Icon(Icons.check_circle, color: Colors.green)
                : FilledButton(
                    onPressed: buyable ? () => onBuy(item) : null,
                    child: const Text('شراء'),
                  ),
          ),
        );
      },
    );
  }
}

/// قائمة عناصر الفلكس: كل عنصر مستقل، تُشترى مرة وحدة بلا مستويات.
class _CosmeticCategoryList extends StatelessWidget {
  final List<ShopItem> items;
  final Set<String> ownedIds;
  final ValueChanged<ShopItem> onBuy;

  const _CosmeticCategoryList({
    required this.items,
    required this.ownedIds,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final owned = ownedIds.contains(item.id);

        return Card(
          child: ListTile(
            title: Text(item.name),
            subtitle: Text(owned ? 'مملوك' : '\$${item.price}'),
            trailing: owned
                ? const Icon(Icons.check_circle, color: Colors.green)
                : FilledButton(
                    onPressed: () => onBuy(item),
                    child: const Text('شراء'),
                  ),
          ),
        );
      },
    );
  }
}
