import 'dart:async';

import '../models/enums.dart';
import '../models/models.dart';

/// The contract every screen talks to. Two implementations:
///  * [LocalApi]    — on-device rules engine mirroring 001_initial.sql (works offline, used in tests)
///  * [SupabaseApi] — the real backend (RPCs + RLS-filtered reads)
abstract class AlMunjezApi {
  /// Emits after any mutation so screens can refresh.
  Stream<void> get changes;

  // ---- identity
  AppUser? get currentUser;
  Stream<AppUser?> get authState;
  Future<void> signInWithApple();
  Future<void> signInWithGoogle();
  Future<void> sendPhoneOtp(String phone);
  Future<void> verifyPhoneOtp(String phone, String code);

  /// Email OTP: works on a fresh Supabase project with no extra setup
  /// (unlike phone, which needs a paid SMS provider configured first).
  Future<void> sendEmailOtp(String email);
  Future<void> verifyEmailOtp(String email, String code);

  /// Email + password. Needs nothing configured in the Supabase dashboard,
  /// which is why it is the primary method: the magic link needs Site URL /
  /// Redirect URLs set, the OTP code needs the email template edited, phone
  /// needs an SMS provider, Apple/Google need OAuth clients.
  /// Returns true when a session exists immediately; false when Supabase
  /// sent a confirmation email first (its default for new projects).
  Future<bool> signUpWithPassword(String email, String password);
  Future<void> signInWithPassword(String email, String password);
  Future<void> signInDemo();
  Future<void> signOut();
  Future<AppUser> completeProfile({required String displayName, String? locale});
  Future<void> deleteAccount();
  Future<void> registerDevice(String token);
  Future<AppUser?> getUser(String id);
  Future<Map<String, AppUser>> getUsers(Iterable<String> ids);

  // ---- groups & invitations
  Future<List<GroupSummary>> myGroups();
  Future<Group?> getGroup(String id);
  Future<Group> createGroup({required String name, required GroupType type, GroupSettings? settings});
  Future<Group> updateGroupSettings(String groupId, {String? name, GroupType? type, GroupSettings? settings});
  Future<String?> activeInviteCode(String groupId);
  Future<String> regenerateInvite(String groupId);
  Future<void> revokeInvite(String groupId);
  Future<InvitePreview> previewInvite(String code);
  Future<JoinRequest> requestJoin(String code, {String? message});
  Future<List<JoinRequest>> pendingJoinRequests(String groupId);
  Future<List<JoinRequest>> myJoinRequests();
  Future<void> cancelJoinRequest(String requestId);
  Future<void> decideJoin(String requestId, {required bool accept});

  // ---- membership
  Future<List<Member>> members(String groupId);
  Future<Set<String>> myPermissions(String groupId);
  Future<MembershipRole?> myRole(String groupId);
  Future<void> setMemberRole(String groupId, String userId, MembershipRole role);
  Future<void> removeMember(String groupId, String userId);
  Future<void> leaveGroup(String groupId);
  Future<void> transferOwnership(String groupId, String toUserId);
  Future<void> archiveGroup(String groupId);

  // ---- tasks
  Future<List<Task>> groupTasks(String groupId);
  Future<List<Task>> personalTasks();
  Future<List<TodayRow>> myTasks();
  Future<DashboardCounts> dashboardCounts(String groupId);
  Future<Task?> getTask(String id);
  Future<List<Task>> subtasks(String parentId);
  Future<Task> createTask(TaskDraft draft);
  Future<Task> updateTask(String id, TaskPatch patch, int version);
  Future<Task> claimTask(String id);
  Future<Task> startTask(String id);
  Future<Task> releaseTask(String id);
  Future<Task> reassignTask(String id, String assigneeId);
  Future<Task> unassignTask(String id);
  Future<Task> completeTask(String id, {String? note});
  Future<Task> approveCompletion(String id);
  Future<Task> rejectCompletion(String id, String reason);
  Future<Task> cancelTask(String id, {String? reason});
  Future<Task> reopenTask(String id);
  Future<List<TaskComment>> comments(String taskId);
  Future<TaskComment> addComment(String taskId, String body);
  Future<List<ActivityEvent>> taskActivity(String taskId);

  // ---- activity, notifications, stats, search
  Future<List<ActivityEvent>> groupActivity(String groupId, {int limit = 100});
  Future<List<AppNotification>> notifications();
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();

  /// Rows the user overrode; a type absent here is both push and in-app on
  /// by default (doc 08 §5). G3 groups these by category, not one row each.
  Future<Map<String, NotifPref>> notificationPreferences();
  Future<void> setNotificationPreference(String type, {bool? push, bool? inApp});

  Future<List<MemberStats>> groupStats(String groupId, {required DateTime from, required DateTime to});
  Future<SearchResults> search(String query, {String? groupId, List<TaskStatus>? status, String? assigneeId});
}
