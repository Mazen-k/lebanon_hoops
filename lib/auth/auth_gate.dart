import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../navigation/app_nav_shell_key.dart';
import '../screens/login_screen.dart';
import '../services/session_store.dart';
import '../widgets/main_app_drawer.dart';

/// Restores session on cold start; toggles between login and main shell.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _signedIn;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final session = await SessionStore.instance.load();
      if (!mounted) return;
      setState(() => _signedIn = session != null);
    } catch (_) {
      if (!mounted) return;
      // SharedPreferences or platform store failed — still show the app (login).
      setState(() => _signedIn = false);
    }
  }

  Future<void> _handleSignOut() async {
    if (!mounted) return;
    // Show login immediately; prefs clear can hang on some platforms if awaited first.
    setState(() => _signedIn = false);
    try {
      await SessionStore.instance.clear();
    } catch (_) {
      // Session file may be unreadable; user is already on login.
    }
  }

  Future<void> _handleAuthSuccess() async {
    try {
      final session = await SessionStore.instance.load();
      if (!mounted) return;
      setState(() => _signedIn = session != null);
    } catch (_) {
      if (!mounted) return;
      // Save succeeded in login/sign-up; don't trap user on login if reload fails.
      setState(() => _signedIn = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_signedIn == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFBB0013))),
      );
    }
    if (_signedIn!) {
      return AppNavigationShell(
        key: appNavShellKey,
        drawerBuilder: (hostContext) => MainAppDrawer(
          hostContext: hostContext,
          variant: MainDrawerVariant.mainApp,
          onSignOut: _handleSignOut,
        ),
      );
    }
    return LoginScreen(onAuthSuccess: _handleAuthSuccess);
  }
}
