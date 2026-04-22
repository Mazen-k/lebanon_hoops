import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/games_api_service.dart';

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

  static const _playerStatOrder = [
    'Mins',
    ..._statOrder,
  ];

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
        title: const Text('Box score'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load),
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
    final as = gameMap?['away_score'];
    final scoreLine = (hs != null && as != null) ? '$hs — $as' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Text(
                '$titleHome  vs  $titleAway',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (scoreLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  scoreLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
              if (gameMap?['date_time_text'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  gameMap!['date_time_text'].toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          tabAlignment: TabAlignment.start,
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

    final keys = _TeamTotalsTab._orderedStatKeysStatic(homeTotals, awayTotals);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Team totals',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
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
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
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
                    color: i.isOdd ? scheme.surface.withValues(alpha: 0.4) : null,
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
      ],
    );
  }

  static List<String> _orderedStatKeysStatic(Map<String, String> homeT, Map<String, String> awayT) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: scheme.onSurface),
      ),
    );
  }

  Widget _cellVal(String text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: scheme.onSurface),
      ),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _sectionTitle(titleHome.toUpperCase(), scheme),
        const SizedBox(height: 10),
        _TeamPlayerTable(scheme: scheme, players: homePlayers),
        const SizedBox(height: 24),
        _sectionTitle(titleAway.toUpperCase(), scheme),
        const SizedBox(height: 10),
        _TeamPlayerTable(scheme: scheme, players: awayPlayers),
      ],
    );
  }

  Widget _sectionTitle(String text, ColorScheme scheme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: scheme.onSurfaceVariant,
      ),
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
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
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
      fontWeight: FontWeight.w800,
      fontSize: 10,
      letterSpacing: 0.2,
      height: 1.15,
      color: scheme.onSurfaceVariant,
    );
    final playerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1.2,
      color: scheme.onSurface,
    );
    final statStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 11,
      color: scheme.onSurface,
    );

    final table = Table(
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
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
              color: r.isOdd ? scheme.surface.withValues(alpha: 0.38) : null,
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
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
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

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'No play-by-play for this match yet. The API returns rows from game_events where match_id equals this game — add those rows in your database, or run the server sync that fills them.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      itemCount: events.length,
      separatorBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(left: 58),
        child: Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.08)),
      ),
      itemBuilder: (context, i) => _PbpEventTile(
        scheme: scheme,
        row: events[i],
        titleHome: titleHome,
        titleAway: titleAway,
      ),
    );
  }
}

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

  static String _compactPeriod(String raw) {
    if (raw.isEmpty) return '—';
    final lower = raw.toLowerCase();
    if (lower.contains('overtime') || lower == 'ot') return 'OT';
    final qm = RegExp(r'q\s*(\d+)', caseSensitive: false).firstMatch(raw);
    if (qm != null) return 'Q${qm.group(1)}';
    if (lower.contains('1st')) return 'Q1';
    if (lower.contains('2nd')) return 'Q2';
    if (lower.contains('3rd')) return 'Q3';
    if (lower.contains('4th')) return 'Q4';
    if (raw.length <= 8) return raw;
    return '${raw.substring(0, 7)}…';
  }

  Color _sideAccent() {
    final side = _str(row['team_side']).toLowerCase();
    if (side == 'home') return scheme.primary;
    if (side == 'away') return scheme.tertiary;
    final team = _str(row['team_name']).toLowerCase();
    if (team.isNotEmpty && team == titleHome.toLowerCase()) return scheme.primary;
    if (team.isNotEmpty && team == titleAway.toLowerCase()) return scheme.tertiary;
    return scheme.outline;
  }

  @override
  Widget build(BuildContext context) {
    final period = _str(row['period']);
    final clock = _str(row['clock']);
    final score = _str(row['score']);
    final teamName = _str(row['team_name']);
    final player = _str(row['player']);
    final playerNum = _str(row['player_number']);
    final action = _str(row['action_text']);
    final eventType = _formatEventType(_str(row['event_type']));
    final scoring = _asScoring(row['is_scoring_event']);
    final accent = _sideAccent();

    final periodLabel = _compactPeriod(period);

    String headline() {
      final buf = StringBuffer();
      if (playerNum.isNotEmpty && player.isNotEmpty) {
        buf.write('#$playerNum $player');
      } else if (player.isNotEmpty) {
        buf.write(player);
      }
      if (buf.isNotEmpty && teamName.isNotEmpty) {
        buf.write(' · ');
        buf.write(teamName);
      } else if (buf.isEmpty && teamName.isNotEmpty) {
        buf.write(teamName);
      } else if (buf.isEmpty && action.isNotEmpty) {
        buf.write(action);
      }
      return buf.toString().trim();
    }

    final head = headline();
    final showActionLine = action.isNotEmpty && head != action;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  periodLabel,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (clock.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    clock,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: scheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scoring
                  ? scheme.primary.withValues(alpha: 0.06)
                  : scheme.surfaceContainerLowest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outline.withValues(alpha: scoring ? 0.22 : 0.14),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    color: accent.withValues(alpha: scoring ? 1 : 0.45),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  head.isEmpty ? '—' : head,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    height: 1.25,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              if (score.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(
                                      score,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (showActionLine) ...[
                            const SizedBox(height: 6),
                            Text(
                              action,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (eventType.isNotEmpty)
                                _PbpMetaChip(
                                  label: eventType,
                                  foreground: scheme.onSurfaceVariant,
                                  border: scheme.outline.withValues(alpha: 0.35),
                                  background: scheme.surface.withValues(alpha: 0.5),
                                ),
                              _PbpMetaChip(
                                label: scoring ? 'Scoring' : 'Non-scoring',
                                foreground: scoring ? scheme.primary : scheme.onSurfaceVariant,
                                border: scoring
                                    ? scheme.primary.withValues(alpha: 0.35)
                                    : scheme.outline.withValues(alpha: 0.25),
                                background: scoring ? scheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PbpMetaChip extends StatelessWidget {
  const _PbpMetaChip({
    required this.label,
    required this.foreground,
    required this.border,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color border;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

