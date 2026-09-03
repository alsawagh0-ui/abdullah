import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// C9
class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  final _name = TextEditingController();
  GroupType? _type;
  GroupSettings? _settings;
  bool _loaded = false;

  void _init(Group g) {
    if (_loaded) return;
    _loaded = true;
    _name.text = g.name;
    _type = g.type;
    _settings = g.settings.copyWith(statsVisibility: g.settings.effectiveStatsVisibility(g.type));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = ref.watch(apiProvider);
    final group = ref.watch(groupProvider(widget.groupId));
    final perms = ref.watch(permissionsProvider(widget.groupId)).value;
    final role = ref.watch(myGroupsProvider).value?.where((g) => g.group.id == widget.groupId).firstOrNull?.role;
    final members = ref.watch(membersProvider(widget.groupId)).value ?? const <Member>[];
    final me = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(s.groupSettings)),
      body: asyncBody(context, group, (g) {
        if (g == null) return EmptyState(icon: Icons.error_outline, title: s.error('not_a_member'));
        _init(g);
        final editable = can(perms, Perm.manageSettings) && !g.isArchived;
        final st = _settings!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _name, enabled: editable, decoration: InputDecoration(labelText: s.groupName)),
            const SizedBox(height: 16),
            DropdownButtonFormField<GroupType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: s.groupType),
              items: [for (final t in GroupType.values) DropdownMenuItem(value: t, child: Text(s.groupTypeLabel(t)))],
              onChanged: editable ? (v) => setState(() => _type = v) : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(value: st.requiresApprovalDefault, onChanged: editable ? (v) => setState(() => _settings = st.copyWith(requiresApprovalDefault: v)) : null, title: Text(s.requiresApprovalDefault), subtitle: Text(s.requiresApprovalDefaultHint, style: const TextStyle(fontSize: 12)), contentPadding: EdgeInsets.zero),
            SwitchListTile(value: st.gamificationEnabled, onChanged: editable ? (v) => setState(() => _settings = st.copyWith(gamificationEnabled: v)) : null, title: Text(s.gamification), subtitle: Text(s.gamificationHint, style: const TextStyle(fontSize: 12)), contentPadding: EdgeInsets.zero),
            SwitchListTile(value: st.membersCanCreateTasks, onChanged: editable ? (v) => setState(() => _settings = st.copyWith(membersCanCreateTasks: v)) : null, title: Text(s.membersCanCreate), contentPadding: EdgeInsets.zero),
            SwitchListTile(value: st.activityVisibleToMembers, onChanged: editable ? (v) => setState(() => _settings = st.copyWith(activityVisibleToMembers: v)) : null, title: Text(s.activityVisible), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 8),
            Text(s.statsVisibility, style: const TextStyle(fontWeight: FontWeight.w700)),
            RadioGroup<String>(
              groupValue: st.statsVisibility,
              onChanged: editable ? (x) => setState(() => _settings = st.copyWith(statsVisibility: x)) : (_) {},
              child: Column(
                children: [
                  for (final (v, label) in [('private', s.statsPrivate), ('admins', s.statsAdmins), ('all', s.statsAll)])
                    RadioListTile<String>(value: v, enabled: editable, title: Text(label), contentPadding: EdgeInsets.zero),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (editable)
              FilledButton(
                onPressed: () async {
                  final r = await guard(context, () => api.updateGroupSettings(widget.groupId, name: _name.text.trim(), type: _type, settings: _settings), success: s.save);
                  if (r != null && context.mounted) context.pop();
                },
                child: Text(s.save),
              ),
            const SizedBox(height: 32),
            const Divider(),
            if (role == MembershipRole.owner && !g.isArchived) ...[
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(s.transferOwnership),
                onTap: () async {
                  final others = members.where((m) => m.userId != me?.id).toList();
                  if (others.isEmpty) return;
                  final pick = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    builder: (c) => ListView(shrinkWrap: true, children: [for (final m in others) ListTile(leading: Avatar(name: m.user.displayName), title: Text(m.user.displayName), onTap: () => Navigator.pop(c, m.userId))]),
                  );
                  if (pick != null && context.mounted && await confirmDialog(context, title: s.transferOwnership)) {
                    if (context.mounted) guard(context, () => api.transferOwnership(widget.groupId, pick));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined, color: AppTheme.danger),
                title: Text(s.archiveGroup, style: const TextStyle(color: AppTheme.danger)),
                onTap: () async {
                  if (await confirmDialog(context, title: s.archiveGroup, destructive: true)) {
                    if (context.mounted) {
                      final ok = await guardOk(context, () => api.archiveGroup(widget.groupId));
                      if (ok && context.mounted) context.go('/groups');
                    }
                  }
                },
              ),
            ] else if (role != null)
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppTheme.danger),
                title: Text(s.leaveGroup, style: const TextStyle(color: AppTheme.danger)),
                onTap: () async {
                  if (await confirmDialog(context, title: s.leaveGroup, destructive: true)) {
                    if (context.mounted) {
                      final ok = await guardOk(context, () => api.leaveGroup(widget.groupId));
                      if (ok && context.mounted) context.go('/groups');
                    }
                  }
                },
              ),
          ],
        );
      }, onRetry: () => ref.invalidate(groupProvider(widget.groupId))),
    );
  }
}
