import 'package:flutter/material.dart';

/// شاشة متجر التطوير (عتاد/شبكة/فلكس) — Placeholder، تُبنى لاحقاً.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المتجر')),
      body: const Center(child: Text('قريباً 🛒')),
    );
  }
}
