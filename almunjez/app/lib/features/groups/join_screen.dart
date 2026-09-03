import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// C4 — code entry or QR scan → preview → request (brief §2: never auto-join).
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.initialCode});
  final String? initialCode;
  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  final _message = TextEditingController();
  InvitePreview? _preview;
  bool _sent = false;

  static String extractCode(String raw) {
    final t = raw.trim();
    final m = RegExp(r'/join/([A-Za-z0-9]{8})').firstMatch(t);
    return (m?.group(1) ?? t).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    if ((widget.initialCode ?? '').isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final api = ref.read(apiProvider);
    final p = await guard(context, () => api.previewInvite(extractCode(_code.text)));
    if (mounted) setState(() => _preview = p);
  }

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
    if (result != null && mounted) {
      _code.text = extractCode(result);
      _check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = ref.watch(apiProvider);
    final p = _preview;
    return Scaffold(
      appBar: AppBar(title: Text(s.joinGroup)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_sent)
            EmptyState(icon: Icons.hourglass_top_rounded, title: s.requestSent, body: p?.groupName, action: FilledButton(onPressed: () => context.go('/home'), child: Text(s.ok)))
          else ...[
            TextField(
              controller: _code,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 24, letterSpacing: 4, fontFamily: 'monospace'),
              decoration: InputDecoration(labelText: s.enterCode, hintText: 'ABCD2345'),
              onChanged: (_) => setState(() => _preview = null),
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner_rounded), label: Text(s.scanQr))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.tonal(onPressed: _code.text.trim().length < 8 ? null : _check, child: Text(s.checkCode))),
              ],
            ),
            if (p != null) ...[
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      GroupIcon(p.groupType, size: 64),
                      const SizedBox(height: 12),
                      Text(p.groupName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      Text('${s.groupTypeLabel(p.groupType)} · ${s.members(p.memberCount)}', style: const TextStyle(color: AppTheme.muted)),
                      const SizedBox(height: 16),
                      if (p.alreadyMember)
                        Text(s.alreadyMember, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700))
                      else if (p.pending)
                        Text(s.pendingApproval, style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700))
                      else ...[
                        TextField(controller: _message, decoration: InputDecoration(hintText: s.t('رسالة قصيرة للمالك (اختياري)', 'Short note to the owner (optional)')), maxLines: 2),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () async {
                            final r = await guard(context, () => api.requestJoin(extractCode(_code.text), message: _message.text.trim().isEmpty ? null : _message.text.trim()));
                            if (r != null && mounted) setState(() => _sent = true);
                          },
                          child: Text(s.requestJoin),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();
  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(S.of(context).scanQr)),
        body: MobileScanner(
          onDetect: (capture) {
            if (_done) return;
            final v = capture.barcodes.firstOrNull?.rawValue;
            if (v == null) return;
            _done = true;
            Navigator.of(context).pop(v);
          },
        ),
      );
}
