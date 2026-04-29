import 'package:flutter/material.dart';
import '../config/app_display_name.dart';
import '../theme/colors.dart';
import '../navigation/app_nav_shell_key.dart';
import '../navigation/card_collection_section_route.dart';
import '../screens/fan_shop_screen.dart';
import '../screens/court_reservation_page.dart';
import '../screens/menu_pages.dart';
import '../screens/games/games_shell.dart';
import '../theme/theme_controller.dart';

enum MainDrawerVariant { mainApp, gamesSection }

/// Hamburger drawer: main sections + profile pinned at the bottom.
class MainAppDrawer extends StatelessWidget {
  const MainAppDrawer({
    super.key,
    required this.hostContext,
    required this.variant,
    this.onSignOut,
  });

  /// Scaffold context from the screen that owns this drawer (for navigation after close).
  final BuildContext hostContext;
  final MainDrawerVariant variant;

  /// Clears saved session and returns to login (await after drawer is closed).
  final Future<void> Function()? onSignOut;

  void _closeDrawerThen(BuildContext drawerContext, VoidCallback action) {
    Navigator.pop(drawerContext);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hostContext.mounted) action();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.sports_basketball, color: colorScheme.onPrimary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      kAppDisplayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerTile(
                    icon: Icons.flag_outlined,
                    label: 'Lebanese basketball',
                    onTap: () {
                      Navigator.pop(context);
                      if (variant == MainDrawerVariant.gamesSection) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (hostContext.mounted) Navigator.pop(hostContext);
                        });
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          appNavShellKey.currentState?.goHome();
                        });
                      }
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.sports_esports_outlined,
                    label: 'Games',
                    selected: variant == MainDrawerVariant.gamesSection,
                    onTap: () {
                      if (variant == MainDrawerVariant.gamesSection) {
                        Navigator.pop(context);
                        return;
                      }
                      _closeDrawerThen(context, () {
                        Navigator.of(hostContext).push(
                          buildCardCollectionSectionRoute(onSignOut: onSignOut),
                        );
                      });
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Fan shop',
                    onTap: () => _closeDrawerThen(context, () {
                      Navigator.of(hostContext).push(
                        MaterialPageRoute<void>(builder: (_) => const FanShopScreen()),
                      );
                    }),
                  ),
                  _DrawerTile(
                    icon: Icons.event_available_outlined,
                    label: 'Court booking',
                    onTap: () => _closeDrawerThen(context, () {
                      Navigator.of(hostContext).push(
                        MaterialPageRoute<void>(builder: (_) => const CourtReservationPage()),
                      );
                    }),
                  ),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _closeDrawerThen(context, () {
                      Navigator.of(hostContext).push(
                        MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                      );
                    }),
                  ),
                  _DrawerTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About us',
                    onTap: () => _closeDrawerThen(context, () {
                      Navigator.of(hostContext).push(
                        MaterialPageRoute<void>(builder: (_) => const AboutUsPage()),
                      );
                    }),
                  ),
                  ListenableBuilder(
                    listenable: ThemeController(),
                    builder: (context, _) {
                      final isDark = ThemeController().isDarkMode;
                      return _DrawerSwitchTile(
                        icon: isDark ? Icons.dark_mode : Icons.light_mode,
                        label: 'Dark Mode',
                        value: isDark,
                        onChanged: (val) => ThemeController().toggleTheme(val),
                      );
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            if (onSignOut != null)
              _DrawerTile(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                denseBottom: true,
                onTap: () {
                  final signOut = onSignOut!;
                  // Close drawer first (maybePop returns a Future; pop() is void on some SDKs).
                  Navigator.maybePop(context).whenComplete(() => signOut());
                },
              ),
            _DrawerTile(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              denseBottom: true,
              onTap: () => _closeDrawerThen(context, () {
                Navigator.of(hostContext).push(
                  MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.denseBottom = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool denseBottom;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = selected ? colorScheme.primary.withAlpha((255 * 0.08).round()) : null;
    return Material(
      color: bg,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: denseBottom ? 4 : 2),
        leading: Icon(icon, color: selected ? colorScheme.primary : colorScheme.secondary),
        title: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _DrawerSwitchTile extends StatelessWidget {
  const _DrawerSwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, color: colorScheme.secondary),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
      ),
    );
  }
}
