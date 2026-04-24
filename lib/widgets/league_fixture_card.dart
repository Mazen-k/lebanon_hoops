import 'package:flutter/material.dart';

import '../models/game_fixture_view.dart';

/// League-style match card. When [onCardTap] is set, the whole card is tappable.
class LeagueFixtureCard extends StatelessWidget {
  const LeagueFixtureCard({
    super.key,
    required this.fixture,
    this.onCardTap,
  });

  final GameFixtureView fixture;
  final VoidCallback? onCardTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLive = fixture.centerLabel == 'LIVE';
    final interactive = onCardTap != null;

    final cardBody = Ink(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fixture.metaLine.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusLabel(isPast: fixture.isPast, isLive: isLive, colorScheme: cs),
              ],
            ),
            const SizedBox(height: 14),
            if (fixture.isPast || isLive)
              _ScoredRows(fixture: fixture, colorScheme: cs)
            else
              _UpcomingRow(fixture: fixture, colorScheme: cs),
          ],
        ),
      ),
    );

    const _kShadow = BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      boxShadow: [
        BoxShadow(
          color: Color(0x18000000), // ~9 % black — subtle in light & dark
          blurRadius: 10,
          spreadRadius: 0,
          offset: Offset(0, 3),
        ),
      ],
    );

    if (!interactive) {
      return DecoratedBox(
        decoration: _kShadow,
        child: Material(color: Colors.transparent, child: cardBody),
      );
    }

    return DecoratedBox(
      decoration: _kShadow,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCardTap,
          borderRadius: BorderRadius.circular(12),
          child: cardBody,
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.isPast,
    required this.isLive,
    required this.colorScheme,
  });

  final bool isPast;
  final bool isLive;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (isLive) {
      return Text(
        'LIVE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: colorScheme.error,
        ),
      );
    }
    return Text(
      isPast ? 'FT' : 'UPCOMING',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Two stacked team rows each showing [logo | name | score], used for
/// completed and live games so each score aligns with its team name.
class _ScoredRows extends StatelessWidget {
  const _ScoredRows({required this.fixture, required this.colorScheme});

  final GameFixtureView fixture;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TeamScoreRow(
          name: fixture.homeName,
          logoUrl: fixture.homeLogoUrl,
          score: fixture.homeScore,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 10),
        _TeamScoreRow(
          name: fixture.awayName,
          logoUrl: fixture.awayLogoUrl,
          score: fixture.awayScore,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({
    required this.name,
    required this.logoUrl,
    required this.score,
    required this.colorScheme,
  });

  final String name;
  final String? logoUrl;
  final int? score;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TeamVisual(name: name, logoUrl: logoUrl, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: -0.3,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Text(
          score != null ? '$score' : '—',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -1.0,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Single horizontal row: [home logo | home name | VS | away name | away logo]
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.fixture, required this.colorScheme});

  final GameFixtureView fixture;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final nameStyle = TextStyle(
      fontFamily: 'Lexend',
      fontWeight: FontWeight.w900,
      fontSize: 13,
      letterSpacing: -0.3,
      color: colorScheme.onSurface,
    );

    return Row(
      children: [
        _TeamVisual(name: fixture.homeName, logoUrl: fixture.homeLogoUrl, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            fixture.homeName.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'VS',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: -0.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            fixture.awayName.toUpperCase(),
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
        const SizedBox(width: 10),
        _TeamVisual(name: fixture.awayName, logoUrl: fixture.awayLogoUrl, size: 36),
      ],
    );
  }
}

class _TeamVisual extends StatelessWidget {
  const _TeamVisual({required this.name, this.logoUrl, this.size = 40});

  final String name;
  final String? logoUrl;
  final double size;

  static String _initials(String teamName) {
    final parts = teamName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _tint(ColorScheme scheme) {
    var h = 0.0;
    for (final c in name.codeUnits) {
      h = (h + c) * 1.618 % 360;
    }
    return HSLColor.fromAHSL(1, h, 0.42, 0.48).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = logoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _initialsBadge(scheme),
          ),
        ),
      );
    }
    return _initialsBadge(scheme);
  }

  Widget _initialsBadge(ColorScheme scheme) {
    final tint = _tint(scheme);
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [tint, Color.lerp(tint, scheme.surface, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w900,
          fontSize: size * 0.28,
          color: Colors.white,
        ),
      ),
    );
  }
}
