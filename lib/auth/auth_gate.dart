import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_shell.dart';
import '../models/shop_vendor_session.dart';
import '../models/user_session.dart';
import '../models/vendor_session.dart';
import '../navigation/app_nav_shell_key.dart';
import '../screens/login_screen.dart';
import '../screens/vendor_court_dashboard_page.dart';
import '../screens/vendor_shop_dashboard_page.dart';
import '../services/session_store.dart';
import '../services/shop_vendor_session_store.dart';
import '../services/supabase_auth_service.dart';
import '../services/vendor_session_store.dart';
import '../widgets/main_app_drawer.dart';

/// Routes to fan login, vendor dashboard, or the main app shell.
///
/// Auth state source of truth:
///  • Fan: [Supabase.instance.client.auth.currentSession] (persisted by
///    supabase_flutter across restarts). The integer user_id / username are
///    cached in SharedPreferences by [SessionStore] so we don't hit the DB
///    on every cold start.
///  • Vendor: still managed via SharedPreferences in [VendorSessionStore].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;
  UserSession? _user;
  VendorSession? _vendor;
  ShopVendorSession? _shopVendor;

  final _authService = SupabaseAuthService();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for Supabase auth changes (Google OAuth redirect, token refresh,
    // sign-out from another tab on web, etc.).
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );
    _restore();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  // ── Startup restore ───────────────────────────────────────────────────────

  Future<void> _restore() async {
    try {
      // Shop vendor session takes precedence over court vendor.
      final shopVendor = await ShopVendorSessionStore.instance.load();
      if (shopVendor != null) {
        if (!mounted) return;
        setState(() { _shopVendor = shopVendor; _ready = true; });
        return;
      }

      // Court vendor session.
      final vendor = await VendorSessionStore.instance.load();
      if (vendor != null) {
        if (!mounted) return;
        setState(() { _vendor = vendor; _ready = true; });
        return;
      }

      // Check if Supabase has a valid (possibly refreshed) session.
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      if (supabaseUser != null) {
        // Try the local cache first to avoid a DB round-trip on every launch.
        UserSession? user = await SessionStore.instance.load();
        if (user == null || user.authId != supabaseUser.id) {
          // Cache miss or stale: fetch from Supabase DB.
          user = await _authService.fetchProfile(supabaseUser.id);
          await SessionStore.instance.save(user);
        }
        if (!mounted) return;
        setState(() { _user = user; _ready = true; });
        return;
      }
    } catch (_) {
      // Fall through to show login.
    }

    if (!mounted) return;
    setState(() { _vendor = null; _user = null; _ready = true; });
  }

  // ── Supabase auth-state stream ────────────────────────────────────────────

  Future<void> _onAuthStateChange(AuthState data) async {
    if (!mounted) return;

    if (data.event == AuthChangeEvent.signedIn && data.session != null) {
      final uid = data.session!.user.id;
      try {
        final user = await _authService.fetchProfile(uid);
        await SessionStore.instance.save(user);
        if (!mounted) return;
        setState(() { _user = user; _vendor = null; });
      } catch (_) {
        // Profile fetch failed (e.g. trigger not yet run). Show login again.
        if (!mounted) return;
        setState(() => _user = null);
      }
    } else if (data.event == AuthChangeEvent.signedOut) {
      await SessionStore.instance.clear();
      if (!mounted) return;
      setState(() => _user = null);
    } else if (data.event == AuthChangeEvent.tokenRefreshed) {
      // Session was silently refreshed — nothing to update in UI.
    }
  }

  // ── Sign-out handlers ─────────────────────────────────────────────────────

  Future<void> _handleSignOut() async {
    // Supabase sign-out fires onAuthStateChange(signedOut) which clears
    // _user via the stream listener. We also eagerly update state here so
    // the UI is instant even if the network call takes a moment.
    if (!mounted) return;
    setState(() => _user = null);
    try {
      await _authService.signOut();
    } catch (_) {}
    try {
      await SessionStore.instance.clear();
    } catch (_) {}
  }

  Future<void> _handleVendorSignOut() async {
    if (!mounted) return;
    setState(() => _vendor = null);
    try {
      await VendorSessionStore.instance.clear();
    } catch (_) {}
  }

  Future<void> _handleShopVendorSignOut() async {
    if (!mounted) return;
    setState(() => _shopVendor = null);
    try {
      await ShopVendorSessionStore.instance.clear();
    } catch (_) {}
  }

  // ── Callbacks from login / sign-up screens ────────────────────────────────

  /// Called after a successful email/password login or sign-up. The Supabase
  /// session is already active; we just need to load the user profile.
  Future<void> _handleAuthSuccess() async {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) return;
    try {
      final user = await _authService.fetchProfile(supabaseUser.id);
      await SessionStore.instance.save(user);
      if (!mounted) return;
      setState(() { _user = user; _vendor = null; });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _handleVendorSignedIn() async {
    try {
      final vendor = await VendorSessionStore.instance.load();
      if (!mounted) return;
      setState(() { _vendor = vendor; _user = null; _shopVendor = null; });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _handleShopVendorSignedIn() async {
    try {
      final shopVendor = await ShopVendorSessionStore.instance.load();
      if (!mounted) return;
      setState(() { _shopVendor = shopVendor; _user = null; _vendor = null; });
    } catch (_) {
      if (!mounted) return;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFBB0013))),
      );
    }
    if (_shopVendor != null) {
      return VendorShopDashboardPage(
        session: _shopVendor!,
        onSignedOut: _handleShopVendorSignOut,
      );
    }
    if (_vendor != null) {
      return VendorCourtDashboardPage(
        session: _vendor!,
        onSignedOut: _handleVendorSignOut,
      );
    }
    if (_user != null) {
      return AppNavigationShell(
        key: appNavShellKey,
        drawerBuilder: (hostContext) => MainAppDrawer(
          hostContext: hostContext,
          variant: MainDrawerVariant.mainApp,
          onSignOut: _handleSignOut,
        ),
      );
    }
    return LoginScreen(
      onAuthSuccess: _handleAuthSuccess,
      onVendorSignedIn: _handleVendorSignedIn,
      onShopVendorSignedIn: _handleShopVendorSignedIn,
    );
  }
}
