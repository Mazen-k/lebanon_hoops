import 'package:flutter/material.dart';

import '../screens/games/games_shell.dart';
import '../theme/colors.dart';

/// Opens [GamesShell] with a short transition so the jump from main app styling
/// to the darker card hub feels intentional rather than abrupt.
PageRoute<void> buildCardCollectionSectionRoute({
  Future<void> Function()? onSignOut,
}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (context, animation, secondaryAnimation) {
      final veilCurve = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.72, curve: Curves.easeInOutCubic),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          GamesShell(onSignOut: onSignOut),
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(veilCurve),
            child: ColoredBox(
              color: AppColors.surfaceContainerLowest,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final enter = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.028),
            end: Offset.zero,
          ).animate(enter),
          child: child,
        ),
      );
    },
  );
}
