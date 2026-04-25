import 'package:flutter/material.dart';

import '../models/team_season_stats.dart';
import '../services/games_api_service.dart';
import '../state/competition_filter.dart';

/// League-wide team totals: every final/live game counts toward GP; missing
/// box scores add 0 for that game. Stats columns scroll horizontally; team
/// column stays fixed.
class TeamStatsScreen extends StatefulWidget {
  const TeamStatsScreen({super.key});

  @override
  State<TeamStatsScreen> createState() => _TeamStatsScreenState();
}

class _TeamStatsScreenState extends State<TeamStatsScreen> {
  final GamesApiService _api = GamesApiService();
  final AppCompetitionFilter _filter = AppCompetitionFilter.instance;

  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  List<TeamSeasonStats> _rows = const [];
  bool _loading = true;
  String? _error;
  int? _loadedForCompetitionId;
  int _loadSeq = 0;

  /// `false` = season totals (T), `true` = per game (PG).
  bool _perGame = false;

  static const double _hdrH = 46;
  static const double _rowH = 52;
  static const double _pinnedW = 168;

  static final _statKeys = <(String label, int Function(TeamSeasonStats) pick)>[
    ('GP', (TeamSeasonStats r) => r.gp),
    ('PTS', (TeamSeasonStats r) => r.pts),
    ('REB', (TeamSeasonStats r) => r.reb),
    ('AST', (TeamSeasonStats r) => r.ast),
    ('FGM', (TeamSeasonStats r) => r.fgm),
    ('FGA', (TeamSeasonStats r) => r.fga),
    ('3PM', (TeamSeasonStats r) => r.threePm),
    ('3PA', (TeamSeasonStats r) => r.threePa),
    ('FTM', (TeamSeasonStats r) => r.ftm),
    ('FTA', (TeamSeasonStats r) => r.fta),
    ('OREB', (TeamSeasonStats r) => r.oreb),
    ('DREB', (TeamSeasonStats r) => r.dreb),
    ('STL', (TeamSeasonStats r) => r.stl),
    ('BLK', (TeamSeasonStats r) => r.blk),
  ];

  @override
  void initState() {
    super.initState();
    _filter.addListener(_onFilterChanged);
    _load();
  }

  @override
  void dispose() {
    _filter.removeListener(_onFilterChanged);
    _vScroll.dispose();
    _hScroll.dispose();
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
      final list = await _api.fetchTeamSeasonStats(competitionId: cid);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _rows = list;
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

  static String _cell(
    TeamSeasonStats r,
    int Function(TeamSeasonStats) pick,
    String label,
    bool perGame,
  ) {
    final raw = pick(r);
    if (label == 'GP') return '${r.gp}';
    if (!perGame) return '$raw';
    if (r.gp <= 0) return '0.0';
    return (raw / r.gp).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    return ColoredBox(
      color: cs.surface,
      child: Column(
        children: [
          SizedBox(height: topInset),
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              onRefresh: _load,
              child: CustomScrollView(
                controller: _vScroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  if (_loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorBlock(message: _error!, onRetry: _load),
                    )
                  else if (_rows.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No teams for this competition.',
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
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: _buildBody(cs),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    final sel = _filter.selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${sel.genderLabel} ${sel.competitionName} · ${sel.seasonLabel}',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'GP counts every final/live game. Missing box scores count as 0 for that game.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              height: 1.35,
              color: cs.onSurfaceVariant.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('T'),
                  tooltip: 'Season totals',
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('PG'),
                  tooltip: 'Per game (÷ GP)',
                ),
              ],
              selected: {_perGame},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                setState(() => _perGame = s.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _perGame
                ? 'Showing per-game averages (1 decimal). GP is still games played.'
                : 'Showing season totals.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: cs.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPinnedTeamStrip(cs),
                    Expanded(
                      child: Scrollbar(
                        controller: _hScroll,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _hScroll,
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStatsHeaderRow(cs),
                              for (final r in _rows) _buildStatsDataRow(r, cs),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedTeamStrip(ColorScheme cs) {
    return Container(
      width: _pinnedW,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _hdrH,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Team',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          for (final r in _rows)
            SizedBox(
              height: _rowH,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Row(
                  children: [
                    _TeamLogo(url: r.teamLogoUrl, scheme: cs),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.teamName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.15,
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
    );
  }

  Widget _buildStatsHeaderRow(ColorScheme cs) {
    return SizedBox(
      height: _hdrH,
      child: DecoratedBox(
        decoration: BoxDecoration(color: cs.surfaceContainerHighest),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final e in _statKeys) _buildStatHeadCell(e.$1, cs)],
        ),
      ),
    );
  }

  Widget _buildStatsDataRow(TeamSeasonStats r, ColorScheme cs) {
    return Container(
      height: _rowH,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in _statKeys)
            _buildStatValueCell(
              _cell(r, e.$2, e.$1, _perGame),
              cs,
              emphasize: e.$1 == 'PTS',
            ),
        ],
      ),
    );
  }

  Widget _buildStatHeadCell(String label, ColorScheme cs) {
    return SizedBox(
      width: 52,
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.15,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildStatValueCell(
    String text,
    ColorScheme cs, {
    bool emphasize = false,
  }) {
    return SizedBox(
      width: 52,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12,
            color: emphasize ? cs.primary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({this.url, required this.scheme});

  final String? url;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const size = 34.0;
    final border = Border.all(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    );
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Icon(
          Icons.shield_outlined,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: border,
          shape: BoxShape.circle,
        ),
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(
            Icons.shield_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

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
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.secondary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
