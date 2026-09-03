import 'package:flutter/material.dart';

/// شريحة صغيرة لعرض إحصائية (فلوس، يوم، إنذارات...) مع أيقونة.
class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const StatChip({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(value),
        ],
      ),
    );
  }
}
