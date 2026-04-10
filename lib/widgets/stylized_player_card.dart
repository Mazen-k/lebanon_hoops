import 'package:flutter/material.dart';
import '../theme/colors.dart';

class StylizedPlayerCard extends StatelessWidget {
  final String playerName;
  final String playerNumber;
  final String position;

  const StylizedPlayerCard({
    super.key,
    required this.playerName,
    required this.playerNumber,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 32), // space for overlapping head
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 48, bottom: 16, left: 16, right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [AppColors.surfaceContainerLow, AppColors.surfaceContainerHighest],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.48, // Tight letter spacing from design
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  position.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                ),
              ],
            ),
          ),
          
          // Background Number (10% opacity)
          Positioned(
            right: -8,
            bottom: -20,
            child: Text(
              playerNumber,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.onSurface.withAlpha((255 * 0.1).round()),
                    fontSize: 100,
                  ),
            ),
          ),
          
          // Overlapping Player Silhouette Placeholder
          Positioned(
            top: -32,
            right: 16,
            child: Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: const Icon(Icons.person, size: 64, color: AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}
