import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_vendor_session.dart';
import 'session_store.dart';
import 'vendor_session_store.dart';

/// Persists shop-owner (vendor) login separately from fan [SessionStore]
/// and court [VendorSessionStore].
class ShopVendorSessionStore {
  ShopVendorSessionStore._();
  static final ShopVendorSessionStore instance = ShopVendorSessionStore._();

  static const _kToken = 'shop_vendor_token';
  static const _kId = 'shop_vendor_id';
  static const _kShopName = 'shop_vendor_shop_name';
  static const _kUsername = 'shop_vendor_username';

  Future<void> save(ShopVendorSession session) async {
    // Clear competing sessions.
    await SessionStore.instance.clear();
    await VendorSessionStore.instance.clear();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, session.token);
    await p.setInt(_kId, session.shopVendorId);
    await p.setString(_kShopName, session.shopName);
    await p.setString(_kUsername, session.username);
  }

  Future<ShopVendorSession?> load() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString(_kToken);
    final id = p.getInt(_kId);
    final shopName = p.getString(_kShopName);
    final username = p.getString(_kUsername);
    if (token == null || token.isEmpty || id == null || shopName == null || username == null) {
      return null;
    }
    return ShopVendorSession(
      token: token,
      shopVendorId: id,
      shopName: shopName,
      username: username,
    );
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kId);
    await p.remove(_kShopName);
    await p.remove(_kUsername);
  }
}
