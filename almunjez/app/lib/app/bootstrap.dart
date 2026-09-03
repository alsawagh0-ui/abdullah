import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api/almunjez_api.dart';
import '../core/api/local/local_api.dart';
import '../core/api/supabase/supabase_api.dart';
import 'config.dart';

class PrefsStore implements LocalStore {
  PrefsStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'almunjez.local.v1';
  @override
  Future<String?> read() async => _prefs.getString(_key);
  @override
  Future<void> write(String json) => _prefs.setString(_key, json);
}

Future<AlMunjezApi> buildApi() async {
  if (AppConfig.useSupabase) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
    final api = SupabaseApi(Supabase.instance.client);
    await api.init();
    return api;
  }
  final prefs = await SharedPreferences.getInstance();
  final api = LocalApi(PrefsStore(prefs));
  await api.load();
  return api;
}
