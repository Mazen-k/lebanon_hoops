import 'package:flutter/material.dart';
import '../config/app_display_name.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/auth_text_field.dart';
import '../services/supabase_auth_service.dart';
import '../services/session_store.dart';
import 'sign_up_screen.dart';
import 'shop_vendor_login_screen.dart';
import 'vendor_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onAuthSuccess, this.onVendorSignedIn, this.onShopVendorSignedIn});

  final Future<void> Function()? onAuthSuccess;
  final Future<void> Function()? onVendorSignedIn;
  final Future<void> Function()? onShopVendorSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = SupabaseAuthService();

  bool _obscurePassword = true;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // ── Email / password sign-in ──────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final session = await _auth.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      await SessionStore.instance.save(session);
      if (!mounted) return;
      await widget.onAuthSuccess?.call();
    } on SupabaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Network error. Check your connection and try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google OAuth ──────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      // Opens the system browser; AuthGate reacts via onAuthStateChange.
      await _auth.signInWithGoogle();
      // On web the page reloads; on mobile the deep-link fires.
      // Either way, AuthGate handles the transition automatically.
    } on SupabaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start Google sign-in. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _buildHero(context),
              const SizedBox(height: 12),
              _buildSectionTitle(context, 'SIGN IN'),
              const SizedBox(height: 8),

              // Email + password inside GlassCard only.
              // Google button lives OUTSIDE the GlassCard so it is never
              // inside a BackdropFilter compositing layer — which can silently
              // clip content on iOS with the Impeller renderer.
              GlassCard(
                borderRadius: 12,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        controller: _email,
                        label: 'Email',
                        hint: 'Your email address',
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        controller: _password,
                        label: 'Password',
                        hint: 'Your account password',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: colorScheme.secondary,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 8) return 'At least 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(color: colorScheme.primary),
                          ),
                        )
                      else
                        GradientButton(text: 'Sign in', onPressed: _submit),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── OR divider ────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: colorScheme.outlineVariant,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: colorScheme.outlineVariant,
                      thickness: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Google sign-in button ─────────────────────────────────────
              _googleLoading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(color: colorScheme.primary),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _loading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: colorScheme.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const _GoogleLogo(),
                      label: Text(
                        'Continue with Google',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),

              const SizedBox(height: 12),

              // ── Create account link ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New here? ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final signedUp = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => const SignUpScreen(),
                        ),
                      );
                      if (signedUp == true && context.mounted) {
                        await widget.onAuthSuccess?.call();
                      }
                    },
                    child: Text(
                      'Create account',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Vendor links ──────────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: (_loading || _googleLoading)
                      ? null
                      : () async {
                          final ok = await Navigator.of(context).push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (_) => const VendorLoginScreen(),
                            ),
                          );
                          if (ok == true && context.mounted) {
                            await widget.onVendorSignedIn?.call();
                          }
                        },
                  child: Text(
                    'Sign in as court vendor',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.secondary,
                        ),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: (_loading || _googleLoading)
                      ? null
                      : () async {
                          final ok = await Navigator.of(context).push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (_) => const ShopVendorLoginScreen(),
                            ),
                          );
                          if (ok == true && context.mounted) {
                            await widget.onShopVendorSignedIn?.call();
                          }
                        },
                  child: Text(
                    'Sign in as shop vendor',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.secondary,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.primaryContainer]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha((255 * 0.25).round()),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kAppDisplayName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back — pick up where you left off.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withAlpha((255 * 0.92).round()),
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
          ),
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -1,
              height: 1,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple inline Google "G" logo painted with a CustomPainter.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    void arc(double start, double sweep, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        start,
        sweep,
        false,
        paint,
      );
    }

    arc(-0.3, 1.3, const Color(0xFF4285F4)); // blue  (top-right → right)
    arc(1.0,  1.2, const Color(0xFFEA4335)); // red   (bottom-right → bottom)
    arc(2.2,  1.2, const Color(0xFFFBBC05)); // yellow (bottom-left)
    arc(3.4,  1.2, const Color(0xFF34A853)); // green  (left → top-left)

    // Horizontal bar for the "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.72 - size.width * 0.04, cy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
