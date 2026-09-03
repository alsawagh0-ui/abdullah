import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../almunjez_api.dart';
import '../api_error.dart';

/// Persistence hook so the engine runs in tests without a platform.
abstract class LocalStore {
  Future<String?> read();
  Future<void> write(String json);
}

class MemoryStore implements LocalStore {
  String? _data;
  @override
  Future<String?> read() async => _data;
  @override
  Future<void> write(String json) async => _data = json;
}

/// On-device implementation of the same rules as backend/schema/001_initial.sql:
/// permission resolution, the task state machine, activity log and
/// notification fan-out. Single-user by nature (one device), but the data
/// model is identical so the UI does not know which backend it talks to.
class LocalApi implements AlMunjezApi {
  LocalApi(this._store);

  final LocalStore _store;
  final _changes = StreamController<void>.broadcast();
  final _auth = StreamController<AppUser?>.broadcast();
  final _rnd = Random();

  final Map<String, AppUser> _users = {};
  final Map<String, Group> _groups = {};
  final Map<String, _Invite> _invites = {};
  final Map<String, JoinRequest> _requests = {};
  final Map<String, Membership> _memberships = {};
  final Map<String, Task> _tasks = {};
  final Map<String, TaskComment> _comments = {};
  final List<ActivityEvent> _events = [];
  final Map<String, AppNotification> _notifications = {};
  String? _currentUserId;
  int _eventSeq = 0;

  Future<void> load() async {
    final raw = await _store.read();
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    for (final u in (j['users'] as List? ?? const [])) {
      final user = AppUser.fromJson(u as Map<String, dynamic>);
      _users[user.id] = user;
    }
    for (final g in (j['groups'] as List? ?? const [])) {
      final group = Group.fromJson(g as Map<String, dynamic>);
      _groups[group.id] = group;
    }
    for (final i in (j['invites'] as List? ?? const [])) {
      final inv = _Invite.fromJson(i as Map<String, dynamic>);
      _invites[inv.id] = inv;
    }
    for (final r in (j['requests'] as List? ?? const [])) {
      final req = JoinRequest.fromJson(r as Map<String, dynamic>);
      _requests[req.id] = req;
    }
    for (final m in (j['memberships'] as List? ?? const [])) {
      final mem = Membership.fromJson(m as Map<String, dynamic>);
      _memberships[mem.id] = mem;
    }
    for (final t in (j['tasks'] as List? ?? const [])) {
      final task = Task.fromJson(t as Map<String, dynamic>);
      _tasks[task.id] = task;
    }
    for (final c in (j['comments'] as List? ?? const [])) {
      final com = TaskComment.fromJson(c as Map<String, dynamic>);
      _comments[com.id] = com;
    }
    for (final e in (j['events'] as List? ?? const [])) {
      _events.add(ActivityEvent.fromJson(e as Map<String, dynamic>));
    }
    for (final n in (j['notifications'] as List? ?? const [])) {
      final notif = AppNotification.fromJson(n as Map<String, dynamic>);
      _notifications[notif.id] = notif;
    }
    _eventSeq = _events.isEmpty ? 0 : _events.map((e) => e.id).reduce(max);
    _currentUserId = j['current_user_id'] as String?;
  }

  Future<void> _save() => _store.write(jsonEncode({
        'users': _users.values.map((e) => e.toJson()).toList(),
        'groups': _groups.values.map((e) => e.toJson()).toList(),
        'invites': _invites.values.map((e) => e.toJson()).toList(),
        'requests': _requests.values.map((e) => e.toJson()).toList(),
        'memberships': _memberships.values.map((e) => e.toJson()).toList(),
        'tasks': _tasks.values.map((e) => e.toJson()).toList(),
        'comments': _comments.values.map((e) => e.toJson()).toList(),
        'events': _events.map((e) => e.toJson()).toList(),
        'notifications': _notifications.values.map((e) => e.toJson()).toList(),
        'current_user_id': _currentUserId,
      }));

  Future<void> _commit() async {
    await _save();
    _changes.add(null);
  }

  String _id() {
    const hex = '0123456789abcdef';
    String s(int n) => List.generate(n, (_) => hex[_rnd.nextInt(16)]).join();
    return '${s(8)}-${s(4)}-4${s(3)}-a${s(3)}-${s(12)}';
  }

  Never _fail(String code, [Map<String, dynamic> detail = const {}]) => throw ApiException(code, detail);

  String _uid() => _currentUserId ?? _fail('unauthenticated');

  // ------------------------------------------------------------------ rules
  Membership? _membership(String userId, String groupId) => _memberships.values
      .where((m) => m.userId == userId && m.groupId == groupId && m.isActive)
      .firstOrNull;

  bool _isActiveMember(String userId, String groupId) => _membership(userId, groupId) != null;

  MembershipRole? _role(String userId, String groupId) => _membership(userId, groupId)?.role;

  /// Same resolution order as has_permission_for (doc 06 §8).
  bool _has(String userId, String groupId, String key) {
    final m = _membership(userId, groupId);
    if (m == null) return false;
    if (m.role == MembershipRole.owner) return true;
    if (key == Perm.transfer || key == Perm.archive) return false;
    final override = m.permissions[key];
    if (override != null) return override;
    final g = _groups[groupId]!;
    if (key == Perm.taskCreate) return m.role == MembershipRole.admin || g.settings.membersCanCreateTasks;
    if (key == Perm.activityView) return m.role == MembershipRole.admin || g.settings.activityVisibleToMembers;
    if (key == Perm.statsViewAll) {
      final v = g.settings.effectiveStatsVisibility(g.type);
      return (m.role == MembershipRole.admin && (v == 'admins' || v == 'all')) || v == 'all';
    }
    if (m.role == MembershipRole.admin) return Perm.adminDefaults.contains(key);
    return false;
  }

  bool _hasMine(String groupId, String key) => _has(_uid(), groupId, key);

  Iterable<String> _membersWith(String groupId, String key) =>
      _memberships.values.where((m) => m.groupId == groupId && m.isActive && _has(m.userId, groupId, key)).map((m) => m.userId);

  bool _canView(String userId, Task t) => t.groupId == null ? t.creatorId == userId : _isActiveMember(userId, t.groupId!);

  Task _taskForUpdate(String id) {
    final t = _tasks[id] ?? _fail('not_found');
    final uid = _uid();
    if (t.groupId != null && !_isActiveMember(uid, t.groupId!)) _fail('not_a_member');
    if (t.groupId == null && t.creatorId != uid) _fail('not_found');
    return t;
  }

  bool _canApprove(Task t, String userId) =>
      t.groupId != null && userId != t.assigneeId && (t.creatorId == userId || _has(userId, t.groupId!, Perm.approveCompletion));

  // ------------------------------------------------------------------ events & fan-out
  int _log(String? groupId, String action, String targetType, String? targetId, [Map<String, dynamic> meta = const {}]) {
    final e = ActivityEvent(
      id: ++_eventSeq,
      groupId: groupId,
      actorId: _currentUserId,
      action: action,
      targetType: targetType,
      targetId: targetId,
      metadata: meta,
      createdAt: DateTime.now(),
    );
    _events.add(e);
    _fanout(e);
    return e.id;
  }

