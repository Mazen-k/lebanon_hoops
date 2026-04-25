import 'package:flutter/material.dart';

/// Provided above the tab [IndexedStack] by [AppNavigationShell]. Holds the
/// measured height of the bottom navigation bar (including [SafeArea] insets),
/// so scrollables can pad by exactly the overlap from `extendBody: true`.
class AppShellBottomOverlapScope extends InheritedWidget {
  const AppShellBottomOverlapScope({
    super.key,
    required this.overlap,
    required super.child,
  });

  /// Total height of the shell bottom bar in logical pixels, or `0` before the
  /// first layout measurement.
  final double overlap;

  static AppShellBottomOverlapScope? _maybe(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppShellBottomOverlapScope>();
  }

  /// Bottom padding for scrollables so the last item clears the nav bar.
  ///
  /// Uses the **measured** bar height from the shell. Before the first measure,
  /// falls back to [MediaQuery.viewPadding] bottom only (minimal); one frame
  /// later the measured value applies.
  static double bottomPadding(BuildContext context) {
    final scope = _maybe(context);
    final measured = scope?.overlap ?? 0;
    if (measured > 0.5) return measured;
    return MediaQuery.viewPaddingOf(context).bottom;
  }

  @override
  bool updateShouldNotify(AppShellBottomOverlapScope oldWidget) {
    return (oldWidget.overlap - overlap).abs() > 0.5;
  }
}

/// Same as [AppShellBottomOverlapScope.bottomPadding] for call sites that
/// already use this name.
double appShellBottomBarOverlap(BuildContext context) {
  return AppShellBottomOverlapScope.bottomPadding(context);
}
