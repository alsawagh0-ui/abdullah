import 'package:flutter/material.dart';

/// شريط تقدّم بسيط لعرض الطاقة (أو أي قيمة 0-100) بلون يتغيّر حسب الحالة.
class EnergyBar extends StatelessWidget {
  final int value;
  final String label;

  const EnergyBar({super.key, required this.value, required this.label});

  Color _colorFor(int value) {
    if (value <= 30) return Colors.redAccent;
    if (value <= 60) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Text('$value%'),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 10,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation(_colorFor(value)),
          ),
        ),
      ],
    );
  }
}
