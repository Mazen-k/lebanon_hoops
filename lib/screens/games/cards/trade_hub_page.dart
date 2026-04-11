import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import 'trade_lobby_page.dart';
import 'wishlist_editor_page.dart';

class TradeHubPage extends StatelessWidget {
  const TradeHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Trade'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trading',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your wishlist or trade duplicate cards with another player.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
            ),
            const SizedBox(height: 28),
            _TradeChoiceCard(
              icon: Icons.favorite_outline_rounded,
              title: 'Edit wishlist',
              subtitle: 'Browse all cards, mark what you want. Others can see your list when trading.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const WishlistEditorPage()),
              ),
            ),
            const SizedBox(height: 14),
            _TradeChoiceCard(
              icon: Icons.swap_horiz_rounded,
              title: 'Trade',
              subtitle: 'Create or join a room. Offer up to 3 duplicate cards (3-for-3 swap).',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TradeLobbyPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeChoiceCard extends StatelessWidget {
  const _TradeChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [AppColors.surfaceContainerLow, AppColors.surfaceContainerHighest],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary, height: 1.35),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
