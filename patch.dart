import 'dart:io';

void main() {
  final file = File('lib/screens/team_profile_screen.dart');
  var content = file.readAsStringSync();
  
  // Regex to match _OverviewUpcomingMatchCard
  final upcomingRegex = RegExp(r"class _OverviewUpcomingMatchCard extends StatelessWidget \{.*?\n\}\n", dotAll: true);
  
  // Regex to match _LeagueFixtureCard
  final fixtureRegex = RegExp(r"class _LeagueFixtureCard extends StatelessWidget \{.*?\n\}\n", dotAll: true);
  
  content = content.replaceFirst(upcomingRegex, '''class _OverviewUpcomingMatchCard extends StatelessWidget {
  const _OverviewUpcomingMatchCard({required this.fixture, required this.onTap});

  final _DemoFixture fixture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fixture.leagueLabel.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: colorScheme.onInverseSurface.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      fixture.metaLine.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _TeamCrestBadge(teamName: fixture.homeName, size: 56),
                          const SizedBox(height: 12),
                          Text(
                            fixture.homeName.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: -0.5,
                              color: colorScheme.onInverseSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Text(
                            'VS',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              color: colorScheme.onInverseSurface.withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              fixture.centerLabel ?? '—',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _TeamCrestBadge(teamName: fixture.awayName, size: 56),
                          const SizedBox(height: 12),
                          Text(
                            fixture.awayName.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: -0.5,
                              color: colorScheme.onInverseSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: colorScheme.onInverseSurface.withOpacity(0.1), height: 1),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'GET TICKETS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: colorScheme.primary,
                    ),
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
''');

  content = content.replaceFirst(fixtureRegex, '''class _LeagueFixtureCard extends StatelessWidget {
  const _LeagueFixtureCard({
    required this.fixture,
    required this.onMenu,
    this.onCardTap,
  });

  final _DemoFixture fixture;
  final VoidCallback onMenu;
  final VoidCallback? onCardTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isFuture = !fixture.isPast;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isFuture ? onCardTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.onSurface.withOpacity(0.04),
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
                    Text(
                      fixture.metaLine.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                    if (isFuture)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
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
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
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
                          _TeamCrestBadge(teamName: fixture.homeName, size: 40),
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
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  fixture.centerLabel ?? '—',
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              )
                           : Text(
                                '\ - \',
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
                          _TeamCrestBadge(teamName: fixture.awayName, size: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
''');

  file.writeAsStringSync(content);
}
