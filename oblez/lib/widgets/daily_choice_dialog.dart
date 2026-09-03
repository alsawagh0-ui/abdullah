import 'package:flutter/material.dart';

import '../models/game_day.dart';

/// حوار القرار اليومي: خيار واحد بس بنهاية كل يوم، يحدد تنوّع اليوم التالي.
class DailyChoiceDialog extends StatelessWidget {
  final ValueChanged<DailyChoice> onChoice;

  const DailyChoiceDialog({super.key, required this.onChoice});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('قرار اليوم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('اختر شي واحد قبل ما تنام:'),
            const SizedBox(height: 16),
            _ChoiceButton(
              icon: Icons.leaderboard,
              label: 'رانك إضافي',
              subtitle: 'طاقة -15، نقاط رانك +25',
              onTap: () => onChoice(DailyChoice.extraRank),
            ),
            const SizedBox(height: 8),
            _ChoiceButton(
              icon: Icons.work,
              label: 'عمل إضافي',
              subtitle: 'فلوس +80، طاقة -20',
              onTap: () => onChoice(DailyChoice.extraWork),
            ),
            const SizedBox(height: 8),
            _ChoiceButton(
              icon: Icons.bedtime,
              label: 'نوم بدري',
              subtitle: 'يخفف إنذار واحد من سجلك',
              onTap: () => onChoice(DailyChoice.sleepEarly),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
