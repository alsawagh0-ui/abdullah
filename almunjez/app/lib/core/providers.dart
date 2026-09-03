import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/almunjez_api.dart';
import 'models/enums.dart';
import 'models/models.dart';

/// Overridden at bootstrap with LocalApi or SupabaseApi.
final apiProvider = Provider<AlMunjezApi>((ref) => throw UnimplementedError('apiProvider must be overridden'));

/// Signed-in user; null while signed out.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final api = ref.watch(apiProvider);
  final c = StreamController<AppUser?>();
  c.add(api.currentUser);
  final sub = api.authState.listen(c.add);
  ref.onDispose(() {
    sub.cancel();
    c.close();
  });
  return c.stream;
});

/// Ticks after every mutation so data providers refresh (doc 12 §E45).
final changeTickProvider = StreamProvider<int>((ref) {
  final api = ref.watch(apiProvider);
  var n = 0;
  return api.changes.map((_) => ++n);
});

/// Helper: a FutureProvider that re-runs on every change tick.
FutureProvider<T> _live<T>(Future<T> Function(AlMunjezApi api) fetch) => FutureProvider<T>((ref) {
      ref.watch(changeTickProvider);
      return fetch(ref.watch(apiProvider));
    });

FutureProviderFamily<T, A> _liveFamily<T, A>(Future<T> Function(AlMunjezApi api, A arg) fetch) => FutureProvider.family<T, A>((ref, arg) {
      ref.watch(changeTickProvider);
      return fetch(ref.watch(apiProvider), arg);
    });

final myGroupsProvider = _live((api) => api.myGroups());
final myTasksProvider = _live((api) => api.myTasks());
final personalTasksProvider = _live((api) => api.personalTasks());
final notificationsProvider = _live((api) => api.notifications());
final unreadCountProvider = _live((api) => api.unreadCount());
final myJoinRequestsProvider = _live((api) => api.myJoinRequests());

final groupProvider = _liveFamily<Group?, String>((api, id) => api.getGroup(id));
final groupTasksProvider = _liveFamily<List<Task>, String>((api, id) => api.groupTasks(id));
final dashboardCountsProvider = _liveFamily<DashboardCounts, String>((api, id) => api.dashboardCounts(id));
final membersProvider = _liveFamily<List<Member>, String>((api, id) => api.members(id));
final permissionsProvider = _liveFamily<Set<String>, String>((api, id) => api.myPermissions(id));
final pendingRequestsProvider = _liveFamily<List<JoinRequest>, String>((api, id) => api.pendingJoinRequests(id));
final groupActivityProvider = _liveFamily<List<ActivityEvent>, String>((api, id) => api.groupActivity(id));
final inviteCodeProvider = _liveFamily<String?, String>((api, id) => api.activeInviteCode(id));

final taskProvider = _liveFamily<Task?, String>((api, id) => api.getTask(id));
final subtasksProvider = _liveFamily<List<Task>, String>((api, id) => api.subtasks(id));
final commentsProvider = _liveFamily<List<TaskComment>, String>((api, id) => api.comments(id));
final taskActivityProvider = _liveFamily<List<ActivityEvent>, String>((api, id) => api.taskActivity(id));

final userProvider = FutureProvider.family<AppUser?, String>((ref, id) => ref.watch(apiProvider).getUser(id));

/// Pending join requests across every group where I can approve — for the home card.
final allPendingRequestsProvider = FutureProvider<List<JoinRequest>>((ref) async {
  final groups = await ref.watch(myGroupsProvider.future);
  final api = ref.watch(apiProvider);
  final out = <JoinRequest>[];
  for (final g in groups.where((g) => g.pendingRequests > 0)) {
    out.addAll(await api.pendingJoinRequests(g.group.id));
  }
  return out;
});

/// Convenience: does the current user hold a permission in a group?
bool can(Set<String>? perms, String key) => perms?.contains(key) ?? false;

extension RoleX on MembershipRole? {
  bool get isOwner => this == MembershipRole.owner;
  bool get isAdminOrOwner => this == MembershipRole.owner || this == MembershipRole.admin;
}
