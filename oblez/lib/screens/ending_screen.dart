import 'package:flutter/material.dart';

import 'room_screen.dart';

/// شاشة الفوز: اللاعب اشترى عقاره الخاص = بنق مستقر 0ms، نهاية القصة.
class EndingScreen extends StatelessWidget {
  const EndingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'مبروك! اشتريت عقارك الخاص',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'بنق مستقر 0ms، ولا سهر يهدد الدوام، ولا مدير يتصل...\n'
                'من قيمر يعاني من راوتر البيت، لبطل EWC بعقاره الخاص. 🎮🏠',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoomScreen()),
                  (route) => false,
                ),
                child: const Text('رجوع للغرفة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
