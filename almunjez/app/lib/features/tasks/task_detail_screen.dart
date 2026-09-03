import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';
import '../groups/group_activity_screen.dart';

/// D1 — the most important screen (brief §21). The state header is large,
/// the one right next action is the big button, and the screen never
/// navigates away on a state change.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;
  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _comment = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final api = ref.watch(apiProvider);
    final task = ref.watch(taskProvider(widget.taskId));
    final me = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: asyncBody(context, task, (t) {
        if (t == null) return EmptyState(icon: Icons.search_off_rounded, title: s.error('not_found'));
        final perms = t.groupId == null ? <String>{} : (ref.watch(permissionsProvider(t.groupId!)).value ?? <String>{});
        final group = t.groupId == null ? null : ref.watch(groupProvider(t.groupId!)).value;
        final comments = ref.watch(commentsProvider(t.id)).value ?? const <TaskComment>[];
        final events = ref.watch(taskActivityProvider(t.id)).value ?? const <ActivityEvent>[];
        final subs = ref.watch(subtasksProvider(t.id)).value ?? const <Task>[];
        final uid = me?.id;
        final isAssignee = t.assigneeId != null && t.assigneeId == uid;
        final isCreator = t.creatorId == uid;
        final canManage = isCreator || perms.contains(Perm.editAny);
        final canAssign = isCreator || perms.contains(Perm.assignOthers);
        final color = AppTheme.statusColor(t.status, overdue: t.isOverdue);

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              actions: [
                if (!t.status.isTerminal || t.status == TaskStatus.completed)
                  PopupMenuButton<String>(
                    onSelected: (v) => _action(v, t, api),
                    itemBuilder: (_) => [
                      if (canManage && !t.status.isTerminal) PopupMenuItem(value: 'edit', child: Text(s.edit)),
                      if (isAssignee && !t.isPersonal && (t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)) PopupMenuItem(value: 'release', child: Text(s.release)),
                      if (canAssign && !t.isPersonal && (t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)) PopupMenuItem(value: 'reassign', child: Text(s.reassign)),
                      if (canAssign && !t.isPersonal && t.assigneeId != null && (t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)) PopupMenuItem(value: 'unassign', child: Text(s.unassign)),
                      if (canManage && !t.isPersonal && !t.status.isTerminal && t.parentTaskId == null) PopupMenuItem(value: 'subtask', child: Text(s.addSubtask)),
                      if ((isCreator || perms.contains(Perm.cancelAny)) && !t.status.isTerminal) PopupMenuItem(value: 'cancel', child: Text(s.cancelTask, style: const TextStyle(color: AppTheme.danger))),
                      if (canManage && t.status == TaskStatus.completed) PopupMenuItem(value: 'reopen', child: Text(s.reopen)),
                    ],
                  ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList.list(children: [
                // ---- state header
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      Icon(_icon(t), color: color, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_headline(s, t, isAssignee), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                            if (t.assigneeId != null && t.status != TaskStatus.completed)
                              UserName(t.assigneeId, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w600)),
                            if (t.status == TaskStatus.completed && t.completedBy != null)
                              Row(children: [Text('${s.by} ', style: TextStyle(color: color)), UserName(t.completedBy, style: TextStyle(color: color, fontWeight: FontWeight.w600))]),
                          ],
                        ),
                      ),
                      if (t.isOverdue) Text(f.until(t.dueAt!), style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(t.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.3)),
                if (t.description != null) ...[const SizedBox(height: 8), Text(t.description!, style: const TextStyle(fontSize: 16, height: 1.6, color: AppTheme.muted))],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (group != null) _chip(GroupIcon.iconFor(group.type), group.name, onTap: () => context.push('/group/${group.id}')),
                    if (t.isPersonal) _chip(Icons.lock_outline_rounded, s.personal),
                    if (t.dueAt != null) _chip(Icons.schedule_rounded, f.dateTime(t.dueAt!, dateOnly: t.dueDateOnly), color: t.isOverdue ? AppTheme.danger : null),
                    if (t.priority != TaskPriority.normal) _chip(Icons.flag_rounded, s.priorityLabel(t.priority), color: AppTheme.priorityColor(t.priority)),
                    if (t.points != null && (group?.settings.gamificationEnabled ?? false)) _chip(Icons.stars_rounded, '${f.num(t.points!)} ${s.points}'),
                    if (t.requiresApproval) _chip(Icons.verified_outlined, s.requireApproval),
                    if (t.requiresProof) _chip(Icons.photo_camera_outlined, s.requireProof),
                    if (t.assignmentMode == AssignmentMode.collaborative) _chip(Icons.groups_rounded, s.modeCollaborative),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [Text('${s.createdBy} ', style: const TextStyle(color: AppTheme.muted, fontSize: 13)), UserName(t.creatorId, style: const TextStyle(color: AppTheme.muted, fontSize: 13, fontWeight: FontWeight.w600)), Text(' · ${f.relative(t.createdAt)}', style: const TextStyle(color: AppTheme.muted, fontSize: 13))]),

                // ---- participants
                if (t.participantIds.isNotEmpty) ...[
                  SectionHeader(s.participants),
                  Wrap(spacing: 8, children: [for (final p in t.participantIds) Chip(avatar: const Icon(Icons.person, size: 16), label: UserName(p))]),
                ],

                // ---- subtasks
                if (subs.isNotEmpty) ...[
                  SectionHeader(s.subtasks, trailing: Text('${f.num(subs.where((x) => x.status == TaskStatus.completed).length)}/${f.num(subs.length)}', style: const TextStyle(color: AppTheme.muted))),
                  for (final st in subs) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskTile(task: st)),
                ],

                // ---- comments
                SectionHeader(s.comments),
                if (comments.isEmpty) Text(s.t('لا تعليقات بعد', 'No comments yet'), style: const TextStyle(color: AppTheme.muted)),
                for (final c in comments) _CommentRow(c),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _comment, decoration: InputDecoration(hintText: s.writeComment), minLines: 1, maxLines: 4)),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        if (_comment.text.trim().isEmpty) return;
                        final r = await guard(context, () => api.addComment(t.id, _comment.text.trim()));
                        if (r != null) _comment.clear();
                      },
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),

                // ---- history
                if (events.isNotEmpty) ...[
                  SectionHeader(s.history),
                  for (final e in events) ActivityRow(e, title: t.title),
                ],
              ]),
            ),
          ],
        );
      }, onRetry: () => ref.invalidate(taskProvider(widget.taskId))),
      bottomNavigationBar: task.value == null ? null : _primaryAction(context, task.value!, me?.id, api),
    );
  }

  IconData _icon(Task t) => switch (t.status) {
        TaskStatus.newTask => t.assigneeId == null ? Icons.front_hand_rounded : Icons.person_pin_circle_rounded,
        TaskStatus.inProgress => Icons.autorenew_rounded,
        TaskStatus.awaitingApproval => Icons.hourglass_top_rounded,
        TaskStatus.completed => Icons.check_circle_rounded,
        TaskStatus.cancelled => Icons.cancel_rounded,
      };

  String _headline(S s, Task t, bool isAssignee) {
    if (t.status == TaskStatus.newTask) {
      if (t.assigneeId == null) {
        if (t.isPersonal) return s.status(t.status);
        if (t.assignmentMode == AssignmentMode.collaborative) return '${s.status(t.status)} — ${s.modeCollaborative}';
        return '${s.status(t.status)} — ${s.available}';
      }
      return isAssignee ? '${s.status(t.status)} — ${s.forYou}' : s.status(t.status);
    }
    return s.status(t.status);
  }

  Widget _chip(IconData icon, String label, {Color? color, VoidCallback? onTap}) => ActionChip(
        avatar: Icon(icon, size: 16, color: color ?? AppTheme.muted),
        label: Text(label, style: TextStyle(color: color, fontSize: 13)),
        onPressed: onTap,
        backgroundColor: (color ?? AppTheme.muted).withValues(alpha: 0.08),
      );

  /// The single big button (doc 02 §2).
  Widget? _primaryAction(BuildContext context, Task t, String? uid, api) {
    final s = S.of(context);
    final isAssignee = t.assigneeId != null && t.assigneeId == uid;
    final perms = t.groupId == null ? <String>{} : (ref.watch(permissionsProvider(t.groupId!)).value ?? <String>{});
    final canApprove = t.groupId != null && !isAssignee && (t.creatorId == uid || perms.contains(Perm.approveCompletion));
    Widget? child;
    if (t.isOpenForClaim && !t.isPersonal) {
      child = FilledButton.icon(icon: const Icon(Icons.front_hand_rounded), onPressed: () => guard(context, () => api.claimTask(t.id)), label: Text(s.claim));
    } else if (isAssignee && (t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)) {
      child = Row(
        children: [
          if (t.status == TaskStatus.newTask) ...[
            Expanded(child: OutlinedButton(onPressed: () => guard(context, () => api.startTask(t.id)), child: Text(s.start))),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
              icon: const Icon(Icons.check_rounded),
              onPressed: () => _complete(t, api),
              label: Text(s.markDone),
            ),
          ),
        ],
      );
    } else if (t.status == TaskStatus.awaitingApproval && canApprove) {
      child = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
              onPressed: () async {
                final reason = await promptText(context, title: s.sendBackReason, required: true, confirmLabel: s.sendBack);
                if (reason != null && context.mounted) guard(context, () => api.rejectCompletion(t.id, reason));
              },
              child: Text(s.sendBack),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppTheme.success), icon: const Icon(Icons.verified_rounded), onPressed: () => guard(context, () => api.approveCompletion(t.id)), label: Text(s.approve))),
        ],
      );
    }
    if (child == null) return null;
    return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: child));
  }

  Future<void> _complete(Task t, api) async {
    final s = S.of(context);
    String? note;
    if (t.requiresProof || t.requiresApproval) {
      note = await promptText(context, title: t.requiresProof ? s.proofNote : s.completionNote, required: t.requiresProof, confirmLabel: s.markDone);
      if (note == null) return;
    }
    if (!mounted) return;
    guard(context, () => api.completeTask(t.id, note: note));
  }

  Future<void> _action(String v, Task t, api) async {
    final s = S.of(context);
    switch (v) {
      case 'edit':
        context.push('/task/${t.id}/edit');
      case 'subtask':
        context.push('/task/new?group=${t.groupId}&parent=${t.id}');
      case 'release':
        if (await confirmDialog(context, title: s.release)) {
          if (mounted) guard(context, () => api.releaseTask(t.id));
        }
      case 'unassign':
        guard(context, () => api.unassignTask(t.id));
      case 'reassign':
        final members = await ref.read(apiProvider).members(t.groupId!);
        if (!mounted) return;
        final pick = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (c) => ListView(shrinkWrap: true, children: [for (final m in members) ListTile(leading: Avatar(name: m.user.displayName), title: Text(m.user.displayName), onTap: () => Navigator.pop(c, m.userId))]),
        );
        if (pick != null && mounted) guard(context, () => api.reassignTask(t.id, pick));
      case 'cancel':
        if (await confirmDialog(context, title: s.cancelTask, destructive: true)) {
          if (mounted) guard(context, () => api.cancelTask(t.id));
        }
      case 'reopen':
        guard(context, () => api.reopenTask(t.id));
    }
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow(this.c);
  final TaskComment c;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final system = c.kind != 'comment';
    final label = switch (c.kind) {
      'rejection_reason' => s.sendBackReason,
      'proof_note' => s.t('ملاحظة الإنجاز', 'Completion note'),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(name: c.author?.displayName ?? '', size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: system ? AppTheme.warning.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: c.author != null ? Text(c.author!.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)) : UserName(c.authorId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    Text(f.relative(c.createdAt), style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                  ]),
                  if (label != null) Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(c.body, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
