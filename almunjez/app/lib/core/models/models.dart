import 'enums.dart';

DateTime? _ts(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    this.avatarPath,
    this.locale = 'ar',
    this.timezone = 'Asia/Kuwait',
    this.deletedAt,
  });

  final String id;
  final String displayName;
  final String? avatarPath;
  final String locale;
  final String timezone;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  AppUser copyWith({String? displayName, String? avatarPath, String? locale, String? timezone, DateTime? deletedAt}) =>
      AppUser(
        id: id,
        displayName: displayName ?? this.displayName,
        avatarPath: avatarPath ?? this.avatarPath,
        locale: locale ?? this.locale,
        timezone: timezone ?? this.timezone,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        displayName: (j['display_name'] as String?) ?? '',
        avatarPath: j['avatar_path'] as String?,
        locale: (j['locale'] as String?) ?? 'ar',
        timezone: (j['timezone'] as String?) ?? 'Asia/Kuwait',
        deletedAt: _ts(j['deleted_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'avatar_path': avatarPath,
        'locale': locale,
        'timezone': timezone,
        'deleted_at': _iso(deletedAt),
      };
}

class GroupSettings {
  const GroupSettings({
    this.requiresApprovalDefault = false,
    this.gamificationEnabled = false,
    this.membersCanCreateTasks = true,
    this.activityVisibleToMembers = true,
    this.statsVisibility,
  });

  final bool requiresApprovalDefault;
  final bool gamificationEnabled;
  final bool membersCanCreateTasks;
  final bool activityVisibleToMembers;

  /// `private` | `admins` | `all`; null = product default by group type.
  final String? statsVisibility;

  String effectiveStatsVisibility(GroupType type) =>
      statsVisibility ?? ((type == GroupType.home || type == GroupType.family) ? 'private' : 'all');

  GroupSettings copyWith({
    bool? requiresApprovalDefault,
    bool? gamificationEnabled,
    bool? membersCanCreateTasks,
    bool? activityVisibleToMembers,
    String? statsVisibility,
  }) =>
      GroupSettings(
        requiresApprovalDefault: requiresApprovalDefault ?? this.requiresApprovalDefault,
        gamificationEnabled: gamificationEnabled ?? this.gamificationEnabled,
        membersCanCreateTasks: membersCanCreateTasks ?? this.membersCanCreateTasks,
        activityVisibleToMembers: activityVisibleToMembers ?? this.activityVisibleToMembers,
        statsVisibility: statsVisibility ?? this.statsVisibility,
      );

  factory GroupSettings.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return GroupSettings(
      requiresApprovalDefault: j['requires_approval_default'] as bool? ?? false,
      gamificationEnabled: j['gamification_enabled'] as bool? ?? false,
      membersCanCreateTasks: j['members_can_create_tasks'] as bool? ?? true,
      activityVisibleToMembers: j['activity_visible_to_members'] as bool? ?? true,
      statsVisibility: j['stats_visibility'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'requires_approval_default': requiresApprovalDefault,
        'gamification_enabled': gamificationEnabled,
        'members_can_create_tasks': membersCanCreateTasks,
        'activity_visible_to_members': activityVisibleToMembers,
        if (statsVisibility != null) 'stats_visibility': statsVisibility,
      };
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    required this.settings,
    this.memberCount = 0,
    this.archivedAt,
    required this.createdAt,
  });

  final String id;
  final String name;
  final GroupType type;
  final String ownerId;
  final GroupSettings settings;
  final int memberCount;
  final DateTime? archivedAt;
  final DateTime createdAt;

  bool get isArchived => archivedAt != null;

  Group copyWith({String? name, GroupType? type, String? ownerId, GroupSettings? settings, int? memberCount, DateTime? archivedAt}) =>
      Group(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        ownerId: ownerId ?? this.ownerId,
        settings: settings ?? this.settings,
        memberCount: memberCount ?? this.memberCount,
        archivedAt: archivedAt ?? this.archivedAt,
        createdAt: createdAt,
      );

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'] as String,
        name: j['name'] as String,
        type: GroupType.fromWire(j['type'] as String?),
        ownerId: (j['owner_id'] as String?) ?? '',
        settings: GroupSettings.fromJson(j['settings'] as Map<String, dynamic>?),
        memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
        archivedAt: _ts(j['archived_at']),
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.wire,
        'owner_id': ownerId,
        'settings': settings.toJson(),
        'member_count': memberCount,
        'archived_at': _iso(archivedAt),
        'created_at': _iso(createdAt),
      };
}

