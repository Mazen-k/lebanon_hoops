import 'package:flutter/material.dart';

import '../services/shop_vendor_auth_api_service.dart';
import '../services/shop_vendor_session_store.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

/// Shop owner login (credentials from `shop_vendors` table).
class ShopVendorLoginScreen extends StatefulWidget {
  const ShopVendorLoginScreen({super.key});

  @override
  State<ShopVendorLoginScreen> createState() => _ShopVendorLoginScreenState();
}

class _ShopVendorLoginScreenState extends State<ShopVendorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _api = ShopVendorAuthApiService();

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
      final session = await _api.shopVendorLogin(
        username: _username.text.trim(),
        password: _password.text,
      );
      await ShopVendorSessionStore.instance.save(session);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ShopVendorApiException catch (e) {
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
        title: const Text('Shop vendor sign in'),
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
                'Sign in with your shop account to manage items, prices, stock, and photos.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.secondary,
                      height: 1.4,
                    ),
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
                        label: 'Shop username',
                        hint: 'Username from your shop record',
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
                        GradientButton(text: 'Sign in as shop vendor', onPressed: _submit),
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
