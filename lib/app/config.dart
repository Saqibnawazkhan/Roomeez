/// Build-time configuration, passed with `--dart-define-from-file`.
///
/// Without Supabase settings the app runs on the in-memory demo data.
abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The project's publishable key (or the legacy anon key). It is safe to
  /// ship in the app: row-level security decides what each user can do.
  static const String supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static bool get useSupabase => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
