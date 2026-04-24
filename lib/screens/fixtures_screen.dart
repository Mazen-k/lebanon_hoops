import 'package:flutter/material.dart';

import '../models/game_fixture_view.dart';
import '../services/games_api_service.dart';
import 'game_boxscore_screen.dart';
import '../widgets/league_fixture_card.dart';

/// League schedule from `games`, split by `games.week` with a premium week
/// navigator header.  Supports tap-arrows, swipe (PageView), and date-range
/// labels derived from the fixtures themselves.
class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key, this.competitionId = 42001});

  static const int defaultCompetitionId = 42001;

  final int competitionId;

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen>
    with SingleTickerProviderStateMixin {
  final _api = GamesApiService();
  PageController? _pageController;
  List<int> _weeks = const [];
  final Map<int, List<GameFixtureView>> _fixturesByWeek = {};
  final Set<int> _weekLoadInFlight = {};
  bool _loadingBootstrap = true;
  String? _errorBootstrap;
  bool _legacySingleList = false;
  List<GameFixtureView> _legacyFixtures = const [];
  int _pageIndex = 0;

  // Animation controller for the week label cross-fade.
  late final AnimationController _labelAnim;
  late final Animation<double> _labelFade;

  @override
  void initState() {
    super.initState();
    _labelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _labelFade = CurvedAnimation(parent: _labelAnim, curve: Curves.easeInOut);
    _bootstrap();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _labelAnim.dispose();
    super.dispose();
  }

  // ─── bootstrap ────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    setState(() {
      _loadingBootstrap = true;
      _errorBootstrap = null;
    });
    try {
      List<int> weeks = [];
      try {
        weeks = await _api.fetchGameWeeks(competitionId: widget.competitionId);
      } on GamesApiException {
        weeks = [];
      }
      if (!mounted) return;

      if (weeks.isEmpty) {
        final rows = await _api.fetchGames(competitionId: widget.competitionId);
        if (!mounted) return;
        final list = rows
            .map(GameFixtureView.fromGamesApiRow)
            .where((f) => f.matchId > 0)
            .toList();

        final derivedWeeks = list
            .map((f) => f.week)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();

        if (derivedWeeks.isNotEmpty) {
          final grouped = <int, List<GameFixtureView>>{};
          for (final f in list) {
            if (f.week != null) (grouped[f.week!] ??= []).add(f);
          }
          for (final g in grouped.values) {
            g.sort((a, b) => a.matchId.compareTo(b.matchId));
          }

          final initialPage = derivedWeeks.length - 1;
          _pageController?.dispose();
          _pageController = PageController(initialPage: initialPage);

          setState(() {
            _legacySingleList = false;
            _weeks = derivedWeeks;
            _pageIndex = initialPage;
            _fixturesByWeek
              ..clear()
              ..addAll(grouped);
            _weekLoadInFlight.clear();
            _loadingBootstrap = false;
          });
          return;
        }

        // True fallback: no week column at all.
        setState(() {
          _legacySingleList = true;
          _weeks = const [];
          _legacyFixtures = list;
          _loadingBootstrap = false;
        });
        return;
      }

      final initialPage = weeks.length - 1;
      _pageController?.dispose();
      _pageController = PageController(initialPage: initialPage);

      setState(() {
        _legacySingleList = false;
        _weeks = weeks;
        _pageIndex = initialPage;
        _fixturesByWeek.clear();
        _weekLoadInFlight.clear();
        _loadingBootstrap = false;
      });

      await _loadWeek(weeks[initialPage], force: true);
    } on GamesApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorBootstrap = e.message;
          _loadingBootstrap = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorBootstrap = '$e';
          _loadingBootstrap = false;
        });
      }
    }
  }

  // ─── week loading ─────────────────────────────────────────────────────────

  Future<void> _loadWeek(int week, {bool force = false}) async {
    if (!force && _fixturesByWeek.containsKey(week)) return;
    if (_weekLoadInFlight.contains(week)) return;
    setState(() => _weekLoadInFlight.add(week));
    try {
      final rows = await _api.fetchGames(
          competitionId: widget.competitionId, week: week);
      if (!mounted) return;
      final list = rows
          .map(GameFixtureView.fromGamesApiRow)
          .where((f) => f.matchId > 0)
          .toList()
        ..sort((a, b) => a.matchId.compareTo(b.matchId));
      setState(() {
        _fixturesByWeek[week] = list;
        _weekLoadInFlight.remove(week);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weekLoadInFlight.remove(week);
        _fixturesByWeek[week] = [];
      });
    }
  }

  Future<void> _refreshVisible() async {
    if (_legacySingleList) {
      setState(() => _loadingBootstrap = true);
      try {
        final rows =
            await _api.fetchGames(competitionId: widget.competitionId);
        if (!mounted) return;
        final list = rows
            .map(GameFixtureView.fromGamesApiRow)
            .where((f) => f.matchId > 0)
            .toList();
        setState(() {
          _legacyFixtures = list;
          _loadingBootstrap = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loadingBootstrap = false);
      }
      return;
    }
    if (_weeks.isEmpty) return;
    await _loadWeek(_weeks[_pageIndex], force: true);
  }

  // ─── navigation ───────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    _animateLabelChange(() => setState(() => _pageIndex = index));
    if (_weeks.isEmpty) return;
    final w = _weeks[index];
    _loadWeek(w);
    if (index + 1 < _weeks.length) _loadWeek(_weeks[index + 1]);
    if (index > 0) _loadWeek(_weeks[index - 1]);
  }

  void _goToPrev() {
    if (_pageIndex > 0) {
      _pageController?.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goToNext() {
    if (_pageIndex < _weeks.length - 1) {
      _pageController?.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Briefly fades the label out and back in when the week changes.
  void _animateLabelChange(VoidCallback change) {
    _labelAnim.reverse().then((_) {
      change();
      if (mounted) _labelAnim.forward();
    });
  }

  // ─── date-range helper ────────────────────────────────────────────────────

  /// Tries to extract a compact date range string from the fixtures of [week].
  /// Falls back to "Week N" if the dates can't be parsed.
  String _weekLabel(int week) {
    final fixtures = _fixturesByWeek[week];
    if (fixtures == null || fixtures.isEmpty) return 'WEEK $week';

    // metaLine often contains text like "Fri, Apr 25" or "2025-04-25 19:00".
    // Try to parse the earliest and latest dates.
    final dates = <DateTime>[];
    for (final f in fixtures) {
      final dt = _parseDateFromMetaLine(f.metaLine);
      if (dt != null) dates.add(dt);
    }

    if (dates.isEmpty) return 'WEEK $week';

    dates.sort();
    final first = dates.first;
    final last = dates.last;

    if (first.month == last.month) {
      // Same month → "Apr 22 – 28"
      return '${_monthAbbr(first.month)} ${first.day} – ${last.day}';
    } else {
      // Span months → "Apr 28 – May 3"
      return '${_monthAbbr(first.month)} ${first.day} – ${_monthAbbr(last.month)} ${last.day}';
    }
  }

  static DateTime? _parseDateFromMetaLine(String text) {
    // ISO format: 2025-04-25 ...
    final iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
    final m = iso.firstMatch(text);
    if (m != null) {
      return DateTime.tryParse('${m.group(1)}-${m.group(2)}-${m.group(3)}');
    }
    // Friendly format: "Fri, Apr 25" or "Apr 25"
    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final friendly = RegExp(
        r'(?:mon|tue|wed|thu|fri|sat|sun)?[,\s]*([a-z]{3})\s+(\d{1,2})',
        caseSensitive: false);
    final fm = friendly.firstMatch(text);
    if (fm != null) {
      final mo = months[fm.group(1)!.toLowerCase()];
      final day = int.tryParse(fm.group(2)!);
      if (mo != null && day != null) {
        final now = DateTime.now();
        return DateTime(now.year, mo, day);
      }
    }
    return null;
  }

  static String _monthAbbr(int month) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][month];

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loadingBootstrap) {
      return ColoredBox(
        color: cs.surface,
        child: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }
    if (_errorBootstrap != null) {
      return ColoredBox(
        color: cs.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorBootstrap!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _bootstrap, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    // Legacy single-list mode (no week column in the data).
    if (_legacySingleList) {
      return ColoredBox(
        color: cs.surface,
        child: RefreshIndicator(
          color: cs.primary,
          onRefresh: _refreshVisible,
          child: _buildFixtureList(cs, _legacyFixtures),
        ),
      );
    }

    final pc = _pageController;
    if (pc == null || _weeks.isEmpty) {
      return ColoredBox(
        color: cs.surface,
        child: Center(
          child: Text(
            'No week data for this competition.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return ColoredBox(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekNavigatorHeader(
            weekNumber: _weeks[_pageIndex],
            weekLabel: _weekLabel(_weeks[_pageIndex]),
            labelFade: _labelFade,
            canGoPrev: _pageIndex > 0,
            canGoNext: _pageIndex < _weeks.length - 1,
            totalWeeks: _weeks.length,
            currentIndex: _pageIndex,
            onPrev: _goToPrev,
            onNext: _goToNext,
            colorScheme: cs,
          ),
          Expanded(
            child: PageView.builder(
              controller: pc,
              itemCount: _weeks.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final week = _weeks[index];
                final fixtures = _fixturesByWeek[week];
                final inFlight =
                    _weekLoadInFlight.contains(week) && fixtures == null;

                if (inFlight || fixtures == null) {
                  return Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  );
                }

                return RefreshIndicator(
                  color: cs.primary,
                  onRefresh: () => _loadWeek(week, force: true),
                  child: _buildFixtureList(cs, fixtures),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixtureList(ColorScheme cs, List<GameFixtureView> fixtures) {
    if (fixtures.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Text(
            'No games this week.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: fixtures.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final f = fixtures[i];
        return LeagueFixtureCard(
          fixture: f,
          onCardTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => GameBoxscoreScreen(matchId: f.matchId),
            ),
          ),
        );
      },
    );
  }
}

// ─── Week Navigator Header ─────────────────────────────────────────────────

class _WeekNavigatorHeader extends StatelessWidget {
  const _WeekNavigatorHeader({
    required this.weekNumber,
    required this.weekLabel,
    required this.labelFade,
    required this.canGoPrev,
    required this.canGoNext,
    required this.totalWeeks,
    required this.currentIndex,
    required this.onPrev,
    required this.onNext,
    required this.colorScheme,
  });

  final int weekNumber;
  final String weekLabel;
  final Animation<double> labelFade;
  final bool canGoPrev;
  final bool canGoNext;
  final int totalWeeks;
  final int currentIndex;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final hasDates = !weekLabel.startsWith('WEEK ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _NavArrow(
                  icon: Icons.chevron_left_rounded,
                  enabled: canGoPrev,
                  onTap: onPrev,
                  colorScheme: cs,
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: labelFade,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "WEEK 3" always shown as the primary label.
                        Text(
                          'WEEK $weekNumber',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: cs.onSurface,
                          ),
                        ),
                        // Date range shown below when available.
                        if (hasDates) ...[
                          const SizedBox(height: 2),
                          Text(
                            weekLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _NavArrow(
                  icon: Icons.chevron_right_rounded,
                  enabled: canGoNext,
                  onTap: onNext,
                  colorScheme: cs,
                ),
              ],
            ),
            // Dot indicator row.
            if (totalWeeks > 1) ...[
              const SizedBox(height: 8),
              _DotIndicator(
                count: totalWeeks,
                current: currentIndex,
                colorScheme: cs,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Navigation Arrow ──────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.colorScheme,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: enabled
                ? cs.primary.withValues(alpha: 0.10)
                : cs.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: enabled
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

// ─── Dot Indicator ─────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.count,
    required this.current,
    required this.colorScheme,
  });

  final int count;
  final int current;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    // Show at most 7 dots; collapse with an ellipsis effect otherwise.
    const maxDots = 7;
    final showAll = count <= maxDots;
    final cs = colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(showAll ? count : maxDots, (i) {
        // Map visible dot index to actual week index when collapsed.
        final int actualIndex;
        if (showAll) {
          actualIndex = i;
        } else {
          // Sliding window: keep current roughly centred.
          final half = maxDots ~/ 2;
          final start = (current - half).clamp(0, count - maxDots);
          actualIndex = start + i;
        }

        final isActive = actualIndex == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
