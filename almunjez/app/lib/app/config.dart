/// Build-time configuration. Without Supabase values the app runs on the
/// local rules engine (data stays on the device).
///
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get useSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Universal link host used in QR payloads (doc 02 §4, doc 12 §E18).
  static const joinLinkBase = 'https://almunjez.app/join/';
}
