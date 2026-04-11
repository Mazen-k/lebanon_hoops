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
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha((255 * 0.9).round()),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withAlpha((255 * 0.05).round()),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.secondary,
          selectedLabelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: Theme.of(context).textTheme.labelSmall,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Standings'),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Teams'),
            BottomNavigationBarItem(icon: Icon(Icons.sports_basketball), label: 'Book'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Shop'),
            BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Fantasy'),
          ],
        ),
      ),
    );
  }
}
