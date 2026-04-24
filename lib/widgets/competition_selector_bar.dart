import 'package:flutter/material.dart';

import '../models/competition.dart';
import '../state/competition_filter.dart';

/// Top-of-home-page control: pick gender (Men's / Women's) then season.
/// Listens to [AppCompetitionFilter.instance] and stays in sync across the app.
class CompetitionSelectorBar extends StatefulWidget {
  const CompetitionSelectorBar({super.key});

  @override
  State<CompetitionSelectorBar> createState() => _CompetitionSelectorBarState();
}

class _CompetitionSelectorBarState extends State<CompetitionSelectorBar> {
  final AppCompetitionFilter _filter = AppCompetitionFilter.instance;

  @override
  void initState() {
    super.initState();
    _filter.addListener(_onFilterChanged);
    // Fire-and-forget: load competitions on first mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _filter.ensureLoaded();
    });
  }

  @override
  void dispose() {
    _filter.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _filter.selected;
    final gendersAvailable = _filter.availableGenders;
    final seasons = _filter.competitionsForGender(selected.gender);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(13)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GenderSegmented(
              selectedGender: selected.gender,
              available: gendersAvailable.isEmpty
                  ? const {'M'}
                  : gendersAvailable,
              onChanged: _filter.selectGender,
              colorScheme: cs,
            ),
            const SizedBox(height: 10),
            _SeasonPillRow(
              seasons: seasons,
              selectedId: selected.competitionId,
              onSelected: _filter.selectCompetition,
              loading: _filter.loading && seasons.length <= 1,
              colorScheme: cs,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderSegmented extends StatelessWidget {
  const _GenderSegmented({
    required this.selectedGender,
    required this.available,
    required this.onChanged,
    required this.colorScheme,
  });

  final String selectedGender;
  final Set<String> available;
  final ValueChanged<String> onChanged;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final buttons = <Widget>[];
    for (final g in const ['M', 'F']) {
      final isSelected = selectedGender == g;
      final enabled = available.contains(g);
      buttons.add(
        Expanded(
          child: _GenderButton(
            label: g == 'F' ? "WOMEN'S" : "MEN'S",
            icon: g == 'F' ? Icons.female_rounded : Icons.male_rounded,
            isSelected: isSelected,
            enabled: enabled,
            onTap: enabled && !isSelected ? () => onChanged(g) : null,
            colorScheme: cs,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [buttons[0], const SizedBox(width: 4), buttons[1]]),
    );
  }
}

class _GenderButton extends StatelessWidget {
  const _GenderButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    required this.colorScheme,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool enabled;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final baseColor = isSelected
        ? cs.onPrimary
        : (enabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? cs.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: baseColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: baseColor,
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

class _SeasonPillRow extends StatelessWidget {
  const _SeasonPillRow({
    required this.seasons,
    required this.selectedId,
    required this.onSelected,
    required this.loading,
    required this.colorScheme,
  });

  final List<Competition> seasons;
  final int selectedId;
  final ValueChanged<Competition> onSelected;
  final bool loading;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    if (loading && seasons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading seasons…',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    if (seasons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No seasons available',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }
    return Row(
      children: [
        Icon(Icons.event_note_rounded, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          'SEASON',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: seasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final c = seasons[i];
                final isSelected = c.competitionId == selectedId;
                return _SeasonPill(
                  label: c.seasonLabel,
                  isSelected: isSelected,
                  onTap: isSelected ? null : () => onSelected(c),
                  colorScheme: cs,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SeasonPill extends StatelessWidget {
  const _SeasonPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? cs.primary.withValues(alpha: 0.18)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? cs.primary
              : cs.outlineVariant.withValues(alpha: 0.3),
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
