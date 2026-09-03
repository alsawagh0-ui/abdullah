/// Build-time configuration. Defaults to this project's real Supabase
/// instance; pass empty --dart-define values to fall back to the local
/// rules engine (data stays on the device) for offline development/tests.
abstract final class AppConfig {
  // Defaults point at the project's own Supabase instance. The anon/publishable
  // key is the public client key by design (Row-Level Security is what
  // actually protects data, not the key's secrecy) — safe to ship in source,
  // unlike the service_role key, which must never appear here.
  // Pass --dart-define=SUPABASE_URL= (empty) to force local/offline mode instead.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://occukboecvnzjnatubre.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9jY3VrYm9lY3ZuempuYXR1YnJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0MTk2NzUsImV4cCI6MjEwMzk5NTY3NX0.6p49Fd2Mj1jErbVLGAzuMDT-573sstOHj0qkr30kPkc',
  );
  static bool get useSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Universal link host used in QR payloads (doc 02 §4, doc 12 §E18).
  static const joinLinkBase = 'https://almunjez.app/join/';

  /// Where Supabase should send the browser back after an email magic-link
  /// or OAuth redirect completes. Must also be added to Supabase →
  /// Authentication → URL Configuration → Redirect URLs, or Supabase
  /// silently ignores it and falls back to the (unset) Site URL instead.
  static const webAppUrl = 'https://alsawagh0-ui.github.io/abdullah/almunjez/';
}
