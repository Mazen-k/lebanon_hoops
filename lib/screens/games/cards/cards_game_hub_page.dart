import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import 'open_packs_page.dart';
import 'card_mode_placeholders.dart';
import 'trade_hub_page.dart';
import 'view_collection_page.dart';

/// Entry points into the card game modes.
class CardsGameHubPage extends StatelessWidget {
  const CardsGameHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Card game',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a mode',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
            children: [
              _HubBox(
                icon: Icons.inventory_2_outlined,
                label: 'Open packs',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const OpenPacksPage()),
                ),
              ),
              _HubBox(
                icon: Icons.collections_bookmark_outlined,
                label: 'View collection',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ViewCollectionPage()),
                ),
              ),
              _HubBox(
                icon: Icons.layers_outlined,
                label: 'Duplicates',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ViewCollectionPage(duplicatesOnly: true)),
                ),
              ),
              _HubBox(
                icon: Icons.sports_esports_outlined,
                label: '1v1',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const OneVOnePage()),
                ),
              ),
              _HubBox(
                icon: Icons.swap_horiz_rounded,
                label: 'Trade',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const TradeHubPage()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubBox extends StatelessWidget {
  const _HubBox({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.surfaceContainerLow,
                AppColors.surfaceContainerHighest,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withAlpha(18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
