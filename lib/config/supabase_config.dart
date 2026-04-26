/// Supabase project credentials.
///
/// The anon key is safe to ship in the client bundle (it is a public key,
/// not a secret). Never put the service-role key here.
///
/// Provide the key at build time:
///   flutter run --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// Or hard-code it below after copying from:
///   Supabase Dashboard → Project Settings → API → Project API keys → anon/public
abstract final class SupabaseConfig {
  static const String url = 'https://trsvbggjotqywzskqmjm.supabase.co';

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    // Replace the placeholder with your actual anon key if you don't want
    // to pass it via --dart-define every run.
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyc3ZiZ2dqb3RxeXd6c2txbWptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5NDEyNTgsImV4cCI6MjA5MTUxNzI1OH0.VZlgRKzedchbHJtJ22ViW-QOk4hq7XwBUhHqerY2DrU',
  );

  /// Custom URL scheme for OAuth redirects (Google sign-in).
  /// Must match the scheme registered in AndroidManifest.xml and Info.plist.
  static const String oauthRedirectScheme = 'io.supabase.lebhoops';

  static const String oauthRedirectUrl = '$oauthRedirectScheme://login-callback';
}
