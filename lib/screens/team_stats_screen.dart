import 'package:flutter/material.dart';

import '../layout/app_shell_bottom_inset.dart';
import '../models/player_leaders.dart';
import '../models/team_season_stats.dart';
import '../services/games_api_service.dart';
import '../state/competition_filter.dart';
import '../widgets/player_stat_leaders_panel.dart';

/// League team stats — visual style matches Lebanese Basketball reference:
/// light header bar, grid lines, zebra rows, TOTAL switch, sticky TEAM column.
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

  PlayerLeadersSummary? _playerSummary;
  bool _playerLoading = false;
  String? _playerError;
  int? _playerLoadedForCompetitionId;
  int _playerLoadSeq = 0;

  /// `false` = season totals, `true` = per game (÷ GP).
  bool _perGame = false;

  /// `true` = team stats table; `false` = player leaders from box scores.
  bool _showTeamStats = true;

  // —— Table chrome (rows use theme surface so it matches app background) ——
  static const Color _kAccentRed = Color(0xFFBB0013);
  static const Color _kHeaderBg = _kAccentRed;
  static const Color _kPlayerStatsBg = Color(0xFFEDEDED);
  static const Color _kBorder = Color(0xFFCFCFCF);
  static const Color _kText = Color(0xFF000000);
  static const Color _kSubtext = Color(0xFF666666);

  static const double _hdrH = 48;
  static const double _rowH = 56;
  static const double _pinnedW = 176;
  static const double _statColW = 54;

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
    final cid = _filter.selected.competitionId;
    final teamStale = _loadedForCompetitionId != cid;
    final playerStale = _playerLoadedForCompetitionId != cid;
    if (!teamStale && !playerStale) return;
    if (teamStale) _load();
    if (playerStale) {
      setState(() {
        _playerSummary = null;
        _playerLoadedForCompetitionId = null;
        _playerError = null;
      });
      if (!_showTeamStats) _loadPlayerLeaders();
    }
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

  Future<void> _loadPlayerLeaders() async {
    final seq = ++_playerLoadSeq;
    final cid = _filter.selected.competitionId;
    setState(() {
      _playerLoading = true;
      _playerError = null;
    });
    try {
      final s = await _api.fetchPlayerLeaders(competitionId: cid);
      if (!mounted || seq != _playerLoadSeq) return;
      setState(() {
        _playerSummary = s;
        _playerLoading = false;
        _playerLoadedForCompetitionId = cid;
      });
    } catch (e) {
      if (!mounted || seq != _playerLoadSeq) return;
      setState(() {
        _playerError = '$e';
        _playerLoading = false;
        _playerLoadedForCompetitionId = cid;
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

  Color _rowBg(ColorScheme scheme) => scheme.surface;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = appShellBottomBarOverlap(context);
    final pageBg = _showTeamStats ? cs.surface : _kPlayerStatsBg;

    final Widget scrollChild;
    if (!_showTeamStats) {
      scrollChild = PlayerStatLeadersPanel(
        scheme: cs,
        api: _api,
        competitionId: _filter.selected.competitionId,
        summary: _playerSummary,
        loading: _playerLoading,
        error: _playerError,
        onRetry: _loadPlayerLeaders,
        subtitle:
            '${_filter.selected.genderLabel} ${_filter.selected.competitionName} · ${_filter.selected.seasonLabel}',
      );
    } else if (_loading) {
      scrollChild = const SizedBox(
        height: 420,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      scrollChild = SizedBox(
        height: 420,
        child: _ErrorBlock(message: _error!, onRetry: _load),
      );
    } else if (_rows.isEmpty) {
      scrollChild = SizedBox(
        height: 320,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No teams for this competition.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      );
    } else {
      scrollChild = _buildBodyContent(cs);
    }

    return ColoredBox(
      color: pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _StatsModePicker(
              scheme: cs,
              teamStatsSelected: _showTeamStats,
              onTeamSelected: (team) {
                setState(() => _showTeamStats = team);
                if (!team &&
                    (_playerSummary == null ||
                        _playerLoadedForCompetitionId !=
                            _filter.selected.competitionId)) {
                  _loadPlayerLeaders();
                }
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              onRefresh: () async {
                if (_showTeamStats) {
                  await _load();
                } else {
                  await _loadPlayerLeaders();
                }
              },
              child: ListView(
                controller: _vScroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPad),
                children: [scrollChild],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(ColorScheme scheme) {
    final sel = _filter.selected;
    final tableH = _hdrH + _rows.length * _rowH;
    return ColoredBox(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${sel.genderLabel} ${sel.competitionName} · ${sel.seasonLabel}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kSubtext,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                Switch(
                  value: !_perGame,
                  onChanged: (totalsOn) => setState(() => _perGame = !totalsOn),
                  activeTrackColor: _kAccentRed,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFBDBDBD),
                  inactiveThumbColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                Text(
                  _perGame ? 'PER GAME' : 'TOTAL',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                    color: _kText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _perGame
                  ? 'Averages per game (1 decimal). GP = games played.'
                  : 'Season totals. GP counts every final/live game.',
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.25,
                color: _kSubtext,
              ),
            ),
            const SizedBox(height: 12),
            // Explicit height: Row + horizontal ScrollView inside ListView must
            // not rely on intrinsic cross-axis from the scroll view.
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _pinnedW,
                      height: tableH,
                      child: _buildPinnedTeamColumn(scheme),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: tableH,
                        child: Scrollbar(
                          controller: _hScroll,
                          thickness: 4,
                          radius: const Radius.circular(3),
                          child: SingleChildScrollView(
                            controller: _hScroll,
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatsHeaderRow(),
                                for (var i = 0; i < _rows.length; i++)
                                  _buildStatsDataRow(_rows[i], i, scheme),
                              ],
                            ),
                          ),
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

  /// Pinned TEAM: header + rows, zebra synced by index.
  Widget _buildPinnedTeamColumn(ColorScheme scheme) {
    return SizedBox(
      width: _pinnedW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pinnedHeaderCell(),
          for (var i = 0; i < _rows.length; i++)
            _pinnedTeamRow(_rows[i], i, scheme),
        ],
      ),
    );
  }

  Widget _pinnedHeaderCell() {
    return Container(
      height: _hdrH,
      decoration: const BoxDecoration(
        color: _kHeaderBg,
        border: Border(
          bottom: BorderSide(color: _kBorder, width: 1),
          right: BorderSide(color: _kBorder, width: 1),
        ),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: const Text(
        'TEAM',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.6,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _pinnedTeamRow(TeamSeasonStats r, int index, ColorScheme scheme) {
    return Container(
      height: _rowH,
      decoration: BoxDecoration(
        color: _rowBg(scheme),
        border: const Border(
          bottom: BorderSide(color: _kBorder, width: 1),
          right: BorderSide(color: _kBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _TeamLogo(url: r.teamLogoUrl),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              r.teamName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.12,
                color: _kText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeaderRow() {
    return SizedBox(
      height: _hdrH,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _kHeaderBg,
          border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final e in _statKeys) _buildStatHeadCell(e.$1)],
        ),
      ),
    );
  }

  Widget _buildStatHeadCell(String label) {
    return Container(
      width: _statColW,
      height: _hdrH,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _kBorder, width: 1)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 10.5,
          letterSpacing: 0.35,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatsDataRow(TeamSeasonStats r, int index, ColorScheme scheme) {
    return Container(
      height: _rowH,
      decoration: BoxDecoration(
        color: _rowBg(scheme),
        border: const Border(bottom: BorderSide(color: _kBorder, width: 1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in _statKeys)
            _buildStatValueCell(_cell(r, e.$2, e.$1, _perGame)),
        ],
      ),
    );
  }

  Widget _buildStatValueCell(String text) {
    return Container(
      width: _statColW,
      height: _rowH,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _kBorder, width: 1)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: _kText,
        ),
      ),
    );
  }
}

/// Two-way switch matching [GameBoxscoreScreen] team picker styling.
class _StatsModePicker extends StatelessWidget {
  const _StatsModePicker({
    required this.scheme,
    required this.teamStatsSelected,
    required this.onTeamSelected,
  });

  final ColorScheme scheme;
  final bool teamStatsSelected;
  final ValueChanged<bool> onTeamSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatsModeChip(
              scheme: scheme,
              label: 'Team stats',
              selected: teamStatsSelected,
              onTap: () => onTeamSelected(true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatsModeChip(
              scheme: scheme,
              label: 'Player stats',
              selected: !teamStatsSelected,
              onTap: () => onTeamSelected(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsModeChip extends StatelessWidget {
  const _StatsModeChip({
    required this.scheme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ColorScheme scheme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? _TeamStatsScreenState._kAccentRed
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({this.url});

  final String? url;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.shield_outlined,
          size: 20,
          color: _TeamStatsScreenState._kSubtext,
        ),
      );
    }
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _TeamStatsScreenState._kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          alignment: Alignment.center,
          child: const Icon(
            Icons.shield_outlined,
            size: 20,
            color: _TeamStatsScreenState._kSubtext,
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