/// Row of v_my_groups.
class GroupSummary {
  const GroupSummary({
    required this.group,
    required this.role,
    this.openCount = 0,
    this.mineCount = 0,
    this.pendingRequests = 0,
  });

  final Group group;
  final MembershipRole role;
  final int openCount;
  final int mineCount;
  final int pendingRequests;
}

class Membership {
  const Membership({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    this.status = MembershipStatus.active,
    this.permissions = const {},
    required this.joinedAt,
    this.leftAt,
  });

  final String id;
  final String groupId;
  final String userId;
  final MembershipRole role;
  final MembershipStatus status;
  final Map<String, bool> permissions;
  final DateTime joinedAt;
  final DateTime? leftAt;

  bool get isActive => status == MembershipStatus.active;

  Membership copyWith({MembershipRole? role, MembershipStatus? status, Map<String, bool>? permissions, DateTime? joinedAt, DateTime? leftAt}) =>
      Membership(
        id: id,
        groupId: groupId,
        userId: userId,
        role: role ?? this.role,
        status: status ?? this.status,
        permissions: permissions ?? this.permissions,
        joinedAt: joinedAt ?? this.joinedAt,
        leftAt: leftAt ?? this.leftAt,
      );

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        userId: j['user_id'] as String,
        role: MembershipRole.fromWire(j['role'] as String?),
        status: MembershipStatus.fromWire(j['status'] as String?),
        permissions: ((j['permissions'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, v == true)),
        joinedAt: _ts(j['joined_at']) ?? DateTime.now(),
        leftAt: _ts(j['left_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'user_id': userId,
        'role': role.wire,
        'status': status.name,
        'permissions': permissions,
        'joined_at': _iso(joinedAt),
        'left_at': _iso(leftAt),
      };
}

/// Membership joined with the user's profile — what the members screen shows.
class Member {
  const Member({required this.membership, required this.user});
  final Membership membership;
  final AppUser user;
  String get userId => user.id;
  MembershipRole get role => membership.role;
}

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.groupId,
    required this.userId,
    this.status = JoinRequestStatus.pending,
    this.message,
    required this.createdAt,
    this.decidedAt,
    this.user,
    this.groupName,
  });

  final String id;
  final String groupId;
  final String userId;
  final JoinRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final AppUser? user;
  final String? groupName;

  JoinRequest copyWith({JoinRequestStatus? status, DateTime? decidedAt, AppUser? user, String? groupName}) => JoinRequest(
        id: id,
        groupId: groupId,
        userId: userId,
        status: status ?? this.status,
        message: message,
        createdAt: createdAt,
        decidedAt: decidedAt ?? this.decidedAt,
        user: user ?? this.user,
        groupName: groupName ?? this.groupName,
      );

  factory JoinRequest.fromJson(Map<String, dynamic> j) => JoinRequest(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        userId: j['user_id'] as String,
        status: JoinRequestStatus.fromWire(j['status'] as String?),
        message: j['message'] as String?,
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
        decidedAt: _ts(j['decided_at']),
        user: j['users'] is Map<String, dynamic> ? AppUser.fromJson(j['users'] as Map<String, dynamic>) : null,
        groupName: j['groups'] is Map<String, dynamic> ? (j['groups'] as Map<String, dynamic>)['name'] as String? : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'user_id': userId,
        'status': status.name,
        'message': message,
        'created_at': _iso(createdAt),
        'decided_at': _iso(decidedAt),
      };
}

class InvitePreview {
  const InvitePreview({required this.groupName, required this.groupType, required this.memberCount, this.alreadyMember = false, this.pending = false});
  final String groupName;
  final GroupType groupType;
  final int memberCount;
  final bool alreadyMember;
  final bool pending;

  factory InvitePreview.fromJson(Map<String, dynamic> j) => InvitePreview(
        groupName: j['group_name'] as String,
        groupType: GroupType.fromWire(j['group_type'] as String?),
        memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
        alreadyMember: j['already_member'] == true,
        pending: j['pending'] == true,
      );
}

class Task {
  const Task({
    required this.id,
    this.groupId,
    required this.creatorId,
    required this.title,
    this.description,
    this.status = TaskStatus.newTask,
    this.priority = TaskPriority.normal,
    this.assignmentMode = AssignmentMode.open,
    this.assigneeId,
    this.dueAt,
    this.dueDateOnly = false,
    this.points,
    this.requiresProof = false,
    this.proofTypes = const ['photo', 'file', 'note'],
    this.requiresApproval = false,
    this.parentTaskId,
    this.claimedAt,
    this.startedAt,
    this.submittedAt,
    this.completedAt,
    this.completedBy,
    this.approvedBy,
    this.approvedAt,
    this.cancelledAt,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.participantIds = const [],
  });