  void _notify(String? userId, String type, {String? taskId, String? groupId, String? actorId, Map<String, dynamic> data = const {}}) {
    if (userId == null || userId == actorId) return;
    if (_users[userId]?.isDeleted ?? true) return;
    final n = AppNotification(id: _id(), userId: userId, type: type, taskId: taskId, groupId: groupId, actorId: actorId, data: data, createdAt: DateTime.now());
    _notifications[n.id] = n;
  }

  void _fanout(ActivityEvent e) {
    final t = e.targetType == 'task' && e.targetId != null ? _tasks[e.targetId] : null;
    final data = {...e.metadata, if (t != null) 'title': t.title};
    void n(String? u, [String? type]) => _notify(u, type ?? e.action, taskId: t?.id, groupId: e.groupId, actorId: e.actorId, data: data);
    switch (e.action) {
      case 'task.created':
        if (t == null) return;
        if (t.assignmentMode == AssignmentMode.assigned) {
          n(t.assigneeId, 'task.assigned');
        } else {
          for (final m in _memberships.values.where((m) => m.groupId == t.groupId && m.isActive)) {
            n(m.userId);
          }
          for (final p in t.participantIds) {
            n(p, 'task.assigned');
          }
        }
      case 'task.claimed' || 'task.released' || 'task.completed':
        n(t?.creatorId);
      case 'task.submitted':
        n(t?.creatorId);
        for (final u in _membersWith(t!.groupId!, Perm.approveCompletion)) {
          if (u != t.creatorId) n(u);
        }
      case 'task.approved' || 'task.rejected' || 'task.cancelled' || 'task.reopened':
        n(t?.assigneeId);
      case 'task.reassigned':
        n(e.metadata['old_assignee_id'] as String?);
        n(e.metadata['new_assignee_id'] as String?, 'task.assigned');
      case 'task.unassigned':
        n(e.metadata['old_assignee_id'] as String?);
        n(t?.creatorId);
      case 'task.updated':
        if (e.metadata.containsKey('due_at') || e.metadata.containsKey('priority')) n(t?.assigneeId);
      case 'task.comment':
        if (t == null) return;
        final rec = <String?>{t.creatorId, t.assigneeId, ...t.participantIds, ..._comments.values.where((c) => c.taskId == t.id && c.kind == 'comment').map((c) => c.authorId)};
        for (final u in rec) {
          n(u);
        }
      case 'join.requested':
        for (final u in _membersWith(e.groupId!, Perm.approveJoins)) {
          n(u);
        }
      case 'join.accepted' || 'join.rejected' || 'member.removed' || 'member.role_changed':
        n(e.metadata['user_id'] as String?);
      case 'group.ownership_transferred':
        n(e.metadata['new_owner_id'] as String?);
        for (final m in _memberships.values.where((m) => m.groupId == e.groupId && m.isActive && m.role == MembershipRole.admin)) {
          n(m.userId);
        }
      default:
        break;
    }
  }

  // ------------------------------------------------------------------ identity
  @override
  Stream<void> get changes => _changes.stream;

  @override
  AppUser? get currentUser => _currentUserId == null ? null : _users[_currentUserId!];

  @override
  Stream<AppUser?> get authState => _auth.stream;

  Future<void> _signInAs(AppUser u) async {
    _users[u.id] = u;
    _currentUserId = u.id;
    await _commit();
    _auth.add(u);
  }

  @override
  Future<void> signInWithApple() => _signInAs(AppUser(id: _id(), displayName: ''));

  @override
  Future<void> sendPhoneOtp(String phone) async {}

  @override
  Future<void> verifyPhoneOtp(String phone, String code) async {
    if (code.length != 6) _fail('invalid_otp');
    final existing = _users.values.where((u) => u.avatarPath == 'phone:$phone').firstOrNull;
    await _signInAs(existing ?? AppUser(id: _id(), displayName: '', avatarPath: 'phone:$phone'));
  }

  @override
  Future<void> signInDemo() async {
    if (_users.containsKey(DemoSeed.abdullah)) {
      _currentUserId = DemoSeed.abdullah;
      await _commit();
      _auth.add(currentUser);
      return;
    }
    await DemoSeed.apply(this);
    _auth.add(currentUser);
  }

  /// Test/demo hook: switch identity on this device to an existing user.
  Future<void> signInDemoAs(String userId) async {
    final u = _users[userId];
    if (u == null) _fail('not_found');
    _currentUserId = userId;
    await _commit();
    _auth.add(u);
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    await _commit();
    _auth.add(null);
  }

  @override
  Future<AppUser> completeProfile({required String displayName, String? locale}) async {
    if (displayName.trim().isEmpty) _fail('display_name_required');
    final u = _users[_uid()]!.copyWith(displayName: displayName.trim(), locale: locale);
    _users[u.id] = u;
    await _commit();
    _auth.add(u);
    return u;
  }

  @override
  Future<void> deleteAccount() async {
    final uid = _uid();
    final soleOwner = _groups.values.any((g) =>
        g.ownerId == uid && !g.isArchived && _memberships.values.any((m) => m.groupId == g.id && m.isActive && m.userId != uid));
    if (soleOwner) _fail('owner_must_transfer');
    for (final g in _groups.values.where((g) => g.ownerId == uid && !g.isArchived).toList()) {
      _groups[g.id] = g.copyWith(archivedAt: DateTime.now());
    }
    _tasks.removeWhere((_, t) => t.groupId == null && t.creatorId == uid);
    _notifications.removeWhere((_, n) => n.userId == uid);
    for (final r in _requests.values.where((r) => r.userId == uid && r.status == JoinRequestStatus.pending).toList()) {
      _requests[r.id] = r.copyWith(status: JoinRequestStatus.cancelled, decidedAt: DateTime.now());
    }
    for (final m in _memberships.values.where((m) => m.userId == uid && m.isActive).toList()) {
      _memberships[m.id] = m.copyWith(status: MembershipStatus.left, leftAt: DateTime.now());
    }
    for (final t in _tasks.values.where((t) => t.assigneeId == uid && t.groupId != null && (t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)).toList()) {
      _tasks[t.id] = t.copyWith(assigneeId: null, status: TaskStatus.newTask, assignmentMode: AssignmentMode.open, version: t.version + 1);
    }
    _users[uid] = _users[uid]!.copyWith(displayName: 'عضو سابق', deletedAt: DateTime.now());
    _currentUserId = null;
    await _commit();
    _auth.add(null);
  }

  @override
  Future<void> registerDevice(String token) async {}

  @override
  Future<AppUser?> getUser(String id) async => _users[id];

  @override
  Future<Map<String, AppUser>> getUsers(Iterable<String> ids) async => {for (final id in ids) if (_users[id] != null) id: _users[id]!};

