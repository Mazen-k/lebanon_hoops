import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../navigation/app_nav_shell_key.dart';
import '../widgets/menu_placeholder_page.dart';

class ShopBookingPage extends StatelessWidget {
  const ShopBookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Shop / booking'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Jump to the main app sections for court booking and the fan shop.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              appNavShellKey.currentState?.goToTab(3);
            },
            icon: const Icon(Icons.sports_basketball),
            label: const Text('Court booking'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              appNavShellKey.currentState?.goToTab(4);
            },
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Fan shop'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: const MenuPlaceholderPage(
        title: 'Settings',
        subtitle: 'Preferences and account options will go here.',
      ),
    );
  }
}

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('About us'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: const MenuPlaceholderPage(
        title: 'Lebanon Hoops',
        subtitle: 'Lebanese basketball — built for fans.',
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: const MenuPlaceholderPage(
        title: 'Your profile',
        subtitle: 'Stats and account details will show here.',
      ),
    );
  }
}