  final String id;
  final String? groupId;
  final String creatorId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final AssignmentMode assignmentMode;
  final String? assigneeId;
  final DateTime? dueAt;
  final bool dueDateOnly;
  final int? points;
  final bool requiresProof;
  final List<String> proofTypes;
  final bool requiresApproval;
  final String? parentTaskId;
  final DateTime? claimedAt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final String? completedBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? cancelledAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> participantIds;

  bool get isPersonal => groupId == null;

  /// Derived, never stored (doc 07 §1).
  bool get isOverdue => dueAt != null && dueAt!.isBefore(DateTime.now()) && status.isOpenState;

  bool get isOpenForClaim => status == TaskStatus.newTask && assignmentMode == AssignmentMode.open && assigneeId == null;

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    AssignmentMode? assignmentMode,
    Object? assigneeId = _absent,
    Object? dueAt = _absent,
    bool? dueDateOnly,
    Object? points = _absent,
    bool? requiresProof,
    List<String>? proofTypes,
    bool? requiresApproval,
    Object? claimedAt = _absent,
    Object? startedAt = _absent,
    Object? submittedAt = _absent,
    Object? completedAt = _absent,
    Object? completedBy = _absent,
    Object? approvedBy = _absent,
    Object? approvedAt = _absent,
    Object? cancelledAt = _absent,
    int? version,
    DateTime? updatedAt,
    List<String>? participantIds,
  }) =>
      Task(
        id: id,
        groupId: groupId,
        creatorId: creatorId,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        assignmentMode: assignmentMode ?? this.assignmentMode,
        assigneeId: assigneeId == _absent ? this.assigneeId : assigneeId as String?,
        dueAt: dueAt == _absent ? this.dueAt : dueAt as DateTime?,
        dueDateOnly: dueDateOnly ?? this.dueDateOnly,
        points: points == _absent ? this.points : points as int?,
        requiresProof: requiresProof ?? this.requiresProof,
        proofTypes: proofTypes ?? this.proofTypes,
        requiresApproval: requiresApproval ?? this.requiresApproval,
        parentTaskId: parentTaskId,
        claimedAt: claimedAt == _absent ? this.claimedAt : claimedAt as DateTime?,
        startedAt: startedAt == _absent ? this.startedAt : startedAt as DateTime?,
        submittedAt: submittedAt == _absent ? this.submittedAt : submittedAt as DateTime?,
        completedAt: completedAt == _absent ? this.completedAt : completedAt as DateTime?,
        completedBy: completedBy == _absent ? this.completedBy : completedBy as String?,
        approvedBy: approvedBy == _absent ? this.approvedBy : approvedBy as String?,
        approvedAt: approvedAt == _absent ? this.approvedAt : approvedAt as DateTime?,
        cancelledAt: cancelledAt == _absent ? this.cancelledAt : cancelledAt as DateTime?,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        participantIds: participantIds ?? this.participantIds,
      );

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        groupId: j['group_id'] as String?,
        creatorId: j['creator_id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        status: TaskStatus.fromWire(j['status'] as String?),
        priority: TaskPriority.fromWire(j['priority'] as String?),
        assignmentMode: AssignmentMode.fromWire(j['assignment_mode'] as String?),
        assigneeId: j['assignee_id'] as String?,
        dueAt: _ts(j['due_at']),
        dueDateOnly: j['due_date_only'] == true,
        points: (j['points'] as num?)?.toInt(),
        requiresProof: j['requires_proof'] == true,
        proofTypes: ((j['proof_types'] as List?) ?? const ['photo', 'file', 'note']).cast<String>(),
        requiresApproval: j['requires_approval'] == true,
        parentTaskId: j['parent_task_id'] as String?,
        claimedAt: _ts(j['claimed_at']),
        startedAt: _ts(j['started_at']),
        submittedAt: _ts(j['submitted_at']),
        completedAt: _ts(j['completed_at']),
        completedBy: j['completed_by'] as String?,
        approvedBy: j['approved_by'] as String?,
        approvedAt: _ts(j['approved_at']),
        cancelledAt: _ts(j['cancelled_at']),
        version: (j['version'] as num?)?.toInt() ?? 1,
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
        updatedAt: _ts(j['updated_at']) ?? DateTime.now(),
        participantIds: ((j['participant_ids'] as List?) ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'creator_id': creatorId,
        'title': title,
        'description': description,
        'status': status.wire,
        'priority': priority.wire,
        'assignment_mode': assignmentMode.wire,
        'assignee_id': assigneeId,
        'due_at': _iso(dueAt),
        'due_date_only': dueDateOnly,
        'points': points,
        'requires_proof': requiresProof,
        'proof_types': proofTypes,
        'requires_approval': requiresApproval,
        'parent_task_id': parentTaskId,
        'claimed_at': _iso(claimedAt),
        'started_at': _iso(startedAt),
        'submitted_at': _iso(submittedAt),
        'completed_at': _iso(completedAt),
        'completed_by': completedBy,
        'approved_by': approvedBy,
        'approved_at': _iso(approvedAt),
        'cancelled_at': _iso(cancelledAt),
        'version': version,
        'created_at': _iso(createdAt),
        'updated_at': _iso(updatedAt),
        'participant_ids': participantIds,
      };
}

