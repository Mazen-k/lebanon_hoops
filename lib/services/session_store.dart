import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';

/// Persists login so the app opens signed-in after restart.
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _kUserId = 'session_user_id';
  static const _kUsername = 'session_username';
  static const _kEmail = 'session_email';

  /// Must match keys in [VendorSessionStore] — cleared when a fan signs in.
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
  }

  Future<UserSession?> load() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getInt(_kUserId);
    final username = p.getString(_kUsername);
    final email = p.getString(_kEmail);
    if (id == null || username == null || email == null) return null;
    return UserSession(userId: id, username: username, email: email);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUserId);
    await p.remove(_kUsername);
    await p.remove(_kEmail);
  }
}
