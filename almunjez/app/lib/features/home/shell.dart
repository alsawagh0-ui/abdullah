import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/strings.dart';

/// Four tabs + the floating primary CTA (doc 02 §1).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return Scaffold(
      body: shell,
      floatingActionButton: shell.currentIndex == 3
          ? null
          : FloatingActionButton.extended(
              heroTag: 'new-task',
              onPressed: () => context.push('/task/new'),
              icon: const Icon(Icons.add_rounded),
              label: Text(s.newTaskCta.replaceFirst('+ ', ''), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: s.home),
          NavigationDestination(icon: const Icon(Icons.check_circle_outline), selectedIcon: const Icon(Icons.check_circle_rounded), label: s.myTasks),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups_rounded), label: s.groups),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
            selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_rounded)),
            label: s.notifications,
          ),
        ],
      ),
    );
  }
}
