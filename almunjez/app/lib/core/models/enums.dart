library;

/// Enums mirror the Postgres enums in backend/schema/001_initial.sql exactly.
/// `wire` is the value sent to / received from the API.

enum GroupType {
  home, family, company, department, team, project, committee, volunteer, other;

  String get wire => name;
  static GroupType fromWire(String? v) =>
      GroupType.values.firstWhere((e) => e.name == v, orElse: () => GroupType.other);
}

enum MembershipRole {
  owner, admin, member;

  String get wire => name;
  static MembershipRole fromWire(String? v) =>
      MembershipRole.values.firstWhere((e) => e.name == v, orElse: () => MembershipRole.member);
}

enum MembershipStatus {
  active, removed, left;

  static MembershipStatus fromWire(String? v) =>
      MembershipStatus.values.firstWhere((e) => e.name == v, orElse: () => MembershipStatus.active);
}

enum JoinRequestStatus {
  pending, accepted, rejected, cancelled;

  static JoinRequestStatus fromWire(String? v) =>
      JoinRequestStatus.values.firstWhere((e) => e.name == v, orElse: () => JoinRequestStatus.pending);
}

enum TaskStatus {
  newTask('new'),
  inProgress('in_progress'),
  awaitingApproval('awaiting_approval'),
  completed('completed'),
  cancelled('cancelled');

  const TaskStatus(this.wire);
  final String wire;

  bool get isOpenState => this == newTask || this == inProgress || this == awaitingApproval;
  bool get isTerminal => this == completed || this == cancelled;

  static TaskStatus fromWire(String? v) =>
      TaskStatus.values.firstWhere((e) => e.wire == v, orElse: () => TaskStatus.newTask);
}

enum TaskPriority {
  low, normal, high, urgent;

  String get wire => name;
  static TaskPriority fromWire(String? v) =>
      TaskPriority.values.firstWhere((e) => e.name == v, orElse: () => TaskPriority.normal);
}

enum AssignmentMode {
  open, assigned, collaborative;

  String get wire => name;
  static AssignmentMode fromWire(String? v) =>
      AssignmentMode.values.firstWhere((e) => e.name == v, orElse: () => AssignmentMode.open);
}

/// Permission keys (doc 06 §3). Kept as strings because the backend stores
/// them as JSON keys in memberships.permissions.
abstract final class Perm {
  static const manageSettings = 'group.manage_settings';
  static const manageMembers = 'group.manage_members';
  static const approveJoins = 'group.approve_joins';
  static const manageInvite = 'group.manage_invite';
  static const transfer = 'group.transfer';
  static const archive = 'group.archive';
  static const taskCreate = 'task.create';
  static const assignOthers = 'task.assign_others';
  static const editAny = 'task.edit_any';
  static const cancelAny = 'task.cancel_any';
  static const approveCompletion = 'task.approve_completion';
  static const activityView = 'activity.view';
  static const statsViewAll = 'stats.view_all';
  static const commentModerate = 'comment.moderate';

  static const all = [
    manageSettings, manageMembers, approveJoins, manageInvite, transfer, archive,
    taskCreate, assignOthers, editAny, cancelAny, approveCompletion,
    activityView, statsViewAll, commentModerate,
  ];

  /// Default grants for an admin (owner has everything).
  static const adminDefaults = {
    manageSettings, manageMembers, approveJoins, manageInvite,
    assignOthers, editAny, cancelAny, approveCompletion, commentModerate,
  };
}
