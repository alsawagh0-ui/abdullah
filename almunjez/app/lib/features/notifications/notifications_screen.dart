import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// F1 — inbox grouped by day, tap → deep link (doc 08 §8).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final api = ref.watch(apiProvider);
    final items = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.notifications), actions: [TextButton(onPressed: () => guard(context, api.markAllRead), child: Text(s.markAllRead))]),
      body: asyncBody(context, items, (list) {
        if (list.isEmpty) return EmptyState(icon: Icons.notifications_none_rounded, title: s.noNotifications);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final n = list[i];
            final showDay = i == 0 || f.dayHeader(list[i - 1].createdAt) != f.dayHeader(n.createdAt);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDay) SectionHeader(f.dayHeader(n.createdAt)),
                _Row(n),
              ],
            );
          },
        );
      }, onRetry: () => ref.invalidate(notificationsProvider)),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row(this.n);
  final AppNotification n;

  static IconData _icon(String type) => switch (type.split('.').first) {
        'join' => Icons.person_add_alt_1_rounded,
        'member' => Icons.people_rounded,
        'group' => Icons.groups_rounded,
        _ => switch (type) {
            'task.assigned' => Icons.assignment_ind_rounded,
            'task.claimed' => Icons.front_hand_rounded,
            'task.completed' || 'task.approved' => Icons.check_circle_rounded,
            'task.submitted' => Icons.hourglass_top_rounded,
            'task.rejected' => Icons.undo_rounded,
            'task.comment' => Icons.chat_bubble_outline_rounded,
            'task.due_soon' || 'task.overdue' => Icons.alarm_rounded,
            _ => Icons.task_alt_rounded,
          },
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final api = ref.watch(apiProvider);
    final actor = n.actorId == null ? null : ref.watch(userProvider(n.actorId!)).value?.displayName;
    final group = n.groupId == null ? null : ref.watch(groupProvider(n.groupId!)).value?.name;
    final title = s.notificationTitle(n.type, n.data, actor: actor, group: group);
    final danger = n.type == 'task.overdue' || n.type == 'task.rejected';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: n.isRead ? null : AppTheme.accent.withValues(alpha: 0.06),
        child: ListTile(
          leading: Icon(_icon(n.type), color: danger ? AppTheme.danger : AppTheme.accent),
          title: Text(title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700, fontSize: 14)),
          subtitle: Text(f.relative(n.createdAt), style: const TextStyle(fontSize: 12)),
          trailing: n.isRead ? null : Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
          onTap: () {
            api.markRead(n.id);
            if (n.taskId != null) {
              context.push('/task/${n.taskId}');
            } else if (n.type == 'join.requested' && n.groupId != null) {
              context.push('/group/${n.groupId}/requests');
            } else if (n.groupId != null) {
              context.push('/group/${n.groupId}');
            }
          },
        ),
      ),
    );
  }
}
