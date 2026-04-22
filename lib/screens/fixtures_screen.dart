import 'package:flutter/material.dart';

import '../models/game_fixture_view.dart';
import '../services/games_api_service.dart';
import 'game_boxscore_screen.dart';
import '../widgets/league_fixture_card.dart';

/// Read-only league schedule from `games` (competition filter on API).
class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key, this.competitionId = 42001});

  static const int defaultCompetitionId = 42001;

  final int competitionId;

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  final _api = GamesApiService();
  List<GameFixtureView> _fixtures = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchGames(competitionId: widget.competitionId);
      if (!mounted) return;
      final list = rows.map(GameFixtureView.fromGamesApiRow).where((f) => f.matchId > 0).toList();
      setState(() {
        _fixtures = list;
        _loading = false;
      });
    } on GamesApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final listBg = Color.lerp(
      colorScheme.surface,
      colorScheme.surfaceContainerHighest,
      0.55,
    )!;

    if (_loading) {
      return ColoredBox(
        color: listBg,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: listBg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final upcoming = _fixtures.where((f) => !f.isPast).toList();
    final past = _fixtures.where((f) => f.isPast).toList();

    return ColoredBox(
      color: listBg,
      child: RefreshIndicator(
        color: colorScheme.primary,
        onRefresh: _load,
        child: ListView(
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
                  'No games loaded yet for this competition.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
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
