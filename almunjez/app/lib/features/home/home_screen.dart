import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// B1 — understand the workload in seconds (doc 02, brief §14).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final user = ref.watch(currentUserProvider).value;
    final today = ref.watch(myTasksProvider);
    final groups = ref.watch(myGroupsProvider);
    final pending = ref.watch(allPendingRequestsProvider).value ?? const <JoinRequest>[];
    final myRequests = ref.watch(myJoinRequestsProvider).value ?? const <JoinRequest>[];

    final rows = today.value ?? const <TodayRow>[];
    final newCount = rows.where((r) => r.task.status.name == 'newTask').length;
    final inProg = rows.where((r) => r.task.status.name == 'inProgress').length;
    final overdue = rows.where((r) => r.task.isOverdue).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.greeting(user?.displayName ?? '')),
        actions: [
          IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search_rounded)),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: GestureDetector(key: const Key('homeProfileAvatar'), onTap: () => context.push('/profile'), child: Avatar(name: user?.displayName ?? '', size: 34)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTasksProvider);
          ref.invalidate(myGroupsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            SectionHeader(s.today, trailing: TextButton(onPressed: () => context.go('/today'), child: Text(s.myTasks))),
            Row(
              children: [
                CountTile(label: s.newTasks, count: newCount, color: AppTheme.accent, onTap: () => context.go('/today')),
                const SizedBox(width: 8),
                CountTile(label: s.inProgress, count: inProg, color: AppTheme.progress, onTap: () => context.go('/today')),
                const SizedBox(width: 8),
                CountTile(label: s.overdue, count: overdue, color: AppTheme.danger, onTap: () => context.go('/today')),
              ],
            ),
            if (pending.isNotEmpty) ...[
              SectionHeader(s.pendingJoinRequests, color: AppTheme.warning),
              for (final r in pending.take(3)) _JoinRequestCard(r),
            ],
            if (myRequests.isNotEmpty) ...[
              SectionHeader(s.pendingApproval),
              for (final r in myRequests)
                Card(child: ListTile(leading: const Icon(Icons.hourglass_top_rounded, color: AppTheme.warning), title: Text(r.groupName ?? ''), subtitle: Text(s.requestSent))),
            ],
            if (rows.isNotEmpty) ...[
              SectionHeader(s.myTasks),
              for (final r in rows.take(4)) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: r.task, groupName: r.groupName, showGroup: true)),
            ],
            SectionHeader(s.myGroups, trailing: TextButton(onPressed: () => context.go('/groups'), child: Text(s.all))),
            asyncBody(context, groups, (gs) {
              if (gs.isEmpty) {
                return Column(
                  children: [
                    Card(child: ListTile(leading: const Icon(Icons.add_home_rounded, color: AppTheme.accent), title: Text(s.createFirstGroup), trailing: const Icon(Icons.chevron_left_rounded), onTap: () => context.push('/group/new'))),
                    const SizedBox(height: 8),
                    Card(child: ListTile(leading: const Icon(Icons.qr_code_rounded, color: AppTheme.accent), title: Text(s.haveCode), trailing: const Icon(Icons.chevron_left_rounded), onTap: () => context.push('/join'))),
                  ],
                );
              }
              return Column(children: [for (final g in gs) Padding(padding: const EdgeInsets.only(bottom: 8), child: _GroupRow(g, f))]);
            }, onRetry: () => ref.invalidate(myGroupsProvider)),
          ],
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow(this.g, this.f);
  final GroupSummary g;
  final Fmt f;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Card(
      child: ListTile(
        leading: GroupIcon(g.group.type),
        title: Text(g.group.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${s.openTasks}: ${f.num(g.openCount)} · ${s.mine}: ${f.num(g.mineCount)}', style: const TextStyle(fontSize: 12)),
        trailing: g.pendingRequests > 0 ? Badge(label: Text('${g.pendingRequests}'), backgroundColor: AppTheme.warning) : const Icon(Icons.chevron_left_rounded),
        onTap: () => context.push('/group/${g.group.id}'),
      ),
    );
  }
}

class _JoinRequestCard extends ConsumerWidget {
  const _JoinRequestCard(this.r);
  final JoinRequest r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Card(
      child: ListTile(
        leading: Avatar(name: r.user?.displayName ?? ''),
        title: Text('${r.user?.displayName ?? ''} · ${r.groupName ?? ''}'),
        subtitle: r.message == null ? null : Text(r.message!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.close_rounded, color: AppTheme.danger), onPressed: () => guard(context, () => api.decideJoin(r.id, accept: false))),
            IconButton.filled(icon: const Icon(Icons.check_rounded), onPressed: () => guard(context, () => api.decideJoin(r.id, accept: true))),
          ],
        ),
        onTap: () => context.push('/group/${r.groupId}/requests'),
      ),
    );
  }
}
