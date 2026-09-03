import 'package:flutter/material.dart';

/// شاشة فشل كوميدية — Placeholder، النص المخصص يجي لاحقاً من بنك النصوص.
class GameOverScreen extends StatelessWidget {
  final String reason;

  const GameOverScreen({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('انتهت اللعبة 💀', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 12),
            Text(reason),
          ],
        ),
      ),
    );
  }
}
