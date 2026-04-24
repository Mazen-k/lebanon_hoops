import 'package:flutter/material.dart';

import '../../../models/team.dart';
import '../../../theme/colors.dart';
import 'card_game_ui_theme.dart';

/// Bundled art for card type filter (`base` / `import` in DB).
const String kCardTypeAssetBase = 'assets/images/card_type/base.png';
const String kCardTypeAssetImport = 'assets/images/card_type/Import.png';

String clubLogoAssetPath(int teamId) => 'assets/images/club_logo/$teamId.png';

Widget _clubMenuLogo(Team t) {
  final url = t.logoUrl?.trim();
  if (url != null && url.isNotEmpty) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: 40,
      height: 40,
      errorBuilder: (_, __, ___) => Image.asset(
        clubLogoAssetPath(t.teamId),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.groups_2_outlined, color: AppColors.primary),
      ),
    );
  }
  return Image.asset(
    clubLogoAssetPath(t.teamId),
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) =>
        Icon(Icons.groups_2_outlined, color: AppColors.primary),
  );
}

/// Flag for known codes; otherwise null (caller may use 🏳️).
String? _nationalityFlagEmojiForValue(String raw) {
  final u = raw.trim().toUpperCase();
  if (const {'LB', 'LEB', 'LEBANON', 'LBN'}.contains(u)) return '🇱🇧';
  if (const {'US', 'USA', 'UNITED STATES'}.contains(u)) return '🇺🇸';
  return null;
}

String _cardTypeBarLabel(String? canonical) {
  if (canonical == null) return 'Type';
  if (canonical == 'base') return 'Base';
  if (canonical == 'import') return 'Import';
  return 'Type';
}

Widget? _cardTypeBarTop(String? canonical) {
  String? asset;
  if (canonical == 'base') {
    asset = kCardTypeAssetBase;
  } else if (canonical == 'import') {
    asset = kCardTypeAssetImport;
  }
  if (asset == null) return null;
  return SizedBox(
    height: 26,
    width: 34,
    child: Image.asset(
      asset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.style_outlined,
        size: 22,
        color: CardGameUiTheme.onDark,
      ),
    ),
  );
}

Widget _clubBarTop(List<Team> teams, int? teamId, Color iconColor) {
  if (teamId == null) {
    return Icon(Icons.groups_outlined, size: 24, color: iconColor);
  }
  String? logoUrl;
  for (final t in teams) {
    if (t.teamId == teamId) {
      logoUrl = t.logoUrl?.trim();
      break;
    }
  }
  if (logoUrl != null && logoUrl.isNotEmpty) {
    return SizedBox(
      height: 26,
      width: 34,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.network(
            logoUrl,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.groups_outlined, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }
  return SizedBox(
    height: 26,
    width: 34,
    child: Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.asset(
          clubLogoAssetPath(teamId),
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.groups_outlined, size: 22, color: iconColor),
        ),
      ),
    ),
  );
}

/// Position / card type / nation / club filters (collection, duplicates, wishlist, trading).
class CardCatalogFilterBar extends StatelessWidget {
  const CardCatalogFilterBar({
    super.key,
    required this.positionOptions,
    required this.teams,

    /// Distinct `players.nationality` values from the API (Lebanon variants first).
    this.nationalityOptions = const [],
    required this.positionFilter,
    required this.cardTypeFilter,
    required this.nationalityFilter,
    required this.teamIdFilter,
    required this.onPosition,
    required this.onCardType,
    required this.onNationality,
    required this.onClub,
    this.cardGameStyle = false,
  });

  final List<String> positionOptions;
  final List<Team> teams;
  final List<String> nationalityOptions;
  final String? positionFilter;

  /// Lowercase `base` or `import` to match [play_cards.card_type].
  final String? cardTypeFilter;
  final String? nationalityFilter;
  final int? teamIdFilter;
  final void Function(String?) onPosition;
  final void Function(String?) onCardType;
  final void Function(String?) onNationality;
  final void Function(int?) onClub;

  /// When true, matches card hub / store dark styling ([CardGameUiTheme]).
  final bool cardGameStyle;

