import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../models/enums.dart';
import '../../models/models.dart';
import '../almunjez_api.dart';
import '../api_error.dart';

/// Real backend: every mutation is an RPC from backend/schema/001_initial.sql,
/// every read goes through PostgREST under Row-Level Security.
class SupabaseApi implements AlMunjezApi {
  SupabaseApi(this._client) {
    _client.auth.onAuthStateChange.listen((e) async {
      await _loadProfile();
      _auth.add(_profile);
    });
    _subscribeRealtime();
  }

  final sb.SupabaseClient _client;
  final _changes = StreamController<void>.broadcast();
  final _auth = StreamController<AppUser?>.broadcast();
  AppUser? _profile;
  sb.RealtimeChannel? _channel;

  Future<void> init() => _loadProfile();

  Future<void> _loadProfile() async {
    final u = _client.auth.currentUser;
    if (u == null) {
      _profile = null;
      return;
    }
    final row = await _client.from('users').select().eq('id', u.id).maybeSingle();
    _profile = row == null ? AppUser(id: u.id, displayName: '') : AppUser.fromJson(row);
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = _client
        .channel('almunjez')
        .onPostgresChanges(event: sb.PostgresChangeEvent.all, schema: 'public', table: 'tasks', callback: (_) => _changes.add(null))
        .onPostgresChanges(event: sb.PostgresChangeEvent.all, schema: 'public', table: 'notifications', callback: (_) => _changes.add(null))
        .onPostgresChanges(event: sb.PostgresChangeEvent.all, schema: 'public', table: 'join_requests', callback: (_) => _changes.add(null))
        .onPostgresChanges(event: sb.PostgresChangeEvent.all, schema: 'public', table: 'memberships', callback: (_) => _changes.add(null))
        .subscribe();
  }

