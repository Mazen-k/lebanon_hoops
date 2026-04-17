import 'package:shared_preferences/shared_preferences.dart';

import '../models/vendor_session.dart';
import 'session_store.dart';

/// Persists court-owner (vendor) login separately from fan [SessionStore].
class VendorSessionStore {
  VendorSessionStore._();
  static final VendorSessionStore instance = VendorSessionStore._();

  static const _kToken = 'vendor_token';
  static const _kCourtId = 'vendor_court_id';
  static const _kCourtName = 'vendor_court_name';
  static const _kLocation = 'vendor_location';
  static const _kUsername = 'vendor_username';

  Future<void> save(VendorSession session) async {
    await SessionStore.instance.clear();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, session.token);
    await p.setInt(_kCourtId, session.courtId);
    await p.setString(_kCourtName, session.courtName);
    await p.setString(_kLocation, session.location);
    await p.setString(_kUsername, session.username);
  }

  Future<VendorSession?> load() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString(_kToken);
    final courtId = p.getInt(_kCourtId);
    final courtName = p.getString(_kCourtName);
    final location = p.getString(_kLocation);
    final username = p.getString(_kUsername);
    if (token == null || token.isEmpty || courtId == null || courtName == null || location == null || username == null) {
      return null;
    }
    return VendorSession(
      token: token,
      courtId: courtId,
      courtName: courtName,
      location: location,
      username: username,
    );
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kCourtId);
    await p.remove(_kCourtName);
    await p.remove(_kLocation);
    await p.remove(_kUsername);
  }
}
