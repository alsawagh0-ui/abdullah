import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

enum _Filter { all, newTask, inProgress, completed, mine, overdue }

/// C5 — counts, filters, list (brief §15).
class GroupDashboardScreen extends ConsumerStatefulWidget {
  const GroupDashboardScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends ConsumerState<GroupDashboardScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final id = widget.groupId;
    final group = ref.watch(groupProvider(id));
    final tasks = ref.watch(groupTasksProvider(id));
    final counts = ref.watch(dashboardCountsProvider(id)).value ?? const DashboardCounts();
    final perms = ref.watch(permissionsProvider(id)).value;
    final me = ref.watch(currentUserProvider).value;
    final pendingCount = ref.watch(myGroupsProvider).value?.where((g) => g.group.id == id).firstOrNull?.pendingRequests ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.value?.name ?? ''),
        actions: [
          IconButton(onPressed: () => context.push('/search?group=$id'), icon: const Icon(Icons.search_rounded)),
          if (can(perms, Perm.approveJoins))
            IconButton(
              tooltip: s.joinRequests,
              onPressed: () => context.push('/group/$id/requests'),
              icon: Badge(isLabelVisible: pendingCount > 0, label: Text('$pendingCount'), child: const Icon(Icons.person_add_alt_1_outlined)),
            ),
          PopupMenuButton<String>(
            onSelected: (v) => context.push('/group/$id/$v'),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'members', child: ListTile(leading: const Icon(Icons.people_outline), title: Text(s.membersTitle))),
              if (can(perms, Perm.manageInvite)) PopupMenuItem(value: 'invite', child: ListTile(leading: const Icon(Icons.qr_code_rounded), title: Text(s.inviteMembers))),
              if (can(perms, Perm.activityView)) PopupMenuItem(value: 'activity', child: ListTile(leading: const Icon(Icons.history_rounded), title: Text(s.activityLog))),
              PopupMenuItem(value: 'stats', child: ListTile(leading: const Icon(Icons.insights_rounded), title: Text(s.stats))),
              PopupMenuItem(value: 'settings', child: ListTile(leading: const Icon(Icons.settings_outlined), title: Text(s.groupSettings))),
            ],
          ),
        ],
      ),
      floatingActionButton: can(perms, Perm.taskCreate) && !(group.value?.isArchived ?? false)
          ? FloatingActionButton.extended(onPressed: () => context.push('/task/new?group=$id'), icon: const Icon(Icons.add_rounded), label: Text(s.newTask))
          : null,
      body: asyncBody(context, tasks, (list) {
        final filtered = list.where((t) => switch (_filter) {
              _Filter.all => t.status != TaskStatus.cancelled,
              _Filter.newTask => t.status == TaskStatus.newTask,
              _Filter.inProgress => t.status == TaskStatus.inProgress || t.status == TaskStatus.awaitingApproval,
              _Filter.completed => t.status == TaskStatus.completed,
              _Filter.mine => t.assigneeId == me?.id || t.participantIds.contains(me?.id),
              _Filter.overdue => t.isOverdue,
            }).toList();
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupTasksProvider(id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              if (group.value?.isArchived ?? false)
                Card(color: AppTheme.muted.withValues(alpha: 0.1), child: ListTile(leading: const Icon(Icons.archive_outlined), title: Text(s.archived))),
              const SizedBox(height: 8),
              Row(
                children: [
                  CountTile(label: s.openTasks, count: counts.newCount, color: AppTheme.accent, onTap: () => setState(() => _filter = _Filter.newTask)),
                  const SizedBox(width: 8),
                  CountTile(label: s.inProgress, count: counts.inProgress + counts.awaiting, color: AppTheme.progress, onTap: () => setState(() => _filter = _Filter.inProgress)),
                  const SizedBox(width: 8),
                  CountTile(label: s.completed, count: counts.completed, color: AppTheme.success, onTap: () => setState(() => _filter = _Filter.completed)),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _Filter.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(switch (f) {
                            _Filter.all => s.all,
                            _Filter.newTask => s.newTasks,
                            _Filter.inProgress => s.inProgress,
                            _Filter.completed => s.completed,
                            _Filter.mine => s.mine,
                            _Filter.overdue => s.overdue,
                          }),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                EmptyState(icon: Icons.inbox_outlined, title: s.noTasksHere, body: list.isEmpty ? s.noTasksHereBody : null)
              else
                for (final t in filtered) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: t)),
            ],
          ),
        );
      }, onRetry: () => ref.invalidate(groupTasksProvider(id))),
    );
  }
}