  /// Maps PostgREST/Postgres errors to the stable codes of doc 09 §4.
  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      final r = await f();
      _changes.add(null);
      return r;
    } on sb.PostgrestException catch (e) {
      Map<String, dynamic> detail = const {};
      final d = e.details;
      if (d is Map<String, dynamic>) detail = d;
      throw ApiException(e.message, detail);
    } on sb.AuthException catch (e) {
      throw ApiException('auth_${e.statusCode ?? 'error'}', {'message': e.message});
    } catch (e) {
      throw ApiException('network', {'message': e.toString()});
    }
  }

  Future<T> _read<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on sb.PostgrestException catch (e) {
      throw ApiException(e.message);
    } catch (e) {
      throw ApiException('network', {'message': e.toString()});
    }
  }

  Task _task(dynamic row) => Task.fromJson(row as Map<String, dynamic>);
  List<Map<String, dynamic>> _rows(dynamic r) => (r as List).cast<Map<String, dynamic>>();

  // ---- identity
  @override
  Stream<void> get changes => _changes.stream;
  @override
  AppUser? get currentUser => _profile;
  @override
  Stream<AppUser?> get authState => _auth.stream;

  @override
  Future<void> signInWithApple() => _call(() => _client.auth.signInWithOAuth(sb.OAuthProvider.apple));

  @override
  Future<void> sendPhoneOtp(String phone) => _call(() => _client.auth.signInWithOtp(phone: phone));

  @override
  Future<void> verifyPhoneOtp(String phone, String code) => _call(() => _client.auth.verifyOTP(type: sb.OtpType.sms, phone: phone, token: code));

  @override
  Future<void> signInDemo() async => throw ApiException('demo_unavailable');

  @override
  Future<void> signOut() => _call(() => _client.auth.signOut());

  @override
  Future<AppUser> completeProfile({required String displayName, String? locale}) => _call(() async {
        final row = await _client.rpc('complete_profile', params: {'p_display_name': displayName, 'p_locale': locale});
        _profile = AppUser.fromJson(row as Map<String, dynamic>);
        _auth.add(_profile);
        return _profile!;
      });

  @override
  Future<void> deleteAccount() => _call(() async {
        await _client.rpc('delete_account');
        await _client.auth.signOut();
      });

  @override
  Future<void> registerDevice(String token) => _call(() => _client.rpc('register_device', params: {'p_apns_token': token, 'p_platform': 'ios'}));

  @override
  Future<AppUser?> getUser(String id) => _read(() async {
        final r = await _client.from('users').select().eq('id', id).maybeSingle();
        return r == null ? null : AppUser.fromJson(r);
      });

  @override
  Future<Map<String, AppUser>> getUsers(Iterable<String> ids) => _read(() async {
        final list = ids.toSet().toList();
        if (list.isEmpty) return {};
        final r = await _client.from('users').select().inFilter('id', list);
        return {for (final row in _rows(r)) row['id'] as String: AppUser.fromJson(row)};
      });

  // ---- groups
  @override
  Future<List<GroupSummary>> myGroups() => _read(() async {
        final r = await _client.from('v_my_groups').select();
        return _rows(r)
            .map((j) => GroupSummary(
                  group: Group.fromJson({...j, 'owner_id': j['owner_id'] ?? '', 'settings': j['settings'] ?? const {}}),
                  role: MembershipRole.fromWire(j['role'] as String?),
                  openCount: (j['open_count'] as num?)?.toInt() ?? 0,
                  mineCount: (j['mine_count'] as num?)?.toInt() ?? 0,
                  pendingRequests: (j['pending_requests'] as num?)?.toInt() ?? 0,
                ))
            .toList();
      });

  @override
  Future<Group?> getGroup(String id) => _read(() async {
        final r = await _client.from('groups').select().eq('id', id).maybeSingle();
        return r == null ? null : Group.fromJson(r);
      });

  @override
  Future<Group> createGroup({required String name, required GroupType type, GroupSettings? settings}) => _call(() async {
        final r = await _client.rpc('create_group', params: {'p_name': name, 'p_type': type.wire, 'p_settings': settings?.toJson() ?? const {}}) as Map<String, dynamic>;
        return (await getGroup(r['group_id'] as String))!;
      });

  @override
  Future<Group> updateGroupSettings(String groupId, {String? name, GroupType? type, GroupSettings? settings}) => _call(() async {
        final r = await _client.rpc('update_group_settings', params: {'p_group': groupId, 'p_name': name, 'p_type': type?.wire, 'p_settings': settings?.toJson()});
        return Group.fromJson(r as Map<String, dynamic>);
      });

  @override
  Future<String?> activeInviteCode(String groupId) => _read(() async {
        final r = await _client.from('group_invites').select('code').eq('group_id', groupId).isFilter('revoked_at', null).maybeSingle();
        return r?['code'] as String?;
      });

  @override
  Future<String> regenerateInvite(String groupId) => _call(() async => (await _client.rpc('regenerate_invite', params: {'p_group': groupId})) as String);

  @override
  Future<void> revokeInvite(String groupId) => _call(() => _client.rpc('revoke_invite', params: {'p_group': groupId}));

  @override
  Future<InvitePreview> previewInvite(String code) => _read(() async => InvitePreview.fromJson((await _client.rpc('preview_invite', params: {'p_code': code})) as Map<String, dynamic>));

  @override
  Future<JoinRequest> requestJoin(String code, {String? message}) => _call(() async => JoinRequest.fromJson((await _client.rpc('request_join', params: {'p_code': code, 'p_message': message})) as Map<String, dynamic>));

  @override
  Future<List<JoinRequest>> pendingJoinRequests(String groupId) => _read(() async {
        final r = await _client.from('join_requests').select('*, users:user_id(*), groups:group_id(name)').eq('group_id', groupId).eq('status', 'pending').order('created_at');
        return _rows(r).map(JoinRequest.fromJson).toList();
      });

  @override
  Future<List<JoinRequest>> myJoinRequests() => _read(() async {
        final uid = _client.auth.currentUser?.id;
        if (uid == null) return const [];
        final r = await _client.from('join_requests').select('*, groups:group_id(name)').eq('user_id', uid).eq('status', 'pending');
        return _rows(r).map(JoinRequest.fromJson).toList();
      });

  @override
  Future<void> cancelJoinRequest(String requestId) => _call(() => _client.rpc('cancel_join_request', params: {'p_request': requestId}));

  @override
  Future<void> decideJoin(String requestId, {required bool accept}) => _call(() => _client.rpc('decide_join', params: {'p_request': requestId, 'p_accept': accept}));

  // ---- membership
  @override
  Future<List<Member>> members(String groupId) => _read(() async {
        final r = await _client.from('memberships').select('*, users:user_id(*)').eq('group_id', groupId).eq('status', 'active').order('joined_at');
        final out = _rows(r).map((j) => Member(membership: Membership.fromJson(j), user: AppUser.fromJson(j['users'] as Map<String, dynamic>))).toList();
        out.sort((a, b) => a.role.index.compareTo(b.role.index));
        return out;
      });

  @override
  Future<Set<String>> myPermissions(String groupId) => _read(() async {
        final r = await _client.from('v_my_permissions').select('permissions').eq('group_id', groupId).maybeSingle();
        final p = (r?['permissions'] as Map<String, dynamic>?) ?? const {};
        return {for (final e in p.entries) if (e.value == true) e.key};
      });

  @override
  Future<MembershipRole?> myRole(String groupId) => _read(() async {
        final r = await _client.from('v_my_permissions').select('role').eq('group_id', groupId).maybeSingle();
        return r == null ? null : MembershipRole.fromWire(r['role'] as String?);
      });

  @override
  Future<void> setMemberRole(String groupId, String userId, MembershipRole role) => _call(() => _client.rpc('set_member_role', params: {'p_group': groupId, 'p_user': userId, 'p_role': role.wire}));

  @override
  Future<void> removeMember(String groupId, String userId) => _call(() => _client.rpc('remove_member', params: {'p_group': groupId, 'p_user': userId}));

  @override
  Future<void> leaveGroup(String groupId) => _call(() => _client.rpc('leave_group', params: {'p_group': groupId}));

  @override
  Future<void> transferOwnership(String groupId, String toUserId) => _call(() => _client.rpc('transfer_ownership', params: {'p_group': groupId, 'p_to_user': toUserId}));

  @override
  Future<void> archiveGroup(String groupId) => _call(() => _client.rpc('archive_group', params: {'p_group': groupId}));

  // ---- tasks
  static const _taskSelect = '*, participant_ids:task_participants(user_id)';

  Task _taskRow(Map<String, dynamic> j) {
    final parts = (j['participant_ids'] as List?)?.map((p) => (p as Map)['user_id'] as String).toList() ?? const <String>[];
    return Task.fromJson({...j, 'participant_ids': parts});
  }

  @override
  Future<List<Task>> groupTasks(String groupId) => _read(() async {
        final r = await _client.from('tasks').select(_taskSelect).eq('group_id', groupId).isFilter('parent_task_id', null).order('created_at', ascending: false);
        return _rows(r).map(_taskRow).toList();
      });

  @override
  Future<List<Task>> personalTasks() => _read(() async {
        final r = await _client.from('tasks').select(_taskSelect).isFilter('group_id', null).order('created_at', ascending: false);
        return _rows(r).map(_taskRow).toList();
      });

  @override
  Future<List<TodayRow>> myTasks() => _read(() async {
        final r = await _client.rpc('my_tasks');
        return _rows(r).map((j) => TodayRow(task: _task(j['task']), section: j['section'] as String, groupName: j['group_name'] as String?)).toList();
      });

  @override
  Future<DashboardCounts> dashboardCounts(String groupId) => _read(() async {
        final r = await _client.from('v_group_dashboard_counts').select().eq('group_id', groupId).maybeSingle();
        return r == null ? const DashboardCounts() : DashboardCounts.fromJson(r);
      });

  @override
  Future<Task?> getTask(String id) => _read(() async {
        final r = await _client.from('tasks').select(_taskSelect).eq('id', id).maybeSingle();
        return r == null ? null : _taskRow(r);
      });

  @override
  Future<List<Task>> subtasks(String parentId) => _read(() async {
        final r = await _client.from('tasks').select(_taskSelect).eq('parent_task_id', parentId).order('created_at');
        return _rows(r).map(_taskRow).toList();
      });

  Future<Task> _rpcTask(String fn, Map<String, dynamic> params) => _call(() async => _task(await _client.rpc(fn, params: params)));

  @override
  Future<Task> createTask(TaskDraft draft) => _rpcTask('create_task', draft.toRpcParams());
  @override
  Future<Task> updateTask(String id, TaskPatch patch, int version) => _rpcTask('update_task', {'p_task': id, 'p_patch': patch.toJson(), 'p_version': version});
  @override
  Future<Task> claimTask(String id) => _rpcTask('claim_task', {'p_task': id});
  @override
  Future<Task> startTask(String id) => _rpcTask('start_task', {'p_task': id});
  @override
  Future<Task> releaseTask(String id) => _rpcTask('release_task', {'p_task': id});
  @override
  Future<Task> reassignTask(String id, String assigneeId) => _rpcTask('reassign_task', {'p_task': id, 'p_assignee': assigneeId});
  @override
  Future<Task> unassignTask(String id) => _rpcTask('unassign_task', {'p_task': id});
  @override
  Future<Task> completeTask(String id, {String? note}) => _rpcTask('complete_task', {'p_task': id, 'p_note': note});
  @override
  Future<Task> approveCompletion(String id) => _rpcTask('approve_completion', {'p_task': id});
  @override
  Future<Task> rejectCompletion(String id, String reason) => _rpcTask('reject_completion', {'p_task': id, 'p_reason': reason});
  @override
  Future<Task> cancelTask(String id, {String? reason}) => _rpcTask('cancel_task', {'p_task': id, 'p_reason': reason});
  @override
  Future<Task> reopenTask(String id) => _rpcTask('reopen_task', {'p_task': id});

  @override
  Future<List<TaskComment>> comments(String taskId) => _read(() async {
        final r = await _client.from('task_comments').select('*, users:author_id(*)').eq('task_id', taskId).isFilter('deleted_at', null).order('created_at');
        return _rows(r).map(TaskComment.fromJson).toList();
      });

  @override
  Future<TaskComment> addComment(String taskId, String body) => _call(() async {
        final uid = _client.auth.currentUser!.id;
        final r = await _client.from('task_comments').insert({'task_id': taskId, 'author_id': uid, 'body': body}).select('*, users:author_id(*)').single();
        return TaskComment.fromJson(r);
      });

  @override
  Future<List<ActivityEvent>> taskActivity(String taskId) => _read(() async {
        final r = await _client.from('activity_events').select('*, users:actor_id(*)').eq('target_type', 'task').eq('target_id', taskId).order('id');
        return _rows(r).map(ActivityEvent.fromJson).toList();
      });

  @override
  Future<List<ActivityEvent>> groupActivity(String groupId, {int limit = 100}) => _read(() async {
        final r = await _client.from('activity_events').select('*, users:actor_id(*)').eq('group_id', groupId).order('id', ascending: false).limit(limit);
        return _rows(r).map(ActivityEvent.fromJson).toList();
      });

  // ---- notifications
  @override
  Future<List<AppNotification>> notifications() => _read(() async {
        final r = await _client.from('notifications').select().order('created_at', ascending: false).limit(200);
        return _rows(r).map(AppNotification.fromJson).toList();
      });

  @override
  Future<int> unreadCount() => _read(() async {
        final r = await _client.from('notifications').count(sb.CountOption.exact).isFilter('read_at', null);
        return r;
      });

  @override
  Future<void> markRead(String id) => _call(() => _client.rpc('mark_notification_read', params: {'p_id': id}));

  @override
  Future<void> markAllRead() => _call(() => _client.rpc('mark_all_read'));

  // ---- stats & search
  @override
  Future<List<MemberStats>> groupStats(String groupId, {required DateTime from, required DateTime to}) => _read(() async {
        final r = await _client.rpc('group_member_stats', params: {'p_group': groupId, 'p_from': from.toUtc().toIso8601String(), 'p_to': to.toUtc().toIso8601String()});
        return _rows(r).map(MemberStats.fromJson).toList();
      });

  @override
  Future<SearchResults> search(String query, {String? groupId, List<TaskStatus>? status, String? assigneeId}) => _read(() async {
        final r = await _client.rpc('search', params: {'p_query': query, 'p_group': groupId, 'p_status': status?.map((s) => s.wire).toList(), 'p_assignee': assigneeId}) as Map<String, dynamic>;
        final tasks = ((r['tasks'] as List?) ?? const []).cast<Map<String, dynamic>>();
        final groups = ((r['groups'] as List?) ?? const []).cast<Map<String, dynamic>>();
        final members = ((r['members'] as List?) ?? const []).cast<Map<String, dynamic>>();
        return SearchResults(
          tasks: tasks.map((j) => Task.fromJson({...j, 'creator_id': j['creator_id'] ?? '', 'created_at': j['created_at'], 'updated_at': j['updated_at']})).toList(),
          groups: groups.map((j) => Group.fromJson({...j, 'owner_id': '', 'settings': const {}})).toList(),
          members: members
              .map((j) => Member(
                    membership: Membership(id: '', groupId: j['group_id'] as String, userId: j['user_id'] as String, role: MembershipRole.member, joinedAt: DateTime.now()),
                    user: AppUser(id: j['user_id'] as String, displayName: (j['display_name'] as String?) ?? ''),
                  ))
              .toList(),
        );
      });
}
