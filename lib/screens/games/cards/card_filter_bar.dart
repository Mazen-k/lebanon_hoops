import 'package:flutter/material.dart';

import '../../../models/team.dart';
import '../../../theme/colors.dart';
import 'card_game_ui_theme.dart';

String? _nationalityFlagEmoji(String country) {
  switch (country) {
    case 'Lebanon':
      return '🇱🇧';
    case 'USA':
      return '🇺🇸';
    default:
      return null;
  }
}

String _clubBarLabel(List<Team> teams, int? teamId) {
  if (teamId == null) return 'Club';
  for (final t in teams) {
    if (t.teamId == teamId) return t.teamName;
  }
  return 'Club';
}

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
    this.cardGameStyle = false,
  });

  final List<String> positionOptions;
  final List<Team> teams;
  final String? positionFilter;
  final String? nationalityFilter;
  final int? teamIdFilter;
  final void Function(String?) onPosition;
  final void Function(String?) onNationality;
  final void Function(int?) onClub;
  /// When true, matches card hub / store dark styling ([CardGameUiTheme]).
  final bool cardGameStyle;

  @override
  Widget build(BuildContext context) {
    if (cardGameStyle) {
      return Material(
        color: CardGameUiTheme.elevated,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: CardFilterBoxTrigger(
                  icon: Icons.sports_basketball_rounded,
                  label: positionFilter ?? 'Position',
                  active: positionFilter != null,
                  onTap: () => _showPositionBoxPicker(
                    context,
                    options: positionOptions,
                    current: positionFilter,
                    onPick: onPosition,
                  ),
                ),
              ),
              Expanded(
                child: CardFilterBoxTrigger(
                  icon: Icons.flag_outlined,
                  topOverride: nationalityFilter != null
                      ? Text(
                          _nationalityFlagEmoji(nationalityFilter!) ?? '🏳️',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, height: 1.1),
                        )
                      : null,
                  label: nationalityFilter ?? 'Nation',
                  active: nationalityFilter != null,
                  onTap: () => _showNationalityBoxPicker(
                    context,
                    current: nationalityFilter,
                    onPick: onNationality,
                  ),
                ),
              ),
              Expanded(
                child: CardFilterBoxTrigger(
                  icon: Icons.groups_outlined,
                  label: _clubBarLabel(teams, teamIdFilter),
                  active: teamIdFilter != null,
                  onTap: () => _showClubBoxPicker(
                    context,
                    teams: teams,
                    currentTeamId: teamIdFilter,
                    onPick: onClub,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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

Future<void> _showPositionBoxPicker(
  BuildContext context, {
  required List<String> options,
  required String? current,
  required void Function(String?) onPick,
}) {
  final entries = <({String label, String value, String? flagEmoji})>[
    for (final p in options) (label: p, value: p, flagEmoji: null),
  ];
  return _showFilterBoxDialog<String>(
    context: context,
    title: 'Position',
    entries: entries,
    clearLabel: 'All positions',
    onClear: () => onPick(null),
    isSelected: (v) => v == current,
    onSelect: (v) => onPick(v),
  );
}

Future<void> _showNationalityBoxPicker(
  BuildContext context, {
  required String? current,
  required void Function(String?) onPick,
}) {
  const nations = ['Lebanon', 'USA'];
  final entries = nations
      .map(
        (n) => (
          label: n,
          value: n,
          flagEmoji: _nationalityFlagEmoji(n),
        ),
      )
      .toList();
  return _showFilterBoxDialog<String>(
    context: context,
    title: 'Nation',
    entries: entries,
    clearLabel: 'All nations',
    onClear: () => onPick(null),
    isSelected: (v) => v == current,
    onSelect: (v) => onPick(v),
  );
}

Future<void> _showClubBoxPicker(
  BuildContext context, {
  required List<Team> teams,
  required int? currentTeamId,
  required void Function(int?) onPick,
}) {
  final entries = <({String label, int value, String? flagEmoji})>[
    for (final t in teams) (label: t.teamName, value: t.teamId, flagEmoji: null),
  ];
  return _showFilterBoxDialog<int>(
    context: context,
    title: 'Club',
    entries: entries,
    clearLabel: 'All clubs',
    onClear: () => onPick(null),
    isSelected: (v) => v == currentTeamId,
    onSelect: (v) => onPick(v),
  );
}

Future<void> _showFilterBoxDialog<T>({
  required BuildContext context,
  required String title,
  required List<({String label, T value, String? flagEmoji})> entries,
  required String clearLabel,
  required VoidCallback onClear,
  required bool Function(T value) isSelected,
  required void Function(T value) onSelect,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withAlpha(200),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 400, maxHeight: maxH),
          decoration: BoxDecoration(
            color: CardGameUiTheme.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: CardGameUiTheme.gold.withAlpha(100), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: CardGameUiTheme.orangeGlow.withAlpha(40),
                blurRadius: 24,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CardGameUiTheme.onDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Tap a box to filter',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CardGameUiTheme.onDark.withAlpha(140),
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: (maxH - 150).clamp(160.0, 520.0)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: entries.map((e) {
                      final sel = isSelected(e.value);
                      return _FilterOptionBox(
                        label: e.label,
                        flagEmoji: e.flagEmoji,
                        selected: sel,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onSelect(e.value);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onClear();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CardGameUiTheme.onDark.withAlpha(220),
                    side: BorderSide(color: CardGameUiTheme.gold.withAlpha(120)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    clearLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FilterOptionBox extends StatelessWidget {
  const _FilterOptionBox({
    required this.label,
    this.flagEmoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? flagEmoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nameStyle = TextStyle(
      color: selected ? CardGameUiTheme.onDark : CardGameUiTheme.onDark.withAlpha(210),
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      fontSize: 13.5,
      height: 1.2,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minWidth: 96, maxWidth: 160),
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: flagEmoji != null ? 14 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: selected ? 2 : 1.2,
              color: selected ? CardGameUiTheme.gold : CardGameUiTheme.panelBorder.withAlpha(200),
            ),
            color: selected
                ? CardGameUiTheme.gold.withAlpha(42)
                : CardGameUiTheme.elevated.withAlpha(230),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: CardGameUiTheme.orangeGlow.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (flagEmoji != null) ...[
                Text(
                  flagEmoji!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, height: 1.05),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable filter control that opens the box picker (card game style).
class CardFilterBoxTrigger extends StatelessWidget {
  const CardFilterBoxTrigger({
    super.key,
    required this.icon,
    this.topOverride,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  /// When set (e.g. nation flag emoji), shown instead of [icon] in the top slot.
  final Widget? topOverride;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        active ? CardGameUiTheme.gold : CardGameUiTheme.onDark.withAlpha(160);
    final labelColor =
        active ? CardGameUiTheme.gold : CardGameUiTheme.onDark.withAlpha(150);

    final top = topOverride != null
        ? SizedBox(
            height: 26,
            width: 40,
            child: Center(child: topOverride),
          )
        : Icon(icon, size: 26, color: iconColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            top,
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: labelColor,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                    height: 1.15,
                  ),
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
