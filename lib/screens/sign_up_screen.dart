import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/auth_text_field.dart';
import '../config/backend_config.dart';
import '../data/team_repository.dart';
import '../models/sign_up_data.dart';
import '../models/team.dart';
import '../services/auth_api_service.dart';
import '../services/auth_service.dart';
import '../services/session_store.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _phone = TextEditingController();

  final _teamsRepo = const TeamRepository();
  final _auth = AuthApiService();

  List<Team> _teams = [];
  bool _teamsLoading = true;
  String? _teamsError;
  int? _favoriteTeamId;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _teamsLoading = true;
      _teamsError = null;
    });
    try {
      final list = await _teamsRepo.fetchTeams();
      if (mounted) {
        setState(() {
          _teams = list;
          _teamsLoading = false;
          _teamsError = null;
        });
      }
    } on TeamRepositoryException catch (e) {
      if (mounted) {
        setState(() {
          _teams = [];
          _teamsLoading = false;
          _teamsError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _teams = [];
          _teamsLoading = false;
          _teamsError = 'Failed to load teams: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final phone = _phone.text.trim();
      final session = await _auth.signUp(
        SignUpData(
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          phoneNumber: phone.isEmpty ? null : phone,
          favoriteTeamId: _favoriteTeamId,
        ),
      );
      await SessionStore.instance.save(session);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('CREATE ACCOUNT'),
              const SizedBox(height: 12),
              Text(
                'Teams: GET ${BackendConfig.apiBaseUrl}/${BackendConfig.teamsPath} (DB ${BackendConfig.postgresDatabaseName}). Emulator: API_BASE_URL=http://10.0.2.2:3000',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.secondary,
                      height: 1.4,
                    ),
              ),
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
                        controller: _username,
                        label: 'Username',
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().length > 50) return 'Max 50 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        controller: _email,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().length > 100) return 'Max 100 characters';
                          final s = v.trim();
                          if (!s.contains('@') || !s.contains('.')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        controller: _password,
                        label: 'Password',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
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
                          if (v.length > 255) return 'Max 255 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        controller: _confirmPassword,
                        label: 'Confirm password',
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.next,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.secondary,
                          ),
                        ),
                        validator: (v) {
                          if (v != _password.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        controller: _phone,
                        label: 'Phone (optional)',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (v.trim().length > 20) return 'Max 20 characters';
                          return null;
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s()]')),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildFavoriteTeamField(context),
                      const SizedBox(height: 28),
                      if (_submitting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        )
                      else
                        GradientButton(text: 'Sign up', onPressed: _submit),
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

  Widget _buildFavoriteTeamField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favorite team (optional)',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (_teamsLoading)
          const LinearProgressIndicator(color: AppColors.primary, minHeight: 3)
        else if (_teamsError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _teamsError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadTeams,
                icon: const Icon(Icons.refresh, color: AppColors.primary, size: 20),
                label: Text(
                  'Retry',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          )
        else
          DropdownButtonFormField<int?>(
            value: _favoriteTeamId,
            isExpanded: true,
            hint: Text(
              _teams.isEmpty ? 'No teams from server' : 'Select a team',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('No favorite team'),
              ),
              ..._teams.map(
                (t) => DropdownMenuItem<int?>(
                  value: t.teamId,
                  child: Text(t.teamName),
                ),
              ),
            ],
            onChanged: _teams.isEmpty ? null : (v) => setState(() => _favoriteTeamId = v),
          ),
      ],
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
