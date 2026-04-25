import 'dart:ui';

import 'package:flutter/material.dart';

import 'layout/app_shell_bottom_inset.dart';
import 'screens/home_screen.dart';
import 'screens/fixtures_screen.dart';
import 'screens/standings_screen.dart';
import 'screens/team_stats_screen.dart';
import 'screens/teams_grid_screen.dart';

class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({super.key, required this.drawerBuilder});

  final Widget Function(BuildContext hostContext) drawerBuilder;

  @override
  State<AppNavigationShell> createState() => AppNavigationShellState();
}

class AppNavigationShellState extends State<AppNavigationShell> {
  int _currentIndex = 0;

  /// Measured height of [bottomNavigationBar] (logical px), for tab scroll padding.
  double _bottomOverlap = 0;

  static const _titles = ['Home', 'Games', 'Standings', 'Teams', 'Stats'];

  final List<Widget> _screens = [
    const HomeScreen(),
    const FixturesScreen(),
    const StandingsScreen(),
    const TeamsGridScreen(),
    const TeamStatsScreen(),
  ];

  void goToTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() => _currentIndex = index);
  }

  void goHome() => goToTab(0);

  void _onBottomNavLaidOut(double height) {
    if (!mounted) return;
    if ((height - _bottomOverlap).abs() < 0.5) return;
    setState(() => _bottomOverlap = height);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: false,
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
      body: AppShellBottomOverlapScope(
        overlap: _bottomOverlap,
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: _ShellBottomNavMeasure(
        onHeight: _onBottomNavLaidOut,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withAlpha(204),
                border: Border(
                  top: BorderSide(color: Colors.white.withAlpha(13)),
                ), // border-white/5
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home, 'Home'),
                      _buildNavItem(1, Icons.event_note_rounded, 'Games'),
                      _buildNavItem(2, Icons.leaderboard, 'Standings'),
                      _buildNavItem(3, Icons.group, 'Teams'),
                      _buildNavItem(4, Icons.table_chart_outlined, 'Stats'),
                    ],
                  ),
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
          color: isSelected
              ? colorScheme.primary.withAlpha(26)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withAlpha(128),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withAlpha(128),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reports the laid-out height of the bottom nav after each frame (text scale,
/// orientation, and safe-area changes update the parent shell).
class _ShellBottomNavMeasure extends StatefulWidget {
  const _ShellBottomNavMeasure({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<_ShellBottomNavMeasure> createState() => _ShellBottomNavMeasureState();
}

class _ShellBottomNavMeasureState extends State<_ShellBottomNavMeasure> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _postFrameScheduled = false;

  void _scheduleMeasure() {
    if (_postFrameScheduled) return;
    _postFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameScheduled = false;
      if (!mounted) return;
      final ctx = _repaintKey.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      widget.onHeight(box.size.height);
    });
  }

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return RepaintBoundary(key: _repaintKey, child: widget.child);
  }
}
