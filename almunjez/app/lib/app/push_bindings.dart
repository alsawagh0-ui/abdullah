import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/push.dart';
import 'router.dart';

/// Wires PushService into the running app: tokens → registerDevice,
/// taps → router, unread count → app badge.
class PushBindings extends ConsumerStatefulWidget {
  const PushBindings({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PushBindings> createState() => _PushBindingsState();
}

class _PushBindingsState extends ConsumerState<PushBindings> {
  @override
  void initState() {
    super.initState();
    final push = PushService.instance;
    push.bind();
    push.tokens.listen((t) => ref.read(apiProvider).registerDevice(t).catchError((_) {}));
    push.routeTaps.listen(_go);
    push.initialRoute().then((r) {
      if (r != null) _go(r);
    });
  }

  void _go(String link) {
    final route = routeFromLink(link);
    if (route == null || !mounted) return;
    ref.read(routerProvider).push(route);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(unreadCountProvider, (_, next) {
      final n = next.value;
      if (n != null) PushService.instance.setBadge(n);
    });
    // Permission is requested explicitly from the A5 screen (router redirect), not here.
    return widget.child;
  }
}
