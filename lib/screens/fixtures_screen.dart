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

        final derivedWeeks =
            list.map((f) => f.week).whereType<int>().toSet().toList()..sort();

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
        competitionId: widget.competitionId,
        week: week,
      );
      if (!mounted) return;
      final list =
          rows
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
        final rows = await _api.fetchGames(competitionId: widget.competitionId);
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

  /// Briefly fades the label out and back in when the week changes.
  void _animateLabelChange(VoidCallback change) {
    _labelAnim.reverse().then((_) {
      change();
      if (mounted) _labelAnim.forward();
    });
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    if (_loadingBootstrap) {
      return ColoredBox(
        color: cs.surface,
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Center(child: CircularProgressIndicator(color: cs.primary)),
        ),
      );
    }
    if (_errorBootstrap != null) {
      return ColoredBox(
        color: cs.surface,
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorBootstrap!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _bootstrap,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Legacy single-list mode (no week column in the data).
    if (_legacySingleList) {
      return ColoredBox(
        color: cs.surface,
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: RefreshIndicator(
            color: cs.primary,
            onRefresh: _refreshVisible,
            child: _buildFixtureList(cs, _legacyFixtures),
          ),
        ),
      );
    }

    final pc = _pageController;
    if (pc == null || _weeks.isEmpty) {
      return ColoredBox(
        color: cs.surface,
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Center(
            child: Text(
              'No week data for this competition.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topInset),
          _WeekNavigatorHeader(
            weeks: _weeks,
            focusedIndex: _pageIndex,
            labelFade: _labelFade,
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
    required this.weeks,
    required this.focusedIndex,
    required this.labelFade,
    required this.colorScheme,
  });

  final List<int> weeks;
  final int focusedIndex;
  final Animation<double> labelFade;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: FadeTransition(
        opacity: labelFade,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final visibleCount = width >= 430
                ? 7
                : width >= 340
                ? 5
                : 3;
            final half = visibleCount ~/ 2;
            final start = (focusedIndex - half).clamp(
              0,
              (weeks.length - visibleCount).clamp(0, weeks.length),
            );
            final end = (start + visibleCount).clamp(0, weeks.length);
            final visibleWeeks = weeks.sublist(start, end);

            return Row(
              children: [
                for (var i = 0; i < visibleWeeks.length; i++) ...[
                  Expanded(
                    child: _WeekLabelChip(
                      week: visibleWeeks[i],
                      isFocused: start + i == focusedIndex,
                      colorScheme: cs,
                    ),
                  ),
                  if (i != visibleWeeks.length - 1) const SizedBox(width: 4),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WeekLabelChip extends StatelessWidget {
  const _WeekLabelChip({
    required this.week,
    required this.isFocused,
    required this.colorScheme,
  });

  final int week;
  final bool isFocused;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: isFocused ? 6 : 4,
        vertical: isFocused ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: isFocused
            ? cs.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'WEEK',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: isFocused ? 9 : 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: isFocused
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$week',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: isFocused ? 24 : 16,
              fontWeight: isFocused ? FontWeight.w900 : FontWeight.w700,
              fontStyle: isFocused ? FontStyle.italic : FontStyle.normal,
              letterSpacing: isFocused ? -0.7 : -0.2,
              color: isFocused ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: isFocused ? 28 : 16,
            height: 3,
            decoration: BoxDecoration(
              color: isFocused
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
