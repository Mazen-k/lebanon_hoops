import 'package:flutter/material.dart';
import '../navigation/app_nav_shell_key.dart';
import 'court_booking_screen.dart';
import 'games/games_shell.dart';
import '../widgets/menu_placeholder_page.dart';

class ShopBookingPage extends StatelessWidget {
  const ShopBookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Shop & shortcuts'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Jump to league fixtures, the fan shop, or open court booking in a full screen.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colorScheme.secondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              appNavShellKey.currentState?.goToTab(1);
            },
            icon: const Icon(Icons.event_note_rounded),
            label: const Text('League fixtures'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final host = appNavShellKey.currentContext;
                if (host != null && host.mounted) {
                  Navigator.of(host).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const GamesShell()),
                  );
                }
              });
            },
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Fan shop'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final host = appNavShellKey.currentContext;
                if (host != null && host.mounted) {
                  Navigator.of(host).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const CourtBookingScreen(),
                    ),
                  );
                }
              });
            },
            icon: const Icon(Icons.sports_basketball),
            label: const Text('Book a court'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary.withAlpha(180)),
              padding: const EdgeInsets.symmetric(vertical: 14),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('About us'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: const MenuPlaceholderPage(
        title: 'Your profile',
        subtitle: 'Stats and account details will show here.',
      ),
    );
  }
}
