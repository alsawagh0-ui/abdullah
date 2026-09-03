import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/shop_catalog.dart';
import '../logic/progression_logic.dart';
import '../models/player_state.dart';
import '../models/shop_item.dart';
import 'ending_screen.dart';

/// متجر التطوير: عتاد وشبكة (مسارات مستويات) + فلكس (عناصر تجميلية مستقلة)
/// + تبويب الهدف النهائي (العقار).
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

/// لون مميّز لكل فئة — يُستخدم بالأيقونات وأشرطة التقدم والأزرار.
Color _accentFor(ShopCategory category) {
  switch (category) {
    case ShopCategory.gear:
      return Colors.orangeAccent;
    case ShopCategory.network:
      return Colors.cyanAccent;
    case ShopCategory.cosmetic:
      return Colors.pinkAccent;
  }
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  void _handlePropertyPurchase(PlayerState player) {
    if (!player.buyProperty()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لازم توصل لمرحلة "المحترف" وتوفر السعر كامل.'),
        ),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EndingScreen()),
      (route) => false,
    );
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
            Tab(text: 'الهدف النهائي'),
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
          _PropertyTab(
            player: player,
            onBuy: () => _handlePropertyPurchase(player),
          ),
        ],
      ),
    );
  }
}

/// شارة حالة صغيرة (مملوك/قابل للشراء/مقفل) بلون خلفية شفاف.
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// أيقونة العنصر بدائرة ملوّنة — رمادية لو مقفل، بلون الفئة لو مفعّل.
class _ItemAvatar extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final bool active;

  const _ItemAvatar({
    required this.icon,
    required this.accent,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Colors.white38;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

/// قائمة عناصر مسار مُدرّج (عتاد/شبكة): مستوى واحد أعلى من الحالي فقط قابل
/// للشراء، مع شريط تقدّم أعلى القائمة يبيّن المستوى الحالي من الإجمالي.
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
    final accent = _accentFor(items.first.category);
    final maxTier = items.last.tier;
    final progress = maxTier == 0 ? 1.0 : currentTier / maxTier;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('التقدّم بالمسار', style: TextStyle(color: Colors.white70)),
            Text(
              'المستوى $currentTier من $maxTier',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
        const SizedBox(height: 20),
        for (final item in items) ...[
          _LeveledItemCard(
            item: item,
            accent: accent,
            currentTier: currentTier,
            onBuy: () => onBuy(item),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LeveledItemCard extends StatelessWidget {
  final ShopItem item;
  final Color accent;
  final int currentTier;
  final VoidCallback onBuy;

  const _LeveledItemCard({
    required this.item,
    required this.accent,
    required this.currentTier,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final owned = item.tier <= currentTier;
    final buyable = item.tier == currentTier + 1;

    return Card(
      color: owned ? accent.withOpacity(0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: owned ? accent.withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _ItemAvatar(icon: item.icon, accent: accent, active: owned || buyable),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  _StatusChip(
                    label: owned
                        ? 'مملوك حالياً'
                        : buyable
                            ? '\$${item.price}'
                            : 'يحتاج الترقية السابقة',
                    color: owned ? Colors.greenAccent : (buyable ? accent : Colors.white38),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (owned)
              const Icon(Icons.check_circle, color: Colors.greenAccent)
            else
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                onPressed: buyable ? onBuy : null,
                child: const Text('شراء'),
              ),
          ],
        ),
      ),
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
    final accent = _accentFor(ShopCategory.cosmetic);
    final ownedCount = items.where((item) => ownedIds.contains(item.id)).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('عناصر الفلكس', style: TextStyle(color: Colors.white70)),
            Text(
              'مملوك $ownedCount من ${items.length}',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'مظهر فقط — بلا أي تأثير على الطاقة أو البنق أو الفلوس.',
          style: TextStyle(fontSize: 12, color: Colors.white54),
        ),
        const SizedBox(height: 16),
        for (final item in items) ...[
          _CosmeticItemCard(
            item: item,
            accent: accent,
            owned: ownedIds.contains(item.id),
            onBuy: () => onBuy(item),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CosmeticItemCard extends StatelessWidget {
  final ShopItem item;
  final Color accent;
  final bool owned;
  final VoidCallback onBuy;

  const _CosmeticItemCard({
    required this.item,
    required this.accent,
    required this.owned,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: owned ? accent.withOpacity(0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: owned ? accent.withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _ItemAvatar(icon: item.icon, accent: accent, active: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  _StatusChip(
                    label: owned ? 'مملوك' : '\$${item.price}',
                    color: owned ? Colors.greenAccent : accent,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (owned)
              const Icon(Icons.check_circle, color: Colors.greenAccent)
            else
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                onPressed: onBuy,
                child: const Text('شراء'),
              ),
          ],
        ),
      ),
    );
  }
}

/// تبويب الهدف النهائي: شراء عقار = شاشة الفوز، يتطلب الوصول لمرحلة "المحترف".
class _PropertyTab extends StatelessWidget {
  final PlayerState player;
  final VoidCallback onBuy;

  const _PropertyTab({required this.player, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    const accent = Colors.amberAccent;
    final eligible = player.canBuyProperty;
    final moneyProgress =
        (player.money / PlayerState.propertyPrice).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [Color(0x33FFD54F), Colors.transparent],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.15),
                  border: Border.all(color: accent, width: 3),
                ),
                child: const Icon(Icons.home_rounded, size: 46, color: accent),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'عقار في مدينة عربية كبرى',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'الهدف النهائي: بنق مستقر 0ms واستقرار تام. '
              'يتطلب الوصول لمرحلة "المحترف" (ترقية عتاد وشبكة عاليتين + نقاط رانك كافية).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('مرحلتك الحالية', style: TextStyle(color: Colors.white70)),
                      _StatusChip(
                        label: ProgressionLogic.labelFor(player.tier),
                        color: player.tier == ProgressionTier.pro ? Colors.greenAccent : accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الفلوس', style: TextStyle(color: Colors.white70)),
                      Text(
                        '\$${player.money} / \$${PlayerState.propertyPrice}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: moneyProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              onPressed: eligible ? onBuy : null,
              icon: const Icon(Icons.vpn_key),
              label: Text(eligible ? 'اشترِ العقار 🏆' : 'لسا ما توصلت لمرحلة المحترف'),
            ),
          ],
        ),
      ),
    );
  }
}