const _absent = Object();

/// Input for create_task.
class TaskDraft {
  const TaskDraft({
    required this.title,
    this.groupId,
    this.description,
    this.assignmentMode = AssignmentMode.open,
    this.assigneeId,
    this.dueAt,
    this.dueDateOnly = false,
    this.priority = TaskPriority.normal,
    this.points,
    this.requiresProof = false,
    this.proofTypes = const ['photo', 'file', 'note'],
    this.requiresApproval,
    this.parentTaskId,
    this.participantIds = const [],
  });

  final String title;
  final String? groupId;
  final String? description;
  final AssignmentMode assignmentMode;
  final String? assigneeId;
  final DateTime? dueAt;
  final bool dueDateOnly;
  final TaskPriority priority;
  final int? points;
  final bool requiresProof;
  final List<String> proofTypes;
  final bool? requiresApproval;
  final String? parentTaskId;
  final List<String> participantIds;

  Map<String, dynamic> toRpcParams() => {
        'p_title': title,
        'p_group_id': groupId,
        'p_description': description,
        'p_assignment_mode': assignmentMode.wire,
        'p_assignee_id': assigneeId,
        'p_due_at': _iso(dueAt),
        'p_due_date_only': dueDateOnly,
        'p_priority': priority.wire,
        'p_points': points,
        'p_requires_proof': requiresProof,
        'p_proof_types': proofTypes,
        'p_requires_approval': requiresApproval,
        'p_parent_task_id': parentTaskId,
        'p_participant_ids': participantIds,
      };
}

/// Patch for update_task (only present keys are applied).
class TaskPatch {
  const TaskPatch({this.title, this.description, this.dueAt, this.clearDue = false, this.priority, this.points, this.clearPoints = false, this.requiresProof, this.requiresApproval});
  final String? title;
  final String? description;
  final DateTime? dueAt;
  final bool clearDue;
  final TaskPriority? priority;
  final int? points;
  final bool clearPoints;
  final bool? requiresProof;
  final bool? requiresApproval;

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (dueAt != null || clearDue) 'due_at': _iso(dueAt),
        if (priority != null) 'priority': priority!.wire,
        if (points != null || clearPoints) 'points': points,
        if (requiresProof != null) 'requires_proof': requiresProof,
        if (requiresApproval != null) 'requires_approval': requiresApproval,
      };
}

/// One row of my_tasks(): section ∈ overdue | today | no_date | upcoming.
class TodayRow {
  const TodayRow({required this.task, required this.section, this.groupName});
  final Task task;
  final String section;
  final String? groupName;
}

class TaskComment {
  const TaskComment({required this.id, required this.taskId, required this.authorId, required this.body, this.kind = 'comment', required this.createdAt, this.deletedAt, this.author});
  final String id;
  final String taskId;
  final String authorId;
  final String body;
  final String kind;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final AppUser? author;

  factory TaskComment.fromJson(Map<String, dynamic> j) => TaskComment(
        id: j['id'] as String,
        taskId: j['task_id'] as String,
        authorId: j['author_id'] as String,
        body: j['body'] as String,
        kind: (j['kind'] as String?) ?? 'comment',
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
        deletedAt: _ts(j['deleted_at']),
        author: j['users'] is Map<String, dynamic> ? AppUser.fromJson(j['users'] as Map<String, dynamic>) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_id': taskId,
        'author_id': authorId,
        'body': body,
        'kind': kind,
        'created_at': _iso(createdAt),
        'deleted_at': _iso(deletedAt),
      };
}

