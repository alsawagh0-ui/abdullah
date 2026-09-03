import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/api/api_error.dart';
import '../core/format.dart';
import '../core/models/enums.dart';
import '../core/models/models.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';

/// Runs an API call, shows the Arabic copy for any backend error code.
Future<T?> guard<T>(BuildContext context, Future<T> Function() f, {String? success}) async {
  final s = S.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final r = await f();
    if (success != null) messenger?.showSnackBar(SnackBar(content: Text(success)));
    HapticFeedback.lightImpact();
    return r;
  } on ApiException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(s.error(e.code, e.detail)), backgroundColor: AppTheme.danger));
    return null;
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(s.error('unknown')), backgroundColor: AppTheme.danger));
    return null;
  }
}

/// Like [guard] for void operations: true on success.
Future<bool> guardOk(BuildContext context, Future<void> Function() f, {String? success}) async {
  final r = await guard<bool>(context, () async {
    await f();
    return true;
  }, success: success);
  return r ?? false;
}

Future<bool> confirmDialog(BuildContext context, {required String title, String? body, String? confirmLabel, bool destructive = false}) async {
  final s = S.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppTheme.danger) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel ?? s.confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptText(BuildContext context, {required String title, String? hint, String? confirmLabel, bool required = false}) async {
  final s = S.of(context);
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, maxLines: 3, minLines: 1, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            if (required && ctrl.text.trim().isEmpty) return;
            Navigator.pop(c, ctrl.text.trim());
          },
          child: Text(confirmLabel ?? s.confirm),
        ),
      ],
    ),
  );
  return r;
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 36, this.color});
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color ?? scheme.primaryContainer,
      child: Text(initials(name), style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
    );
  }
}

class UserName extends ConsumerWidget {
  const UserName(this.userId, {super.key, this.style, this.fallback});
  final String? userId;
  final TextStyle? style;
  final String? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == null) return Text(fallback ?? '—', style: style);
    final me = ref.watch(currentUserProvider).value;
    if (me?.id == userId) return Text(S.of(context).you, style: style);
    final u = ref.watch(userProvider(userId!)).value;
    return Text(u?.displayName.isNotEmpty == true ? u!.displayName : (fallback ?? '…'), style: style);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.task, this.large = false});
  final Task task;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final color = AppTheme.statusColor(task.status, overdue: task.isOverdue);
    final label = task.isOverdue ? s.overdue : s.status(task.status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: large ? 14 : 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// The row used in every task list. One tap opens; the trailing quick action
/// is the primary next step (claim / done) when it is the user's to take.
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.groupName, this.showGroup = false});
  final Task task;
  final String? groupName;
  final bool showGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final me = ref.watch(currentUserProvider).value;
    final api = ref.watch(apiProvider);
    final color = AppTheme.statusColor(task.status, overdue: task.isOverdue);
    final mine = task.assigneeId != null && task.assigneeId == me?.id;
    final canClaim = task.isOpenForClaim && !task.isPersonal;
    final canDone = mine && (task.status == TaskStatus.newTask || task.status == TaskStatus.inProgress) && !task.requiresProof;
    final done = task.status == TaskStatus.completed;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/task/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(width: 4, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, decoration: done ? TextDecoration.lineThrough : null, color: done ? AppTheme.muted : null)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(task: task),
                        if (task.assigneeId != null) UserName(task.assigneeId, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                        if (task.dueAt != null && !done) Text(task.isOverdue ? f.until(task.dueAt!) : f.dateTime(task.dueAt!, dateOnly: task.dueDateOnly), style: TextStyle(fontSize: 12, color: task.isOverdue ? AppTheme.danger : AppTheme.muted)),
                        if (showGroup) Text(groupName ?? s.personal, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                        if (task.priority == TaskPriority.high || task.priority == TaskPriority.urgent)
                          Text(s.priorityLabel(task.priority), style: TextStyle(fontSize: 12, color: AppTheme.priorityColor(task.priority), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              if (canClaim)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  onPressed: () => guard(context, () => api.claimTask(task.id)),
                  child: Text(s.claim, style: const TextStyle(fontSize: 13)),
                )
              else if (canDone)
                IconButton.filledTonal(
                  tooltip: s.markDone,
                  onPressed: () => guard(context, () => api.completeTask(task.id)),
                  icon: const Icon(Icons.check_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.color});
  final String title;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color ?? AppTheme.muted))),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppTheme.muted.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              if (body != null) ...[const SizedBox(height: 6), Text(body!, style: const TextStyle(color: AppTheme.muted), textAlign: TextAlign.center)],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final msg = error is ApiException ? s.error((error as ApiException).code) : s.error('unknown');
    return EmptyState(icon: Icons.error_outline, title: msg, action: OutlinedButton(onPressed: onRetry, child: Text(s.retry)));
  }
}

/// Renders an AsyncValue with the shared loading / error treatment.
Widget asyncBody<T>(BuildContext context, AsyncValue<T> v, Widget Function(T data) builder, {VoidCallback? onRetry}) => v.when(
      data: builder,
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) => ErrorRetry(error: e, onRetry: onRetry ?? () {}),
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
    );

class CountTile extends StatelessWidget {
  const CountTile({super.key, required this.label, required this.count, required this.color, this.onTap});
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Text(Fmt.of(context).num(count), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
                  Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );
}

class GroupIcon extends StatelessWidget {
  const GroupIcon(this.type, {super.key, this.size = 40});
  final GroupType type;
  final double size;

  static IconData iconFor(GroupType t) => switch (t) {
        GroupType.home => Icons.home_rounded,
        GroupType.family => Icons.family_restroom_rounded,
        GroupType.company => Icons.business_rounded,
        GroupType.department => Icons.account_tree_rounded,
        GroupType.team => Icons.groups_rounded,
        GroupType.project => Icons.rocket_launch_rounded,
        GroupType.committee => Icons.gavel_rounded,
        GroupType.volunteer => Icons.volunteer_activism_rounded,
        GroupType.other => Icons.workspaces_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(size / 3.2)),
      child: Icon(iconFor(type), color: scheme.onPrimaryContainer, size: size * 0.55),
    );
  }
}