  // ------------------------------------------------------------------ groups
  @override
  Future<List<GroupSummary>> myGroups() async {
    final uid = _uid();
    final out = <GroupSummary>[];
    for (final m in _memberships.values.where((m) => m.userId == uid && m.isActive)) {
      final g = _groups[m.groupId]!;
      out.add(GroupSummary(
        group: g,
        role: m.role,
        openCount: _tasks.values.where((t) => t.groupId == g.id && t.isOpenForClaim).length,
        mineCount: _tasks.values.where((t) => t.groupId == g.id && t.assigneeId == uid && (t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)).length,
        pendingRequests: _has(uid, g.id, Perm.approveJoins) ? _requests.values.where((r) => r.groupId == g.id && r.status == JoinRequestStatus.pending).length : 0,
      ));
    }
    out.sort((a, b) => a.group.createdAt.compareTo(b.group.createdAt));
    return out;
  }

  @override
  Future<Group?> getGroup(String id) async {
    final g = _groups[id];
    if (g == null || !_isActiveMember(_uid(), id)) return null;
    return g;
  }

  @override
  Future<Group> createGroup({required String name, required GroupType type, GroupSettings? settings}) async {
    final uid = _uid();
    if (name.trim().isEmpty) _fail('name_required');
    final g = Group(id: _id(), name: name.trim(), type: type, ownerId: uid, settings: settings ?? const GroupSettings(), memberCount: 1, createdAt: DateTime.now());
    _groups[g.id] = g;
    final m = Membership(id: _id(), groupId: g.id, userId: uid, role: MembershipRole.owner, joinedAt: DateTime.now());
    _memberships[m.id] = m;
    final inv = _Invite(id: _id(), groupId: g.id, code: _genCode(), createdAt: DateTime.now());
    _invites[inv.id] = inv;
    _log(g.id, 'group.created', 'group', g.id, {'name': g.name, 'type': type.wire});
    await _commit();
    return g;
  }

  @override
  Future<Group> updateGroupSettings(String groupId, {String? name, GroupType? type, GroupSettings? settings}) async {
    if (!_hasMine(groupId, Perm.manageSettings)) _fail('permission_denied');
    var g = _groups[groupId] ?? _fail('not_found');
    if (g.isArchived) _fail('invalid_transition');
    g = g.copyWith(name: name?.trim(), type: type, settings: settings);
    _groups[groupId] = g;
    _log(groupId, 'group.updated', 'group', groupId, settings?.toJson() ?? const {});
    await _commit();
    return g;
  }

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  String _genCode() {
    while (true) {
      final c = List.generate(8, (_) => _alphabet[_rnd.nextInt(_alphabet.length)]).join();
      if (!_invites.values.any((i) => i.code == c)) return c;
    }
  }

  _Invite? _activeInvite(String groupId) => _invites.values.where((i) => i.groupId == groupId && i.revokedAt == null).firstOrNull;

  @override
  Future<String?> activeInviteCode(String groupId) async {
    if (!_hasMine(groupId, Perm.manageInvite)) return null;
    return _activeInvite(groupId)?.code;
  }

  @override
  Future<String> regenerateInvite(String groupId) async {
    if (!_hasMine(groupId, Perm.manageInvite)) _fail('permission_denied');
    final cur = _activeInvite(groupId);
    if (cur != null) _invites[cur.id] = cur.copyWith(revokedAt: DateTime.now());
    final inv = _Invite(id: _id(), groupId: groupId, code: _genCode(), createdAt: DateTime.now());
    _invites[inv.id] = inv;
    _log(groupId, 'invite.regenerated', 'group', groupId);
    await _commit();
    return inv.code;
  }

  @override
  Future<void> revokeInvite(String groupId) async {
    if (!_hasMine(groupId, Perm.manageInvite)) _fail('permission_denied');
    final cur = _activeInvite(groupId);
    if (cur != null) _invites[cur.id] = cur.copyWith(revokedAt: DateTime.now());
    _log(groupId, 'invite.revoked', 'group', groupId);
    await _commit();
  }

  _Invite _findInvite(String code) {
    final c = code.trim().toUpperCase();
    final inv = _invites.values.where((i) => i.code == c && i.revokedAt == null).firstOrNull;
    if (inv == null || (_groups[inv.groupId]?.isArchived ?? true)) _fail('invalid_invite');
    return inv;
  }

  @override
  Future<InvitePreview> previewInvite(String code) async {
    final uid = _uid();
    final inv = _findInvite(code);
    final g = _groups[inv.groupId]!;
    return InvitePreview(
      groupName: g.name,
      groupType: g.type,
      memberCount: g.memberCount,
      alreadyMember: _isActiveMember(uid, g.id),
      pending: _requests.values.any((r) => r.groupId == g.id && r.userId == uid && r.status == JoinRequestStatus.pending),
    );
  }

  @override
  Future<JoinRequest> requestJoin(String code, {String? message}) async {
    final uid = _uid();
    final inv = _findInvite(code);
    if (_isActiveMember(uid, inv.groupId)) _fail('already_member');
    final existing = _requests.values.where((r) => r.groupId == inv.groupId && r.userId == uid && r.status == JoinRequestStatus.pending).firstOrNull;
    if (existing != null) return existing;
    final r = JoinRequest(id: _id(), groupId: inv.groupId, userId: uid, message: message, createdAt: DateTime.now());
    _requests[r.id] = r;
    _log(inv.groupId, 'join.requested', 'join_request', r.id, {'user_id': uid});
    await _commit();
    return r;
  }

