import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../models/user_session.dart';
import '../models/vendor_session.dart';
import '../navigation/app_nav_shell_key.dart';
import '../screens/login_screen.dart';
import '../screens/vendor_court_dashboard_page.dart';
import '../services/session_store.dart';
import '../services/vendor_session_store.dart';
import '../widgets/main_app_drawer.dart';

/// Restores fan or court-vendor session; toggles between login, main shell, or vendor hub.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;
  UserSession? _user;
  VendorSession? _vendor;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      var vendor = await VendorSessionStore.instance.load();
      var user = await SessionStore.instance.load();
      if (vendor != null && user != null) {
        await VendorSessionStore.instance.clear();
        vendor = null;
      }
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _user = user;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vendor = null;
        _user = null;
        _ready = true;
      });
    }
  }

  Future<void> _handleSignOut() async {
    if (!mounted) return;
    setState(() => _user = null);
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

  Future<void> _handleAuthSuccess() async {
    try {
      final user = await SessionStore.instance.load();
      if (!mounted) return;
      setState(() {
        _user = user;
        _vendor = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _user = null);
    }
  }

  Future<void> _handleVendorSignedIn() async {
    try {
      final vendor = await VendorSessionStore.instance.load();
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _user = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _vendor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFBB0013))),
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
    );
  }
}
