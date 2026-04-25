import 'package:flutter/material.dart';

import '../models/team_season_stats.dart';
import '../services/games_api_service.dart';
import '../state/competition_filter.dart';

/// League-wide team totals from `team_boxscores` for the selected competition.
class TeamStatsScreen extends StatefulWidget {
  const TeamStatsScreen({super.key});

  @override
  State<TeamStatsScreen> createState() => _TeamStatsScreenState();
}

class _TeamStatsScreenState extends State<TeamStatsScreen> {
  final GamesApiService _api = GamesApiService();
  final AppCompetitionFilter _filter = AppCompetitionFilter.instance;

  List<TeamSeasonStats> _rows = const [];
  bool _loading = true;
  String? _error;
  int? _loadedForCompetitionId;
  int _loadSeq = 0;

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

  static String _fmtMin(double m) {
    if (m == m.roundToDouble()) return '${m.round()}';
    return m.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    return ColoredBox(
      color: cs.surface,
      child: RefreshIndicator(
        color: cs.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topInset + 4)),
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
              SliverToBoxAdapter(child: _buildTable(cs)),
            const SliverToBoxAdapter(child: SizedBox(height: 128)),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(ColorScheme cs) {
    final sel = _filter.selected;
    const headers = [
      'Team',
      'GP',
      'PTS',
      'REB',
      'AST',
      'FGM',
      'FGA',
      '3PM',
      '3PA',
      'FTM',
      'FTA',
      'MIN',
      'OREB',
      'DREB',
      'STL',
      'BLK',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
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
          const SizedBox(height: 4),
          Text(
            'Totals from team box scores (final & live games).',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: Table(
                          columnWidths: const {0: FixedColumnWidth(132)},
                          defaultColumnWidth: const IntrinsicColumnWidth(),
                          border: TableBorder(
                            horizontalInside: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.35),
                            ),
                            bottom: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                              ),
                              children: [
                                for (final h in headers) _HeadCell(h, cs),
                              ],
                            ),
                            for (final r in _rows)
                              TableRow(
                                children: [
                                  _DataCell(r.teamName, cs, left: true),
                                  _DataCell('${r.gp}', cs),
                                  _DataCell('${r.pts}', cs, emphasize: true),
                                  _DataCell('${r.reb}', cs),
                                  _DataCell('${r.ast}', cs),
                                  _DataCell('${r.fgm}', cs),
                                  _DataCell('${r.fga}', cs),
                                  _DataCell('${r.threePm}', cs),
                                  _DataCell('${r.threePa}', cs),
                                  _DataCell('${r.ftm}', cs),
                                  _DataCell('${r.fta}', cs),
                                  _DataCell(_fmtMin(r.min), cs),
                                  _DataCell('${r.oreb}', cs),
                                  _DataCell('${r.dreb}', cs),
                                  _DataCell('${r.stl}', cs),
                                  _DataCell('${r.blk}', cs),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell(this.text, this.cs);

  final String text;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.2,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell(
    this.text,
    this.cs, {
    this.left = false,
    this.emphasize = false,
  });

  final String text;
  final ColorScheme cs;
  final bool left;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Text(
        text,
        textAlign: left ? TextAlign.left : TextAlign.right,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          fontSize: left ? 12.5 : 12,
          color: emphasize ? cs.primary : cs.onSurface,
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
