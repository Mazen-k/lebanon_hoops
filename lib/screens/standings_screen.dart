import 'package:flutter/material.dart';

import '../data/standings_calculator.dart';
import '../data/team_repository.dart';
import '../services/games_api_service.dart';
import '../state/competition_filter.dart';
import 'game_boxscore_screen.dart';

/// League standings table, computed on the client from `/games`.
///
/// - One row per team, equally sized, sorted by FIBA points (`W*2 + L`).
/// - Top rows get colored accents based on playoff qualification.
/// - Bottom 4 rows get a red left accent (relegation playoff).
/// - Legend at the bottom explains the colors.
class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final GamesApiService _api = GamesApiService();
  final TeamRepository _teamsRepo = const TeamRepository();
  final AppCompetitionFilter _filter = AppCompetitionFilter.instance;

  List<StandingRow> _rows = const [];
  List<_PlayoffSeries> _playoffSeries = const [];
  bool _loading = true;
  String? _error;
  int? _loadedForCompetitionId;
  int _loadSeq = 0;
  bool _showRegularSeason = true;

  static const int _final8AdvanceCount = 3;
  static const int _final4PlayoffStart = 4;
  static const int _final4PlayoffEnd = 5;
  static const int _relegationCount = 4; // bottom N highlighted red

  @override
  void initState() {
    super.initState();
    _filter.addListener(_onFilterChanged);
    _load();
  }

  @override
  void dispose() {
    _filter.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    if (!mounted) return;
    if (_loadedForCompetitionId == _filter.selected.competitionId) return;
    _load();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    final cid = _filter.selected.competitionId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gameRows = await _api.fetchGames(competitionId: cid);
      if (!mounted || seq != _loadSeq) return;
      final regularSeasonRows = gameRows.where(_isPositiveWeekGame);
      var standings = computeStandings(regularSeasonRows);
      final playoffSeries = _buildPlayoffSeries(gameRows);
      try {
        final teams = await _teamsRepo.fetchTeams(competitionId: cid);
        if (!mounted || seq != _loadSeq) return;
        final logoById = <String, String?>{
          for (final t in teams) '${t.teamId}': t.logoUrl,
        };
        standings = applyLogosFromTeamTable(standings, logoById);
      } catch (_) {
        // Keep logos from game rows if /teams fails.
      }
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _rows = standings;
        _playoffSeries = playoffSeries;
        _loading = false;
        _loadedForCompetitionId = cid;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _loadedForCompetitionId = cid;
      });
    }
  }

  bool _isPositiveWeekGame(Map<String, dynamic> game) {
    final week = _asInt(game['week']);
    return week != null && week > 0;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: cs.surface,
      child: RefreshIndicator(
        color: cs.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorView(message: _error!, onRetry: _load),
              )
            else if (_rows.isEmpty && _playoffSeries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No finished games yet for this competition.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(child: _buildContent(cs)),
            const SliverToBoxAdapter(child: SizedBox(height: 128)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final selected = _filter.selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StandingsHeader(
            subtitle:
                '${selected.genderLabel} ${selected.competitionName} · ${selected.seasonLabel}',
            colorScheme: cs,
          ),
          const SizedBox(height: 14),
          _StandingsSectionPicker(
            colorScheme: cs,
            regularSeasonSelected: _showRegularSeason,
            onRegularSeasonSelected: (regularSeason) {
              setState(() => _showRegularSeason = regularSeason);
            },
          ),
          const SizedBox(height: 16),
          if (_showRegularSeason) ...[
            if (_rows.isEmpty)
              _EmptyStandingsMessage(colorScheme: cs)
            else ...[
              _StandingsTable(
                rows: _rows,
                final8AdvanceCount: _final8AdvanceCount,
                final4PlayoffStart: _final4PlayoffStart,
                final4PlayoffEnd: _final4PlayoffEnd,
                relegationCount: _relegationCount,
                colorScheme: cs,
              ),
              const SizedBox(height: 16),
              _StandingsLegend(colorScheme: cs),
            ],
          ] else
            _PlayoffBracket(series: _playoffSeries, colorScheme: cs),
        ],
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────

class _StandingsHeader extends StatelessWidget {
  const _StandingsHeader({required this.subtitle, required this.colorScheme});

  final String subtitle;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LEAGUE TABLE',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.5,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StandingsSectionPicker extends StatelessWidget {
  const _StandingsSectionPicker({
    required this.colorScheme,
    required this.regularSeasonSelected,
    required this.onRegularSeasonSelected,
  });

  final ColorScheme colorScheme;
  final bool regularSeasonSelected;
  final ValueChanged<bool> onRegularSeasonSelected;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StandingsSectionChip(
              colorScheme: cs,
              label: 'Regular season',
              selected: regularSeasonSelected,
              onTap: () => onRegularSeasonSelected(true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StandingsSectionChip(
              colorScheme: cs,
              label: 'Playoff',
              selected: !regularSeasonSelected,
              onTap: () => onRegularSeasonSelected(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingsSectionChip extends StatelessWidget {
  const _StandingsSectionChip({
    required this.colorScheme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              fontSize: 13,
              color: selected ? Colors.white : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Table ─────────────────────────────────────────────────────────────────

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({
    required this.rows,
    required this.final8AdvanceCount,
    required this.final4PlayoffStart,
    required this.final4PlayoffEnd,
    required this.relegationCount,
    required this.colorScheme,
  });

  final List<StandingRow> rows;
  final int final8AdvanceCount;
  final int final4PlayoffStart;
  final int final4PlayoffEnd;
  final int relegationCount;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final total = rows.length;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _TableHeader(colorScheme: cs),
          for (int i = 0; i < total; i++)
            _TableRow(
              rank: i + 1,
              row: rows[i],
              colorScheme: cs,
              accent: _accentFor(i, total),
              isLast: i == total - 1,
            ),
        ],
      ),
    );
  }

  _RowAccent _accentFor(int index, int total) {
    if (index >= total - relegationCount) return _RowAccent.relegation;
    final rank = index + 1;
    if (rank <= final8AdvanceCount) return _RowAccent.final8;
    if (rank >= final4PlayoffStart && rank <= final4PlayoffEnd) {
      return _RowAccent.final4Playoff;
    }
    return _RowAccent.none;
  }
}

enum _RowAccent { none, final8, final4Playoff, relegation }

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final style = TextStyle(
      fontFamily: 'Lexend',
      fontSize: 10,
      fontWeight: FontWeight.w900,
      color: cs.onSurfaceVariant,
      letterSpacing: 1.2,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4), // accent bar column spacer
          SizedBox(
            width: 28,
            child: Text('#', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text('TEAM', style: style)),
          SizedBox(
            width: 30,
            child: Text('W', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(
            width: 30,
            child: Text('L', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(
            width: 48,
            child: Text('DIFF', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(
            width: 36,
            child: Text('PTS', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.rank,
    required this.row,
    required this.colorScheme,
    required this.accent,
    required this.isLast,
  });

  final int rank;
  final StandingRow row;
  final ColorScheme colorScheme;
  final _RowAccent accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final accentColor = switch (accent) {
      _RowAccent.final8 => const Color(0xFF2BB673),
      _RowAccent.final4Playoff => const Color(0xFF2F80ED),
      _RowAccent.relegation => const Color(0xFFE04B4B),
      _RowAccent.none => Colors.transparent,
    };
    final diffText = row.diff > 0 ? '+${row.diff}' : '${row.diff}';
    final diffColor = row.diff > 0
        ? const Color(0xFF2BB673)
        : row.diff < 0
        ? const Color(0xFFE04B4B)
        : cs.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$rank',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Row(
                        children: [
                          _TeamLogoBadge(
                            logoUrl: row.teamLogo,
                            colorScheme: cs,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              row.teamName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${row.wins}',
                        textAlign: TextAlign.center,
                        style: _numStyle(cs, bold: false),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${row.losses}',
                        textAlign: TextAlign.center,
                        style: _numStyle(cs, bold: false),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        diffText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: diffColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${row.leaguePoints}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _numStyle(ColorScheme cs, {required bool bold}) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
    color: cs.onSurface,
  );
}

class _TeamLogoBadge extends StatelessWidget {
  const _TeamLogoBadge({required this.logoUrl, required this.colorScheme});

  final String? logoUrl;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final fallback = Icon(Icons.shield, size: 20, color: cs.onSurfaceVariant);
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: (logoUrl == null || logoUrl!.isEmpty)
          ? fallback
          : Image.network(
              logoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

// ─── Legend ────────────────────────────────────────────────────────────────

class _StandingsLegend extends StatelessWidget {
  const _StandingsLegend({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _LegendRow(
            color: const Color(0xFF2BB673),
            label: 'Advances to Final 8',
            colorScheme: cs,
          ),
          const SizedBox(height: 6),
          _LegendRow(
            color: const Color(0xFF2F80ED),
            label: 'Final 4 playoff',
            colorScheme: cs,
          ),
          const SizedBox(height: 6),
          _LegendRow(
            color: const Color(0xFFE04B4B),
            label: 'Relegation playoff',
            colorScheme: cs,
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.colorScheme,
  });

  final Color color;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─── Playoff bracket ───────────────────────────────────────────────────────

class _PlayoffBracket extends StatelessWidget {
  const _PlayoffBracket({required this.series, required this.colorScheme});

  final List<_PlayoffSeries> series;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final final4Playoff = _seriesForWeek(-3);
    final final4 = _seriesForWeek(-4);
    final finals = _seriesForWeek(-6);
    final thirdPlace = _seriesForWeek(-5);
    final final4PlayoffWinners = {
      for (final s in final4Playoff)
        if (s.winnerTeamId != null) s.winnerTeamId!,
    };
    final final4FromPlayoff = final4PlayoffWinners.isEmpty
        ? <_PlayoffSeries>[]
        : final4.where((s) => s.containsAnyTeam(final4PlayoffWinners)).toList();
    final otherFinal4 = final4
        .where((s) => !final4FromPlayoff.contains(s))
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PLAYOFF BRACKET',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          _BracketStage(
            title: 'Final 4 Playoff',
            subtitle: 'Best of 3',
            series: final4Playoff,
            placeholders: const [_BracketPlaceholder('4th', '5th')],
            colorScheme: cs,
          ),
          const _BracketConnector(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BracketStage(
                  title: 'Final 4',
                  subtitle: 'Best of 5',
                  series: final4FromPlayoff,
                  placeholders: const [
                    _BracketPlaceholder('1st', 'Winner of Final 4 Playoff'),
                  ],
                  colorScheme: cs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BracketStage(
                  title: 'Final 4',
                  subtitle: 'Best of 5',
                  series: otherFinal4,
                  placeholders: const [_BracketPlaceholder('2nd', '3rd')],
                  colorScheme: cs,
                ),
              ),
            ],
          ),
          const _BracketConnector(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _BracketStage(
                  title: 'Finals',
                  subtitle: 'Best of 7',
                  series: finals,
                  placeholders: const [
                    _BracketPlaceholder('Final 4A winner', 'Final 4B winner'),
                  ],
                  colorScheme: cs,
                  highlight: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _BracketStage(
                  title: '3rd Place',
                  subtitle: '1 game',
                  series: thirdPlace,
                  placeholders: const [
                    _BracketPlaceholder('Final 4A loser', 'Final 4B loser'),
                  ],
                  colorScheme: cs,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_PlayoffSeries> _seriesForWeek(int week) =>
      series.where((s) => s.week == week).toList();
}

class _BracketStage extends StatelessWidget {
  const _BracketStage({
    required this.title,
    required this.subtitle,
    required this.series,
    required this.placeholders,
    required this.colorScheme,
    this.highlight = false,
  });

  final String title;
  final String subtitle;
  final List<_PlayoffSeries> series;
  final List<_BracketPlaceholder> placeholders;
  final ColorScheme colorScheme;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight
            ? cs.primary.withValues(alpha: 0.10)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? cs.primary.withValues(alpha: 0.30)
              : cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: highlight ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (series.isEmpty)
            for (var i = 0; i < placeholders.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _PlaceholderSeriesCard(
                placeholder: placeholders[i],
                colorScheme: cs,
              ),
            ]
          else
            for (var i = 0; i < series.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _SeriesCard(series: series[i], colorScheme: cs),
            ],
        ],
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series, required this.colorScheme});

  final _PlayoffSeries series;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openSeriesGamesDialog(context, series, cs),
        child: Ink(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              _SeriesTeamRow(
                team: series.home,
                wins: series.homeWins,
                isWinner: series.winnerTeamId == series.home.id,
                colorScheme: cs,
              ),
              const SizedBox(height: 6),
              _SeriesTeamRow(
                team: series.away,
                wins: series.awayWins,
                isWinner: series.winnerTeamId == series.away.id,
                colorScheme: cs,
              ),
              const SizedBox(height: 6),
              Text(
                '${series.games.length} game${series.games.length == 1 ? '' : 's'} scheduled · tap to view',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderSeriesCard extends StatelessWidget {
  const _PlaceholderSeriesCard({
    required this.placeholder,
    required this.colorScheme,
  });

  final _BracketPlaceholder placeholder;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _PlaceholderTeamRow(label: placeholder.homeLabel, colorScheme: cs),
          const SizedBox(height: 6),
          _PlaceholderTeamRow(label: placeholder.awayLabel, colorScheme: cs),
        ],
      ),
    );
  }
}

class _PlaceholderTeamRow extends StatelessWidget {
  const _PlaceholderTeamRow({required this.label, required this.colorScheme});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            Icons.help_outline_rounded,
            size: 14,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _BracketPlaceholder {
  const _BracketPlaceholder(this.homeLabel, this.awayLabel);

  final String homeLabel;
  final String awayLabel;
}

void _openSeriesGamesDialog(
  BuildContext context,
  _PlayoffSeries series,
  ColorScheme colorScheme,
) {
  final cs = colorScheme;
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: cs.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${series.home.name} vs ${series.away.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: series.games.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _SeriesGameTile(
                        game: series.games[index],
                        colorScheme: cs,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SeriesGameTile extends StatelessWidget {
  const _SeriesGameTile({required this.game, required this.colorScheme});

  final _PlayoffGame game;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final score = game.hasScore
        ? '${game.homeScore} - ${game.awayScore}'
        : 'vs';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: game.matchId <= 0
            ? null
            : () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => GameBoxscoreScreen(matchId: game.matchId),
                  ),
                );
              },
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                game.dateText.isEmpty ? 'Date TBC' : game.dateText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      game.homeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    constraints: const BoxConstraints(minWidth: 58),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: game.hasScore
                          ? cs.primary.withValues(alpha: 0.10)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      score,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: game.hasScore ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      game.awayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesTeamRow extends StatelessWidget {
  const _SeriesTeamRow({
    required this.team,
    required this.wins,
    required this.isWinner,
    required this.colorScheme,
  });

  final _PlayoffTeam team;
  final int wins;
  final bool isWinner;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Row(
      children: [
        _MiniTeamLogo(logoUrl: team.logoUrl, colorScheme: cs),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 11.5,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
              color: isWinner ? cs.primary : cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$wins',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isWinner ? cs.primary : cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _MiniTeamLogo extends StatelessWidget {
  const _MiniTeamLogo({required this.logoUrl, required this.colorScheme});

  final String? logoUrl;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final fallback = Icon(Icons.shield, size: 14, color: cs.onSurfaceVariant);
    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(7),
      ),
      child: (logoUrl == null || logoUrl!.isEmpty)
          ? fallback
          : Image.network(
              logoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _BracketConnector extends StatelessWidget {
  const _BracketConnector();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 3,
        height: 24,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _EmptyStandingsMessage extends StatelessWidget {
  const _EmptyStandingsMessage({
    required this.colorScheme,
    this.message = 'No regular-season games yet for this competition.',
  });

  final ColorScheme colorScheme;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Inter', color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _PlayoffTeam {
  const _PlayoffTeam({
    required this.id,
    required this.name,
    required this.logoUrl,
  });

  final String id;
  final String name;
  final String? logoUrl;
}

class _PlayoffSeries {
  const _PlayoffSeries({
    required this.week,
    required this.home,
    required this.away,
    required this.homeWins,
    required this.awayWins,
    required this.playedGames,
    required this.games,
  });

  final int week;
  final _PlayoffTeam home;
  final _PlayoffTeam away;
  final int homeWins;
  final int awayWins;
  final int playedGames;
  final List<_PlayoffGame> games;

  String? get winnerTeamId {
    if (homeWins == awayWins) return null;
    return homeWins > awayWins ? home.id : away.id;
  }

  bool containsAnyTeam(Set<String> teamIds) =>
      teamIds.contains(home.id) || teamIds.contains(away.id);
}

class _PlayoffGame {
  const _PlayoffGame({
    required this.matchId,
    required this.dateText,
    required this.homeName,
    required this.awayName,
    required this.homeScore,
    required this.awayScore,
  });

  final int matchId;
  final String dateText;
  final String homeName;
  final String awayName;
  final int? homeScore;
  final int? awayScore;

  bool get hasScore => homeScore != null && awayScore != null;
}

class _PlayoffSeriesAccumulator {
  _PlayoffSeriesAccumulator({
    required this.week,
    required this.home,
    required this.away,
  });

  final int week;
  final _PlayoffTeam home;
  final _PlayoffTeam away;
  int homeWins = 0;
  int awayWins = 0;
  int playedGames = 0;
  final List<_PlayoffGame> games = [];

  void addGame({
    required String gameHomeTeamId,
    required String gameAwayTeamId,
    required _PlayoffGame game,
    required int? homeScore,
    required int? awayScore,
  }) {
    games.add(game);
    if (homeScore == null || awayScore == null || homeScore == awayScore) {
      return;
    }
    playedGames++;
    final winnerId = homeScore > awayScore ? gameHomeTeamId : gameAwayTeamId;
    if (winnerId == home.id) {
      homeWins++;
    } else if (winnerId == away.id) {
      awayWins++;
    }
  }

  _PlayoffSeries toSeries() => _PlayoffSeries(
    week: week,
    home: home,
    away: away,
    homeWins: homeWins,
    awayWins: awayWins,
    playedGames: playedGames,
    games: [...games]..sort((a, b) => a.matchId.compareTo(b.matchId)),
  );
}

List<_PlayoffSeries> _buildPlayoffSeries(
  Iterable<Map<String, dynamic>> gameRows,
) {
  const playoffWeeks = {-3, -4, -5, -6};
  final bySeries = <String, _PlayoffSeriesAccumulator>{};
  for (final game in gameRows) {
    final week = _readInt(game['week']);
    if (week == null || !playoffWeeks.contains(week)) continue;

    final homeId = _readString(game['home_team_id'] ?? game['homeTeamId']);
    final awayId = _readString(game['away_team_id'] ?? game['awayTeamId']);
    if (homeId == null || awayId == null || homeId == awayId) continue;

    final orderedIds = [homeId, awayId]..sort();
    final key = '$week:${orderedIds.join('|')}';
    final existing = bySeries[key];
    final acc =
        existing ??
        _PlayoffSeriesAccumulator(
          week: week,
          home: _PlayoffTeam(
            id: homeId,
            name:
                _readString(game['home_team_name'] ?? game['homeTeamName']) ??
                'Team $homeId',
            logoUrl: _readString(
              game['home_team_logo'] ?? game['homeTeamLogo'],
            ),
          ),
          away: _PlayoffTeam(
            id: awayId,
            name:
                _readString(game['away_team_name'] ?? game['awayTeamName']) ??
                'Team $awayId',
            logoUrl: _readString(
              game['away_team_logo'] ?? game['awayTeamLogo'],
            ),
          ),
        );
    bySeries[key] = acc;

    final homeScore = _readInt(game['home_score'] ?? game['homeScore']);
    final awayScore = _readInt(game['away_score'] ?? game['awayScore']);
    acc.addGame(
      gameHomeTeamId: homeId,
      gameAwayTeamId: awayId,
      game: _PlayoffGame(
        matchId: _readInt(game['match_id'] ?? game['matchId']) ?? 0,
        dateText:
            _readString(game['date_time_text'] ?? game['dateTimeText']) ?? '',
        homeName:
            _readString(game['home_team_name'] ?? game['homeTeamName']) ??
            'Team $homeId',
        awayName:
            _readString(game['away_team_name'] ?? game['awayTeamName']) ??
            'Team $awayId',
        homeScore: homeScore,
        awayScore: awayScore,
      ),
      homeScore: homeScore,
      awayScore: awayScore,
    );
  }

  final out = bySeries.values.map((a) => a.toSeries()).toList();
  out.sort((a, b) {
    final byWeek = _playoffWeekOrder(
      a.week,
    ).compareTo(_playoffWeekOrder(b.week));
    if (byWeek != 0) return byWeek;
    return a.home.name.toLowerCase().compareTo(b.home.name.toLowerCase());
  });
  return out;
}

int _playoffWeekOrder(int week) => switch (week) {
  -3 => 0,
  -4 => 1,
  -6 => 2,
  -5 => 3,
  _ => 99,
};

String? _readString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

// ─── Error view ────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: cs.secondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
