import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// C8 — immutable timeline (brief §13).
class GroupActivityScreen extends ConsumerWidget {
  const GroupActivityScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final events = ref.watch(groupActivityProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: Text(s.activityLog)),
      body: asyncBody(context, events, (list) {
        if (list.isEmpty) return EmptyState(icon: Icons.history_rounded, title: s.noResults);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) => ActivityRow(list[i], showDay: i == 0 || !_sameDay(list[i - 1].createdAt, list[i].createdAt)),
        );
      }, onRetry: () => ref.invalidate(groupActivityProvider(groupId))),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class ActivityRow extends ConsumerWidget {
  const ActivityRow(this.e, {super.key, this.showDay = false, this.title});
  final ActivityEvent e;
  final bool showDay;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final actor = e.actor?.displayName ?? (e.actorId == null ? s.t('النظام', 'System') : (ref.watch(userProvider(e.actorId!)).value?.displayName ?? '…'));
    final task = e.targetType == 'task' && e.targetId != null && title == null ? ref.watch(taskProvider(e.targetId!)).value : null;
    final line = s.activityLine(e.action, e.metadata, actor: actor, target: title ?? task?.title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDay) Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 6), child: Text(f.dayHeader(e.createdAt), style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.muted))),
        InkWell(
          onTap: e.targetType == 'task' && e.targetId != null ? () => context.push('/task/${e.targetId}') : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 56, child: Text(f.time(e.createdAt), style: const TextStyle(fontSize: 12, color: AppTheme.muted))),
                Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(line, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