  @override
  Widget build(BuildContext context) {
    if (cardGameStyle) {
      final clubActive = teamIdFilter != null;
      final clubIconColor = clubActive
          ? CardGameUiTheme.gold
          : CardGameUiTheme.onDark.withAlpha(160);
      return Material(
        color: CardGameUiTheme.elevated,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                  icon: Icons.style_outlined,
                  topOverride: _cardTypeBarTop(cardTypeFilter),
                  label: _cardTypeBarLabel(cardTypeFilter),
                  active: cardTypeFilter != null,
                  onTap: () => _showCardTypeBoxPicker(
                    context,
                    current: cardTypeFilter,
                    onPick: onCardType,
                  ),
                ),
              ),
              Expanded(
                child: CardFilterBoxTrigger(
                  icon: Icons.flag_outlined,
                  topOverride: nationalityFilter != null
                      ? Text(
                          _nationalityFlagEmojiForValue(nationalityFilter!) ??
                              '🏳️',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, height: 1.05),
                        )
                      : null,
                  label: nationalityFilter ?? 'Nation',
                  active: nationalityFilter != null,
                  onTap: () => _showNationalityBoxPicker(
                    context,
                    nationalityOptions: nationalityOptions,
                    current: nationalityFilter,
                    onPick: onNationality,
                  ),
                ),
              ),
              Expanded(
                child: CardFilterBoxTrigger(
                  icon: Icons.groups_outlined,
                  topOverride: _clubBarTop(teams, teamIdFilter, clubIconColor),
                  label: 'Club',
                  active: clubActive,
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
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
              icon: Icons.style_outlined,
              label: 'Type',
              active: cardTypeFilter != null,
              itemBuilder: (ctx) => [
                const PopupMenuItem<String>(
                  value: '__clear__',
                  child: Text('All types'),
                ),
                PopupMenuItem<String>(
                  value: 'base',
                  child: Row(
                    children: [
                      Image.asset(
                        kCardTypeAssetBase,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Base'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'import',
                  child: Row(
                    children: [
                      Image.asset(
                        kCardTypeAssetImport,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Import'),
                    ],
                  ),
                ),
              ],
              onSelected: (v) {
                if (v == '__clear__') {
                  onCardType(null);
                } else {
                  onCardType(v);
                }
              },
            ),
            CardFilterPopupButton<String>(
              icon: Icons.flag_outlined,
              label: 'Nation',
              active: nationalityFilter != null,
              itemBuilder: (ctx) => [
                const PopupMenuItem<String>(
                  value: '__clear__',
                  child: Text('All'),
                ),
                ...nationalityOptions.map(
                  (n) => PopupMenuItem<String>(value: n, child: Text(n)),
                ),
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
                  (t) => PopupMenuItem<int>(
                    value: t.teamId,
                    child: Semantics(
                      label: t.teamName,
                      child: Row(
                        children: [
                          SizedBox(
                            height: 40,
                            width: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: _clubMenuLogo(t),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.teamName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
  final entries = <_FilterBoxEntry<String>>[
    for (final p in options) _FilterBoxEntry(value: p, label: p),
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

Future<void> _showCardTypeBoxPicker(
  BuildContext context, {
  required String? current,
  required void Function(String?) onPick,
}) {
  const entries = <_FilterBoxEntry<String>>[
    _FilterBoxEntry(
      value: 'base',
      label: 'Base',
      imageAsset: kCardTypeAssetBase,
    ),
    _FilterBoxEntry(
      value: 'import',
      label: 'Import',
      imageAsset: kCardTypeAssetImport,
    ),
  ];
  return _showFilterBoxDialog<String>(
    context: context,
    title: 'Card type',
    entries: entries,
    clearLabel: 'All types',
    onClear: () => onPick(null),
    isSelected: (v) => v == current,
    onSelect: (v) => onPick(v),
  );
}

Future<void> _showNationalityBoxPicker(
  BuildContext context, {
  required List<String> nationalityOptions,
  required String? current,
  required void Function(String?) onPick,
}) {
  final entries = nationalityOptions
      .map(
        (n) => _FilterBoxEntry<String>(
          value: n,
          label: n,
          flagEmoji: _nationalityFlagEmojiForValue(n),
        ),
      )
      .toList();
  return _showFilterBoxDialog<String>(
    context: context,
    title: 'Nation',
    entries: entries,
    emptyMessage: nationalityOptions.isEmpty
        ? 'No nationalities loaded yet. After deploying the API, open this screen again. Values also appear from your cards once the catalog loads.'
        : null,
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
  final entries = <_FilterBoxEntry<int>>[
    for (final t in teams)
      _FilterBoxEntry(
        value: t.teamId,
        label: t.teamName,
        imageAsset: clubLogoAssetPath(t.teamId),
        networkImageUrl: (t.logoUrl != null && t.logoUrl!.trim().isNotEmpty)
            ? t.logoUrl!.trim()
            : null,
        semanticsLabel: t.teamName,
      ),
  ];
  return _showFilterBoxDialog<int>(
    context: context,
    title: 'Club',
    entries: entries,
    emptyMessage: teams.isEmpty
        ? 'No clubs loaded yet. Check your network and that GET /cards/filter-options is deployed. Teams also fall back from GET /teams after a refresh.'
        : null,
    clearLabel: 'All clubs',
    onClear: () => onPick(null),
    isSelected: (v) => v == currentTeamId,
    onSelect: (v) => onPick(v),
  );
}

class _FilterBoxEntry<T> {
  const _FilterBoxEntry({
    required this.value,
    required this.label,
    this.flagEmoji,
    this.imageAsset,
    this.networkImageUrl,
    this.imageSize = 56,
    this.semanticsLabel,
  });

  final T value;
  final String label;
  final String? flagEmoji;
  final String? imageAsset;
  final String? networkImageUrl;
  final double imageSize;
  final String? semanticsLabel;
}

Future<void> _showFilterBoxDialog<T>({
  required BuildContext context,
  required String title,
  required List<_FilterBoxEntry<T>> entries,

  /// Shown instead of an empty grid when [entries] has no items.
  String? emptyMessage,
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
            border: Border.all(
              color: CardGameUiTheme.gold.withAlpha(100),
              width: 1.2,
            ),
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
                constraints: BoxConstraints(
                  maxHeight: (maxH - 150).clamp(160.0, 520.0),
                ),
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: Text(
                          emptyMessage ?? 'Nothing to show here yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CardGameUiTheme.onDark.withAlpha(170),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
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
                              imageAsset: e.imageAsset,
                              networkImageUrl: e.networkImageUrl,
                              imageSize: e.imageSize,
                              semanticsLabel: e.semanticsLabel,
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
                    side: BorderSide(
                      color: CardGameUiTheme.gold.withAlpha(120),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    clearLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
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
    this.imageAsset,
    this.networkImageUrl,
    this.imageSize = 56,
    this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? flagEmoji;
  final String? imageAsset;
  final String? networkImageUrl;
  final double imageSize;
  final String? semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nameStyle = TextStyle(
      color: selected
          ? CardGameUiTheme.onDark
          : CardGameUiTheme.onDark.withAlpha(210),
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      fontSize: 13.5,
      height: 1.2,
    );

    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(
        minWidth:
            (imageAsset != null || networkImageUrl != null) && label.isEmpty
            ? imageSize + 16
            : 96,
        maxWidth:
            (imageAsset != null || networkImageUrl != null) && label.isEmpty
            ? imageSize + 24
            : 160,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: (imageAsset != null || networkImageUrl != null)
            ? 10
            : (flagEmoji != null ? 14 : 12),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          width: selected ? 2 : 1.2,
          color: selected
              ? CardGameUiTheme.gold
              : CardGameUiTheme.panelBorder.withAlpha(200),
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
          if (networkImageUrl != null) ...[
            SizedBox(
              width: imageSize,
              height: imageSize,
              child: Image.network(
                networkImageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => imageAsset != null
                    ? Image.asset(
                        imageAsset!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_not_supported_outlined,
                          size: imageSize * 0.45,
                          color: CardGameUiTheme.onDark.withAlpha(120),
                        ),
                      )
                    : Icon(
                        Icons.image_not_supported_outlined,
                        size: imageSize * 0.45,
                        color: CardGameUiTheme.onDark.withAlpha(120),
                      ),
              ),
            ),
            if (label.isNotEmpty) const SizedBox(height: 8),
          ] else if (imageAsset != null) ...[
            SizedBox(
              width: imageSize,
              height: imageSize,
              child: Image.asset(
                imageAsset!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.image_not_supported_outlined,
                  size: imageSize * 0.45,
                  color: CardGameUiTheme.onDark.withAlpha(120),
                ),
              ),
            ),
            if (label.isNotEmpty) const SizedBox(height: 8),
          ] else if (flagEmoji != null) ...[
            Text(
              flagEmoji!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, height: 1.05),
            ),
            const SizedBox(height: 8),
          ],
          if (label.isNotEmpty)
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: nameStyle,
            ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: semanticsLabel ?? (label.isNotEmpty ? label : 'Club logo'),
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: inner,
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
    final iconColor = active
        ? CardGameUiTheme.gold
        : CardGameUiTheme.onDark.withAlpha(160);
    final labelColor = active
        ? CardGameUiTheme.gold
        : CardGameUiTheme.onDark.withAlpha(150);

    final top = topOverride != null
        ? SizedBox(height: 26, width: 40, child: Center(child: topOverride))
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
