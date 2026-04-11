import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/auth_text_field.dart';
import '../services/auth_api_service.dart';
import '../services/auth_service.dart';
import '../services/session_store.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onAuthSuccess});

  /// Called after credentials are saved; parent should reload session and show the app shell.
  final Future<void> Function()? onAuthSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmail = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthApiService();

  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameOrEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final session = await _auth.login(
        usernameOrEmail: _usernameOrEmail.text.trim(),
        password: _password.text,
      );
      await SessionStore.instance.save(session);
      if (!mounted) return;
      await widget.onAuthSuccess?.call();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not reach the server. Check API_BASE_URL and that the API is running.\n$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _buildHero(context),
              const SizedBox(height: 28),
              _buildSectionTitle('SIGN IN'),
              const SizedBox(height: 20),
              GlassCard(
                borderRadius: 12,
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        controller: _usernameOrEmail,
                        label: 'Username or email',
                        hint: 'Your username or email',
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      AuthTextField(
                        controller: _password,
                        label: 'Password',
                        hint: 'Your account password',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.secondary,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 8) return 'At least 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        )
                      else
                        GradientButton(text: 'Log in', onPressed: _submit),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New here? ',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onSurfaceVariant,
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
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      decoration: BoxDecoration(
        gradient: AppColors.signatureGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha((255 * 0.25).round()),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lebanon Hoops',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome back — pick up where you left off.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.onPrimary.withAlpha((255 * 0.92).round()),
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
          ),
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -1,
              height: 1,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
