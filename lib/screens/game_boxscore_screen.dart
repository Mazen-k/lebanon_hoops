import 'package:flutter/material.dart';

import '../services/games_api_service.dart';
import '../widgets/boxscore_expanded_stat_panel.dart';

// ---------------------------------------------------------------------------
// PBP list item types — period header or event row
// ---------------------------------------------------------------------------

sealed class _PbpListItem {}

class _PbpPeriodHeader extends _PbpListItem {
  _PbpPeriodHeader(this.label);
  final String label;
}

class _PbpEventRow extends _PbpListItem {
  _PbpEventRow(this.row);
  final Map<String, dynamic> row;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Team totals, player lines, and play-by-play (`game_events`) — swipe between tabs.
class GameBoxscoreScreen extends StatefulWidget {
  const GameBoxscoreScreen({super.key, required this.matchId});

  final int matchId;

  @override
  State<GameBoxscoreScreen> createState() => _GameBoxscoreScreenState();
}

class _GameBoxscoreScreenState extends State<GameBoxscoreScreen>
    with SingleTickerProviderStateMixin {
  final _api = GamesApiService();
  Map<String, dynamic>? _payload;
  List<Map<String, dynamic>> _periodScores = const [];
  String? _error;
  bool _loading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final boxscoreF = _api.fetchBoxscore(matchId: widget.matchId);
      final periodsF = _api
          .fetchPeriodScores(matchId: widget.matchId)
          .onError((_, __) => <Map<String, dynamic>>[]);
      final data = await boxscoreF;
      final periods = await periodsF;
      if (!mounted) return;
      setState(() {
        _payload = data;
        _periodScores = periods;
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

  static Map<String, String> _parseTotals(dynamic raw) => parseBoxscoreStatTotals(raw);

  static Map<String, dynamic>? _teamBySide(
    List<dynamic>? teams,
    String sideNorm,
  ) {
    if (teams == null) return null;
    for (final t in teams) {
      if (t is! Map) continue;
      final m = Map<String, dynamic>.from(t);
      final side = (m['side'] ?? '').toString().trim().toLowerCase();
      if (side == sideNorm) return m;
    }
    return null;
  }

  static List<Map<String, dynamic>> _normalizeEventRows(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(_coercePbpRow(e));
      } else if (e is Map) {
        out.add(_coercePbpRow(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  /// Maps API/DB rows to the snake_case keys the UI expects (handles camelCase too).
  static Map<String, dynamic> _coercePbpRow(Map<String, dynamic> m) {
    dynamic pickDyn(List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && m[k] != null) return m[k];
      }
      for (final e in m.entries) {
        final el = e.key.toString().toLowerCase();
        for (final k in keys) {
          if (el == k.toLowerCase()) return e.value;
        }
      }
      return null;
    }

    String pickStr(List<String> keys) {
      final v = pickDyn(keys);
      if (v == null) return '';
      return v.toString().trim();
    }

    return {
      'period': pickStr(['period', 'Period']),
      'clock': pickStr(['clock', 'Clock']),
      'score': pickStr(['score', 'Score']),
      'team_side': pickStr(['team_side', 'teamSide', 'TeamSide']),
      'team_name': pickStr(['team_name', 'teamName', 'TeamName']),
      'player': pickStr(['player', 'Player']),
      'player_number': pickStr([
        'player_number',
        'playerNumber',
        'PlayerNumber',
      ]),
      'action_text': pickStr(['action_text', 'actionText', 'ActionText']),
      'event_type': pickStr(['event_type', 'eventType', 'EventType']),
      'is_scoring_event': pickDyn([
        'is_scoring_event',
        'isScoringEvent',
        'IsScoringEvent',
      ]),
    };
  }

  List<Map<String, dynamic>> _playersForSide(
    List<dynamic>? players,
    String sideNorm,
  ) {
    if (players == null) return [];
    final out = <Map<String, dynamic>>[];
    for (final p in players) {
      if (p is! Map) continue;
      final m = Map<String, dynamic>.from(p);
      final side = (m['side'] ?? '').toString().trim().toLowerCase();
      if (side == sideNorm) out.add(m);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? scheme.surface : Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: scheme.onSurface),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
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
            )
          : _buildBody(context, scheme),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payload = _payload!;
    final game = payload['game'];
    final teamsRaw = payload['teams'];
    final teams = teamsRaw is List ? teamsRaw : const [];
    final playersRaw = payload['players'];
    final players = playersRaw is List ? playersRaw : const [];
    final eventsRaw = payload['events'];
    final events = _normalizeEventRows(eventsRaw);

    final gameMap = game is Map<String, dynamic>
        ? game
        : (game is Map ? Map<String, dynamic>.from(game) : null);

    final homeRow = _teamBySide(teams, 'home');
    final awayRow = _teamBySide(teams, 'away');
    final homeName = (homeRow?['team_name'] ?? '').toString().trim();
    final awayName = (awayRow?['team_name'] ?? '').toString().trim();
    final homeTotals = _parseTotals(homeRow?['totals']);
    final awayTotals = _parseTotals(awayRow?['totals']);

    final titleHome = homeName.isNotEmpty
        ? homeName
        : (gameMap?['home_team_name']?.toString() ?? 'Home');
    final titleAway = awayName.isNotEmpty
        ? awayName
        : (gameMap?['away_team_name']?.toString() ?? 'Away');
    final hs = gameMap?['home_score'];
    final as_ = gameMap?['away_score'];
    final status = (gameMap?['status'] ?? '').toString();
    final isLive = status.toLowerCase() == 'live';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Editorial game header — dark inverse-surface banner (Stitch Live Score Card style)
        _GameHeader(
          scheme: scheme,
          titleHome: titleHome,
          titleAway: titleAway,
          homeScore: hs?.toString(),
          awayScore: as_?.toString(),
          dateText: gameMap?['date_time_text']?.toString(),
          status: status,
          isLive: isLive,
          homeLogo: gameMap?['home_team_logo']?.toString(),
          awayLogo: gameMap?['away_team_logo']?.toString(),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? scheme.surface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withAlpha(60),
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant.withAlpha(160),
            indicatorColor: scheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(color: scheme.primary, width: 3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            labelStyle: const TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              letterSpacing: 0.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: 0.5,
            ),
            tabs: const [
              Tab(text: 'INFO'),
              Tab(text: 'BOX SCORE'),
              Tab(text: 'PLAY-BY-PLAY'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TeamTotalsTab(
                scheme: scheme,
                titleHome: titleHome,
                titleAway: titleAway,
                homeTotals: homeTotals,
                awayTotals: awayTotals,
                homePlayers: _playersForSide(players, 'home'),
                awayPlayers: _playersForSide(players, 'away'),
                periodScores: _periodScores,
              ),
              _PlayersTab(
                scheme: scheme,
                titleHome: titleHome,
                titleAway: titleAway,
                homeLogo: gameMap?['home_team_logo']?.toString(),
                awayLogo: gameMap?['away_team_logo']?.toString(),
                homePlayers: _playersForSide(players, 'home'),
                awayPlayers: _playersForSide(players, 'away'),
              ),
              _PlayByPlayTab(
                scheme: scheme,
                events: events,
                titleHome: titleHome,
                titleAway: titleAway,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Game Header — editorial dark banner (Stitch inverse-surface Live Score Card)
// ---------------------------------------------------------------------------

class _GameHeader extends StatelessWidget {
  const _GameHeader({
    required this.scheme,
    required this.titleHome,
    required this.titleAway,
    this.homeScore,
    this.awayScore,
    this.dateText,
    required this.status,
    required this.isLive,
    this.homeLogo,
    this.awayLogo,
  });

  final ColorScheme scheme;
  final String titleHome;
  final String titleAway;
  final String? homeScore;
  final String? awayScore;
  final String? dateText;
  final String status;
  final bool isLive;
  final String? homeLogo;
  final String? awayLogo;

  @override
  Widget build(BuildContext context) {
    final hasScore = homeScore != null && awayScore != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : Colors.white,
      ),
      child: Stack(
        children: [
          // Translucent Home Logo Background
          if (homeLogo != null && homeLogo!.isNotEmpty)
            Positioned(
              left: -30,
              bottom: -40,
              child: Opacity(
                opacity: isDark ? 0.08 : 0.05,
                child: Image.network(
                  homeLogo!,
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          // Translucent Away Logo Background
          if (awayLogo != null && awayLogo!.isNotEmpty)
            Positioned(
              right: -30,
              bottom: -40,
              child: Opacity(
                opacity: isDark ? 0.08 : 0.05,
                child: Image.network(
                  awayLogo!,
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          // (Removed gradient overlay for pure white look)
          const SizedBox.shrink(),
          // Main content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (dateText != null && dateText!.isNotEmpty)
                      Flexible(
                        child: Text(
                          dateText!,
                          style: TextStyle(
                            color: scheme.onSurface.withAlpha(153),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            letterSpacing: 0.3,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withAlpha(100),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: scheme.onPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontFamily: 'Lexend',
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (status.isNotEmpty)
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: scheme.onSurface.withAlpha(115),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontFamily: 'Lexend',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                // Teams and score
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _TeamColumn(
                        scheme: scheme,
                        name: titleHome,
                        logoUrl: homeLogo,
                        align: CrossAxisAlignment.start,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: hasScore
                          ? Text(
                              '$homeScore — $awayScore',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                fontFamily: 'Lexend',
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withAlpha(20),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              'vs',
                              style: TextStyle(
                                color: scheme.onSurface.withAlpha(102),
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Lexend',
                              ),
                            ),
                    ),
                    Expanded(
                      child: _TeamColumn(
                        scheme: scheme,
                        name: titleAway,
                        logoUrl: awayLogo,
                        align: CrossAxisAlignment.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.scheme,
    required this.name,
    this.logoUrl,
    required this.align,
  });

  final ColorScheme scheme;
  final String name;
  final String? logoUrl;
  final CrossAxisAlignment align;

  static Widget _initials(String name, ColorScheme scheme) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final label = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
        ? name.substring(0, name.length.clamp(0, 2)).toUpperCase()
        : '?';
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.7),
          fontWeight: FontWeight.w800,
          fontSize: 13,
          fontFamily: 'Lexend',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: hasLogo ? Colors.white : scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            boxShadow: hasLogo ? [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          padding: hasLogo ? const EdgeInsets.all(4) : EdgeInsets.zero,
          child: hasLogo
              ? Image.network(
                  logoUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => _initials(name, scheme),
                )
              : _initials(name, scheme),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: align == CrossAxisAlignment.start
              ? TextAlign.start
              : TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            fontFamily: 'Lexend',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Team Totals Tab
// ---------------------------------------------------------------------------

class _TeamTotalsTab extends StatelessWidget {
  const _TeamTotalsTab({
    required this.scheme,
    required this.titleHome,
    required this.titleAway,
    required this.homeTotals,
    required this.awayTotals,
    required this.homePlayers,
    required this.awayPlayers,
    required this.periodScores,
  });

  final ColorScheme scheme;
  final String titleHome;
  final String titleAway;
  final Map<String, String> homeTotals;
  final Map<String, String> awayTotals;
  final List<Map<String, dynamic>> homePlayers;
  final List<Map<String, dynamic>> awayPlayers;
  final List<Map<String, dynamic>> periodScores;

  static List<_PeriodScoreRow> _buildPeriodRows(
    List<Map<String, dynamic>> scores,
  ) {
    if (scores.isEmpty) {
      return const [
        _PeriodScoreRow(label: 'Q1', homeValue: '', awayValue: ''),
        _PeriodScoreRow(label: 'Q2', homeValue: '', awayValue: ''),
        _PeriodScoreRow(label: 'Q3', homeValue: '', awayValue: ''),
        _PeriodScoreRow(label: 'Q4', homeValue: '', awayValue: ''),
        _PeriodScoreRow(label: 'Total', homeValue: '', awayValue: '', isTotal: true),
      ];
    }
    String toLabel(String period) {
      final m = RegExp(r'^P(\d+)$').firstMatch(period);
      return m != null ? 'Q${m.group(1)}' : period;
    }

    final rows = scores
        .map(
          (p) => _PeriodScoreRow(
            label: toLabel(p['period'] as String),
            homeValue: '${p['home_score']}',
            awayValue: '${p['away_score']}',
          ),
        )
        .toList();

    final last = scores.last;
    rows.add(
      _PeriodScoreRow(
        label: 'Total',
        homeValue: '${last['home_running_total']}',
        awayValue: '${last['away_running_total']}',
        isTotal: true,
      ),
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final periodRows = _buildPeriodRows(periodScores);
    final topScorers = _buildTopScorers(
      homePlayers: homePlayers,
      awayPlayers: awayPlayers,
      homeTeamName: titleHome,
      awayTeamName: titleAway,
    );
    final statRows = _buildStatRows(homeTotals, awayTotals);

    if (topScorers.isEmpty && statRows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _InfoHeroCard(
            scheme: scheme,
            titleHome: titleHome,
            titleAway: titleAway,
          ),
          const SizedBox(height: 20),
          _SectionHeading('Score by quarter', scheme),
          const SizedBox(height: 10),
          _QuarterScoreTable(
            scheme: scheme,
            titleHome: titleHome,
            titleAway: titleAway,
            rows: periodRows,
          ),
          const SizedBox(height: 24),
          Text(
            'Game info will appear here as soon as the stats feed is synced.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _InfoHeroCard(
          scheme: scheme,
          titleHome: titleHome,
          titleAway: titleAway,
        ),
        const SizedBox(height: 20),
        _SectionHeading('Score by quarter', scheme),
        const SizedBox(height: 10),
        _QuarterScoreTable(
          scheme: scheme,
          titleHome: titleHome,
          titleAway: titleAway,
          rows: periodRows,
        ),
        const SizedBox(height: 24),
        if (topScorers.isNotEmpty) ...[
          _SectionHeading('Top leaders', scheme),
          const SizedBox(height: 10),
          _TopScorersStrip(scheme: scheme, scorers: topScorers),
          const SizedBox(height: 24),
        ],
        if (statRows.isNotEmpty) ...[
          _SectionHeading('Team stats', scheme),
          const SizedBox(height: 10),
          _TeamStatsComparisonCard(
            scheme: scheme,
            titleHome: titleHome,
            titleAway: titleAway,
            rows: statRows,
          ),
        ],
      ],
    );
  }

  static List<_TopScorerRow> _buildTopScorers({
    required List<Map<String, dynamic>> homePlayers,
    required List<Map<String, dynamic>> awayPlayers,
    required String homeTeamName,
    required String awayTeamName,
  }) {
    final rows = <_TopScorerRow?>[
      for (final player in homePlayers)
        _topScorerFromPlayer(player, teamName: homeTeamName, isHome: true),
      for (final player in awayPlayers)
        _topScorerFromPlayer(player, teamName: awayTeamName, isHome: false),
    ].whereType<_TopScorerRow>().toList();

    rows.sort((a, b) {
      final pointCompare = b.points.compareTo(a.points);
      if (pointCompare != 0) return pointCompare;
      final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (nameCompare != 0) return nameCompare;
      return a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase());
    });

    final nonZero = rows.where((row) => row.points > 0).toList();
    return (nonZero.isNotEmpty ? nonZero : rows).take(3).toList();
  }

  static _TopScorerRow? _topScorerFromPlayer(
    Map<String, dynamic> player, {
    required String teamName,
    required bool isHome,
  }) {
    final name = (player['player_name'] ?? player['playerName'] ?? '')
        .toString()
        .trim();
    if (name.isEmpty) return null;
    final stats = _GameBoxscoreScreenState._parseTotals(player['stats']);
    final points = _readInt(stats['Pts']) ?? 0;
    final number = (player['player_number'] ?? player['playerNumber'] ?? '')
        .toString()
        .trim();
    return _TopScorerRow(
      name: name,
      number: number,
      teamName: teamName,
      points: points,
      isHome: isHome,
    );
  }

  static List<_StatComparisonRow> _buildStatRows(
    Map<String, String> homeT,
    Map<String, String> awayT,
  ) {
    final rows = <_StatComparisonRow>[
      _StatComparisonRow(
        label: 'Points',
        homeValue: homeT['Pts'] ?? '—',
        awayValue: awayT['Pts'] ?? '—',
      ),
      _StatComparisonRow(
        label: 'Field goals',
        homeValue: _formatShootingLine(
          homeT,
          madeKey: 'FGM',
          attemptsKey: 'FGA',
          pctKey: 'FG%',
        ),
        awayValue: _formatShootingLine(
          awayT,
          madeKey: 'FGM',
          attemptsKey: 'FGA',
          pctKey: 'FG%',
        ),
      ),
      _StatComparisonRow(
        label: '2 points',
        homeValue: _formatShootingLine(
          homeT,
          madeKey: '2PM',
          attemptsKey: '2PA',
          pctKey: '2P%',
        ),
        awayValue: _formatShootingLine(
          awayT,
          madeKey: '2PM',
          attemptsKey: '2PA',
          pctKey: '2P%',
        ),
      ),
      _StatComparisonRow(
        label: '3 points',
        homeValue: _formatShootingLine(
          homeT,
          madeKey: '3PM',
          attemptsKey: '3PA',
          pctKey: '3P%',
        ),
        awayValue: _formatShootingLine(
          awayT,
          madeKey: '3PM',
          attemptsKey: '3PA',
          pctKey: '3P%',
        ),
      ),
      _StatComparisonRow(
        label: 'Free throws',
        homeValue: _formatShootingLine(
          homeT,
          madeKey: 'FTM',
          attemptsKey: 'FTA',
          pctKey: 'FT%',
        ),
        awayValue: _formatShootingLine(
          awayT,
          madeKey: 'FTM',
          attemptsKey: 'FTA',
          pctKey: 'FT%',
        ),
      ),
      _StatComparisonRow(
        label: 'Rebounds',
        homeValue: homeT['REB'] ?? '—',
        awayValue: awayT['REB'] ?? '—',
      ),
      _StatComparisonRow(
        label: 'Offensive',
        homeValue: homeT['OFF'] ?? '—',
        awayValue: awayT['OFF'] ?? '—',
      ),
      _StatComparisonRow(
        label: 'Defensive',
        homeValue: homeT['DEF'] ?? '—',
        awayValue: awayT['DEF'] ?? '—',
      ),
      _StatComparisonRow(
        label: 'Assists',
        homeValue: homeT['AST'] ?? '—',
        awayValue: awayT['AST'] ?? '—',
      ),
      _StatComparisonRow(
        label: 'Steals',
        homeValue: homeT['STL'] ?? '—',
        awayValue: awayT['STL'] ?? '—',
      ),
      _StatComparisonRow(
        label: 'Blocks',
        homeValue: homeT['BLK'] ?? '—',
        awayValue: awayT['BLK'] ?? '—',
      ),
      _StatComparisonRow(
        label: 'Turnovers',
        homeValue: homeT['TO'] ?? '—',
        awayValue: awayT['TO'] ?? '—',
      ),
      _StatComparisonRow(
        label: 'Fouls',
        homeValue: homeT['PF'] ?? '—',
        awayValue: awayT['PF'] ?? '—',
      ),
    ];
    return rows
        .where((row) => row.homeValue != '—' || row.awayValue != '—')
        .toList();
  }

  static String _formatShootingLine(
    Map<String, String> totals, {
    required String madeKey,
    required String attemptsKey,
    required String pctKey,
  }) {
    final made = totals[madeKey];
    final attempts = totals[attemptsKey];
    final pct = totals[pctKey];

    final hasMakes = made != null && made.isNotEmpty;
    final hasAttempts = attempts != null && attempts.isNotEmpty;
    final hasPct = pct != null && pct.isNotEmpty;

    if (!hasMakes && !hasAttempts && !hasPct) return '—';

    final buffer = StringBuffer();
    if (hasMakes || hasAttempts) {
      buffer.write('${made ?? '0'}/${attempts ?? '0'}');
    }
    if (hasPct) {
      if (buffer.isNotEmpty) buffer.write('  ');
      buffer.write('(${_percentLabel(pct)})');
    }
    return buffer.toString();
  }

  static String _percentLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == '—') return '—';
    return value.endsWith('%') ? value : '$value%';
  }

  static int? _readInt(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned) ??
        int.tryParse(cleaned.split('.').first) ??
        int.tryParse(cleaned.replaceAll(RegExp(r'[^0-9-]'), ''));
  }
}

class _InfoHeroCard extends StatelessWidget {
  const _InfoHeroCard({
    required this.scheme,
    required this.titleHome,
    required this.titleAway,
  });

  final ColorScheme scheme;
  final String titleHome;
  final String titleAway;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.surfaceContainerHighest, scheme.surfaceContainerLow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'GAME INFO',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$titleHome vs $titleAway',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuarterScoreTable extends StatelessWidget {
  const _QuarterScoreTable({
    required this.scheme,
    required this.titleHome,
    required this.titleAway,
    required this.rows,
  });

  final ColorScheme scheme;
  final String titleHome;
  final String titleAway;
  final List<_PeriodScoreRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.surfaceContainerLow,
            scheme.surfaceContainer.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.8)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
              children: [
                _quarterHeaderCell(titleHome, scheme, align: TextAlign.left),
                for (final row in rows)
                  _quarterHeaderCell(
                    row.label,
                    scheme,
                    align: TextAlign.center,
                  ),
              ],
            ),
            _quarterScoreRow(
              scheme: scheme,
              teamName: titleHome,
              values: [for (final row in rows) row.homeValue],
              emphasizeTotal: rows.map((row) => row.isTotal).toList(),
              striped: false,
            ),
            _quarterScoreRow(
              scheme: scheme,
              teamName: titleAway,
              values: [for (final row in rows) row.awayValue],
              emphasizeTotal: rows.map((row) => row.isTotal).toList(),
              striped: true,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _quarterHeaderCell(
    String text,
    ColorScheme scheme, {
    required TextAlign align,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static TableRow _quarterScoreRow({
    required ColorScheme scheme,
    required String teamName,
    required List<String> values,
    required List<bool> emphasizeTotal,
    required bool striped,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        color: striped ? scheme.surfaceContainer.withValues(alpha: 0.45) : null,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            teamName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: scheme.onSurface,
            ),
          ),
        ),
        for (var index = 0; index < values.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              values[index].isEmpty ? '—' : values[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontWeight: emphasizeTotal[index]
                    ? FontWeight.w900
                    : FontWeight.w700,
                fontSize: emphasizeTotal[index] ? 14 : 13,
                color: scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

class _TopScorersStrip extends StatelessWidget {
  const _TopScorersStrip({required this.scheme, required this.scorers});

  final ColorScheme scheme;
  final List<_TopScorerRow> scorers;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < scorers.length; index++) ...[
          Expanded(
            child: _TopScorerCard(scheme: scheme, scorer: scorers[index]),
          ),
          if (index != scorers.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _TopScorerCard extends StatelessWidget {
  const _TopScorerCard({required this.scheme, required this.scorer});

  final ColorScheme scheme;
  final _TopScorerRow scorer;

  @override
  Widget build(BuildContext context) {
    final accent = scorer.isHome ? scheme.primary : scheme.secondary;
    final avatarLabel = scorer.number.isNotEmpty
        ? '#${scorer.number}'
        : _initials(scorer.name);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              avatarLabel,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w800,
                fontSize: scorer.number.isNotEmpty ? 13 : 15,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            scorer.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1.2,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scorer.teamName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.25,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${scorer.points}',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.8,
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'PTS',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.9,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final token = parts.first.replaceAll('.', '');
      return token.substring(0, token.length.clamp(0, 2)).toUpperCase();
    }
    final first = parts.first.replaceAll('.', '');
    final last = parts.last.replaceAll('.', '');
    final firstChar = first.isNotEmpty ? first[0] : '';
    final lastChar = last.isNotEmpty ? last[0] : '';
    final label = '$firstChar$lastChar'.trim();
    return label.isEmpty ? '?' : label.toUpperCase();
  }
}

class _TeamStatsComparisonCard extends StatelessWidget {
  const _TeamStatsComparisonCard({
    required this.scheme,
    required this.titleHome,
    required this.titleAway,
    required this.rows,
  });

  final ColorScheme scheme;
  final String titleHome;
  final String titleAway;
  final List<_StatComparisonRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titleHome.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'TEAM STATS',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.9,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    titleAway.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < rows.length; index++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: index.isOdd
                  ? scheme.surfaceContainer.withValues(alpha: 0.4)
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[index].homeValue,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 124,
                    child: Text(
                      rows[index].label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[index].awayValue,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodScoreRow {
  const _PeriodScoreRow({
    required this.label,
    required this.homeValue,
    required this.awayValue,
    this.isTotal = false,
  });

  final String label;
  final String homeValue;
  final String awayValue;
  final bool isTotal;
}

class _TopScorerRow {
  const _TopScorerRow({
    required this.name,
    required this.number,
    required this.teamName,
    required this.points,
    required this.isHome,
  });

  final String name;
  final String number;
  final String teamName;
  final int points;
  final bool isHome;
}

class _StatComparisonRow {
  const _StatComparisonRow({
    required this.label,
    required this.homeValue,
    required this.awayValue,
  });

  final String label;
  final String homeValue;
  final String awayValue;
}

// ---------------------------------------------------------------------------
// Players Tab
// ---------------------------------------------------------------------------

class _PlayersTab extends StatefulWidget {
  const _PlayersTab({
    required this.scheme,
    required this.titleHome,
    required this.titleAway,
    this.homeLogo,
    this.awayLogo,
    required this.homePlayers,
    required this.awayPlayers,
  });

  final ColorScheme scheme;
  final String titleHome;
  final String titleAway;
  final String? homeLogo;
  final String? awayLogo;
  final List<Map<String, dynamic>> homePlayers;
  final List<Map<String, dynamic>> awayPlayers;

  @override
  State<_PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<_PlayersTab> {
  bool _showHome = true;

  static int _minsToSeconds(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == '—') return -1;
    final parts = value.split(':');
    if (parts.length == 2) {
      final mins = int.tryParse(parts[0]) ?? 0;
      final secs = int.tryParse(parts[1]) ?? 0;
      return mins * 60 + secs;
    }
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final mins = int.tryParse(parts[1]) ?? 0;
      final secs = int.tryParse(parts[2]) ?? 0;
      return hours * 3600 + mins * 60 + secs;
    }
    return int.tryParse(value) ?? -1;
  }

  static List<Map<String, dynamic>> _sortedPlayers(
    List<Map<String, dynamic>> players,
  ) {
    final list = List<Map<String, dynamic>>.from(players);
    list.sort((a, b) {
      final aStats = _GameBoxscoreScreenState._parseTotals(a['stats']);
      final bStats = _GameBoxscoreScreenState._parseTotals(b['stats']);
      final minsCompare = _minsToSeconds(
        bStats['Mins'] ?? bStats['MIN'] ?? '—',
      ).compareTo(_minsToSeconds(aStats['Mins'] ?? aStats['MIN'] ?? '—'));
      if (minsCompare != 0) return minsCompare;
      final bPts = int.tryParse((bStats['Pts'] ?? '0').split('.').first) ?? 0;
      final aPts = int.tryParse((aStats['Pts'] ?? '0').split('.').first) ?? 0;
      if (bPts != aPts) return bPts.compareTo(aPts);
      final aName = (a['player_name'] ?? '').toString().toLowerCase();
      final bName = (b['player_name'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.homePlayers.isEmpty && widget.awayPlayers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Box score data is not available yet. It appears after the match is synced.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    final visiblePlayers = _showHome
        ? _sortedPlayers(widget.homePlayers)
        : _sortedPlayers(widget.awayPlayers);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SectionHeading('BOX SCORE', widget.scheme),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _BoxScoreTeamPicker(
            scheme: widget.scheme,
            homeTitle: widget.titleHome,
            awayTitle: widget.titleAway,
            homeLogo: widget.homeLogo,
            awayLogo: widget.awayLogo,
            showHome: _showHome,
            onSelected: (showHome) => setState(() => _showHome = showHome),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: _BoxScoreTeamSection(
            scheme: widget.scheme,
            title: _showHome ? widget.titleHome : widget.titleAway,
            players: visiblePlayers,
            isHome: _showHome,
          ),
        ),
      ],
    );
  }
}

class _BoxScoreTeamSection extends StatelessWidget {
  const _BoxScoreTeamSection({
    required this.scheme,
    required this.title,
    required this.players,
    required this.isHome,
  });

  final ColorScheme scheme;
  final String title;
  final List<Map<String, dynamic>> players;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Text(
            'No player lines for this side.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (isHome ? scheme.primary : scheme.secondary).withValues(
                      alpha: 0.12,
                    ),
                    scheme.surfaceContainerHighest,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isHome ? scheme.primary : scheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _BoxScoreHeaderRow(),
                ],
              ),
            ),
            for (var index = 0; index < players.length; index++) ...[
              if (index != 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              _BoxScorePlayerTile(scheme: scheme, player: players[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _BoxScoreTeamPicker extends StatelessWidget {
  const _BoxScoreTeamPicker({
    required this.scheme,
    required this.homeTitle,
    required this.awayTitle,
    required this.homeLogo,
    required this.awayLogo,
    required this.showHome,
    required this.onSelected,
  });

  final ColorScheme scheme;
  final String homeTitle;
  final String awayTitle;
  final String? homeLogo;
  final String? awayLogo;
  final bool showHome;
  final ValueChanged<bool> onSelected;

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
            child: _TeamPickerChip(
              scheme: scheme,
              label: homeTitle,
              logoUrl: homeLogo,
              selected: showHome,
              onTap: () => onSelected(true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TeamPickerChip(
              scheme: scheme,
              label: awayTitle,
              logoUrl: awayLogo,
              selected: !showHome,
              onTap: () => onSelected(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamPickerChip extends StatelessWidget {
  const _TeamPickerChip({
    required this.scheme,
    required this.label,
    required this.logoUrl,
    required this.selected,
    required this.onTap,
  });

  final ColorScheme scheme;
  final String label;
  final String? logoUrl;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary.withAlpha(80) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _TeamPickerLogo(scheme: scheme, label: label, logoUrl: logoUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 13,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamPickerLogo extends StatelessWidget {
  const _TeamPickerLogo({
    required this.scheme,
    required this.label,
    required this.logoUrl,
  });

  final ColorScheme scheme;
  final String label;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(2),
      child: hasLogo
          ? Image.network(
              logoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  _TeamPickerLogoFallback(label: label, scheme: scheme),
            )
          : _TeamPickerLogoFallback(label: label, scheme: scheme),
    );
  }
}

class _TeamPickerLogoFallback extends StatelessWidget {
  const _TeamPickerLogoFallback({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'
        : label.isNotEmpty
        ? label.substring(0, label.length.clamp(0, 2))
        : '?';
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w800,
          fontSize: 9,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _BoxScoreHeaderRow extends StatelessWidget {
  const _BoxScoreHeaderRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerStyle = TextStyle(
      fontFamily: 'Lexend',
      fontWeight: FontWeight.w800,
      fontSize: 10,
      letterSpacing: 0.7,
      color: scheme.onSurfaceVariant,
    );

    return Row(
      children: [
        Expanded(flex: 7, child: Text('PLAYER', style: headerStyle)),
        _CompactHeaderCell(label: 'MIN', style: headerStyle),
        _CompactHeaderCell(label: 'PTS', style: headerStyle),
        _CompactHeaderCell(label: 'REB', style: headerStyle),
        _CompactHeaderCell(label: 'AST', style: headerStyle),
        const SizedBox(width: 28),
      ],
    );
  }
}

class _CompactHeaderCell extends StatelessWidget {
  const _CompactHeaderCell({required this.label, required this.style});

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(label, textAlign: TextAlign.center, style: style),
    );
  }
}

class _BoxScorePlayerTile extends StatefulWidget {
  const _BoxScorePlayerTile({required this.scheme, required this.player});

  final ColorScheme scheme;
  final Map<String, dynamic> player;

  @override
  State<_BoxScorePlayerTile> createState() => _BoxScorePlayerTileState();
}

class _BoxScorePlayerTileState extends State<_BoxScorePlayerTile> {
  bool _expanded = false;

  static Map<String, String> _stats(Map<String, dynamic> player) {
    return _GameBoxscoreScreenState._parseTotals(player['stats']);
  }

  static String _playerName(Map<String, dynamic> player) {
    return (player['player_name'] ?? player['playerName'] ?? '')
        .toString()
        .trim();
  }

  static String _playerNumber(Map<String, dynamic> player) {
    return (player['player_number'] ?? player['playerNumber'] ?? '')
        .toString()
        .trim();
  }

  static String? _playerImageUrl(Map<String, dynamic> player) {
    final value =
        player['picture_url'] ??
        player['pictureUrl'] ??
        player['player_image_url'] ??
        player['playerImageUrl'];
    final url = value?.toString().trim() ?? '';
    return url.isEmpty ? null : url;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats(widget.player);
    final name = _playerName(widget.player);
    final number = _playerNumber(widget.player);

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        onExpansionChanged: (value) => setState(() => _expanded = value),
        tilePadding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: const Color(0xFFF2C94C),
        collapsedIconColor: const Color(0xFFF2C94C),
        shape: const Border(),
        collapsedShape: const Border(),
        trailing: Icon(
          _expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: const Color(0xFFF2C94C),
          size: 30,
        ),
        title: Row(
          children: [
            Expanded(
              flex: 7,
              child: Row(
                children: [
                  _PlayerMiniAvatar(
                    scheme: widget.scheme,
                    name: name,
                    number: number,
                    imageUrl: _playerImageUrl(widget.player),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name.isEmpty ? '—' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                        color: widget.scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _CompactStatValue(value: boxscoreMinutesDisplay(stats)),
            _CompactStatValue(value: boxscoreStatValue(stats, 'Pts')),
            _CompactStatValue(value: boxscoreStatValue(stats, 'REB')),
            _CompactStatValue(value: boxscoreStatValue(stats, 'AST')),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
            decoration: BoxDecoration(
              color: widget.scheme.surface,
              border: Border(
                top: BorderSide(
                  color: widget.scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: Column(
              children: [
                BoxscoreExpandedStatPanel(
                  scheme: widget.scheme,
                  stats: stats,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatValue extends StatelessWidget {
  const _CompactStatValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 40,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: scheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PlayerMiniAvatar extends StatelessWidget {
  const _PlayerMiniAvatar({
    required this.scheme,
    required this.name,
    required this.number,
    required this.imageUrl,
  });

  final ColorScheme scheme;
  final String name;
  final String number;
  final String? imageUrl;

  static String _initials(String raw) {
    final parts = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final token = parts.first.replaceAll('.', '');
      return token.substring(0, token.length.clamp(0, 2)).toUpperCase();
    }
    return '${parts.first.replaceAll('.', '')[0]}${parts.last.replaceAll('.', '')[0]}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _PlayerMiniAvatarFallback(
                      initials: _initials(name),
                      scheme: scheme,
                    ),
                  )
                : _PlayerMiniAvatarFallback(
                    initials: _initials(name),
                    scheme: scheme,
                  ),
          ),
        ),
        if (number.isNotEmpty)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                number,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlayerMiniAvatarFallback extends StatelessWidget {
  const _PlayerMiniAvatarFallback({
    required this.initials,
    required this.scheme,
  });

  final String initials;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Play-by-Play Tab — grouped by period, no borders, tonal surface hierarchy
// ---------------------------------------------------------------------------

class _PlayByPlayTab extends StatelessWidget {
  const _PlayByPlayTab({
    required this.scheme,
    required this.events,
    required this.titleHome,
    required this.titleAway,
  });

  final ColorScheme scheme;
  final List<Map<String, dynamic>> events;
  final String titleHome;
  final String titleAway;

  static String _expandPeriod(String raw) {
    if (raw.isEmpty) return '—';
    final lower = raw.toLowerCase();
    // OT1, OT2, OT3 (numbered overtimes)
    final otm = RegExp(r'^ot\s*(\d+)$', caseSensitive: false).firstMatch(raw);
    if (otm != null) return 'Overtime ${otm.group(1)}';
    if (lower.contains('overtime') || lower == 'ot') return 'Overtime';
    // P1–P4 format used by FLB / Genius Sports scraper
    final pm = RegExp(r'^p\s*(\d+)$', caseSensitive: false).firstMatch(raw);
    if (pm != null) return 'Quarter ${pm.group(1)}';
    // Q1–Q4 generic format
    final qm = RegExp(r'q\s*(\d+)', caseSensitive: false).firstMatch(raw);
    if (qm != null) return 'Quarter ${qm.group(1)}';
    if (lower.contains('1st')) return '1st Quarter';
    if (lower.contains('2nd')) return '2nd Quarter';
    if (lower.contains('3rd')) return '3rd Quarter';
    if (lower.contains('4th')) return '4th Quarter';
    return raw;
  }

  List<_PbpListItem> _buildListItems() {
    final items = <_PbpListItem>[];
    String? lastPeriod;
    for (final row in events.reversed) {
      final raw = (row['period'] ?? '').toString().trim();
      final label = _expandPeriod(raw);
      if (label != lastPeriod) {
        items.add(_PbpPeriodHeader(label));
        lastPeriod = label;
      }
      items.add(_PbpEventRow(row));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_basketball_outlined,
                size: 52,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 20),
              Text(
                'No play-by-play events yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Play-by-play appears here during and after live games.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = _buildListItems();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is _PbpPeriodHeader) {
          return _PeriodHeaderWidget(
            label: item.label,
            scheme: scheme,
            isFirst: i == 0,
          );
        } else if (item is _PbpEventRow) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PbpEventTile(
              scheme: scheme,
              row: item.row,
              titleHome: titleHome,
              titleAway: titleAway,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Editorial period section header — left red accent bar + Lexend uppercase.
class _PeriodHeaderWidget extends StatelessWidget {
  const _PeriodHeaderWidget({
    required this.label,
    required this.scheme,
    required this.isFirst,
  });

  final String label;
  final ColorScheme scheme;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 8 : 28, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: -0.2,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single play-by-play event tile.
/// Tonal background (no border) differentiates scoring vs non-scoring.
/// Left accent bar colors home (primary red) vs away (secondary navy).
class _PbpEventTile extends StatelessWidget {
  const _PbpEventTile({
    required this.scheme,
    required this.row,
    required this.titleHome,
    required this.titleAway,
  });

  final ColorScheme scheme;
  final Map<String, dynamic> row;
  final String titleHome;
  final String titleAway;

  /// FLB stores clock as "MM:SS:00" (centiseconds always zero). Strip the trailing ":00".
  static String _formatClock(String raw) {
    if (raw.isEmpty) return '';
    final parts = raw.split(':');
    if (parts.length == 3 && parts[2] == '00') return '${parts[0]}:${parts[1]}';
    return raw;
  }

  static bool _asScoring(dynamic v) {
    if (v == true) return true;
    if (v == false || v == null) return false;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == 't' || s == '1' || s == 'yes';
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();

  static String _formatEventType(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) {
          final lower = w.toLowerCase();
          if (lower == '2pt') return '2PT';
          if (lower == '3pt') return '3PT';
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  Color _sideAccent() {
    final side = _str(row['team_side']).toLowerCase();
    if (side == 'home') return scheme.primary;
    if (side == 'away') return scheme.secondary;
    final team = _str(row['team_name']).toLowerCase();
    if (team.isNotEmpty && team == titleHome.toLowerCase()) {
      return scheme.primary;
    }
    if (team.isNotEmpty && team == titleAway.toLowerCase()) {
      return scheme.secondary;
    }
    // Neutral events (e.g. Game/Period end) — Use a distinct highlight Gold
    return const Color(0xFFF2C94C);
  }

  @override
  Widget build(BuildContext context) {
    final clock = _formatClock(_str(row['clock']));
    final score = _str(row['score']);
    final teamName = _str(row['team_name']);
    final player = _str(row['player']);
    final playerNum = _str(row['player_number']);
    final action = _str(row['action_text']);
    final eventType = _formatEventType(_str(row['event_type']));
    final scoring = _asScoring(row['is_scoring_event']);
    final accent = _sideAccent();

    String headline() {
      final buf = StringBuffer();
      if (playerNum.isNotEmpty && player.isNotEmpty) {
        buf.write('#$playerNum $player');
      } else if (player.isNotEmpty) {
        buf.write(player);
      }
      if (buf.isNotEmpty && teamName.isNotEmpty) {
        buf.write(' · $teamName');
      } else if (buf.isEmpty && teamName.isNotEmpty) {
        buf.write(teamName);
      } else if (buf.isEmpty && action.isNotEmpty) {
        buf.write(action);
      }
      return buf.toString().trim();
    }

    final head = headline();
    final showActionLine = action.isNotEmpty && head != action;

    // Tonal backgrounds per Stitch surface hierarchy — no borders
    // Scoring: faint primary tint (level 2+) | Non-scoring: surfaceContainer (level 2)
    final tileBg = scoring
        ? scheme.primary.withValues(alpha: 0.09)
        : scheme.surfaceContainer;

    final side = _str(row['team_side']).toLowerCase();
    final teamNameLower = teamName.toLowerCase();
    final isHome = side == 'home' || (teamNameLower.isNotEmpty && teamNameLower == titleHome.toLowerCase());
    final isAway = side == 'away' || (teamNameLower.isNotEmpty && teamNameLower == titleAway.toLowerCase());
    final isNeutral = !isHome && !isAway;

    final accentColor = accent.withValues(alpha: scoring ? 1.0 : 0.55);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clock column
        SizedBox(
          width: 50,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, right: 8),
            child: Text(
              clock.isNotEmpty ? clock : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Lexend',
                fontFeatures: const [FontFeature.tabularFigures()],
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        // Event card
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: tileBg,
                border: Border(
                  left: (isHome || isNeutral)
                      ? BorderSide(color: accentColor, width: 3.5)
                      : BorderSide.none,
                  right: (isAway || isNeutral)
                      ? BorderSide(color: accentColor, width: 3.5)
                      : BorderSide.none,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: isAway ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Player/team headline + score badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: isAway ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (isAway && score.isNotEmpty) ...[
                        _ScoreBadge(score: score, scheme: scheme),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          head.isEmpty ? '—' : head,
                          textAlign: isAway ? TextAlign.right : TextAlign.start,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            height: 1.2,
                            letterSpacing: -0.2,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (!isAway && score.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _ScoreBadge(score: score, scheme: scheme),
                      ],
                    ],
                  ),
                  if (showActionLine) ...[
                    const SizedBox(height: 5),
                    Text(
                      action,
                      textAlign: isAway ? TextAlign.right : TextAlign.start,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (eventType.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _EventTypeChip(
                      label: eventType,
                      scheme: scheme,
                      scoring: scoring,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.scheme});
  final String score;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        score,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w900,
          fontSize: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

/// Event type badge — no border, tonal background.
class _EventTypeChip extends StatelessWidget {
  const _EventTypeChip({
    required this.label,
    required this.scheme,
    required this.scoring,
  });

  final String label;
  final ColorScheme scheme;
  final bool scoring;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: scoring
            ? scheme.primary.withValues(alpha: 0.15)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: scoring ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text, this.scheme);
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Lexend',
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
