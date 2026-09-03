import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/comedy_lines.dart';
import '../logic/manager_call_scheduler.dart';
import '../logic/progression_logic.dart';
import '../models/player_state.dart';
import '../widgets/daily_choice_dialog.dart';
import '../widgets/energy_bar.dart';
import '../widgets/manager_call_dialog.dart';
import '../widgets/stat_chip.dart';
import 'aim_trainer_screen.dart';
import 'game_over_screen.dart';
import 'shop_screen.dart';

/// شاشة الغرفة الرئيسية: مركز اللاعب بين الدوام والقيمنق.
/// تدير نظام اتصالات المدير العشوائية طول ما اللاعب موجود بهالشاشة.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  /// كل نبضة زمنية بالواقع = ساعة وحدة داخل اللعبة.
  static const _hourTickInterval = Duration(seconds: 12);

  final _scheduler = ManagerCallScheduler();
  final _random = Random();
  bool _callActive = false;
  Timer? _hourTimer;

  @override
  void initState() {
    super.initState();
    _scheduler.scheduleNext(_triggerIncomingCall);
    _hourTimer = Timer.periodic(_hourTickInterval, (_) {
      if (!mounted) return;
      context.read<PlayerState>().tickHour();
    });
  }

  @override
  void dispose() {
    _scheduler.cancel();
    _hourTimer?.cancel();
    super.dispose();
  }

  void _triggerIncomingCall() {
    if (!mounted || _callActive) return;
    setState(() => _callActive = true);

    final message = ComedyLines
        .managerCalls[_random.nextInt(ComedyLines.managerCalls.length)];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ManagerCallDialog(
        message: message,
        onAnswered: () => _resolveCall(dialogContext, ignored: false),
        onTimeout: () => _resolveCall(dialogContext, ignored: true),
      ),
    );
  }

  void _resolveCall(BuildContext dialogContext, {required bool ignored}) {
    Navigator.of(dialogContext).pop();
    if (!mounted) return;

    final player = context.read<PlayerState>();
    setState(() => _callActive = false);

    if (ignored) {
      player.ignoreManagerCall();
      if (player.isFired) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const GameOverScreen(
              reason: 'فُصلت من الشغل بعد ثلاث اتصالات متجاهلة!',
            ),
          ),
        );
        return;
      }
    }

    _scheduler.scheduleNext(_triggerIncomingCall);
  }

  void _goTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _endDay(BuildContext context) {
    final player = context.read<PlayerState>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => DailyChoiceDialog(
        onChoice: (choice) {
          Navigator.of(dialogContext).pop();
          player.applyDailyChoice(choice);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('اليوم ${player.day} — الساعة ${player.hour}:00'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                StatChip(icon: Icons.attach_money, value: '${player.money}'),
                StatChip(
                  icon: Icons.warning_amber,
                  value: '${player.missedManagerCalls}/3',
                ),
                StatChip(
                  icon: Icons.wifi,
                  value: 'شبكة ${player.networkLevel}',
                ),
                StatChip(
                  icon: Icons.military_tech,
                  value: '${player.rankPoints}',
                ),
                StatChip(
                  icon: Icons.trending_up,
                  value: ProgressionLogic.labelFor(player.tier),
                ),
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
                  onPressed: () => _endDay(context),
                  icon: const Icon(Icons.bedtime),
                  label: const Text('إنهاء اليوم'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
