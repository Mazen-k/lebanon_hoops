import 'package:flutter/material.dart';

import '../models/game_fixture_view.dart';
import '../services/games_api_service.dart';
import 'game_boxscore_screen.dart';
import '../widgets/league_fixture_card.dart';

/// League schedule from `games`, optionally split by `games.week` (horizontal swipe).
class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key, this.competitionId = 42001});

  static const int defaultCompetitionId = 42001;

  final int competitionId;

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
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

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

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
        final list = rows.map(GameFixtureView.fromGamesApiRow).where((f) => f.matchId > 0).toList();
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

  Future<void> _loadWeek(int week, {bool force = false}) async {
    if (!force && _fixturesByWeek.containsKey(week)) return;
    if (_weekLoadInFlight.contains(week)) return;
    setState(() => _weekLoadInFlight.add(week));
    try {
      final rows = await _api.fetchGames(competitionId: widget.competitionId, week: week);
      if (!mounted) return;
      final list = rows.map(GameFixtureView.fromGamesApiRow).where((f) => f.matchId > 0).toList();
      setState(() {
        _fixturesByWeek[week] = list;
        _weekLoadInFlight.remove(week);
      });
    } catch (e) {
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
        final list = rows.map(GameFixtureView.fromGamesApiRow).where((f) => f.matchId > 0).toList();
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
    final w = _weeks[_pageIndex];
    await _loadWeek(w, force: true);
  }

  void _onPageChanged(int index) {
    setState(() => _pageIndex = index);
    if (_weeks.isEmpty) return;
    final w = _weeks[index];
    _loadWeek(w);
    if (index + 1 < _weeks.length) _loadWeek(_weeks[index + 1]);
    if (index > 0) _loadWeek(_weeks[index - 1]);
  }

  Widget _buildFixtureList(ColorScheme colorScheme, List<GameFixtureView> fixtures) {
    final upcoming = fixtures.where((f) => !f.isPast).toList();
    final past = fixtures.where((f) => f.isPast).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'Lebanese league fixtures — tap a game for team box score.',
          style: TextStyle(
            fontSize: 12.5,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        if (upcoming.isNotEmpty) ...[
          _SectionLabel('Upcoming', colorScheme),
          const SizedBox(height: 10),
          ...upcoming.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LeagueFixtureCard(
                fixture: f,
                onCardTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => GameBoxscoreScreen(matchId: f.matchId)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (past.isNotEmpty) ...[
          _SectionLabel('Results', colorScheme),
          const SizedBox(height: 10),
          ...past.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LeagueFixtureCard(
                fixture: f,
                onCardTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => GameBoxscoreScreen(matchId: f.matchId)),
                ),
              ),
            ),
          ),
        ],
        if (upcoming.isEmpty && past.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              'No games for this week.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final listBg = Color.lerp(
      colorScheme.surface,
      colorScheme.surfaceContainerHighest,
      0.55,
    )!;

    if (_loadingBootstrap) {
      return ColoredBox(
        color: listBg,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorBootstrap != null) {
      return ColoredBox(
        color: listBg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorBootstrap!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_legacySingleList) {
      return ColoredBox(
        color: listBg,
        child: RefreshIndicator(
          color: colorScheme.primary,
          onRefresh: _refreshVisible,
          child: _buildFixtureList(colorScheme, _legacyFixtures),
        ),
      );
    }

    final pc = _pageController;
    if (pc == null || _weeks.isEmpty) {
      return ColoredBox(
        color: listBg,
        child: Center(
          child: Text('No week data for this competition.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
      );
    }

    return ColoredBox(
      color: listBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
              border: Border(
                bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.12)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This is week ${_weeks[_pageIndex]}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          height: 1.05,
                          color: colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_pageIndex + 1} of ${_weeks.length} weeks · swipe sideways to change week',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: pc,
              itemCount: _weeks.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final week = _weeks[index];
                final fixtures = _fixturesByWeek[week];
                final inFlight = _weekLoadInFlight.contains(week) && fixtures == null;

                if (inFlight || fixtures == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: colorScheme.primary,
                  onRefresh: () => _loadWeek(week, force: true),
                  child: _buildFixtureList(colorScheme, fixtures),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, this.colorScheme);

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
