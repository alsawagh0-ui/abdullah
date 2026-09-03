import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// C10 — contribution numbers honouring the visibility setting (brief §11, §12).
class GroupStatsScreen extends ConsumerStatefulWidget {
  const GroupStatsScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupStatsScreen> createState() => _GroupStatsScreenState();
}

class _GroupStatsScreenState extends ConsumerState<GroupStatsScreen> {
  bool _month = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final api = ref.watch(apiProvider);
    final group = ref.watch(groupProvider(widget.groupId)).value;
    final now = DateTime.now();
    final from = _month ? DateTime(now.year, now.month, 1) : now.subtract(Duration(days: (now.weekday % 7)));
    ref.watch(changeTickProvider);
    final future = api.groupStats(widget.groupId, from: DateTime(from.year, from.month, from.day), to: now);
    final gamified = group?.settings.gamificationEnabled ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(s.stats)),
      body: FutureBuilder<List<MemberStats>>(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<bool>(
                segments: [ButtonSegment(value: false, label: Text(s.thisWeek)), ButtonSegment(value: true, label: Text(s.thisMonth))],
                selected: {_month},
                onSelectionChanged: (v) => setState(() => _month = v.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              if (list.length == 1 && (group?.memberCount ?? 0) > 1)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(s.onlyYourStats, style: const TextStyle(color: AppTheme.muted, fontSize: 12))),
              for (final (i, m) in list.indexed)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (gamified) SizedBox(width: 28, child: Text(f.num(i + 1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.muted))),
                        Avatar(name: m.displayName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              Text('${s.completed} ${f.num(m.completed)} · ${s.onTime} ${f.num(m.onTime)} · ${s.late} ${f.num(m.late)} · ${s.inProgress} ${f.num(m.inProgress)}', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                            ],
                          ),
                        ),
                        if (gamified) Text(f.num(m.points), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
