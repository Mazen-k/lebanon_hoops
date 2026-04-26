import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';

/// Local cache for the fan's integer user_id / username / email.
///
/// This is a *cache*, not the auth source-of-truth.
/// [Supabase.instance.client.auth.currentUser] is authoritative for whether
/// the user is authenticated. We store these fields to avoid a DB round-trip
/// on every cold start.
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _kUserId   = 'session_user_id';
  static const _kUsername = 'session_username';
  static const _kEmail    = 'session_email';
  static const _kAuthId   = 'session_auth_id';

  static const _vendorKeys = [
    'vendor_token',
    'vendor_court_id',
    'vendor_court_name',
    'vendor_location',
    'vendor_username',
  ];

  Future<void> save(UserSession session) async {
    final p = await SharedPreferences.getInstance();
    for (final k in _vendorKeys) {
      await p.remove(k);
    }
    await p.setInt(_kUserId, session.userId);
    await p.setString(_kUsername, session.username);
    await p.setString(_kEmail, session.email);
    if (session.authId != null) {
      await p.setString(_kAuthId, session.authId!);
    }
  }

  Future<UserSession?> load() async {
    final p = await SharedPreferences.getInstance();
    final id       = p.getInt(_kUserId);
    final username = p.getString(_kUsername);
    final email    = p.getString(_kEmail);
    if (id == null || username == null || email == null) return null;
    return UserSession(
      userId: id,
      username: username,
      email: email,
      authId: p.getString(_kAuthId),
    );
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUserId);
    await p.remove(_kUsername);
    await p.remove(_kEmail);
    await p.remove(_kAuthId);
  }
}
