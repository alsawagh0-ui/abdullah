import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// C3 — code + QR, regenerate, revoke (brief §2).
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final api = ref.watch(apiProvider);
    final group = ref.watch(groupProvider(groupId)).value;
    final code = ref.watch(inviteCodeProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: Text(s.inviteMembers), actions: [TextButton(onPressed: () => context.go('/group/$groupId'), child: Text(s.ok))]),
      body: asyncBody(context, code, (c) {
        final link = c == null ? null : '${AppConfig.joinLinkBase}$c';
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(group?.name ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(s.inviteHint, style: const TextStyle(color: AppTheme.muted), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (c == null)
              EmptyState(icon: Icons.link_off_rounded, title: s.invitesStopped, action: FilledButton(onPressed: () => guard(context, () => api.regenerateInvite(groupId)), child: Text(s.regenerateCode)))
            else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: QrImageView(data: link!, size: 220, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Text(s.inviteCode, style: const TextStyle(color: AppTheme.muted), textAlign: TextAlign.center),
              SelectableText(c, textDirection: TextDirection.ltr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 4, fontFamily: 'monospace')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.copyCode)));
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(s.copyCode),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Share.share(s.t('انضم إلى «${group?.name ?? ''}» في المنجز: $link\nالرمز: $c', 'Join "${group?.name ?? ''}" on AlMunjez: $link\nCode: $c')),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(s.share),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: () async {
                  if (await confirmDialog(context, title: s.regenerateCode, body: s.t('يتوقف الرمز الحالي فوراً.', 'The current code stops working immediately.'))) {
                    if (context.mounted) guard(context, () => api.regenerateInvite(groupId));
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(s.regenerateCode),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                onPressed: () async {
                  if (await confirmDialog(context, title: s.revokeInvites, destructive: true)) {
                    if (context.mounted) guard(context, () => api.revokeInvite(groupId));
                  }
                },
                icon: const Icon(Icons.link_off_rounded),
                label: Text(s.revokeInvites),
              ),
            ],
          ],
        );
      }, onRetry: () => ref.invalidate(inviteCodeProvider(groupId))),
    );
    }
}
