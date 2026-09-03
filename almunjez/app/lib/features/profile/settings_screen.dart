import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/local/local_api.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// G2 — language, sign out, account deletion (App Store 5.1.1(v)).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final api = ref.watch(apiProvider);
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.language, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
            selected: {user?.locale ?? 'ar'},
            onSelectionChanged: (v) => guard(context, () => api.completeProfile(displayName: user?.displayName ?? '', locale: v.first)),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(s.notificationSettingsTitle),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => context.push('/settings/notifications'),
            ),
          ),
          const SizedBox(height: 8),
          if (api is LocalApi) Card(child: ListTile(leading: const Icon(Icons.phonelink_off_rounded), title: Text(s.offlineMode, style: const TextStyle(fontSize: 13)))),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await guard(context, api.signOut);
              if (context.mounted) context.go('/welcome');
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(s.signOut),
          ),
          const SizedBox(height: 32),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: () async {
              if (await confirmDialog(context, title: s.deleteAccount, body: s.deleteAccountBody, confirmLabel: s.delete, destructive: true)) {
                if (context.mounted) {
                  final ok = await guardOk(context, api.deleteAccount);
                  if (ok && context.mounted) context.go('/welcome');
                }
              }
            },
            child: Text(s.deleteAccount),
          ),
        ],
      ),
    );
  }
}
