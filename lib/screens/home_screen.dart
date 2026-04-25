import 'dart:async';
import 'package:flutter/material.dart';
import '../services/games_api_service.dart';
import '../state/competition_filter.dart';
import '../widgets/competition_selector_bar.dart';
import 'game_boxscore_screen.dart';
import 'ticket_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _newsController = PageController();
  int _currentNewsIndex = 0;
  Timer? _newsTimer;
  final Set<int> _remindedMatchIds = {};
  AnimationController? _pulseController;

  final _api = GamesApiService();
  final _filter = AppCompetitionFilter.instance;
  bool _gamesLoading = false;
  List<Map<String, dynamic>> _liveGames = const [];
  List<Map<String, dynamic>> _upcomingGames = const [];
  List<Map<String, dynamic>> _activeUpcomingGames = const [];
  List<Map<String, dynamic>> _completedChampions = const [];

  // Competitions that are fully over — show their champion instead of live section.
  static const List<int> _completedCompIds = [39158, 39159];

  final List<Map<String, String>> _breakingNews = [
    {
      'title': 'WAEL ARAKJI LEADS RIYADI TO THRILLING OVERTIME VICTORY',
      'subtitle':
          'The Lebanese point guard dropped 34 points in a historic performance at the Saeb Salam Arena tonight.',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCU9MgtLh0Evk_CTs2FKxcCqiKBY4O_K8gyorHPiIje40vJG4ahm-7hnAS-iD9PMyiOtskELCm26E6hoKHsdPxG9uT6rxR7AstGOvL-LEYxzUwU8oUTGAiaXS7fK7ctoHfZ6fEK4IaXaDZjBm7Gbqlusy8pb6V14LFC26b1zE5Q3GjT0wWd0uxE4ufojHPT2ZRP6a8Vd_pxPkzWDwIFWuxRtG-8H4Jyny6cxx-WFSrE2AF9ttSSkejN-V7YZjxQY-XWvtlkRxshMEK-',
      'tag': 'BREAKING NEWS',
    },
    {
      'title': 'SAGESSE SECURES CRITICAL WIN OVER ANTUNIEH',
      'subtitle':
          'The green team dominates the paint to stay top of the standings after a fierce battle at the Ghazir stadium.',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCU9MgtLh0Evk_CTs2FKxcCqiKBY4O_K8gyorHPiIje40vJG4ahm-7hnAS-iD9PMyiOtskELCm26E6hoKHsdPxG9uT6rxR7AstGOvL-LEYxzUwU8oUTGAiaXS7fK7ctoHfZ6fEK4IaXaDZjBm7Gbqlusy8pb6V14LFC26b1zE5Q3GjT0wWd0uxE4ufojHPT2ZRP6a8Vd_pxPkzWDwIFWuxRtG-8H4Jyny6cxx-WFSrE2AF9ttSSkejN-V7YZjxQY-XWvtlkRxshMEK-',
      'tag': 'GAME REPORT',
    },
    {
      'title': 'LBL CUP FINAL TICKETS NOW ON SALE',
      'subtitle':
          'Don\'t miss out on the biggest game of the season. Grab your tickets now for the showdown at Nouhad Nawfal Arena.',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCU9MgtLh0Evk_CTs2FKxcCqiKBY4O_K8gyorHPiIje40vJG4ahm-7hnAS-iD9PMyiOtskELCm26E6hoKHsdPxG9uT6rxR7AstGOvL-LEYxzUwU8oUTGAiaXS7fK7ctoHfZ6fEK4IaXaDZjBm7Gbqlusy8pb6V14LFC26b1zE5Q3GjT0wWd0uxE4ufojHPT2ZRP6a8Vd_pxPkzWDwIFWuxRtG-8H4Jyny6cxx-WFSrE2AF9ttSSkejN-V7YZjxQY-XWvtlkRxshMEK-',
      'tag': 'TICKETS',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startNewsTimer();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _filter.addListener(_onFilterChanged);
    _loadGames();
  }

  void _startNewsTimer() {
    _newsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_newsController.hasClients) {
        int nextIndex = (_currentNewsIndex + 1) % _breakingNews.length;
        _newsController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  void _onFilterChanged() => _loadGames();

  Future<void> _loadGames() async {
    if (mounted) setState(() => _gamesLoading = true);
    try {
      await _filter.ensureLoaded();
      final selectedId = _filter.selected.competitionId;
      final isCompleted = _completedCompIds.contains(selectedId);

      final gamesF = _api.fetchGames(competitionId: selectedId);
      final championF = isCompleted
          ? _api
              .fetchCompetitionChampion(competitionId: selectedId)
              .onError((_, __) => null)
          : Future<Map<String, dynamic>?>.value(null);

      final games = await gamesF;
      final champion = await championF;

      if (!mounted) return;
      setState(() {
        _liveGames = games
            .where(
              (g) => (g['status'] ?? '').toString().toLowerCase() == 'live',
            )
            .toList();
        _upcomingGames = games
            .where((g) {
              final s = (g['status'] ?? '').toString().toLowerCase();
              return s == 'scheduled' || s == 'postponed';
            })
            .take(5)
            .toList();
        _activeUpcomingGames = isCompleted ? const [] : _upcomingGames;
        _completedChampions =
            champion != null ? [champion] : const [];
        _gamesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _gamesLoading = false);
    }
  }

  static String _abbr(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return words.take(3).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();
    }
    final s = words.first;
    return s.substring(0, s.length.clamp(0, 3)).toUpperCase();
  }

  @override
  void dispose() {
    _filter.removeListener(_onFilterChanged);
    _pulseController?.dispose();
    _newsTimer?.cancel();
    _newsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 128),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CompetitionSelectorBar(),
              const SizedBox(height: 24),
              _buildLiveGamesSection(context),
              const SizedBox(height: 32),
              _buildBreakingNewsSection(context),
              const SizedBox(height: 40),
              _buildUpcomingBattlesSection(context),
              const SizedBox(height: 40),
              _buildTopPerformersSection(context),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TicketSelectionScreen()),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: const CircleBorder(),
        elevation: 8,
        child: const Icon(Icons.confirmation_number),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.primary, width: 4),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -1.0,
                height: 1.0,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildLiveGamesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Live games — show them with pulsing LIVE badge
    if (_liveGames.isNotEmpty || _gamesLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            'LIVE LBL GAMES',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha((255 * 0.1).round()),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  if (_pulseController != null)
                    ScaleTransition(
                      scale: Tween(begin: 0.85, end: 1.15).animate(
                        CurvedAnimation(
                          parent: _pulseController!,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(150),
                              blurRadius: 4,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 156,
            child: _gamesLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _liveGames.length,
                    itemBuilder: (context, index) {
                      final g = _liveGames[index];
                      final matchId =
                          int.tryParse(g['match_id'].toString()) ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _buildLiveGameCard(
                          context: context,
                          matchId: matchId,
                          status: (g['raw_status'] ?? g['status'] ?? 'LIVE')
                              .toString()
                              .toUpperCase(),
                          team1Code: _abbr(
                            (g['home_team_name'] ?? 'Home').toString(),
                          ),
                          team2Code: _abbr(
                            (g['away_team_name'] ?? 'Away').toString(),
                          ),
                          score1: (g['home_score'] ?? 0).toString(),
                          score2: (g['away_score'] ?? 0).toString(),
                          team1Img: g['home_team_logo']?.toString() ?? '',
                          team2Img: g['away_team_logo']?.toString() ?? '',
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    // No live games — show upcoming D1 and/or champions as available
    final hasUpcoming = _activeUpcomingGames.isNotEmpty;
    final hasChampions = _completedChampions.isNotEmpty;

    if (!hasUpcoming && !hasChampions) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(13)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.sports_basketball_outlined,
                size: 48,
                color: colorScheme.secondary.withAlpha(100),
              ),
              const SizedBox(height: 16),
              Text(
                'NO LIVE GAMES RIGHT NOW',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stay tuned for upcoming LBL action or re-watch previous highlights.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'VIEW RECENT RESULTS',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Combined: upcoming D1 games and/or season champions
    const gold = Color(0xFFFFD700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasUpcoming) ...[
          _buildSectionHeader(
            context,
            'UPCOMING D1 GAMES',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'NEXT UP',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 156,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _activeUpcomingGames.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildUpcomingGameCard(
                  context,
                  _activeUpcomingGames[index],
                ),
              ),
            ),
          ),
        ],
        if (hasUpcoming && hasChampions) const SizedBox(height: 32),
        if (hasChampions) ...[
          _buildSectionHeader(
            context,
            'SEASON CHAMPIONS',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: gold.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.emoji_events, color: gold, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'FINAL',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _completedChampions.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildChampionCard(
                  context,
                  _completedChampions[index],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUpcomingGameCard(
    BuildContext context,
    Map<String, dynamic> g,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final matchId = int.tryParse(g['match_id'].toString()) ?? 0;
    final dt = (g['date_time_text'] ?? '').toString().trim();
    final st = (g['status'] ?? '').toString().toLowerCase();
    final dateLabel =
        dt.isNotEmpty ? dt.toUpperCase() : (st == 'postponed' ? 'POSTPONED' : 'TBD');
    final team1Code = _abbr((g['home_team_name'] ?? 'Home').toString());
    final team2Code = _abbr((g['away_team_name'] ?? 'Away').toString());
    final team1Img = g['home_team_logo']?.toString() ?? '';
    final team2Img = g['away_team_logo']?.toString() ?? '';

    return GestureDetector(
      onTap: matchId > 0
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameBoxscoreScreen(matchId: matchId),
                ),
              )
          : null,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(13)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: colorScheme.onSurface.withAlpha(179),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: colorScheme.outline.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    st == 'postponed' ? 'POSTPONED' : 'UPCOMING',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTeamColumn(
                  context,
                  team1Code,
                  colorScheme.onSurface,
                  team1Img,
                ),
                Text(
                  'VS',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.primary,
                    height: 1.0,
                  ),
                ),
                _buildTeamColumn(
                  context,
                  team2Code,
                  colorScheme.onSurface,
                  team2Img,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _championLabel(Map<String, dynamic> c) {
    final g = (c['gender'] ?? '').toString().toUpperCase();
    final genderStr = g == 'M' ? "MEN'S" : "WOMEN'S";
    final name = (c['competition_name'] ?? '')
        .toString()
        .toUpperCase()
        .replaceAll('DIVISION', 'DIV');
    final start = (c['start_year'] ?? '').toString();
    final end = (c['end_year'] ?? '').toString();
    final sy = start.length >= 4 ? start.substring(2) : start;
    final ey = end.length >= 4 ? end.substring(2) : end;
    return '$genderStr $name • $sy/$ey';
  }

  Widget _buildChampionCard(
    BuildContext context,
    Map<String, dynamic> champion,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    const gold = Color(0xFFFFD700);
    final teamName = (champion['team_name'] ?? 'Unknown').toString();
    final wins = champion['wins'] ?? 0;
    final losses = champion['losses'] ?? 0;
    final logoUrl = champion['logo_url']?.toString() ?? '';
    final label = _championLabel(champion);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: gold.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: gold.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.emoji_events, color: gold, size: 10),
                    SizedBox(width: 3),
                    Text(
                      'CHAMP',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => Icon(
                Icons.shield,
                color: colorScheme.secondary,
                size: 32,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                teamName.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '$wins W – $losses L',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveGameCard({
    required BuildContext context,
    required int matchId,
    required String status,
    required String team1Code,
    required String team2Code,
    required String score1,
    required String score2,
    required String team1Img,
    required String team2Img,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final statusColor = colorScheme.onSurface.withAlpha(179);
    final vsColor = colorScheme.primary;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameBoxscoreScreen(matchId: matchId),
        ),
      ),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(13)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: statusColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Live',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTeamColumn(context, team1Code, textColor, team1Img),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      score1,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '-',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: vsColor,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      score2,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                _buildTeamColumn(context, team2Code, textColor, team2Img),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(
    BuildContext context,
    String code,
    Color textColor,
    String imgUrl,
  ) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(8),
          child: Image.network(
            imgUrl,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Icon(
              Icons.shield,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          code,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakingNewsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        height: 400,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            PageView.builder(
              controller: _newsController,
              onPageChanged: (index) {
                setState(() => _currentNewsIndex = index);
              },
              itemCount: _breakingNews.length,
              itemBuilder: (context, index) {
                final item = _breakingNews[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 0.6,
                      child: Image.network(item['image']!, fit: BoxFit.cover),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.surface,
                            colorScheme.surface.withAlpha(102),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item['tag']!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item['title']!,
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 30,
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item['subtitle']!,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha(
                                204,
                              ), // text-on-surface/80
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 40), // Space for dots
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              bottom: 32,
              left: 32,
              child: Row(
                children: List.generate(_breakingNews.length, (index) {
                  final isSelected = _currentNewsIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 8),
                    width: isSelected ? 32 : 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.white.withAlpha(77),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBattlesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'UPCOMING BATTLES',
          trailing: TextButton(
            onPressed: () {
              // Navigate to Standings/Schedule tab
              final state = context.findAncestorStateOfType<State>();
              // This is a bit hacky, but let's assume the user wants to see more.
              // We'll just show a snackbar for now or navigate if we can find the shell state.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening Full Schedule...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Text(
              'VIEW SCHEDULE',
              style: TextStyle(
                fontFamily: 'Inter',
                color: colorScheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: colorScheme.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_gamesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_upcomingGames.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'No upcoming games scheduled.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _upcomingGames.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final g = _upcomingGames[index];
                final matchId =
                    int.tryParse(g['match_id'].toString()) ?? 0;
                return _buildTicketCard(
                  context: context,
                  matchId: matchId,
                  date: (() {
                    final dt = (g['date_time_text'] ?? '').toString().trim();
                    final st = (g['status'] ?? '').toString().toLowerCase();
                    return dt.isNotEmpty
                        ? dt.toUpperCase()
                        : (st == 'postponed' ? 'POSTPONED' : 'TBD');
                  })(),
                  venue: (g['venue'] ?? '').toString().toUpperCase(),
                  team1Code: _abbr(
                    (g['home_team_name'] ?? 'Home').toString(),
                  ),
                  team2Code: _abbr(
                    (g['away_team_name'] ?? 'Away').toString(),
                  ),
                  team1Img: g['home_team_logo']?.toString() ?? '',
                  team2Img: g['away_team_logo']?.toString() ?? '',
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTicketCard({
    required BuildContext context,
    required int matchId,
    required String date,
    required String venue,
    required String team1Code,
    required String team2Code,
    required String team1Img,
    required String team2Img,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReminded = _remindedMatchIds.contains(matchId);

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withAlpha(13)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (isReminded) {
                        _remindedMatchIds.remove(matchId);
                      } else {
                        _remindedMatchIds.add(matchId);
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isReminded
                              ? 'Reminder removed'
                              : 'Reminder set for this game!',
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(
                    isReminded
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: isReminded
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    venue,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTicketTeam(context, team1Code, team1Img),
                  Text(
                    'VS',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 20,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  _buildTicketTeam(context, team2Code, team2Img),
                ],
              ),
            ),
          ),
          Material(
            color: colorScheme.primary,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TicketSelectionScreen(),
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'BUY TICKETS',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
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

  Widget _buildTicketTeam(BuildContext context, String code, String imgUrl) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          child: Image.network(
            imgUrl,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) =>
                Icon(Icons.shield, color: colorScheme.secondary, size: 28),
          ),
        ),
        Text(
          code.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTopPerformersSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'TOP PERFORMERS'),
          const SizedBox(height: 24),
          // Main Performer Card
          Container(
            height: 224,
            width: double.infinity,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: colorScheme.surfaceContainer,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  bottom: -40,
                  child: Text(
                    '23',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.primary.withAlpha(26), // primary/10
                      height: 1.0,
                    ),
                  ),
                ),
                Positioned(
                  right: -20,
                  top: 0,
                  bottom: 0,
                  width: 200,
                  child: Opacity(
                    opacity: 0.8,
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDIzsjzrOvYPWBDZsnhO7BpxSHRAC90apP10GjUVN1_Mkbt7YR5RjeENChGJ1AdDwL7Qzs0lqnHX7gvrxV5ERKZj6sXSG0zdKhNbP1GuUHxGWGTInKmMm1hG3txybGHc3Qw3cnrfsTnMNaNjf_08KiF2HWdLMTvXpzGch-yhVPA373AbEZr3F9qJwFz2NAIXOEbPwCwa5AFC3uuWr9KRMrH_tkNJXF9AFo7iyCSYSOspDHYFClQsA0YqTCkDHHLAoaoh-QSDLzPEun2',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (c, e, s) => Icon(
                        Icons.person,
                        size: 100,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PLAYER OF THE WEEK',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 12,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SERGIO\nEL DARWICH',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BEIRUT CLUB • GUARD',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildStat(context, 'PTS', '28.4', false),
                          const SizedBox(width: 16),
                          _buildStat(context, 'AST', '6.2', true),
                          const SizedBox(width: 16),
                          _buildStat(context, 'REB', '5.8', true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryPerformer(
                  context,
                  'Omari Spellman',
                  'Rebounds Leader',
                  '14.3',
                  'RPG',
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBGkL957XYsrycUmC-N_7vejj9y4jFXS9pXb74WJSNyMW3VSm8GRtIse6uSng_hWepCONIh80CLfQE54WmUDJ-_nbnKegpHBlHkv_t9RByTCG0FGC4vxfx89SRQdPNOYmeOg-RlVZDi5IbOZkFeGNFroj4-N1vxLwu0l_GCXNb80Dw69Ubmt2r25UTt7-rMtlYvdLbFRLo_HjXuz6BE2Rnz-oXEbkrp7Rni_6fQI0SCpIkIoz3IOncehQ71xlZr8KDqn4uLTFk-zD2p',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSecondaryPerformer(
                  context,
                  'Ali Mezher',
                  'Assists Leader',
                  '8.9',
                  'APG',
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCRr_ol2LJioV3KhfH-1HZc3hw7nBKIaEptbKc9l3bFSLHsTKRZtCmwxNBLhiII57FBTReMI_V9HeJjha7rXZ-PZxcbFZki6ddl5RFSiSROTkUHrCeuRvDDuCOjIQ4AgmzJR1qieUQX7xBz-SJUXRS0otz35g90wggZU4UmaBMKe427lP3qMe7QkSkYlGnZvXi8lnXKkkUFS1IVkop7yKYKdmvsWRohaVOVzvKJmGfR_WBETAeOv5PQEjJhfF6y5vpt7EQg6S__9k35',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    BuildContext context,
    String label,
    String value,
    bool borderLeft,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(left: borderLeft ? 16 : 0),
      decoration: BoxDecoration(
        border: borderLeft
            ? Border(left: BorderSide(color: Colors.white.withAlpha(26)))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colorScheme.secondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colorScheme.primary,
              fontFamily: 'Lexend',
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryPerformer(
    BuildContext context,
    String name,
    String sublabel,
    String stat,
    String statLabel,
    String imgUrl,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(
                  color: Colors.white10,
                  shape: BoxShape.circle,
                ),
                child: Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) =>
                      Icon(Icons.person, color: colorScheme.secondary),
                ),
              ),
              Text(
                '#1',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stat,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  statLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
