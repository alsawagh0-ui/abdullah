import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// C1
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final groups = ref.watch(myGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.groups),
        actions: [
          IconButton(tooltip: s.joinGroup, onPressed: () => context.push('/join'), icon: const Icon(Icons.qr_code_scanner_rounded)),
          IconButton(tooltip: s.createGroup, onPressed: () => context.push('/group/new'), icon: const Icon(Icons.add_circle_outline_rounded)),
        ],
      ),
      body: asyncBody(context, groups, (gs) {
        if (gs.isEmpty) {
          return EmptyState(
            icon: Icons.groups_outlined,
            title: s.createFirstGroup,
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(onPressed: () => context.push('/group/new'), child: Text(s.createGroup)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => context.push('/join'), child: Text(s.joinGroup)),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            for (final g in gs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: GroupIcon(g.group.type, size: 46),
                    title: Text(g.group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    subtitle: Text('${s.groupTypeLabel(g.group.type)} · ${s.members(g.group.memberCount)} · ${s.roleLabel(g.role)}${g.group.isArchived ? ' · ${s.archived}' : ''}', style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (g.pendingRequests > 0) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Badge(label: Text('${g.pendingRequests}'), backgroundColor: AppTheme.warning)),
                        if (g.openCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                            child: Text('${f.num(g.openCount)} ${s.openTasks}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                          ),
                        const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
                      ],
                    ),
                    onTap: () => context.push('/group/${g.group.id}'),
                  ),
                ),
              ),
          ],
        );
      }, onRetry: () => ref.invalidate(myGroupsProvider)),
    );
  }
}
