import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_state.dart';
import 'room_screen.dart';

/// نوع نهاية اللعبة — يحدد الأيقونة والألوان والعنوان بشاشة الفشل.
enum GameOverKind { fired, kickedFromTeam }

/// شاشة فشل كوميدية: أيقونة وألوان تتغيّر حسب سبب الفشل، نص عشوائي من
/// بنك النصوص، وملخص إحصائيات الجولة، مع زر "من جديد" يصفّر التقدم.
class GameOverScreen extends StatelessWidget {
  final String reason;
  final GameOverKind kind;

  const GameOverScreen({
    super.key,
    required this.reason,
    this.kind = GameOverKind.fired,
  });

  _GameOverStyle get _style {
    switch (kind) {
      case GameOverKind.fired:
        return const _GameOverStyle(
          icon: Icons.work_off_rounded,
          accent: Colors.orangeAccent,
          title: 'انفصلت عن الشغل! 💼💥',
        );
      case GameOverKind.kickedFromTeam:
        return const _GameOverStyle(
          icon: Icons.groups_rounded,
          accent: Colors.purpleAccent,
          title: 'طردوك من الفريق! 🎮💔',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerState>();
    final style = _style;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.3,
            colors: [
              style.accent.withOpacity(0.25),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: style.accent.withOpacity(0.15),
                      border: Border.all(color: style.accent, width: 3),
                    ),
                    child: Icon(style.icon, size: 54, color: style.accent),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  style.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
                _StatsSummary(player: player, accent: style.accent),
                const SizedBox(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: style.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () {
                    player.resetGame();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const RoomScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('من جديد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameOverStyle {
  final IconData icon;
  final Color accent;
  final String title;

  const _GameOverStyle({
    required this.icon,
    required this.accent,
    required this.title,
  });
}

/// ملخص إحصائيات الجولة اللي انتهت: اليوم اللي وصله، الفلوس، ونقاط الرانك.
class _StatsSummary extends StatelessWidget {
  final PlayerState player;
  final Color accent;

  const _StatsSummary({required this.player, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatTile(
          icon: Icons.calendar_today,
          label: 'وصلت لليوم',
          value: '${player.day}',
          accent: accent,
        ),
        _StatTile(
          icon: Icons.attach_money,
          label: 'الفلوس',
          value: '${player.money}',
          accent: accent,
        ),
        _StatTile(
          icon: Icons.military_tech,
          label: 'نقاط الرانك',
          value: '${player.rankPoints}',
          accent: accent,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