class ActivityEvent {
  const ActivityEvent({required this.id, this.groupId, this.actorId, required this.action, required this.targetType, this.targetId, this.metadata = const {}, required this.createdAt, this.actor});
  final int id;
  final String? groupId;
  final String? actorId;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final AppUser? actor;

  factory ActivityEvent.fromJson(Map<String, dynamic> j) => ActivityEvent(
        id: (j['id'] as num).toInt(),
        groupId: j['group_id'] as String?,
        actorId: j['actor_id'] as String?,
        action: j['action'] as String,
        targetType: j['target_type'] as String,
        targetId: j['target_id'] as String?,
        metadata: (j['metadata'] as Map<String, dynamic>?) ?? const {},
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
        actor: j['users'] is Map<String, dynamic> ? AppUser.fromJson(j['users'] as Map<String, dynamic>) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'actor_id': actorId,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'metadata': metadata,
        'created_at': _iso(createdAt),
      };
}

class AppNotification {
  const AppNotification({required this.id, required this.userId, required this.type, this.taskId, this.groupId, this.actorId, this.data = const {}, this.readAt, required this.createdAt});
  final String id;
  final String userId;
  final String type;
  final String? taskId;
  final String? groupId;
  final String? actorId;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(id: id, userId: userId, type: type, taskId: taskId, groupId: groupId, actorId: actorId, data: data, readAt: readAt ?? this.readAt, createdAt: createdAt);

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        type: j['type'] as String,
        taskId: j['task_id'] as String?,
        groupId: j['group_id'] as String?,
        actorId: j['actor_id'] as String?,
        data: (j['data'] as Map<String, dynamic>?) ?? const {},
        readAt: _ts(j['read_at']),
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'task_id': taskId,
        'group_id': groupId,
        'actor_id': actorId,
        'data': data,
        'read_at': _iso(readAt),
        'created_at': _iso(createdAt),
      };
}

class DashboardCounts {
  const DashboardCounts({this.newCount = 0, this.inProgress = 0, this.awaiting = 0, this.completed = 0, this.completedToday = 0, this.overdue = 0, this.mine = 0});
  final int newCount, inProgress, awaiting, completed, completedToday, overdue, mine;

  factory DashboardCounts.fromJson(Map<String, dynamic> j) => DashboardCounts(
        newCount: (j['new_count'] as num?)?.toInt() ?? 0,
        inProgress: (j['in_progress_count'] as num?)?.toInt() ?? 0,
        awaiting: (j['awaiting_count'] as num?)?.toInt() ?? 0,
        completed: (j['completed_count'] as num?)?.toInt() ?? 0,
        completedToday: (j['completed_today_count'] as num?)?.toInt() ?? 0,
        overdue: (j['overdue_count'] as num?)?.toInt() ?? 0,
        mine: (j['mine_count'] as num?)?.toInt() ?? 0,
      );
}

class MemberStats {
  const MemberStats({required this.userId, required this.displayName, this.completed = 0, this.onTime = 0, this.late = 0, this.inProgress = 0, this.overdue = 0, this.points = 0});
  final String userId;
  final String displayName;
  final int completed, onTime, late, inProgress, overdue, points;

  factory MemberStats.fromJson(Map<String, dynamic> j) => MemberStats(
        userId: j['user_id'] as String,
        displayName: (j['display_name'] as String?) ?? '',
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        onTime: (j['on_time'] as num?)?.toInt() ?? 0,
        late: (j['late'] as num?)?.toInt() ?? 0,
        inProgress: (j['in_progress'] as num?)?.toInt() ?? 0,
        overdue: (j['overdue'] as num?)?.toInt() ?? 0,
        points: (j['points'] as num?)?.toInt() ?? 0,
      );
}

/// One row of notification_preferences (doc 08 §5). Absence for a type
/// means both defaults apply — the API omits rows the user never overrode.
class NotifPref {
  const NotifPref({this.push = true, this.inApp = true});
  final bool push;
  final bool inApp;

  NotifPref copyWith({bool? push, bool? inApp}) => NotifPref(push: push ?? this.push, inApp: inApp ?? this.inApp);

  factory NotifPref.fromJson(Map<String, dynamic> j) => NotifPref(push: j['push'] as bool? ?? true, inApp: (j['in_app'] as bool?) ?? true);

  Map<String, dynamic> toJson() => {'push': push, 'in_app': inApp};
}

class SearchResults {
  const SearchResults({this.tasks = const [], this.groups = const [], this.members = const []});
  final List<Task> tasks;
  final List<Group> groups;
  final List<Member> members;
}
