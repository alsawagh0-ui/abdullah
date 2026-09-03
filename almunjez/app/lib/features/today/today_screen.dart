import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// B2 / E1 — the unified "what do I have to do" view (brief §10).
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.myTasks),
        actions: [IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search_rounded))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<int>(
              segments: [ButtonSegment(value: 0, label: Text(s.today)), ButtonSegment(value: 1, label: Text(s.personal))],
              selected: {_segment},
              onSelectionChanged: (v) => setState(() => _segment = v.first),
              showSelectedIcon: false,
            ),
          ),
        ),
      ),
      body: _segment == 0 ? const _TodayList() : const _PersonalList(),
    );
  }
}

class _TodayList extends ConsumerWidget {
  const _TodayList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final rows = ref.watch(myTasksProvider);
    return asyncBody(context, rows, (list) {
      if (list.isEmpty) return EmptyState(icon: Icons.self_improvement_rounded, title: s.nothingToday, body: s.nothingTodayBody);
      final sections = <String, List<TodayRow>>{};
      for (final r in list) {
        sections.putIfAbsent(r.section, () => []).add(r);
      }
      final order = ['overdue', 'today', 'no_date', 'upcoming'];
      final labels = {'overdue': s.overdue, 'today': s.today, 'no_date': s.noDate, 'upcoming': s.upcoming};
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTasksProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            for (final k in order)
              if (sections[k]?.isNotEmpty ?? false) ...[
                SectionHeader(labels[k]!, color: k == 'overdue' ? AppTheme.danger : null),
                for (final r in sections[k]!) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: r.task, groupName: r.groupName, showGroup: true)),
              ],
          ],
        ),
      );
    }, onRetry: () => ref.invalidate(myTasksProvider));
  }
}

class _PersonalList extends ConsumerWidget {
  const _PersonalList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final tasks = ref.watch(personalTasksProvider);
    return asyncBody(context, tasks, (list) {
      final open = list.where((t) => !t.status.isTerminal).toList();
      final done = list.where((t) => t.status.isTerminal).toList();
      if (list.isEmpty) {
        return EmptyState(
          icon: Icons.lock_outline_rounded,
          title: s.noPersonalTasks,
          action: FilledButton.tonal(onPressed: () => context.push('/task/new?personal=1'), child: Text(s.newTask)),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final t in open) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: t)),
          if (done.isNotEmpty) SectionHeader(s.completed),
          for (final t in done) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: t)),
        ],
      );
    }, onRetry: () => ref.invalidate(personalTasksProvider));
  }
}
