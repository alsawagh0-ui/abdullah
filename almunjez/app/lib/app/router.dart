import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/auth_screens.dart';
import '../features/groups/create_group_screen.dart';
import '../features/groups/group_activity_screen.dart';
import '../features/groups/group_dashboard_screen.dart';
import '../features/groups/group_settings_screen.dart';
import '../features/groups/group_stats_screen.dart';
import '../features/groups/groups_screen.dart';
import '../features/groups/invite_screen.dart';
import '../features/groups/join_requests_screen.dart';
import '../features/groups/join_screen.dart';
import '../features/groups/members_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/shell.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/search/search_screen.dart';
import '../features/tasks/task_detail_screen.dart';
import '../features/tasks/task_form_screen.dart';
import '../features/today/today_screen.dart';

/// Routes double as deep-link targets (doc 02 §4):
///   almunjez://task/{id}  almunjez://group/{id}  almunjez://group/{id}/requests
///   almunjez://join/{code}  almunjez://notifications
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<int>(0);
  ref.listen(currentUserProvider, (_, __) => auth.value++);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider).value;
      final loc = state.matchedLocation;
      final inAuth = loc.startsWith('/welcome') || loc.startsWith('/sign-in');
      if (user == null) return inAuth ? null : '/welcome';
      if (user.displayName.trim().isEmpty) return loc == '/profile-setup' ? null : '/profile-setup';
      if (inAuth || loc == '/profile-setup') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/today', builder: (_, __) => const TodayScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/groups', builder: (_, __) => const GroupsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen())]),
        ],
      ),
      GoRoute(path: '/task/new', builder: (_, s) => TaskFormScreen(groupId: s.uri.queryParameters['group'], parentTaskId: s.uri.queryParameters['parent'], personal: s.uri.queryParameters['personal'] == '1')),
      GoRoute(path: '/task/:id', builder: (_, s) => TaskDetailScreen(taskId: s.pathParameters['id']!)),
      GoRoute(path: '/task/:id/edit', builder: (_, s) => TaskFormScreen(editTaskId: s.pathParameters['id'])),
      GoRoute(path: '/group/new', builder: (_, __) => const CreateGroupScreen()),
      GoRoute(path: '/join', builder: (_, s) => JoinScreen(initialCode: s.uri.queryParameters['code'])),
      GoRoute(path: '/join/:code', builder: (_, s) => JoinScreen(initialCode: s.pathParameters['code'])),
      GoRoute(path: '/group/:id', builder: (_, s) => GroupDashboardScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/group/:id/invite', builder: (_, s) => InviteScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/group/:id/requests', builder: (_, s) => JoinRequestsScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/group/:id/members', builder: (_, s) => MembersScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/group/:id/activity', builder: (_, s) => GroupActivityScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/group/:id/settings', builder: (_, s) => GroupSettingsScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/group/:id/stats', builder: (_, s) => GroupStatsScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/search', builder: (_, s) => SearchScreen(groupId: s.uri.queryParameters['group'])),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
