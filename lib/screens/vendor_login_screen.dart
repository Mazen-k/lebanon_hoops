import 'package:flutter/material.dart';

import '../services/vendor_auth_api_service.dart';
import '../services/vendor_session_store.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

/// Court owner login (credentials from `courts` table).
class VendorLoginScreen extends StatefulWidget {
  const VendorLoginScreen({super.key});

  @override
  State<VendorLoginScreen> createState() => _VendorLoginScreenState();
}

class _VendorLoginScreenState extends State<VendorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _api = VendorAuthApiService();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final session = await _api.courtLogin(
        username: _username.text.trim(),
        password: _password.text,
      );
      await VendorSessionStore.instance.save(session);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on VendorAuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Court / vendor sign in'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign in with your court account to manage playgrounds, photos, prices, and booking slots.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.secondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              GlassCard(
                borderRadius: 12,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        controller: _username,
                        label: 'Court username',
                        hint: 'Username from your court record',
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        controller: _password,
                        label: 'Password',
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: colorScheme.secondary,
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
                        GradientButton(text: 'Sign in as court', onPressed: _submit),
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
}
