import 'package:flutter/material.dart';

import '../../../models/team.dart';
import '../../../theme/colors.dart';

/// Position / nation / club filters (same row as collection).
class CardCatalogFilterBar extends StatelessWidget {
  const CardCatalogFilterBar({
    super.key,
    required this.positionOptions,
    required this.teams,
    required this.positionFilter,
    required this.nationalityFilter,
    required this.teamIdFilter,
    required this.onPosition,
    required this.onNationality,
    required this.onClub,
  });

  final List<String> positionOptions;
  final List<Team> teams;
  final String? positionFilter;
  final String? nationalityFilter;
  final int? teamIdFilter;
  final void Function(String?) onPosition;
  final void Function(String?) onNationality;
  final void Function(int?) onClub;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CardFilterPopupButton<String>(
              icon: Icons.sports_basketball_rounded,
              label: 'Position',
              active: positionFilter != null,
              itemBuilder: (ctx) => [
                const PopupMenuItem<String>(
                  value: '__clear__',
                  child: Text('All positions'),
                ),
                ...positionOptions.map(
                  (p) => PopupMenuItem<String>(value: p, child: Text(p)),
                ),
              ],
              onSelected: (v) {
                if (v == '__clear__') {
                  onPosition(null);
                } else {
                  onPosition(v);
                }
              },
            ),
            CardFilterPopupButton<String>(
              icon: Icons.flag_outlined,
              label: 'Nation',
              active: nationalityFilter != null,
              itemBuilder: (ctx) => const [
                PopupMenuItem<String>(value: '__clear__', child: Text('All')),
                PopupMenuItem<String>(value: 'Lebanon', child: Text('Lebanon')),
                PopupMenuItem<String>(value: 'USA', child: Text('USA')),
              ],
              onSelected: (v) {
                if (v == '__clear__') {
                  onNationality(null);
                } else {
                  onNationality(v);
                }
              },
            ),
            CardFilterPopupButton<int>(
              icon: Icons.groups_outlined,
              label: 'Club',
              active: teamIdFilter != null,
              itemBuilder: (ctx) => [
                const PopupMenuItem<int>(value: -1, child: Text('All clubs')),
                ...teams.map(
                  (t) => PopupMenuItem<int>(value: t.teamId, child: Text(t.teamName)),
                ),
              ],
              onSelected: (v) {
                if (v == -1) {
                  onClub(null);
                } else {
                  onClub(v);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CardFilterPopupButton<T> extends StatelessWidget {
  const CardFilterPopupButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.itemBuilder,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool active;
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final PopupMenuItemSelected<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: label,
      offset: const Offset(0, 40),
      itemBuilder: itemBuilder,
      onSelected: onSelected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 26,
            color: active ? AppColors.primary : AppColors.secondary,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active ? AppColors.primary : AppColors.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