  @override
  Future<List<JoinRequest>> pendingJoinRequests(String groupId) async {
    if (!_hasMine(groupId, Perm.approveJoins)) return const [];
    return _requests.values
        .where((r) => r.groupId == groupId && r.status == JoinRequestStatus.pending)
        .map((r) => r.copyWith(user: _users[r.userId], groupName: _groups[groupId]?.name))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<JoinRequest>> myJoinRequests() async {
    final uid = _uid();
    return _requests.values.where((r) => r.userId == uid && r.status == JoinRequestStatus.pending).map((r) => r.copyWith(groupName: _groups[r.groupId]?.name)).toList();
  }

  @override
  Future<void> cancelJoinRequest(String requestId) async {
    final r = _requests[requestId];
    if (r == null || r.userId != _uid() || r.status != JoinRequestStatus.pending) _fail('invalid_transition');
    _requests[requestId] = r.copyWith(status: JoinRequestStatus.cancelled, decidedAt: DateTime.now());
    await _commit();
  }

  @override
  Future<void> decideJoin(String requestId, {required bool accept}) async {
    final r = _requests[requestId] ?? _fail('not_found');
    if (!_hasMine(r.groupId, Perm.approveJoins)) _fail('permission_denied');
    if (r.status != JoinRequestStatus.pending) _fail('invalid_transition');
    if (_groups[r.groupId]!.isArchived) _fail('invalid_transition');
    if (accept) {
      final existing = _memberships.values.where((m) => m.groupId == r.groupId && m.userId == r.userId).firstOrNull;
      if (existing != null) {
        _memberships[existing.id] = existing.copyWith(role: MembershipRole.member, status: MembershipStatus.active, permissions: const {}, joinedAt: DateTime.now());
      } else {
        final m = Membership(id: _id(), groupId: r.groupId, userId: r.userId, role: MembershipRole.member, joinedAt: DateTime.now());
        _memberships[m.id] = m;
      }
      _refreshCount(r.groupId);
      _requests[r.id] = r.copyWith(status: JoinRequestStatus.accepted, decidedAt: DateTime.now());
      _log(r.groupId, 'join.accepted', 'join_request', r.id, {'user_id': r.userId});
    } else {
      _requests[r.id] = r.copyWith(status: JoinRequestStatus.rejected, decidedAt: DateTime.now());
      _log(r.groupId, 'join.rejected', 'join_request', r.id, {'user_id': r.userId});
    }
    await _commit();
  }

  void _refreshCount(String groupId) {
    final g = _groups[groupId]!;
    _groups[groupId] = g.copyWith(memberCount: _memberships.values.where((m) => m.groupId == groupId && m.isActive).length);
  }

  // ------------------------------------------------------------------ membership
  @override
  Future<List<Member>> members(String groupId) async {
    if (!_isActiveMember(_uid(), groupId)) _fail('not_a_member');
    final out = _memberships.values
        .where((m) => m.groupId == groupId && m.isActive)
        .map((m) => Member(membership: m, user: _users[m.userId] ?? AppUser(id: m.userId, displayName: '')))
        .toList();
    out.sort((a, b) {
      final r = a.role.index.compareTo(b.role.index);
      return r != 0 ? r : a.membership.joinedAt.compareTo(b.membership.joinedAt);
    });
    return out;
  }

  @override
  Future<Set<String>> myPermissions(String groupId) async {
    final uid = _uid();
    return {for (final k in Perm.all) if (_has(uid, groupId, k)) k};
  }

  @override
  Future<MembershipRole?> myRole(String groupId) async => _role(_uid(), groupId);

  @override
  Future<void> setMemberRole(String groupId, String userId, MembershipRole role) async {
    final uid = _uid();
    final caller = _role(uid, groupId);
    if (!_has(uid, groupId, Perm.manageMembers)) _fail('permission_denied');
    if (role == MembershipRole.owner) _fail('use_transfer_ownership');
    final target = _membership(userId, groupId) ?? _fail('not_a_member');
    if (target.role == MembershipRole.owner) _fail('permission_denied');
    if (caller == MembershipRole.admin && (target.role == MembershipRole.admin || userId == uid)) _fail('permission_denied');
    _memberships[target.id] = target.copyWith(role: role, permissions: role == MembershipRole.member ? const {} : null);
    _log(groupId, 'member.role_changed', 'membership', target.id, {'user_id': userId, 'role': role.wire});
    await _commit();
  }

  void _releaseTasksOf(String groupId, String userId) {
    for (final t in _tasks.values.where((t) => t.groupId == groupId && t.assigneeId == userId && (t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)).toList()) {
      _tasks[t.id] = t.copyWith(assigneeId: null, status: TaskStatus.newTask, assignmentMode: AssignmentMode.open, claimedAt: null, startedAt: null, version: t.version + 1);
      _log(groupId, 'task.unassigned', 'task', t.id, {'old_assignee_id': userId, 'reason': 'member_left'});
    }
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    final uid = _uid();
    final caller = _role(uid, groupId);
    if (!_has(uid, groupId, Perm.manageMembers)) _fail('permission_denied');
    final target = _membership(userId, groupId) ?? _fail('not_a_member');
    if (target.role == MembershipRole.owner || userId == uid) _fail('permission_denied');
    if (caller == MembershipRole.admin && target.role == MembershipRole.admin) _fail('permission_denied');
    _memberships[target.id] = target.copyWith(status: MembershipStatus.removed, leftAt: DateTime.now(), permissions: const {});
    _refreshCount(groupId);
    _releaseTasksOf(groupId, userId);
    _log(groupId, 'member.removed', 'membership', target.id, {'user_id': userId});
    await _commit();
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final uid = _uid();
    final m = _membership(uid, groupId) ?? _fail('not_a_member');
    if (m.role == MembershipRole.owner) _fail('owner_must_transfer');
    _memberships[m.id] = m.copyWith(status: MembershipStatus.left, leftAt: DateTime.now(), permissions: const {});
    _refreshCount(groupId);
    _releaseTasksOf(groupId, uid);
    _log(groupId, 'member.left', 'membership', m.id, {'user_id': uid});
    await _commit();
  }

  @override
  Future<void> transferOwnership(String groupId, String toUserId) async {
    final uid = _uid();
    if (_role(uid, groupId) != MembershipRole.owner) _fail('permission_denied');
    final target = _membership(toUserId, groupId) ?? _fail('not_a_member');
    if (toUserId == uid) return;
    final me = _membership(uid, groupId)!;
    _memberships[me.id] = me.copyWith(role: MembershipRole.admin);
    _memberships[target.id] = target.copyWith(role: MembershipRole.owner, permissions: const {});
    _groups[groupId] = _groups[groupId]!.copyWith(ownerId: toUserId);
    _log(groupId, 'group.ownership_transferred', 'group', groupId, {'new_owner_id': toUserId, 'old_owner_id': uid});
    await _commit();
  }

  @override
  Future<void> archiveGroup(String groupId) async {
    if (!_hasMine(groupId, Perm.archive)) _fail('permission_denied');
    _groups[groupId] = _groups[groupId]!.copyWith(archivedAt: DateTime.now());
    final inv = _activeInvite(groupId);
    if (inv != null) _invites[inv.id] = inv.copyWith(revokedAt: DateTime.now());
    for (final r in _requests.values.where((r) => r.groupId == groupId && r.status == JoinRequestStatus.pending).toList()) {
      _requests[r.id] = r.copyWith(status: JoinRequestStatus.cancelled, decidedAt: DateTime.now());
    }
    _log(groupId, 'group.archived', 'group', groupId);
    await _commit();
  }

  // ------------------------------------------------------------------ tasks
  @override
  Future<List<Task>> groupTasks(String groupId) async {
    if (!_isActiveMember(_uid(), groupId)) _fail('not_a_member');
    return _tasks.values.where((t) => t.groupId == groupId && t.parentTaskId == null).toList()..sort(_taskOrder);
  }

  int _taskOrder(Task a, Task b) {
    final o = (b.isOverdue ? 1 : 0).compareTo(a.isOverdue ? 1 : 0);
    if (o != 0) return o;
    if (a.dueAt != null && b.dueAt != null) return a.dueAt!.compareTo(b.dueAt!);
    if (a.dueAt != null) return -1;
    if (b.dueAt != null) return 1;
    return b.createdAt.compareTo(a.createdAt);
  }

  @override
  Future<List<Task>> personalTasks() async {
    final uid = _uid();
    return _tasks.values.where((t) => t.groupId == null && t.creatorId == uid).toList()..sort(_taskOrder);
  }

  @override
  Future<List<TodayRow>> myTasks() async {
    final uid = _uid();
    final now = DateTime.now();
    final rows = <TodayRow>[];
    for (final t in _tasks.values) {
      if (!t.status.isOpenState) continue;
      final mine = t.assigneeId == uid || (t.groupId == null && t.creatorId == uid) || t.participantIds.contains(uid);
      if (!mine) continue;
      final section = t.isOverdue
          ? 'overdue'
          : t.dueAt == null
              ? 'no_date'
              : (t.dueAt!.year == now.year && t.dueAt!.month == now.month && t.dueAt!.day == now.day)
                  ? 'today'
                  : 'upcoming';
      rows.add(TodayRow(task: t, section: section, groupName: t.groupId == null ? null : _groups[t.groupId]?.name));
    }
    rows.sort((a, b) => _taskOrder(a.task, b.task));
    return rows;
  }

  @override
  Future<DashboardCounts> dashboardCounts(String groupId) async {
    final uid = _uid();
    final ts = _tasks.values.where((t) => t.groupId == groupId);
    final now = DateTime.now();
    return DashboardCounts(
      newCount: ts.where((t) => t.status == TaskStatus.newTask).length,
      inProgress: ts.where((t) => t.status == TaskStatus.inProgress).length,
      awaiting: ts.where((t) => t.status == TaskStatus.awaitingApproval).length,
      completed: ts.where((t) => t.status == TaskStatus.completed).length,
      completedToday: ts.where((t) => t.status == TaskStatus.completed && t.completedAt != null && t.completedAt!.year == now.year && t.completedAt!.month == now.month && t.completedAt!.day == now.day).length,
      overdue: ts.where((t) => t.isOverdue).length,
      mine: ts.where((t) => t.assigneeId == uid && t.status.isOpenState).length,
    );
  }

  @override
  Future<Task?> getTask(String id) async {
    final t = _tasks[id];
    if (t == null || !_canView(_uid(), t)) return null;
    return t;
  }

  @override
  Future<List<Task>> subtasks(String parentId) async => _tasks.values.where((t) => t.parentTaskId == parentId).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<Task> createTask(TaskDraft d) async {
    final uid = _uid();
    if (d.title.trim().isEmpty) _fail('title_required');
    var mode = d.assignmentMode;
    var assignee = d.assigneeId;
    var approval = d.requiresApproval ?? false;
    if (d.groupId == null) {
      mode = AssignmentMode.assigned;
      assignee = uid;
      approval = false;
    } else {
      final g = _groups[d.groupId] ?? _fail('not_found');
      if (!_isActiveMember(uid, g.id)) _fail('not_a_member');
      if (g.isArchived) _fail('group_archived');
      if (!_has(uid, g.id, Perm.taskCreate)) _fail('permission_denied');
      if (mode == AssignmentMode.assigned) {
        if (assignee == null) _fail('assignee_required');
        if (!_isActiveMember(assignee, g.id)) _fail('assignee_not_member');
        if (assignee != uid && !_has(uid, g.id, Perm.assignOthers)) _fail('permission_denied');
      } else {
        assignee = null;
      }
      approval = d.requiresApproval ?? g.settings.requiresApprovalDefault;
      for (final p in d.participantIds) {
        if (!_isActiveMember(p, g.id)) _fail('participant_not_member');
      }
      if (d.parentTaskId != null) {
        final parent = _tasks[d.parentTaskId] ?? _fail('not_found');
        if (parent.parentTaskId != null) _fail('subtask_depth_exceeded');
        if (parent.groupId != d.groupId) _fail('subtask_group_mismatch');
      }
    }
    final now = DateTime.now();
    final t = Task(
      id: _id(),
      groupId: d.groupId,
      creatorId: uid,
      title: d.title.trim(),
      description: (d.description?.trim().isEmpty ?? true) ? null : d.description!.trim(),
      priority: d.priority,
      assignmentMode: mode,
      assigneeId: assignee,
      dueAt: d.dueAt,
      dueDateOnly: d.dueDateOnly,
      points: d.points,
      requiresProof: d.requiresProof,
      proofTypes: d.proofTypes,
      requiresApproval: approval,
      parentTaskId: d.parentTaskId,
      createdAt: now,
      updatedAt: now,
      participantIds: mode == AssignmentMode.collaborative ? d.participantIds : const [],
    );
    _tasks[t.id] = t;
    if (d.groupId != null) {
      _log(d.groupId, 'task.created', 'task', t.id, {'assignment_mode': mode.wire, 'assignee_id': assignee, 'parent_task_id': d.parentTaskId});
    }
    await _commit();
    return t;
  }

  @override
  Future<Task> updateTask(String id, TaskPatch p, int version) async {
    final uid = _uid();
    var t = _taskForUpdate(id);
    if (!(t.creatorId == uid || (t.groupId != null && _has(uid, t.groupId!, Perm.editAny)))) _fail('permission_denied');
    if (t.status.isTerminal) _fail('invalid_transition', {'status': t.status.wire});
    if (t.version != version) _fail('stale_version', {'version': t.version});
    if (t.status == TaskStatus.awaitingApproval && p.requiresApproval != null) _fail('invalid_transition');
    t = t.copyWith(
      title: (p.title?.trim().isEmpty ?? true) ? null : p.title!.trim(),
      description: p.description,
      priority: p.priority,
      requiresProof: p.requiresProof,
      requiresApproval: p.requiresApproval,
      version: t.version + 1,
    );
    if (p.dueAt != null || p.clearDue) t = t.copyWith(dueAt: p.dueAt);
    if (p.points != null || p.clearPoints) t = t.copyWith(points: p.points);
    _tasks[id] = t;
    if (t.groupId != null) _log(t.groupId, 'task.updated', 'task', id, p.toJson()..remove('description'));
    await _commit();
    return t;
  }

  @override
  Future<Task> claimTask(String id) async {
    final uid = _uid();
    final t = _tasks[id] ?? _fail('not_found');
    if (t.groupId == null) _fail('not_found');
    if (!_isActiveMember(uid, t.groupId!)) _fail('not_a_member');
    if (t.isOpenForClaim) {
      final now = DateTime.now();
      final u = t.copyWith(assigneeId: uid, status: TaskStatus.inProgress, claimedAt: now, startedAt: now, version: t.version + 1);
      _tasks[id] = u;
      _log(t.groupId, 'task.claimed', 'task', id);
      await _commit();
      return u;
    }
    if (t.assigneeId == uid && t.status == TaskStatus.inProgress) return t;
    if (t.assigneeId != null && (t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)) {
      _fail('already_claimed', {'assignee_id': t.assigneeId, 'assignee_name': _users[t.assigneeId]?.displayName});
    }
    _fail('invalid_transition', {'status': t.status.wire});
  }

  @override
  Future<Task> startTask(String id) async {
    final uid = _uid();
    final t = _taskForUpdate(id);
    if (t.assigneeId != uid) _fail('permission_denied');
    if (t.status != TaskStatus.newTask) _fail('invalid_transition', {'status': t.status.wire});
    final u = t.copyWith(status: TaskStatus.inProgress, startedAt: DateTime.now(), version: t.version + 1);
    _tasks[id] = u;
    if (t.groupId != null) _log(t.groupId, 'task.started', 'task', id);
    await _commit();
    return u;
  }

  @override
  Future<Task> releaseTask(String id) async {
    final uid = _uid();
    final t = _taskForUpdate(id);
    if (t.groupId == null) _fail('invalid_transition');
    if (t.assigneeId != uid) _fail('permission_denied');
    if (!(t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)) _fail('invalid_transition', {'status': t.status.wire});
    final u = t.copyWith(assigneeId: null, status: TaskStatus.newTask, assignmentMode: AssignmentMode.open, claimedAt: null, startedAt: null, version: t.version + 1);
    _tasks[id] = u;
    _log(t.groupId, 'task.released', 'task', id, {'old_assignee_id': uid});
    await _commit();
    return u;
  }

  @override
  Future<Task> reassignTask(String id, String assigneeId) async {
    final uid = _uid();
    final t = _taskForUpdate(id);
    if (t.groupId == null) _fail('invalid_transition');
    if (!(t.creatorId == uid || _has(uid, t.groupId!, Perm.assignOthers))) _fail('permission_denied');
    if (!_isActiveMember(assigneeId, t.groupId!)) _fail('assignee_not_member');
    if (!(t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)) _fail('invalid_transition', {'status': t.status.wire});
    final u = t.copyWith(assigneeId: assigneeId, status: TaskStatus.newTask, assignmentMode: AssignmentMode.assigned, claimedAt: null, startedAt: null, version: t.version + 1);
    _tasks[id] = u;
    _log(t.groupId, 'task.reassigned', 'task', id, {'old_assignee_id': t.assigneeId, 'new_assignee_id': assigneeId});
    await _commit();
    return u;
  }

  @override
  Future<Task> unassignTask(String id) async {
    final uid = _uid();
    final t = _taskForUpdate(id);
    if (t.groupId == null) _fail('invalid_transition');
    if (!(t.creatorId == uid || _has(uid, t.groupId!, Perm.assignOthers))) _fail('permission_denied');
    if (!(t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress) || t.assigneeId == null) _fail('invalid_transition', {'status': t.status.wire});
    final u = t.copyWith(assigneeId: null, status: TaskStatus.newTask, assignmentMode: AssignmentMode.open, claimedAt: null, startedAt: null, version: t.version + 1);
    _tasks[id] = u;
    _log(t.groupId, 'task.unassigned', 'task', id, {'old_assignee_id': t.assigneeId});
    await _commit();
    return u;
  }

  @override
  Future<Task> completeTask(String id, {String? note}) async {
    final uid = _uid();
    final t = _taskForUpdate(id);
    if (t.assigneeId != uid) _fail('permission_denied');
    if (!(t.status == TaskStatus.newTask || t.status == TaskStatus.inProgress)) _fail('invalid_transition', {'status': t.status.wire});
    final hasNote = note != null && note.trim().isNotEmpty;
    if (t.requiresProof && !(hasNote && t.proofTypes.contains('note'))) _fail('proof_required', {'proof_types': t.proofTypes});
    if (hasNote) {
      final c = TaskComment(id: _id(), taskId: id, authorId: uid, body: note.trim(), kind: 'proof_note', createdAt: DateTime.now());
      _comments[c.id] = c;
    }
    final needsApproval = t.groupId != null && t.requiresApproval && (t.creatorId != uid || _membersWith(t.groupId!, Perm.approveCompletion).any((u) => u != uid));
    final Task u;
    if (needsApproval) {
      u = t.copyWith(status: TaskStatus.awaitingApproval, submittedAt: DateTime.now(), version: t.version + 1);
      _tasks[id] = u;
      _log(t.groupId, 'task.submitted', 'task', id);
    } else {
      u = t.copyWith(status: TaskStatus.completed, completedAt: DateTime.now(), completedBy: uid, version: t.version + 1);
      _tasks[id] = u;
      if (t.groupId != null) _log(t.groupId, 'task.completed', 'task', id, {'late': t.dueAt != null && DateTime.now().isAfter(t.dueAt!)});
      _autoCompleteParent(u);
    }
    await _commit();
    return u;
  }

  void _autoCompleteParent(Task sub) {
    if (sub.parentTaskId == null) return;
    final p = _tasks[sub.parentTaskId];
    if (p == null || !(p.status == TaskStatus.newTask || p.status == TaskStatus.inProgress)) return;
    final allDone = _tasks.values.where((s) => s.parentTaskId == p.id).every((s) => s.status.isTerminal);
    if (!allDone) return;
    _tasks[p.id] = p.copyWith(status: TaskStatus.completed, completedAt: DateTime.now(), completedBy: sub.completedBy, version: p.version + 1);
    _log(p.groupId, 'task.completed', 'task', p.id, {'via': 'subtasks'});
  }

  @override
  Future<Task> approveCompletion(String id) async {
    final uid = _uid();
    final t = _taskForUpdate(id);
    if (t.status != TaskStatus.awaitingApproval) _fail('invalid_transition', {'status': t.status.wire});
    if (!_canApprove(t, uid)) _fail('permission_denied');
    final u = t.copyWith(status: TaskStatus.completed, completedAt: DateTime.now(), completedBy: t.assigneeId, approvedBy: uid, approvedAt: DateTime.now(), version: t.version + 1);
    _tasks[id] = u;
    _log(t.groupId, 'task.approved', 'task', id, {'late': t.dueAt != null && t.submittedAt != null && t.submittedAt!.isAfter(t.dueAt!)});
    _autoCompleteParent(u);
    await _commit();
    return u;
  }

  @override
  Future<Task> rejectCompletion(String id, String reason) async {
    final uid = _uid();
    if (reason.trim().isEmpty) _fail('reason_required');
    final t = _taskForUpdate(id);
    if (t.status != TaskStatus.awaitingApproval) _fail('invalid_transition', {'status': t.status.wire});
    if (!_canApprove(t, uid)) _fail('permission_denied');
    final u = t.copyWith(status: TaskStatus.inProgress, submittedAt: null, version: t.version + 1);
    _tasks[id] = u;
    final c = TaskComment(id: _id(), taskId: id, authorId: uid, body: reason.trim(), kind: 'rejection_reason', createdAt: DateTime.now());
    _comments[c.id] = c;
    _log(t.groupId, 'task.rejected', 'task', id, {'reason': reason.trim()});
    await _commit();
    return u;
  }

  @override
  Future<Task> cancelTask(String id, {String? reason}) async {
    final uid = _uid();
    final t = _taskForUpdate(id);
    if (!(t.creatorId == uid || (t.groupId != null && _has(uid, t.groupId!, Perm.cancelAny)))) _fail('permission_denied');
    if (t.status.isTerminal) _fail('invalid_transition', {'status': t.status.wire});
    for (final s in _tasks.values.where((s) => s.parentTaskId == id && !s.status.isTerminal).toList()) {
      _tasks[s.id] = s.copyWith(status: TaskStatus.cancelled, cancelledAt: DateTime.now(), version: s.version + 1);
      if (t.groupId != null) _log(t.groupId, 'task.cancelled', 'task', s.id, {'via': 'parent'});
    }
    final u = t.copyWith(status: TaskStatus.cancelled, cancelledAt: DateTime.now(), version: t.version + 1);
    _tasks[id] = u;
    if (t.groupId != null) _log(t.groupId, 'task.cancelled', 'task', id, {'reason': reason ?? ''});
    await _commit();
    return u;
  }

  @override
  Future<Task> reopenTask(String id) async {
    final uid = _uid();
    final t = _taskForUpdate(id);
    if (!(t.creatorId == uid || (t.groupId != null && _has(uid, t.groupId!, Perm.editAny)))) _fail('permission_denied');
    if (t.status != TaskStatus.completed || (t.completedAt != null && DateTime.now().difference(t.completedAt!).inDays > 30)) _fail('invalid_transition', {'status': t.status.wire});
    final keep = t.assigneeId != null && (t.groupId == null || _isActiveMember(t.assigneeId!, t.groupId!));
    final u = t.copyWith(
      status: keep ? TaskStatus.inProgress : TaskStatus.newTask,
      assigneeId: keep ? t.assigneeId : null,
      assignmentMode: keep ? t.assignmentMode : AssignmentMode.open,
      completedAt: null,
      completedBy: null,
      approvedBy: null,
      approvedAt: null,
      submittedAt: null,
      version: t.version + 1,
    );
    _tasks[id] = u;
    if (t.groupId != null) _log(t.groupId, 'task.reopened', 'task', id);
    await _commit();
    return u;
  }

  @override
  Future<List<TaskComment>> comments(String taskId) async {
    final t = _tasks[taskId];
    if (t == null || !_canView(_uid(), t)) return const [];
    return _comments.values.where((c) => c.taskId == taskId && c.deletedAt == null).map((c) => TaskComment(id: c.id, taskId: c.taskId, authorId: c.authorId, body: c.body, kind: c.kind, createdAt: c.createdAt, author: _users[c.authorId])).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<TaskComment> addComment(String taskId, String body) async {
    final uid = _uid();
    final t = _tasks[taskId] ?? _fail('not_found');
    if (!_canView(uid, t)) _fail('permission_denied');
    if (body.trim().isEmpty) _fail('body_required');
    final c = TaskComment(id: _id(), taskId: taskId, authorId: uid, body: body.trim(), createdAt: DateTime.now(), author: _users[uid]);
    _comments[c.id] = c;
    if (t.groupId != null) _log(t.groupId, 'task.comment', 'task', taskId, {'comment_id': c.id, 'excerpt': body.trim().substring(0, min(80, body.trim().length))});
    await _commit();
    return c;
  }

  List<ActivityEvent> _withActors(Iterable<ActivityEvent> es) => es
      .map((e) => ActivityEvent(id: e.id, groupId: e.groupId, actorId: e.actorId, action: e.action, targetType: e.targetType, targetId: e.targetId, metadata: e.metadata, createdAt: e.createdAt, actor: e.actorId == null ? null : _users[e.actorId]))
      .toList();

  @override
  Future<List<ActivityEvent>> taskActivity(String taskId) async {
    final t = _tasks[taskId];
    if (t == null || !_canView(_uid(), t)) return const [];
    return _withActors(_events.where((e) => e.targetType == 'task' && e.targetId == taskId));
  }

  @override
  Future<List<ActivityEvent>> groupActivity(String groupId, {int limit = 100}) async {
    if (!_hasMine(groupId, Perm.activityView)) _fail('permission_denied');
    final es = _events.where((e) => e.groupId == groupId).toList().reversed.take(limit);
    return _withActors(es);
  }

  // ------------------------------------------------------------------ notifications
  @override
  Future<List<AppNotification>> notifications() async {
    final uid = _uid();
    return _notifications.values.where((n) => n.userId == uid).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<int> unreadCount() async {
    final uid = _currentUserId;
    if (uid == null) return 0;
    return _notifications.values.where((n) => n.userId == uid && !n.isRead).length;
  }

  @override
  Future<void> markRead(String id) async {
    final n = _notifications[id];
    if (n == null || n.userId != _uid() || n.isRead) return;
    _notifications[id] = n.copyWith(readAt: DateTime.now());
    await _commit();
  }

  @override
  Future<void> markAllRead() async {
    final uid = _uid();
    for (final n in _notifications.values.where((n) => n.userId == uid && !n.isRead).toList()) {
      _notifications[n.id] = n.copyWith(readAt: DateTime.now());
    }
    await _commit();
  }

  // ------------------------------------------------------------------ stats & search
  @override
  Future<List<MemberStats>> groupStats(String groupId, {required DateTime from, required DateTime to}) async {
    final uid = _uid();
    final g = _groups[groupId] ?? _fail('not_found');
    if (!_isActiveMember(uid, groupId)) _fail('not_a_member');
    final vis = g.settings.effectiveStatsVisibility(g.type);
    final role = _role(uid, groupId);
    final out = <MemberStats>[];
    for (final m in _memberships.values.where((m) => m.groupId == groupId && m.isActive)) {
      final visible = m.userId == uid || vis == 'all' || (vis == 'admins' && (role == MembershipRole.owner || role == MembershipRole.admin));
      if (!visible) continue;
      final done = _tasks.values.where((t) => t.groupId == groupId && t.status == TaskStatus.completed && t.completedBy == m.userId && t.completedAt != null && !t.completedAt!.isBefore(from) && !t.completedAt!.isAfter(to)).toList();
      final open = _tasks.values.where((t) => t.groupId == groupId && t.assigneeId == m.userId && t.status.isOpenState);
      out.add(MemberStats(
        userId: m.userId,
        displayName: _users[m.userId]?.displayName ?? '',
        completed: done.length,
        onTime: done.where((t) => t.dueAt == null || !t.completedAt!.isAfter(t.dueAt!)).length,
        late: done.where((t) => t.dueAt != null && t.completedAt!.isAfter(t.dueAt!)).length,
        inProgress: open.where((t) => t.status == TaskStatus.inProgress).length,
        overdue: open.where((t) => t.isOverdue).length,
        points: done.fold(0, (s, t) => s + (t.points ?? 0)),
      ));
    }
    out.sort((a, b) => b.points != a.points ? b.points.compareTo(a.points) : b.completed.compareTo(a.completed));
    return out;
  }

  @override
  Future<SearchResults> search(String query, {String? groupId, List<TaskStatus>? status, String? assigneeId}) async {
    final uid = _uid();
    final q = normalizeAr(query);
    final tasks = _tasks.values.where((t) {
      if (!_canView(uid, t)) return false;
      if (q.isNotEmpty && !normalizeAr('${t.title} ${t.description ?? ''}').contains(q)) return false;
      if (groupId != null && t.groupId != groupId) return false;
      if (status != null && status.isNotEmpty && !status.contains(t.status)) return false;
      if (assigneeId != null && t.assigneeId != assigneeId) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groups = q.isEmpty ? <Group>[] : _groups.values.where((g) => _isActiveMember(uid, g.id) && normalizeAr(g.name).contains(q)).toList();
    final members = <Member>[];
    if (q.isNotEmpty) {
      final seen = <String>{};
      for (final m in _memberships.values.where((m) => m.isActive && _isActiveMember(uid, m.groupId) && (groupId == null || m.groupId == groupId))) {
        final u = _users[m.userId];
        if (u == null || !normalizeAr(u.displayName).contains(q) || !seen.add('${m.groupId}:${m.userId}')) continue;
        members.add(Member(membership: m, user: u));
      }
    }
    return SearchResults(tasks: tasks.take(50).toList(), groups: groups, members: members);
  }
}

/// Same rules as normalize_ar() in SQL (doc 12 §E33).
String normalizeAr(String s) {
  const from = 'أإآٱةىؤئ٠١٢٣٤٥٦٧٨٩';
  const to = 'ااااهيوي0123456789';
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    if ((r >= 0x064B && r <= 0x0652) || r == 0x0640) continue;
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase();
}

class _Invite {
  const _Invite({required this.id, required this.groupId, required this.code, required this.createdAt, this.revokedAt});
  final String id;
  final String groupId;
  final String code;
  final DateTime createdAt;
  final DateTime? revokedAt;

  _Invite copyWith({DateTime? revokedAt}) => _Invite(id: id, groupId: groupId, code: code, createdAt: createdAt, revokedAt: revokedAt ?? this.revokedAt);

  factory _Invite.fromJson(Map<String, dynamic> j) => _Invite(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        code: j['code'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        revokedAt: j['revoked_at'] == null ? null : DateTime.parse(j['revoked_at'] as String),
      );

  Map<String, dynamic> toJson() => {'id': id, 'group_id': groupId, 'code': code, 'created_at': createdAt.toUtc().toIso8601String(), 'revoked_at': revokedAt?.toUtc().toIso8601String()};
}

/// Demo data: a family and a small company, so the product can be explored
/// on one device without a backend.
abstract final class DemoSeed {
  static const abdullah = 'd0000000-0000-4000-a000-000000000001';
  static const mohammed = 'd0000000-0000-4000-a000-000000000002';
  static const khaled = 'd0000000-0000-4000-a000-000000000003';
  static const sara = 'd0000000-0000-4000-a000-000000000004';
  static const noura = 'd0000000-0000-4000-a000-000000000005';
  static const faisal = 'd0000000-0000-4000-a000-000000000006';

  static Future<void> apply(LocalApi api) async {
    final now = DateTime.now();
    for (final u in const [
      AppUser(id: abdullah, displayName: 'عبدالله'),
      AppUser(id: mohammed, displayName: 'محمد'),
      AppUser(id: khaled, displayName: 'خالد'),
      AppUser(id: sara, displayName: 'سارة'),
      AppUser(id: noura, displayName: 'نورة'),
      AppUser(id: faisal, displayName: 'فيصل'),
    ]) {
      api._users[u.id] = u;
    }
    api._currentUserId = abdullah;

    // البيت
    final home = await api.createGroup(name: 'البيت', type: GroupType.home);
    for (final u in [mohammed, khaled, sara]) {
      api._currentUserId = u;
      final r = await api.requestJoin(api._activeInvite(home.id)!.code);
      api._currentUserId = abdullah;
      await api.decideJoin(r.id, accept: true);
    }
    await api.setMemberRole(home.id, sara, MembershipRole.admin);
    final ac = await api.createTask(TaskDraft(title: 'إصلاح التكييف', groupId: home.id, description: 'تكييف المجلس لا يبرّد. الفني على واتساب.', priority: TaskPriority.high, dueAt: now.add(const Duration(hours: 6)), points: 30, requiresApproval: true));
    api._currentUserId = mohammed;
    await api.claimTask(ac.id);
    await api.addComment(ac.id, 'تواصلت مع الفني، سيأتي الساعة ٤.');
    api._currentUserId = abdullah;
    await api.addComment(ac.id, 'ممتاز.');
    await api.createTask(TaskDraft(title: 'شراء الخبز', groupId: home.id, points: 5, dueAt: DateTime(now.year, now.month, now.day, 19)));
    await api.createTask(TaskDraft(title: 'أخذ السيارة للصيانة', groupId: home.id, assignmentMode: AssignmentMode.assigned, assigneeId: khaled, dueAt: now.add(const Duration(days: 2)), points: 20));
    final trash = await api.createTask(TaskDraft(title: 'إخراج القمامة', groupId: home.id, dueAt: now.subtract(const Duration(hours: 3)), points: 5));
    final store = await api.createTask(TaskDraft(title: 'ترتيب المخزن', groupId: home.id, points: 50, requiresApproval: true));
    api._currentUserId = khaled;
    await api.claimTask(store.id);
    await api.completeTask(store.id, note: 'رتبت الرفوف وأخرجت الكراتين القديمة.');
    api._currentUserId = abdullah;
    final groc = await api.createTask(TaskDraft(title: 'مشتريات الأسبوع', groupId: home.id, points: 15));
    api._currentUserId = sara;
    await api.claimTask(groc.id);
    await api.completeTask(groc.id);
    api._currentUserId = abdullah;
    final mine = await api.createTask(TaskDraft(title: 'دفع فاتورة الكهرباء', groupId: home.id, assignmentMode: AssignmentMode.assigned, assigneeId: abdullah, dueAt: DateTime(now.year, now.month, now.day, 22), points: 10));
    await api.startTask(mine.id);
    // pending join request
    api._currentUserId = noura;
    await api.requestJoin(api._activeInvite(home.id)!.code, message: 'أنا نورة، أخت سارة.');
    api._currentUserId = abdullah;
    // keep "trash" referenced so the analyzer is happy and the seed is explicit
    assert(trash.isOverdue);

    // شركة الأفق
    final co = await api.createGroup(name: 'شركة الأفق', type: GroupType.company, settings: const GroupSettings(requiresApprovalDefault: true, gamificationEnabled: true, statsVisibility: 'all'));
    for (final u in [faisal, khaled]) {
      api._currentUserId = u;
      final r = await api.requestJoin(api._activeInvite(co.id)!.code);
      api._currentUserId = abdullah;
      await api.decideJoin(r.id, accept: true);
    }
    await api.createTask(TaskDraft(title: 'تقرير المبيعات الأسبوعي', groupId: co.id, assignmentMode: AssignmentMode.assigned, assigneeId: faisal, dueAt: now.add(const Duration(days: 1)), points: 20, priority: TaskPriority.high));
    await api.createTask(TaskDraft(title: 'تنظيف المكتب ٤', groupId: co.id, points: 10, requiresProof: true, proofTypes: const ['photo', 'note']));
    final plan = await api.createTask(TaskDraft(title: 'تجهيز الفرع الجديد', groupId: co.id, assignmentMode: AssignmentMode.collaborative, participantIds: [faisal, khaled], dueAt: now.add(const Duration(days: 14)), priority: TaskPriority.urgent));
    await api.createTask(TaskDraft(title: 'التعاقد مع شركة الديكور', groupId: co.id, parentTaskId: plan.id, assignmentMode: AssignmentMode.assigned, assigneeId: faisal));
    await api.createTask(TaskDraft(title: 'طلب خط الإنترنت', groupId: co.id, parentTaskId: plan.id));

    // personal
    await api.createTask(const TaskDraft(title: 'حجز موعد طبيب الأسنان'));
    await api.createTask(TaskDraft(title: 'قراءة ٢٠ صفحة', dueAt: DateTime(now.year, now.month, now.day, 21)));

    // read the notifications the seed generated for the demo user, keep the last few unread
    final ns = api._notifications.values.where((n) => n.userId == abdullah).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final n in ns.take(max(0, ns.length - 3))) {
      api._notifications[n.id] = n.copyWith(readAt: now);
    }
    await api._commit();
  }
}
