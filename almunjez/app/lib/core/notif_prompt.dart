import 'package:shared_preferences/shared_preferences.dart';

const _kSeenKey = 'almunjez.notif_prompt_seen';

/// Tracks whether A5 (doc 02) has been shown, so the router only routes
/// there once per install. Loaded synchronously before the first frame in
/// main.dart, so the router's redirect can read it without awaiting.
class NotifPromptStore {
  NotifPromptStore._();
  static final instance = NotifPromptStore._();

  bool seen = true; // safe default until load() completes

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    seen = prefs.getBool(_kSeenKey) ?? false;
  }

  Future<void> markSeen() async {
    seen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  }
}
