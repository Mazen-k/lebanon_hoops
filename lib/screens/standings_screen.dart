import 'package:flutter/material.dart';

import '../data/standings_calculator.dart';
import '../data/team_repository.dart';
import '../services/games_api_service.dart';
import '../state/competition_filter.dart';

/// League standings table, computed on the client from `/games`.
///
/// - One row per team, equally sized, sorted by FIBA points (`W*2 + L`).
/// - Top 8 rows get a green left accent (advance to Final 8).
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
  bool _loading = true;
  String? _error;
  int? _loadedForCompetitionId;
  int _loadSeq = 0;

  static const int _playoffCutoff = 8; // top N highlighted green
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
      var standings = computeStandings(gameRows);
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
            else if (_rows.isEmpty)
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
          const SizedBox(height: 16),
          _StandingsTable(
            rows: _rows,
            playoffCutoff: _playoffCutoff,
            relegationCount: _relegationCount,
            colorScheme: cs,
          ),
          const SizedBox(height: 16),
          _StandingsLegend(colorScheme: cs),
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

// ─── Table ─────────────────────────────────────────────────────────────────

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({
    required this.rows,
    required this.playoffCutoff,
    required this.relegationCount,
    required this.colorScheme,
  });

  final List<StandingRow> rows;
  final int playoffCutoff;
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
    if (index < playoffCutoff) return _RowAccent.playoff;
    if (index >= total - relegationCount) return _RowAccent.relegation;
    return _RowAccent.none;
  }
}

enum _RowAccent { none, playoff, relegation }

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
      _RowAccent.playoff => const Color(0xFF2BB673),
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
