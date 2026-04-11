import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../navigation/app_nav_shell_key.dart';
import '../screens/menu_pages.dart';
import '../screens/games/games_shell.dart';

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
    return Drawer(
      backgroundColor: AppColors.surfaceContainerLowest,
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
                      gradient: AppColors.signatureGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sports_basketball, color: AppColors.onPrimary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lebanon Hoops',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            color: AppColors.onSurface,
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
                    icon: Icons.videogame_asset_outlined,
                    label: 'Games',
                    selected: variant == MainDrawerVariant.gamesSection,
                    onTap: () {
                      if (variant == MainDrawerVariant.gamesSection) {
                        Navigator.pop(context);
                        return;
                      }
                      _closeDrawerThen(context, () {
                        Navigator.of(hostContext).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GamesShell(onSignOut: onSignOut),
                          ),
                        );
                      });
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.storefront_outlined,
                    label: 'Shop / booking',
                    onTap: () => _closeDrawerThen(context, () {
                      Navigator.of(hostContext).push(
                        MaterialPageRoute<void>(builder: (_) => const ShopBookingPage()),
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
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outlineVariant),
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
    final bg = selected ? AppColors.primary.withAlpha((255 * 0.08).round()) : null;
    return Material(
      color: bg,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: denseBottom ? 4 : 2),
        leading: Icon(icon, color: selected ? AppColors.primary : AppColors.secondary),
        title: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.onSurface,
              ),
        ),
        onTap: onTap,
      ),
    );
  }
}
