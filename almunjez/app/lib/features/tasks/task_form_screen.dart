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

/// D2 / D3 — title first, everything else optional and collapsed.
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.groupId, this.parentTaskId, this.personal = false, this.editTaskId});
  final String? groupId;
  final String? parentTaskId;
  final bool personal;
  final String? editTaskId;
  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _points = TextEditingController();
  String? _groupId;
  AssignmentMode _mode = AssignmentMode.open;
  String? _assignee;
  final Set<String> _participants = {};
  DateTime? _due;
  bool _dueDateOnly = false;
  TaskPriority _priority = TaskPriority.normal;
  bool? _approval;
  bool _proof = false;
  bool _more = false;
  Task? _editing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _groupId = widget.personal ? null : widget.groupId;
  }

  void _loadEditing(Task t) {
    if (_loaded) return;
    _loaded = true;
    _editing = t;
    _title.text = t.title;
    _desc.text = t.description ?? '';
    _points.text = t.points?.toString() ?? '';
    _groupId = t.groupId;
    _mode = t.assignmentMode;
    _assignee = t.assigneeId;
    _due = t.dueAt;
    _dueDateOnly = t.dueDateOnly;
    _priority = t.priority;
    _approval = t.requiresApproval;
    _proof = t.requiresProof;
    _more = t.points != null || t.requiresApproval || t.requiresProof;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final f = Fmt.of(context);
    final api = ref.watch(apiProvider);
    final me = ref.watch(currentUserProvider).value;
    final groups = ref.watch(myGroupsProvider).value ?? const <GroupSummary>[];
    if (widget.editTaskId != null) {
      final t = ref.watch(taskProvider(widget.editTaskId!)).value;
      if (t != null) _loadEditing(t);
    }
    final editing = _editing != null;
    final gid = _groupId;
    final members = gid == null ? const <Member>[] : (ref.watch(membersProvider(gid)).value ?? const <Member>[]);
    final perms = gid == null ? <String>{} : (ref.watch(permissionsProvider(gid)).value ?? <String>{});
    final group = gid == null ? null : groups.where((g) => g.group.id == gid).firstOrNull?.group;
    final canAssignOthers = perms.contains(Perm.assignOthers);
    final gamified = group?.settings.gamificationEnabled ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? s.editTask : (widget.parentTaskId != null ? s.addSubtask : s.newTask))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: !editing,
            maxLength: 200,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(hintText: s.taskTitle, counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(controller: _desc, minLines: 1, maxLines: 5, decoration: InputDecoration(hintText: s.description)),

          // group
          if (!editing && widget.parentTaskId == null) ...[
            SectionHeader(s.group),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(avatar: const Icon(Icons.lock_outline_rounded, size: 16), label: Text(s.personalNoGroup), selected: gid == null, onSelected: (_) => setState(() { _groupId = null; _assignee = null; _participants.clear(); })),
                for (final g in groups.where((g) => !g.group.isArchived))
                  ChoiceChip(avatar: Icon(GroupIcon.iconFor(g.group.type), size: 16), label: Text(g.group.name), selected: gid == g.group.id, onSelected: (_) => setState(() { _groupId = g.group.id; _assignee = null; _participants.clear(); })),
              ],
            ),
          ],

          // assignment
          if (gid != null && !editing) ...[
            SectionHeader(s.assignment),
            RadioGroup<AssignmentMode>(
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              child: Column(
                children: [
                  for (final (m, label, hint) in [
                    (AssignmentMode.open, s.modeOpen, s.modeOpenHint),
                    (AssignmentMode.assigned, s.modeAssigned, s.modeAssignedHint),
                    (AssignmentMode.collaborative, s.modeCollaborative, s.modeCollaborativeHint),
                  ])
                    RadioListTile<AssignmentMode>(value: m, title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(hint, style: const TextStyle(fontSize: 12)), contentPadding: EdgeInsets.zero, dense: true),
                ],
              ),
            ),
            if (_mode == AssignmentMode.assigned) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in members)
                    if (m.userId == me?.id || canAssignOthers)
                      ChoiceChip(avatar: Avatar(name: m.user.displayName, size: 22), label: Text(m.userId == me?.id ? s.you : m.user.displayName), selected: _assignee == m.userId, onSelected: (_) => setState(() => _assignee = m.userId)),
                ],
              ),
            ],
            if (_mode == AssignmentMode.collaborative)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in members)
                    FilterChip(avatar: Avatar(name: m.user.displayName, size: 22), label: Text(m.userId == me?.id ? s.you : m.user.displayName), selected: _participants.contains(m.userId), onSelected: (v) => setState(() => v ? _participants.add(m.userId) : _participants.remove(m.userId))),
                ],
              ),
          ],

          // due & priority
          SectionHeader(s.dueDate),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  onPressed: _pickDue,
                  label: Text(_due == null ? s.noDueDate : f.dateTime(_due!, dateOnly: _dueDateOnly)),
                ),
              ),
              if (_due != null) IconButton(onPressed: () => setState(() => _due = null), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          SectionHeader(s.priority),
          SegmentedButton<TaskPriority>(
            segments: [for (final p in TaskPriority.values) ButtonSegment(value: p, label: Text(s.priorityLabel(p), style: TextStyle(color: _priority == p ? AppTheme.priorityColor(p) : null)))],
            selected: {_priority},
            onSelectionChanged: (v) => setState(() => _priority = v.first),
            showSelectedIcon: false,
          ),

          // more
          const SizedBox(height: 16),
          if (gid != null) ...[
            TextButton.icon(onPressed: () => setState(() => _more = !_more), icon: Icon(_more ? Icons.expand_less_rounded : Icons.expand_more_rounded), label: Text(s.moreOptions)),
            if (_more) ...[
              if (gamified) TextField(controller: _points, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.points, hintText: '٥ … ٥٠')),
              SwitchListTile(value: _approval ?? (group?.settings.requiresApprovalDefault ?? false), onChanged: (v) => setState(() => _approval = v), title: Text(s.requireApproval), contentPadding: EdgeInsets.zero),
              SwitchListTile(value: _proof, onChanged: (v) => setState(() => _proof = v), title: Text(s.requireProof), contentPadding: EdgeInsets.zero),
            ],
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _title.text.trim().isEmpty || (_mode == AssignmentMode.assigned && gid != null && _assignee == null && !editing) ? null : () => _submit(api),
            child: Text(editing ? s.save : s.add),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _due ?? now, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 365 * 3)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due ?? DateTime(now.year, now.month, now.day, 18)));
    setState(() {
      _dueDateOnly = t == null;
      _due = t == null ? DateTime(d.year, d.month, d.day, 23, 59) : DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _submit(api) async {
    final s = S.of(context);
    final points = int.tryParse(Fmt('en').num(0) == '0' ? _points.text.replaceAllMapped(RegExp('[٠-٩]'), (m) => (m[0]!.codeUnitAt(0) - 0x660).toString()) : _points.text);
    if (_editing != null) {
      final t = _editing!;
      final r = await guard(
        context,
        () => api.updateTask(
          t.id,
          TaskPatch(
            title: _title.text.trim(),
            description: _desc.text.trim(),
            dueAt: _due,
            clearDue: _due == null && t.dueAt != null,
            priority: _priority,
            points: points,
            clearPoints: points == null && t.points != null,
            requiresProof: _proof,
            requiresApproval: _approval,
          ),
          t.version,
        ),
        success: s.save,
      );
      if (r != null && mounted) context.pop();
      return;
    }
    final r = await guard(
      context,
      () => api.createTask(TaskDraft(
        title: _title.text.trim(),
        groupId: _groupId,
        description: _desc.text.trim(),
        assignmentMode: _mode,
        assigneeId: _assignee,
        dueAt: _due,
        dueDateOnly: _dueDateOnly,
        priority: _priority,
        points: points,
        requiresProof: _proof,
        requiresApproval: _approval,
        parentTaskId: widget.parentTaskId,
        participantIds: _participants.toList(),
      )),
    );
    if (r != null && mounted) context.pushReplacement('/task/${(r as Task).id}');
  }
}
