import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// F2 — tasks / groups / members with status filter (brief §16).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.groupId});
  final String? groupId;
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  final Set<TaskStatus> _status = {};
  SearchResults? _results;
  Timer? _debounce;

  void _run() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final api = ref.read(apiProvider);
      final r = await api.search(_q.text, groupId: widget.groupId, status: _status.isEmpty ? null : _status.toList());
      if (mounted) setState(() => _results = r);
    });
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = _results;
    return Scaffold(
      appBar: AppBar(
        title: TextField(controller: _q, autofocus: true, decoration: InputDecoration(hintText: s.searchHint, prefixIcon: const Icon(Icons.search_rounded), isDense: true), onChanged: (_) => _run()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final st in [TaskStatus.newTask, TaskStatus.inProgress, TaskStatus.awaitingApproval, TaskStatus.completed])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8, bottom: 8),
                    child: FilterChip(label: Text(s.status(st)), selected: _status.contains(st), onSelected: (v) { setState(() => v ? _status.add(st) : _status.remove(st)); _run(); }),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : (r.tasks.isEmpty && r.groups.isEmpty && r.members.isEmpty)
              ? EmptyState(icon: Icons.search_off_rounded, title: s.noResults)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    if (r.groups.isNotEmpty) ...[
                      SectionHeader(s.groups),
                      for (final g in r.groups) Card(child: ListTile(leading: GroupIcon(g.type), title: Text(g.name), onTap: () => context.push('/group/${g.id}'))),
                    ],
                    if (r.members.isNotEmpty) ...[
                      SectionHeader(s.membersTitle),
                      for (final m in r.members) Card(child: ListTile(leading: Avatar(name: m.user.displayName), title: Text(m.user.displayName), onTap: () => context.push('/group/${m.membership.groupId}/members'))),
                    ],
                    if (r.tasks.isNotEmpty) ...[
                      SectionHeader(s.tasks),
                      for (final t in r.tasks) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: t, showGroup: true, groupName: null)),
                    ],
                  ],
                ),
    );
  }
}
