import 'dart:async';
import 'package:flutter/material.dart';

/// نافذة اتصال المدير: تعد تنازلياً، ولازم اللاعب يضغط "حاضر!" قبل
/// ما ينتهي الوقت — وإلا يُحسب الاتصال متجاهل.
class ManagerCallDialog extends StatefulWidget {
  final String message;
  final int responseSeconds;
  final VoidCallback onAnswered;
  final VoidCallback onTimeout;

  const ManagerCallDialog({
    super.key,
    required this.message,
    required this.onAnswered,
    required this.onTimeout,
    this.responseSeconds = 5,
  });

  @override
  State<ManagerCallDialog> createState() => _ManagerCallDialogState();
}

class _ManagerCallDialogState extends State<ManagerCallDialog> {
  late int _remaining = widget.responseSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    if (_remaining <= 1) {
      timer.cancel();
      widget.onTimeout();
      return;
    }
    setState(() => _remaining -= 1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('اتصال من المدير 📞'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            Text(
              '$_remaining ثانية...',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              _timer?.cancel();
              widget.onAnswered();
            },
            child: const Text('حاضر!'),
          ),
        ],
      ),
    );
  }
}
