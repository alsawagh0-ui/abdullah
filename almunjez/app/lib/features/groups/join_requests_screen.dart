import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// C6
class JoinRequestsScreen extends ConsumerWidget {
  const JoinRequestsScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final api = ref.watch(apiProvider);
    final reqs = ref.watch(pendingRequestsProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: Text(s.joinRequests)),
      body: asyncBody(context, reqs, (list) {
        if (list.isEmpty) return EmptyState(icon: Icons.person_add_disabled_outlined, title: s.noRequests);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final r = list[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Avatar(name: r.user?.displayName ?? '', size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.user?.displayName ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              Text(f.relative(r.createdAt), style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (r.message != null) ...[const SizedBox(height: 8), Text(r.message!)],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, minimumSize: const Size.fromHeight(44)), onPressed: () => guard(context, () => api.decideJoin(r.id, accept: false)), child: Text(s.reject))),
                        const SizedBox(width: 8),
                        Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)), onPressed: () => guard(context, () => api.decideJoin(r.id, accept: true)), child: Text(s.accept))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }, onRetry: () => ref.invalidate(pendingRequestsProvider(groupId))),
    );
  }
}
