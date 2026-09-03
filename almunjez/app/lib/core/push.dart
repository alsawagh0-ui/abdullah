import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart side of `almunjez/push` (see ios/Runner/AppDelegate.swift).
/// Delivers the APNs token to the backend and notification taps to the router.
class PushService {
  PushService._();
  static final instance = PushService._();

  static const _ch = MethodChannel('almunjez/push');
  final _routes = StreamController<String>.broadcast();
  final _tokens = StreamController<String>.broadcast();
  bool _bound = false;

  Stream<String> get routeTaps => _routes.stream;
  Stream<String> get tokens => _tokens.stream;

  bool get supported => !kIsWeb && Platform.isIOS;

  void bind() {
    if (_bound || !supported) return;
    _bound = true;
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onToken':
          _tokens.add(call.arguments as String);
        case 'onTap':
          _routes.add(call.arguments as String);
        case 'onForeground':
          break; // Realtime already refreshes; no banner (doc 08 §8)
      }
    });
  }

  /// Asks for permission (A5) and starts APNs registration; the token arrives on [tokens].
  Future<bool> requestPermission() async {
    if (!supported) return false;
    bind();
    final granted = await _ch.invokeMethod<bool>('requestPermission') ?? false;
    final existing = await _ch.invokeMethod<String>('getToken');
    if (existing != null) _tokens.add(existing);
    return granted;
  }

  /// Route carried by the notification the app was launched from, if any.
  Future<String?> initialRoute() async {
    if (!supported) return null;
    return _ch.invokeMethod<String>('getInitialRoute');
  }

  Future<void> setBadge(int n) async {
    if (!supported) return;
    await _ch.invokeMethod('setBadge', n);
  }
}

/// `almunjez://task/{id}` → `/task/{id}` for go_router.
String? routeFromLink(String link) {
  final u = Uri.tryParse(link);
  if (u == null) return null;
  if (u.scheme == 'almunjez') return '/${u.host}${u.path}';
  if (u.host == 'almunjez.app' && u.pathSegments.isNotEmpty && u.pathSegments.first == 'join' && u.pathSegments.length == 2) {
    return '/join/${u.pathSegments[1]}';
  }
  return null;
}
