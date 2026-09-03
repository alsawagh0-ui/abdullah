import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// C7 — roles and removal with the separation rules of doc 06 §4.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final api = ref.watch(apiProvider);
    final members = ref.watch(membersProvider(groupId));
    final perms = ref.watch(permissionsProvider(groupId)).value;
    final me = ref.watch(currentUserProvider).value;
    final myRole = members.value?.where((m) => m.userId == me?.id).firstOrNull?.role;

    return Scaffold(
      appBar: AppBar(title: Text(s.membersTitle)),
      body: asyncBody(context, members, (list) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = list[i];
              final isMe = m.userId == me?.id;
              final canTouch = can(perms, Perm.manageMembers) && !isMe && m.role != MembershipRole.owner && !(myRole == MembershipRole.admin && m.role == MembershipRole.admin);
              return Card(
                child: ListTile(
                  leading: Avatar(name: m.user.displayName, size: 44),
                  title: Text(isMe ? '${m.user.displayName} (${s.you})' : m.user.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(s.roleLabel(m.role), style: TextStyle(color: m.role == MembershipRole.owner ? AppTheme.accent : AppTheme.muted, fontWeight: FontWeight.w600)),
                  trailing: canTouch ? const Icon(Icons.more_horiz_rounded) : null,
                  onTap: canTouch ? () => _sheet(context, api, m, myRole) : null,
                ),
              );
            },
          ), onRetry: () => ref.invalidate(membersProvider(groupId))),
    );
  }

  void _sheet(BuildContext context, api, Member m, MembershipRole? myRole) {
    final s = S.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Avatar(name: m.user.displayName), title: Text(m.user.displayName, style: const TextStyle(fontWeight: FontWeight.w700))),
            const Divider(),
            if (m.role == MembershipRole.member)
              ListTile(leading: const Icon(Icons.shield_outlined), title: Text(s.makeAdmin), onTap: () { Navigator.pop(c); guard(context, () => api.setMemberRole(groupId, m.userId, MembershipRole.admin)); })
            else if (m.role == MembershipRole.admin && myRole == MembershipRole.owner)
              ListTile(leading: const Icon(Icons.shield_outlined), title: Text(s.removeAdmin), onTap: () { Navigator.pop(c); guard(context, () => api.setMemberRole(groupId, m.userId, MembershipRole.member)); }),
            if (myRole == MembershipRole.owner)
              ListTile(leading: const Icon(Icons.swap_horiz_rounded), title: Text(s.transferOwnership), onTap: () async {
                Navigator.pop(c);
                if (await confirmDialog(context, title: s.transferOwnership, body: '${m.user.displayName}؟')) {
                  if (context.mounted) guard(context, () => api.transferOwnership(groupId, m.userId));
                }
              }),
            ListTile(leading: const Icon(Icons.person_remove_outlined, color: AppTheme.danger), title: Text(s.removeFromGroup, style: const TextStyle(color: AppTheme.danger)), onTap: () async {
              Navigator.pop(c);
              if (await confirmDialog(context, title: s.removeFromGroup, body: m.user.displayName, destructive: true)) {
                if (context.mounted) guard(context, () => api.removeMember(groupId, m.userId));
              }
            }),
          ],
        ),
      ),
    );
  }
}
