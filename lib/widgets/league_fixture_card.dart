import 'package:flutter/material.dart';

import '../models/game_fixture_view.dart';

/// League-style match row (same look as team profile fixtures). When [onCardTap] is set, the whole card is tappable.
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
    final colorScheme = Theme.of(context).colorScheme;
    final isFuture = !fixture.isPast;
    final interactive = onCardTap != null;

    final content = Ink(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fixture.metaLine.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                if (isFuture)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fixture.centerLabel == 'LIVE' ? Colors.redAccent : colorScheme.primary,
                    ),
                  )
                else
                  Text(
                    'FT',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      _TeamVisual(name: fixture.homeName, logoUrl: fixture.homeLogoUrl, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fixture.homeName.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: isFuture
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: fixture.centerLabel == 'LIVE'
                                  ? Colors.redAccent
                                  : colorScheme.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              fixture.centerLabel ?? '—',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            '${fixture.homeScore ?? '—'} - ${fixture.awayScore ?? '—'}',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          fixture.awayName.toUpperCase(),
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _TeamVisual(name: fixture.awayName, logoUrl: fixture.awayLogoUrl, size: 40),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!interactive) {
      return Material(
        color: Colors.transparent,
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
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
