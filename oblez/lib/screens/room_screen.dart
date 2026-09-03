import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_state.dart';
import '../widgets/energy_bar.dart';
import '../widgets/stat_chip.dart';
import 'aim_trainer_screen.dart';
import 'game_over_screen.dart';
import 'shop_screen.dart';

/// شاشة الغرفة الرئيسية: مركز اللاعب بين الدوام والقيمنق.
/// MVP بلا تفاصيل بصرية معقدة — بس عرض حالة اللاعب وأزرار التنقل.
class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key});

  void _goTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _handleManagerCall(BuildContext context, PlayerState player) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اتصال من المدير 📞'),
        content: const Text('وين التقرير؟! رد بسرعة قبل لا يفوتك.'),
        actions: [
          TextButton(
            onPressed: () {
              player.ignoreManagerCall();
              Navigator.of(dialogContext).pop();
              if (player.isFired) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const GameOverScreen(
                      reason: 'فُصلت من الشغل بعد ثلاث اتصالات متجاهلة!',
                    ),
                  ),
                );
              }
            },
            child: const Text('تجاهل'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('حاضر'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('اليوم ${player.day} — الساعة ${player.hour}:00'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk),
            tooltip: 'محاكاة اتصال المدير',
            onPressed: () => _handleManagerCall(context, player),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatChip(icon: Icons.attach_money, value: '${player.money}'),
                StatChip(
                  icon: Icons.warning_amber,
                  value: '${player.missedManagerCalls}/3',
                ),
                StatChip(icon: Icons.wifi, value: 'شبكة ${player.networkLevel}'),
              ],
            ),
            const SizedBox(height: 24),
            EnergyBar(value: player.energy, label: 'الطاقة'),
            const Spacer(),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => _goTo(context, const AimTrainerScreen()),
                  icon: const Icon(Icons.gamepad),
                  label: const Text('العب Aim Trainer'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _goTo(context, const ShopScreen()),
                  icon: const Icon(Icons.storefront),
                  label: const Text('المتجر'),
                ),
                OutlinedButton.icon(
                  onPressed: () => player.sleep(),
                  icon: const Icon(Icons.bedtime),
                  label: const Text('نام بدري'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
