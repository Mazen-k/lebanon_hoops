import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_session.dart';

/// Thrown for all Supabase auth errors with a user-friendly message.
class SupabaseAuthException implements Exception {
  final String message;
  const SupabaseAuthException(this.message);

  @override
  String toString() => message;
}

/// Wraps Supabase email/password + Google OAuth auth.
///
/// After any successful sign-in, call [fetchProfile] to get the integer
/// user_id (from public.users) that every Node.js API endpoint expects.
class SupabaseAuthService {
  SupabaseClient get _client => Supabase.instance.client;

  // ── Sign-in ──────────────────────────────────────────────────────────────

  Future<UserSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user == null) throw const SupabaseAuthException('Sign in failed.');
      return fetchProfile(res.user!.id);
    } on AuthException catch (e) {
      throw SupabaseAuthException(_mapAuthError(e.message));
    } on SupabaseAuthException {
      rethrow;
    } catch (_) {
      throw const SupabaseAuthException('Network error. Check your connection and try again.');
    }
  }

  // ── Sign-up ───────────────────────────────────────────────────────────────

  Future<UserSession> signUp({
    required String email,
    required String password,
    required String username,
    String? phoneNumber,
    int? favoriteTeamId,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'username': username.trim(),
          if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
          if (favoriteTeamId != null) 'favorite_team_id': favoriteTeamId,
        },
      );
      if (res.user == null) {
        throw const SupabaseAuthException('Sign up failed. Please try again.');
      }
      if (res.session == null) {
        // Email confirmation is required (Supabase default for new projects).
        throw const SupabaseAuthException(
          'Account created! Check your email and click the confirmation link, then sign in.',
        );
      }
      return fetchProfile(res.user!.id);
    } on AuthException catch (e) {
      throw SupabaseAuthException(_mapAuthError(e.message));
    } on SupabaseAuthException {
      rethrow;
    } catch (_) {
      throw const SupabaseAuthException('Network error. Check your connection and try again.');
    }
  }

  // ── Google OAuth ──────────────────────────────────────────────────────────

  /// Launches the system browser for Google OAuth.
  ///
  /// This call returns immediately; the actual sign-in completes asynchronously
  /// when the app receives the OAuth redirect. Listen to
  /// [Supabase.instance.client.auth.onAuthStateChange] in AuthGate to react.
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConfig.oauthRedirectUrl,
      );
    } on AuthException catch (e) {
      throw SupabaseAuthException(_mapAuthError(e.message));
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('abort')) {
        throw const SupabaseAuthException('Google sign-in was cancelled.');
      }
      throw const SupabaseAuthException('Network error. Check your connection and try again.');
    }
  }

  // ── Sign-out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Profile lookup ────────────────────────────────────────────────────────

  /// Fetches the public.users row for [authId] and returns a [UserSession].
  ///
  /// The database trigger (handle_new_user) creates the row automatically
  /// when the Supabase Auth account is created, so this should always succeed
  /// for authenticated users.
  Future<UserSession> fetchProfile(String authId) async {
    try {
      final data = await _client
          .from('users')
          .select('user_id, username, email')
          .eq('auth_id', authId)
          .single();

      return UserSession(
        userId: data['user_id'] as int,
        username: (data['username'] ?? '').toString(),
        email: (data['email'] ?? '').toString(),
        authId: authId,
      );
    } catch (_) {
      throw const SupabaseAuthException(
        'Could not load your profile. Please sign in again.',
      );
    }
  }

  // ── Error mapping ─────────────────────────────────────────────────────────

  String _mapAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
      return 'Wrong email or password.';
    }
    if (lower.contains('already registered') || lower.contains('user already exists')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait a moment before trying again.';
    }
    if (lower.contains('weak password') || lower.contains('password should be')) {
      return 'Password is too weak. Use at least 8 characters.';
    }
    if (lower.contains('network') || lower.contains('socket') || lower.contains('connection')) {
      return 'Network error. Check your connection and try again.';
    }
    return raw;
  }
}
