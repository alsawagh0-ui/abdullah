import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// G1 — name, photo, my numbers across groups (brief §11).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final api = ref.watch(apiProvider);
    final user = ref.watch(currentUserProvider).value;
    final groups = ref.watch(myGroupsProvider).value ?? const <GroupSummary>[];
    ref.watch(changeTickProvider);
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday % 7));
    final future = Future.wait([for (final g in groups) api.groupStats(g.group.id, from: weekStart, to: now)]);

    return Scaffold(
      appBar: AppBar(title: Text(s.profile), actions: [IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined))]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Avatar(name: user?.displayName ?? '', size: 96)),
          const SizedBox(height: 12),
          Center(child: Text(user?.displayName ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          SectionHeader(s.thisWeek),
          FutureBuilder<List<List<MemberStats>>>(
            future: future,
            builder: (context, snap) {
              var completed = 0, onTime = 0, late = 0, inProgress = 0, points = 0;
              for (final list in snap.data ?? const <List<MemberStats>>[]) {
                for (final m in list.where((m) => m.userId == user?.id)) {
                  completed += m.completed;
                  onTime += m.onTime;
                  late += m.late;
                  inProgress += m.inProgress;
                  points += m.points;
                }
              }
              return Column(
                children: [
                  Row(children: [
                    CountTile(label: s.completed, count: completed, color: AppTheme.success),
                    const SizedBox(width: 8),
                    CountTile(label: s.onTime, count: onTime, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    CountTile(label: s.late, count: late, color: AppTheme.danger),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    CountTile(label: s.inProgress, count: inProgress, color: AppTheme.progress),
                    const SizedBox(width: 8),
                    CountTile(label: s.points, count: points, color: AppTheme.warning),
                  ]),
                ],
              );
            },
          ),
          SectionHeader(s.myGroups),
          for (final g in groups)
            Card(child: ListTile(leading: GroupIcon(g.group.type), title: Text(g.group.name), subtitle: Text('${s.roleLabel(g.role)} · ${s.mine}: ${f.num(g.mineCount)}'), onTap: () => context.push('/group/${g.group.id}'))),
        ],
      ),
    );
  }
}
