import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// G3 — one switch per category, not per event type (brief §7: avoid spam,
/// keep cognitive load low). Each switch fans out to every type it covers.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const _categories = <(String label, String hintKey, List<String> types)>[
    (
      'tasks',
      'tasksHint',
      [
        'task.created', 'task.assigned', 'task.claimed', 'task.released', 'task.completed',
        'task.submitted', 'task.approved', 'task.rejected', 'task.reassigned', 'task.unassigned', 'task.cancelled',
      ],
    ),
    ('deadlines', 'deadlinesHint', ['task.due_soon', 'task.overdue']),
    (
      'groups',
      'groupsHint',
      ['join.requested', 'join.accepted', 'join.rejected', 'member.removed', 'member.role_changed', 'group.ownership_transferred'],
    ),
    ('comments', 'commentsHint', ['task.comment']),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final api = ref.watch(apiProvider);
    final prefs = ref.watch(notificationPreferencesProvider);

    (String, String) labels(String key) => switch (key) {
          'tasks' => (s.notifCatTasks, s.notifCatTasksHint),
          'deadlines' => (s.notifCatDeadlines, s.notifCatDeadlinesHint),
          'groups' => (s.notifCatGroups, s.notifCatGroupsHint),
          _ => (s.notifCatComments, s.notifCatCommentsHint),
        };

    return Scaffold(
      appBar: AppBar(title: Text(s.notificationSettingsTitle)),
      body: asyncBody(context, prefs, (Map<String, NotifPref> map) {
        bool enabledFor(List<String> types) => types.every((t) => map[t]?.push ?? true);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (key, _, types) in _categories)
              Builder(builder: (context) {
                final (label, hint) = labels(key);
                return SwitchListTile(
                  value: enabledFor(types),
                  onChanged: (v) => guard(context, () async {
                    for (final t in types) {
                      await api.setNotificationPreference(t, push: v);
                    }
                  }),
                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(hint, style: const TextStyle(fontSize: 12)),
                  contentPadding: EdgeInsets.zero,
                );
              }),
          ],
        );
      }, onRetry: () => ref.invalidate(notificationPreferencesProvider)),
    );
  }
}
