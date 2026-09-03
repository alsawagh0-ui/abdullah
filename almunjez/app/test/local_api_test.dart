import 'package:almunjez/core/api/api_error.dart';
import 'package:almunjez/core/api/local/local_api.dart';
import 'package:almunjez/core/models/enums.dart';
import 'package:almunjez/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The on-device engine must enforce the same rules as
/// backend/schema/001_initial.sql (see backend/tests/smoke.sql).
void main() {
  late LocalApi api;
  late AppUser abdullah, mohammed, khaled, sara;

  Future<AppUser> user(String name) async {
    await api.signInWithApple();
    return api.completeProfile(displayName: name);
  }

  Future<void> as_(AppUser u) async {
    // Switching identity on one device: sign in as that user again.
    await api.signOut();
    await api.signInDemoAs(u.id);
  }

  setUp(() async {
    api = LocalApi(MemoryStore());
    abdullah = await user('عبدالله');
    mohammed = await user('محمد');
    khaled = await user('خالد');
    sara = await user('سارة');
  });

  Future<Matcher> throwsCode(String code) async => throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

  Future<(Group, String)> homeWithMembers() async {
    await as_(abdullah);
    final g = await api.createGroup(name: 'البيت', type: GroupType.home);
    final code = (await api.activeInviteCode(g.id))!;
    for (final u in [mohammed, khaled]) {
      await as_(u);
      final r = await api.requestJoin(code);
      await as_(abdullah);
      await api.decideJoin(r.id, accept: true);
    }
    return (g, code);
  }

  group('groups and joining', () {
    test('create_group makes an owner and an 8-char code', () async {
      await as_(abdullah);
      final g = await api.createGroup(name: 'البيت', type: GroupType.home);
      expect(await api.myRole(g.id), MembershipRole.owner);
      expect((await api.activeInviteCode(g.id))!.length, 8);
      expect(g.memberCount, 1);
    });

    test('a code alone never grants access; approval does', () async {
      await as_(abdullah);
      final g = await api.createGroup(name: 'البيت', type: GroupType.home);
      final code = (await api.activeInviteCode(g.id))!;
      await as_(mohammed);
      final p = await api.previewInvite(code);
      expect(p.groupName, 'البيت');
      final r1 = await api.requestJoin(code);
      final r2 = await api.requestJoin(code);
      expect(r1.id, r2.id, reason: 'idempotent');
      expect(await api.getGroup(g.id), isNull, reason: 'not a member yet');
      expect(() => api.decideJoin(r1.id, accept: true), await throwsCode('permission_denied'));
      await as_(abdullah);
      await api.decideJoin(r1.id, accept: true);
      await as_(mohammed);
      expect(await api.getGroup(g.id), isNotNull);
      expect((await api.notifications()).map((n) => n.type), contains('join.accepted'));
    });

    test('regenerating the code revokes the old one', () async {
      final (g, code) = await homeWithMembers();
      await as_(abdullah);
      final code2 = await api.regenerateInvite(g.id);
      await as_(sara);
      expect(() => api.previewInvite(code), await throwsCode('invalid_invite'));
      expect((await api.previewInvite(code2)).memberCount, 3);
    });
  });

  group('roles', () {
    test('admin cannot touch the owner or other admins; owner must transfer before leaving', () async {
      final (g, _) = await homeWithMembers();
      await as_(abdullah);
      await api.setMemberRole(g.id, khaled.id, MembershipRole.admin);
      await as_(khaled);
      expect(() => api.setMemberRole(g.id, abdullah.id, MembershipRole.admin), await throwsCode('permission_denied'));
      expect(() => api.removeMember(g.id, abdullah.id), await throwsCode('permission_denied'));
      await as_(abdullah);
      expect(() => api.leaveGroup(g.id), await throwsCode('owner_must_transfer'));
      expect(() => api.deleteAccount(), await throwsCode('owner_must_transfer'));
      await api.transferOwnership(g.id, mohammed.id);
      expect(await api.myRole(g.id), MembershipRole.admin);
      await as_(mohammed);
      expect(await api.myRole(g.id), MembershipRole.owner);
    });
  });

  group('task lifecycle', () {
    test('open task: first claim wins, second gets already_claimed, re-claim is idempotent', () async {
      final (g, _) = await homeWithMembers();
      await as_(abdullah);
      final t = await api.createTask(TaskDraft(title: 'إصلاح التكييف', groupId: g.id, requiresApproval: true));
      await as_(mohammed);
      expect((await api.notifications()).map((n) => n.type), contains('task.created'));
      final claimed = await api.claimTask(t.id);
      expect(claimed.status, TaskStatus.inProgress);
      expect(claimed.assigneeId, mohammed.id);
      await as_(khaled);
      expect(() => api.claimTask(t.id), await throwsCode('already_claimed'));
      await as_(mohammed);
      expect((await api.claimTask(t.id)).assigneeId, mohammed.id);
    });

    test('approval loop: assignee never approves own work; rejection reason recorded', () async {
      final (g, _) = await homeWithMembers();
      await as_(abdullah);
      final t = await api.createTask(TaskDraft(title: 'إصلاح التكييف', groupId: g.id, requiresApproval: true));
      await as_(mohammed);
      await api.claimTask(t.id);
      expect((await api.completeTask(t.id)).status, TaskStatus.awaitingApproval);
      expect(() => api.approveCompletion(t.id), await throwsCode('permission_denied'));
      await as_(abdullah);
      expect((await api.rejectCompletion(t.id, 'الفني لم يأتِ بعد')).status, TaskStatus.inProgress);
      await as_(mohammed);
      await api.completeTask(t.id);
      await as_(abdullah);
      final done = await api.approveCompletion(t.id);
      expect(done.status, TaskStatus.completed);
      expect(done.completedBy, mohammed.id);
      expect(done.approvedBy, abdullah.id);
      expect((await api.comments(t.id)).where((c) => c.kind == 'rejection_reason').length, 1);
      expect((await api.taskActivity(t.id)).map((e) => e.action).toList(), ['task.created', 'task.claimed', 'task.submitted', 'task.rejected', 'task.submitted', 'task.approved']);
      expect(() => api.claimTask(t.id), await throwsCode('invalid_transition'));
    });

    test('members cannot assign others; removing a member releases their tasks', () async {
      final (g, _) = await homeWithMembers();
      await as_(mohammed);
      expect(() => api.createTask(TaskDraft(title: 'x', groupId: g.id, assignmentMode: AssignmentMode.assigned, assigneeId: khaled.id)), await throwsCode('permission_denied'));
      await as_(abdullah);
      final t = await api.createTask(TaskDraft(title: 'السيارة', groupId: g.id, assignmentMode: AssignmentMode.assigned, assigneeId: khaled.id));
      await as_(khaled);
      expect((await api.notifications()).map((n) => n.type), contains('task.assigned'));
      await api.startTask(t.id);
      await as_(abdullah);
      await api.removeMember(g.id, khaled.id);
      final after = (await api.getTask(t.id))!;
      expect(after.status, TaskStatus.newTask);
      expect(after.assigneeId, isNull);
      expect(after.assignmentMode, AssignmentMode.open);
    });

    test('personal tasks: no events, self-assigned, today sections and derived overdue', () async {
      await as_(mohammed);
      final now = DateTime.now();
      final p = await api.createTask(TaskDraft(title: 'شراء الخبز', dueAt: now.add(const Duration(minutes: 30))));
      final late = await api.createTask(TaskDraft(title: 'متأخرة', dueAt: now.subtract(const Duration(hours: 1))));
      expect(p.groupId, isNull);
      expect(p.assigneeId, mohammed.id);
      expect(await api.taskActivity(p.id), isEmpty);
      final rows = await api.myTasks();
      expect(rows.firstWhere((r) => r.task.id == late.id).section, 'overdue');
      expect(rows.firstWhere((r) => r.task.id == late.id).task.isOverdue, isTrue);
      expect(rows.firstWhere((r) => r.task.id == p.id).section, anyOf('today', 'upcoming'));
    });

    test('subtask depth limit and parent auto-completion', () async {
      final (g, _) = await homeWithMembers();
      await as_(abdullah);
      final parent = await api.createTask(TaskDraft(title: 'العزيمة', groupId: g.id, assignmentMode: AssignmentMode.collaborative, participantIds: [mohammed.id]));
      final s1 = await api.createTask(TaskDraft(title: 'الثلج', groupId: g.id, parentTaskId: parent.id));
      final s2 = await api.createTask(TaskDraft(title: 'المجلس', groupId: g.id, parentTaskId: parent.id));
      expect(() => api.createTask(TaskDraft(title: 'عمق ٢', groupId: g.id, parentTaskId: s1.id)), await throwsCode('subtask_depth_exceeded'));
      await as_(mohammed);
      await api.claimTask(s1.id);
      await api.completeTask(s1.id);
      expect((await api.getTask(parent.id))!.status, TaskStatus.newTask);
      await api.claimTask(s2.id);
      await api.completeTask(s2.id);
      expect((await api.getTask(parent.id))!.status, TaskStatus.completed);
    });

    test('proof required blocks completion without a note', () async {
      final (g, _) = await homeWithMembers();
      await as_(abdullah);
      final t = await api.createTask(TaskDraft(title: 'تنظيف المكتب', groupId: g.id, requiresProof: true, proofTypes: const ['note']));
      await as_(mohammed);
      await api.claimTask(t.id);
      expect(() => api.completeTask(t.id), await throwsCode('proof_required'));
      expect((await api.completeTask(t.id, note: 'نظّفت المكتب')).status, TaskStatus.completed);
    });

    test('optimistic lock on update', () async {
      final (g, _) = await homeWithMembers();
      await as_(abdullah);
      final t = await api.createTask(TaskDraft(title: 'x', groupId: g.id));
      await api.updateTask(t.id, const TaskPatch(title: 'y'), t.version);
      expect(() => api.updateTask(t.id, const TaskPatch(title: 'z'), t.version), await throwsCode('stale_version'));
    });
  });

  group('isolation, stats, deletion', () {
    test('an outsider sees nothing of the group', () async {
      final (g, _) = await homeWithMembers();
      await as_(abdullah);
      final t = await api.createTask(TaskDraft(title: 'سري', groupId: g.id));
      await as_(sara);
      expect(await api.getGroup(g.id), isNull);
      expect(await api.getTask(t.id), isNull);
      expect(() => api.groupTasks(g.id), await throwsCode('not_a_member'));
      expect(() => api.members(g.id), await throwsCode('not_a_member'));
      expect(() => api.claimTask(t.id), await throwsCode('not_a_member'));
      expect((await api.search('سري')).tasks, isEmpty);
    });

    test('stats visibility: private for home, all when configured', () async {
      final (g, _) = await homeWithMembers();
      await as_(abdullah);
      final t = await api.createTask(TaskDraft(title: 'x', groupId: g.id, points: 30));
      await as_(mohammed);
      await api.claimTask(t.id);
      await api.completeTask(t.id);
      final now = DateTime.now();
      expect((await api.groupStats(g.id, from: now.subtract(const Duration(days: 7)), to: now)).length, 1);
      await as_(abdullah);
      await api.updateGroupSettings(g.id, settings: const GroupSettings(statsVisibility: 'all'));
      await as_(mohammed);
      final all = await api.groupStats(g.id, from: now.subtract(const Duration(days: 7)), to: now);
      expect(all.length, 3);
      expect(all.firstWhere((m) => m.userId == mohammed.id).points, 30);
    });

    test('delete_account anonymises and keeps group history', () async {
      final (g, _) = await homeWithMembers();
      await as_(abdullah);
      final t = await api.createTask(TaskDraft(title: 'x', groupId: g.id));
      await as_(mohammed);
      await api.claimTask(t.id);
      await api.completeTask(t.id);
      await api.createTask(const TaskDraft(title: 'خاصة'));
      await api.deleteAccount();
      expect(api.currentUser, isNull);
      await as_(abdullah);
      expect((await api.getUser(mohammed.id))!.displayName, 'عضو سابق');
      expect((await api.getTask(t.id))!.completedBy, mohammed.id);
      expect((await api.members(g.id)).map((m) => m.userId), isNot(contains(mohammed.id)));
    });
  });

  test('Arabic normalisation matches the SQL function', () {
    expect(normalizeAr('التَّكْيِيف'), 'التكييف');
    expect(normalizeAr('إصلاح'), 'اصلاح');
    expect(normalizeAr('٤ مهام'), '4 مهام');
    expect(normalizeAr('Ahmed'), 'ahmed');
  });

  test('state survives reload from the store', () async {
    final store = MemoryStore();
    var a = LocalApi(store);
    await a.signInWithApple();
    await a.completeProfile(displayName: 'عبدالله');
    final g = await a.createGroup(name: 'البيت', type: GroupType.home);
    await a.createTask(TaskDraft(title: 'مهمة', groupId: g.id));
    a = LocalApi(store);
    await a.load();
    expect(a.currentUser?.displayName, 'عبدالله');
    expect((await a.groupTasks(g.id)).single.title, 'مهمة');
  });
}
