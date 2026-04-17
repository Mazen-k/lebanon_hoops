import 'dart:ui';
import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'screens/home_screen.dart';
import 'screens/team_profile_screen.dart';
import 'screens/standings_screen.dart';
import 'screens/fan_shop_screen.dart';
import 'screens/court_booking_screen.dart';
import 'screens/fantasy_screen.dart';

class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({
    super.key,
    required this.drawerBuilder,
  });

  final Widget Function(BuildContext hostContext) drawerBuilder;

  @override
  State<AppNavigationShell> createState() => AppNavigationShellState();
}

class AppNavigationShellState extends State<AppNavigationShell> {
  int _currentIndex = 0;

  static const _titles = [
    'Home',
    'Standings',
    'Teams',
    'Book',
    'Shop',
    'Fantasy',
  ];

  final List<Widget> _screens = [
    const HomeScreen(),
    const StandingsScreen(),
    const TeamProfileScreen(),
    const CourtBookingScreen(),
    const FanShopScreen(),
    const FantasyScreen(),
  ];

  void goToTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() => _currentIndex = index);
  }

  void goHome() => goToTab(0);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHome = _currentIndex == 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
              title: Text(
                _titles[_currentIndex].toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              backgroundColor: colorScheme.surface.withAlpha(204),
              foregroundColor: colorScheme.onSurface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              ),
              leading: Builder(
                builder: (scaffoldContext) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                ),
              ),
            ),
      drawer: widget.drawerBuilder(context),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withAlpha(204),
              border: Border(top: BorderSide(color: Colors.white.withAlpha(13))), // border-white/5
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                )
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home, 'Home'),
                    _buildNavItem(1, Icons.leaderboard, 'Standings'),
                    _buildNavItem(2, Icons.group, 'Teams'),
                    _buildNavItem(3, Icons.sports_basketball, 'Book'),
                    _buildNavItem(4, Icons.shopping_bag, 'Shop'),
                    _buildNavItem(5, Icons.person, 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withAlpha(128),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withAlpha(128),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
