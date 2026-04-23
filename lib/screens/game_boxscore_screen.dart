import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/games_api_service.dart';

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

class _GameBoxscoreScreenState extends State<GameBoxscoreScreen> with SingleTickerProviderStateMixin {
  final _api = GamesApiService();
  Map<String, dynamic>? _payload;
  String? _error;
  bool _loading = true;
  late final TabController _tabController;

  static const _statOrder = [
    'Pts',
    'REB',
    'AST',
    'STL',
    'BLK',
    'TO',
    'PF',
    'FG%',
    'FGA',
    'FGM',
    '3P%',
    '3PA',
    '3PM',
    '2P%',
    '2PA',
    '2PM',
    'FT%',
    'FTA',
    'FTM',
    'OFF',
    'DEF',
  ];

  static const _playerStatOrder = ['Mins', ..._statOrder];

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
      final data = await _api.fetchBoxscore(matchId: widget.matchId);
      if (!mounted) return;
      setState(() {
        _payload = data;
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

  static Map<String, String> _parseTotals(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return {
        for (final e in raw.entries)
          e.key.toString(): e.value == null ? '—' : e.value.toString(),
      };
    }
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return {};
      try {
        final d = jsonDecode(s);
        return _parseTotals(d);
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  static Map<String, dynamic>? _teamBySide(List<dynamic>? teams, String sideNorm) {
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
      'player_number': pickStr(['player_number', 'playerNumber', 'PlayerNumber']),
      'action_text': pickStr(['action_text', 'actionText', 'ActionText']),
      'event_type': pickStr(['event_type', 'eventType', 'EventType']),
      'is_scoring_event': pickDyn(['is_scoring_event', 'isScoringEvent', 'IsScoringEvent']),
    };
  }

  List<Map<String, dynamic>> _playersForSide(List<dynamic>? players, String sideNorm) {
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

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.inverseSurface,
        foregroundColor: scheme.onInverseSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onInverseSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: scheme.onInverseSurface),
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
    final payload = _payload!;
    final game = payload['game'];
    final teamsRaw = payload['teams'];
    final teams = teamsRaw is List ? teamsRaw : const [];
    final playersRaw = payload['players'];
    final players = playersRaw is List ? playersRaw : const [];
    final eventsRaw = payload['events'];
    final events = _normalizeEventRows(eventsRaw);

    final gameMap = game is Map<String, dynamic> ? game : (game is Map ? Map<String, dynamic>.from(game) : null);

    final homeRow = _teamBySide(teams, 'home');
    final awayRow = _teamBySide(teams, 'away');
    final homeName = (homeRow?['team_name'] ?? '').toString().trim();
    final awayName = (awayRow?['team_name'] ?? '').toString().trim();
    final homeTotals = _parseTotals(homeRow?['totals']);
    final awayTotals = _parseTotals(awayRow?['totals']);

    final titleHome = homeName.isNotEmpty ? homeName : (gameMap?['home_team_name']?.toString() ?? 'Home');
    final titleAway = awayName.isNotEmpty ? awayName : (gameMap?['away_team_name']?.toString() ?? 'Away');
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
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          indicatorWeight: 3,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
          tabs: const [
            Tab(text: 'TEAM TOTALS'),
            Tab(text: 'PLAYERS'),
            Tab(text: 'PLAY-BY-PLAY'),
          ],
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
              ),
              _PlayersTab(
                scheme: scheme,
                titleHome: titleHome,
                titleAway: titleAway,
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

    return Container(
      color: scheme.inverseSurface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                      color: scheme.onInverseSurface.withValues(alpha: 0.6),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(4),
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
                    color: scheme.onInverseSurface.withValues(alpha: 0.45),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: hasScore
                    ? Text(
                        '$homeScore — $awayScore',
                        style: TextStyle(
                          color: scheme.onInverseSurface,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          fontFamily: 'Lexend',
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    : Text(
                        'vs',
                        style: TextStyle(
                          color: scheme.onInverseSurface.withValues(alpha: 0.4),
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
          color: scheme.onInverseSurface.withValues(alpha: 0.7),
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
            color: hasLogo ? Colors.white : Colors.white24,
            shape: BoxShape.circle,
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
          textAlign: align == CrossAxisAlignment.start ? TextAlign.start : TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onInverseSurface,
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
  });

  final ColorScheme scheme;
  final String titleHome;
  final String titleAway;
  final Map<String, String> homeTotals;
  final Map<String, String> awayTotals;

  @override
  Widget build(BuildContext context) {
    if (homeTotals.isEmpty && awayTotals.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Team box score is not available for this game yet (totals appear after the match is synced).',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      );
    }

    final keys = _orderedStatKeys(homeTotals, awayTotals);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SectionHeading('Team totals', scheme),
        const SizedBox(height: 10),
        // Ghost border per Stitch design (outlineVariant at low opacity)
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                  ),
                  children: [
                    _cellHeader('Stat', scheme, align: TextAlign.left),
                    _cellHeader(titleHome.toUpperCase(), scheme, align: TextAlign.right),
                    _cellHeader(titleAway.toUpperCase(), scheme, align: TextAlign.right),
                  ],
                ),
                for (var i = 0; i < keys.length; i++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: i.isOdd ? scheme.surfaceContainer.withValues(alpha: 0.5) : null,
                    ),
                    children: [
                      _cellStat(keys[i], scheme),
                      _cellVal(homeTotals[keys[i]] ?? '—', scheme),
                      _cellVal(awayTotals[keys[i]] ?? '—', scheme),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<String> _orderedStatKeys(Map<String, String> homeT, Map<String, String> awayT) {
    final all = {...homeT.keys, ...awayT.keys}.where((k) => k != 'side').toList();
    int rank(String k) {
      final i = _GameBoxscoreScreenState._statOrder.indexWhere((p) => p.toLowerCase() == k.toLowerCase());
      return i >= 0 ? i : 999;
    }
    all.sort((a, b) {
      final ra = rank(a);
      final rb = rank(b);
      if (ra != rb) return ra.compareTo(rb);
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return all;
  }

  Widget _cellHeader(String text, ColorScheme scheme, {required TextAlign align}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _cellStat(String text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: scheme.onSurface,
        ),
      ),
    );
  }

  Widget _cellVal(String text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: scheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Players Tab
// ---------------------------------------------------------------------------

class _PlayersTab extends StatelessWidget {
  const _PlayersTab({
    required this.scheme,
    required this.titleHome,
    required this.titleAway,
    required this.homePlayers,
    required this.awayPlayers,
  });

  final ColorScheme scheme;
  final String titleHome;
  final String titleAway;
  final List<Map<String, dynamic>> homePlayers;
  final List<Map<String, dynamic>> awayPlayers;

  @override
  Widget build(BuildContext context) {
    if (homePlayers.isEmpty && awayPlayers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Player box scores are not available yet. They appear after the match is synced.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SectionHeading(titleHome.toUpperCase(), scheme),
        const SizedBox(height: 10),
        _TeamPlayerTable(scheme: scheme, players: homePlayers),
        const SizedBox(height: 28),
        _SectionHeading(titleAway.toUpperCase(), scheme),
        const SizedBox(height: 10),
        _TeamPlayerTable(scheme: scheme, players: awayPlayers),
      ],
    );
  }
}

/// One team: header row + one row per player; stats are columns (scroll horizontally).
class _TeamPlayerTable extends StatelessWidget {
  const _TeamPlayerTable({required this.scheme, required this.players});

  final ColorScheme scheme;
  final List<Map<String, dynamic>> players;

  static const _playerColW = 132.0;
  static const _statColW = 46.0;

  static String _playerLabel(Map<String, dynamic> row) {
    final name = (row['player_name'] ?? row['playerName'] ?? '').toString().trim();
    final num = (row['player_number'] ?? row['playerNumber'] ?? '').toString().trim();
    if (num.isNotEmpty && name.isNotEmpty) return '#$num $name';
    if (name.isNotEmpty) return name;
    return '—';
  }

  static String _statCell(Map<String, String> stats, String col) {
    for (final e in stats.entries) {
      if (e.key.toLowerCase() == col.toLowerCase()) return e.value;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final columns = _GameBoxscoreScreenState._playerStatOrder;

    if (players.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Text(
            'No player lines for this side.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.35),
          ),
        ),
      );
    }

    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(_playerColW),
    };
    for (var i = 0; i < columns.length; i++) {
      columnWidths[i + 1] = const FixedColumnWidth(_statColW);
    }

    final headerStyle = TextStyle(
      fontFamily: 'Lexend',
      fontWeight: FontWeight.w800,
      fontSize: 10,
      letterSpacing: 0.2,
      height: 1.15,
      color: scheme.onSurfaceVariant,
    );
    final playerStyle = TextStyle(
      fontFamily: 'Lexend',
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1.2,
      color: scheme.onSurface,
    );
    final statStyle = TextStyle(
      fontFamily: 'Lexend',
      fontWeight: FontWeight.w700,
      fontSize: 11,
      color: scheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final table = Table(
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
              child: Text('PLAYER', style: headerStyle),
            ),
            for (final c in columns)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  c,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: headerStyle,
                ),
              ),
          ],
        ),
        for (var r = 0; r < players.length; r++)
          TableRow(
            decoration: BoxDecoration(
              color: r.isOdd ? scheme.surfaceContainer.withValues(alpha: 0.5) : null,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Text(
                  _playerLabel(players[r]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: playerStyle,
                ),
              ),
              for (final c in columns)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    _statCell(_GameBoxscoreScreenState._parseTotals(players[r]['stats']), c),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: statStyle,
                  ),
                ),
            ],
          ),
      ],
    );

    final tableWidth = _playerColW + columns.length * _statColW;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            if (maxW.isFinite && tableWidth <= maxW) {
              return table;
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: tableWidth, child: table),
            );
          },
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
    for (final row in events) {
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
    if (team.isNotEmpty && team == titleHome.toLowerCase()) return scheme.primary;
    if (team.isNotEmpty && team == titleAway.toLowerCase()) return scheme.secondary;
    return scheme.onSurfaceVariant;
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
        // Event card — left accent via border, no stretch Row
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: tileBg,
                border: Border(
                  left: BorderSide(
                    color: accent.withValues(alpha: scoring ? 1.0 : 0.55),
                    width: 3,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Player/team headline + score badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          head.isEmpty ? '—' : head,
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
                      if (score.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        // Score badge — surfaceContainerHighest (Level 3), no border
                        Container(
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
                        ),
                      ],
                    ],
                  ),
                  if (showActionLine) ...[
                    const SizedBox(height: 5),
                    Text(
                      action,
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