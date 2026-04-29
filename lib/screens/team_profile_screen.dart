import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../data/team_repository.dart';
import '../models/game_fixture_view.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/team_season_stats.dart';
import '../models/team_staff.dart';
import '../models/team_stadium.dart';
import '../models/team_trophy.dart';
import '../services/games_api_service.dart';
import '../services/players_api_service.dart';
import '../state/competition_filter.dart';
import '../widgets/league_fixture_card.dart';
import 'game_boxscore_screen.dart';
import 'player_competition_profile_screen.dart';
import 'ticket_selection_screen.dart';

const _supabaseImageHeaders = {
  'apikey': SupabaseConfig.anonKey,
  'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
};

class TeamProfileScreen extends StatefulWidget {
  const TeamProfileScreen({super.key, required this.teamId});

  final int teamId;

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  final _service = PlayersApiService();
  final GamesApiService _gamesApi = GamesApiService();
  final TeamRepository _teamsRepo = const TeamRepository();
  final AppCompetitionFilter _filter = AppCompetitionFilter.instance;

  TeamWithPlayers? _data;
  bool _loading = true;
  String? _error;

  List<GameFixtureView> _fixtures = const [];
  bool _fixturesLoading = true;
  String? _fixturesError;
  int _fixtureLoadSeq = 0;

  static const _tabLabels = [
    'Overview',
    'Fixtures',
    'Roster',
    'Stats',
    'Trophies',
  ];

  @override
  void initState() {
    super.initState();
    _filter.addListener(_onCompetitionFilterChanged);
    _load();
    _loadFixtures();
  }

  @override
  void dispose() {
    _filter.removeListener(_onCompetitionFilterChanged);
    super.dispose();
  }

  void _onCompetitionFilterChanged() {
    _loadFixtures();
  }

  String? _trimUrl(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

  void _sortTeamFixtures(List<GameFixtureView> list) {
    int weekOf(GameFixtureView f) => f.week ?? 0;
    bool upcoming(GameFixtureView f) => !f.isPast;
    list.sort((a, b) {
      final ua = upcoming(a);
      final ub = upcoming(b);
      if (ua != ub) return ua ? -1 : 1;
      if (ua) {
        final w = weekOf(a).compareTo(weekOf(b));
        if (w != 0) return w;
        return a.matchId.compareTo(b.matchId);
      }
      final w = weekOf(b).compareTo(weekOf(a));
      if (w != 0) return w;
      return b.matchId.compareTo(a.matchId);
    });
  }

  Future<void> _loadFixtures() async {
    final seq = ++_fixtureLoadSeq;
    if (mounted) {
      setState(() {
        _fixturesLoading = true;
        _fixturesError = null;
      });
    }
    try {
      await _filter.ensureLoaded();
      if (!mounted || seq != _fixtureLoadSeq) return;
      final cid = _filter.selected.competitionId;
      final rows = await _gamesApi.fetchGames(
        competitionId: cid,
        teamId: widget.teamId,
      );
      if (!mounted || seq != _fixtureLoadSeq) return;
      final teams = await _teamsRepo.fetchTeams(competitionId: cid);
      if (!mounted || seq != _fixtureLoadSeq) return;
      final logoById = <String, String?>{
        for (final t in teams) '${t.teamId}': t.logoUrl,
      };
      final merged = <GameFixtureView>[];
      for (final e in rows) {
        final row = Map<String, dynamic>.from(e);
        final hid = row['home_team_id']?.toString();
        final aid = row['away_team_id']?.toString();
        final hl = _trimUrl(logoById[hid]);
        final al = _trimUrl(logoById[aid]);
        if (hl != null) row['home_team_logo'] = hl;
        if (al != null) row['away_team_logo'] = al;
        merged.add(GameFixtureView.fromGamesApiRow(row));
      }
      merged.removeWhere((f) => f.matchId <= 0);
      _sortTeamFixtures(merged);
      if (!mounted || seq != _fixtureLoadSeq) return;
      setState(() {
        _fixtures = merged;
        _fixturesLoading = false;
      });
    } catch (e) {
      if (!mounted || seq != _fixtureLoadSeq) return;
      setState(() {
        _fixturesError = e.toString();
        _fixturesLoading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchTeamWithPlayers(widget.teamId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(title: const Text('Team'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: colorScheme.secondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data!;
    GameFixtureView? firstUpcoming;
    for (final f in _fixtures) {
      if (!f.isPast) {
        firstUpcoming = f;
        break;
      }
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ClubHeader(team: data.team),
              Material(
                color: colorScheme.surfaceContainerLow,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorColor: colorScheme.primary,
                  tabs: [for (final l in _tabLabels) Tab(text: l, height: 44)],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _OverviewTab(
                      team: data.team,
                      trophies: data.trophies,
                      stadium: data.stadium,
                      staff: data.staff,
                      upcoming: firstUpcoming,
                      onOpenTickets: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const TicketSelectionScreen(),
                          ),
                        );
                      },
                      onOpenGame: (matchId) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                GameBoxscoreScreen(matchId: matchId),
                          ),
                        );
                      },
                    ),
                    _FixturesTab(
                      teamName: data.team.teamName,
                      fixtures: _fixtures,
                      loading: _fixturesLoading,
                      error: _fixturesError,
                      onRetry: _loadFixtures,
                    ),
                    _RosterTab(
                      team: data.team,
                      players: data.players,
                      gamesApi: _gamesApi,
                      competitionId: _filter.selected.competitionId,
                    ),
                    _TeamStatsTab(
                      team: data.team,
                      competitionId: _filter.selected.competitionId,
                      gamesApi: _gamesApi,
                    ),
                    _TrophiesTab(trophies: data.trophies),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClubHeader extends StatelessWidget {
  const _ClubHeader({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = _initials(team.teamName);

    // Split the team name into two lines if it contains a space for a more dramatic asymmetrical layout
    final nameParts = team.teamName.split(' ');
    final String line1 = nameParts.first;
    final String line2 = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : '';

    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background watermark logo
          Positioned(
            right: -40,
            top: -20,
            child: Opacity(
              opacity: 0.04,
              child: _ClubLogo(
                initials: initials,
                logoUrl: team.logoUrl,
                size: 240,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: colorScheme.onSurface,
                    size: 28,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line1.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2.5,
                              height: 0.95,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (line2.isNotEmpty)
                            Text(
                              line2.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2.0,
                                height: 0.95,
                                color: colorScheme.primary, // Pop of red
                              ),
                            ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LBL',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colorScheme.surface,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ClubLogo(
                      initials: initials,
                      logoUrl: team.logoUrl,
                      size: 64,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _ClubLogo extends StatelessWidget {
  const _ClubLogo({required this.initials, this.logoUrl, this.size = 72.0});

  final String initials;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _fallback(context, size),
        ),
      );
    }
    return _fallback(context, size);
  }

  Widget _fallback(BuildContext context, double size) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w900,
          color: colorScheme.onPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

TeamStaffMember? _pickStaffByRole(List<TeamStaffMember> staff, String roleKey) {
  for (final m in staff) {
    final r = m.role.toLowerCase().trim();
    if (roleKey == 'president') {
      if (r.contains('president') && !r.contains('vice')) return m;
    } else if (roleKey == 'head_coach') {
      if (r == 'head coach' ||
          (r.contains('head') &&
              r.contains('coach') &&
              !r.contains('assistant'))) {
        return m;
      }
    } else if (roleKey == 'assistant_coach') {
      if ((r.contains('assistant') && r.contains('coach')) ||
          r.contains('assistant'))
        return m;
    }
  }
  return null;
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.team,
    required this.trophies,
    required this.stadium,
    required this.staff,
    required this.upcoming,
    required this.onOpenTickets,
    required this.onOpenGame,
  });

  final Team team;
  final List<TeamTrophySummary> trophies;
  final TeamStadium? stadium;
  final List<TeamStaffMember> staff;
  final GameFixtureView? upcoming;
  final VoidCallback onOpenTickets;
  final void Function(int matchId) onOpenGame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalTrophyWins = trophies.fold<int>(0, (a, t) => a + t.winCount);
    final distinctTrophies = trophies.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        Text(
          'Next up',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (upcoming != null)
          _OverviewNextGameCard(
            fixture: upcoming!,
            onTapTickets: onOpenTickets,
            onOpenGame: onOpenGame,
          )
        else
          _OverviewCard(
            child: Row(
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No upcoming fixtures scheduled right now.',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        Text(
          'Club leadership',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _OverviewCard(
          child: Column(
            children: [
              _StaffLeadershipRow(
                sectionTitle: 'Club president',
                icon: Icons.account_balance_rounded,
                member: _pickStaffByRole(staff, 'president'),
                colorScheme: colorScheme,
              ),
              Divider(
                height: 20,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              _StaffLeadershipRow(
                sectionTitle: 'Head coach',
                icon: Icons.sports_rounded,
                member: _pickStaffByRole(staff, 'head_coach'),
                colorScheme: colorScheme,
              ),
              Divider(
                height: 20,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              _StaffLeadershipRow(
                sectionTitle: 'Assistant coach',
                icon: Icons.groups_2_outlined,
                member: _pickStaffByRole(staff, 'assistant_coach'),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Silverware',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _OverviewCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalTrophyWins',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalTrophyWins == 1 ? 'trophy win' : 'trophy wins',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    if (distinctTrophies > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Across $distinctTrophies ${distinctTrophies == 1 ? 'competition' : 'competitions'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Home arena',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _OverviewStadiumCard(
          teamName: team.teamName,
          stadium: stadium,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

class _OverviewNextGameCard extends StatelessWidget {
  const _OverviewNextGameCard({
    required this.fixture,
    required this.onTapTickets,
    required this.onOpenGame,
  });

  final GameFixtureView fixture;
  final VoidCallback onTapTickets;
  final void Function(int matchId) onOpenGame;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LeagueFixtureCard(
            fixture: fixture,
            onCardTap: () => onOpenGame(fixture.matchId),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: onTapTickets,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'GET TICKETS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffLeadershipRow extends StatelessWidget {
  const _StaffLeadershipRow({
    required this.sectionTitle,
    required this.icon,
    required this.member,
    required this.colorScheme,
  });

  final String sectionTitle;
  final IconData icon;
  final TeamStaffMember? member;
  final ColorScheme colorScheme;

  static String _initials(String first, String last) {
    final a = first.trim().isNotEmpty ? first.trim()[0] : '';
    final b = last.trim().isNotEmpty ? last.trim()[0] : '';
    return ('$a$b').toUpperCase().isEmpty ? '?' : ('$a$b').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = member?.pictureUrl?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 52,
            height: 52,
            color: colorScheme.surfaceContainerHighest,
            child: url != null && url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: 52,
                    height: 52,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholderAvatar(),
                  )
                : _placeholderAvatar(),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              if (member != null) ...[
                const SizedBox(height: 4),
                Text(
                  member!.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member!.role,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  'Not listed yet',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholderAvatar() {
    if (member != null) {
      return Center(
        child: Text(
          _initials(member!.firstName, member!.lastName),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: colorScheme.primary,
          ),
        ),
      );
    }
    return Icon(icon, color: colorScheme.onSurfaceVariant, size: 26);
  }
}

class _OverviewStadiumCard extends StatelessWidget {
  const _OverviewStadiumCard({
    required this.teamName,
    required this.stadium,
    required this.colorScheme,
  });

  final String teamName;
  final TeamStadium? stadium;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final name = stadium?.stadiumName ?? 'Home arena';
    final loc = stadium?.location?.trim();
    final cap = stadium?.capacity;
    final url = stadium?.imageUrl?.trim();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: url != null && url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _stadiumPlaceholder(context),
                  )
                : _stadiumPlaceholder(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (stadium == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Stadium details for $teamName will appear here once added to the database.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ] else ...[
                  if (loc != null && loc.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (cap != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.event_seat_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Capacity: ${_formatCapacity(cap)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCapacity(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000)
      return '${(c / 1000).toStringAsFixed(1)}k'.replaceAll('.0k', 'k');
    return c.toString();
  }

  Widget _stadiumPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Stadium photo',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Space reserved for image',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _FixturesTab extends StatelessWidget {
  const _FixturesTab({
    required this.teamName,
    required this.fixtures,
    required this.loading,
    this.error,
    required this.onRetry,
  });

  final String teamName;
  final List<GameFixtureView> fixtures;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final listBg = Color.lerp(
      colorScheme.surface,
      colorScheme.surfaceContainerHighest,
      0.55,
    )!;

    if (loading && fixtures.isEmpty) {
      return ColoredBox(
        color: listBg,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && fixtures.isEmpty) {
      return ColoredBox(
        color: listBg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final upcoming = fixtures.where((f) => !f.isPast).toList();
    final past = fixtures.where((f) => f.isPast).toList();

    void openGame(int matchId) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GameBoxscoreScreen(matchId: matchId),
        ),
      );
    }

    return ColoredBox(
      color: listBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Text(
            'Games for $teamName in the competition selected on Home (gender & season).',
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          if (fixtures.isEmpty) ...[
            Text(
              'No games found for this club in the current competition.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          if (upcoming.isNotEmpty) ...[
            _FixtureSectionLabel('Upcoming', colorScheme),
            const SizedBox(height: 10),
            ...upcoming.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LeagueFixtureCard(
                  fixture: f,
                  onCardTap: () => openGame(f.matchId),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (past.isNotEmpty) ...[
            _FixtureSectionLabel('Results', colorScheme),
            const SizedBox(height: 10),
            ...past.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LeagueFixtureCard(
                  fixture: f,
                  onCardTap: () => openGame(f.matchId),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FixtureSectionLabel extends StatelessWidget {
  const _FixtureSectionLabel(this.label, this.colorScheme);

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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.colorScheme});

  final String title;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
      ),
    );
  }
}

/// Fine position bucket for sorting (PG, SG, SF, PF, C, other).
int _finePositionOrder(String position) {
  final raw = position.trim().toUpperCase();
  if (raw == 'PG' || raw.contains('POINT')) return 0;
  if (raw == 'SG' || raw.contains('SHOOTING')) return 1;
  if (raw == 'SF' || raw.contains('SMALL')) return 2;
  if (raw == 'PF' || raw.contains('POWER')) return 3;
  if (raw == 'C' || raw == 'CENTER' || raw.contains('CENTER')) return 4;
  return 5;
}

/// 0 = Guards (PG+SG), 1 = Forwards (SF+PF), 2 = Centers, 3 = Other.
int _rosterCategory(String position) {
  final f = _finePositionOrder(position);
  if (f <= 1) return 0;
  if (f == 2 || f == 3) return 1;
  if (f == 4) return 2;
  return 3;
}

String _rosterCategoryTitle(int category) {
  switch (category) {
    case 0:
      return 'Guards';
    case 1:
      return 'Forwards';
    case 2:
      return 'Centers';
    default:
      return 'Other';
  }
}

String _exactPositionLabel(String position) {
  final raw = position.trim().toUpperCase();
  if (raw.isEmpty) return 'Position TBD';
  if (raw == 'PG' || (raw.contains('POINT') && raw.contains('GUARD')))
    return 'Point Guard';
  if (raw == 'SG' || (raw.contains('SHOOTING') && raw.contains('GUARD')))
    return 'Shooting Guard';
  if (raw == 'SF' || raw.contains('SMALL')) return 'Small Forward';
  if (raw == 'PF' || raw.contains('POWER')) return 'Power Forward';
  if (raw == 'C' ||
      raw == 'CENTER' ||
      (raw.contains('CENTER') && !raw.contains('FORWARD'))) {
    return 'Center';
  }
  if (raw.contains('POINT')) return 'Point Guard';
  if (raw.contains('SHOOTING')) return 'Shooting Guard';
  if (raw.contains('SMALL')) return 'Small Forward';
  if (raw.contains('POWER')) return 'Power Forward';
  return position.trim().isEmpty ? 'Position TBD' : position.trim();
}

class _RosterTab extends StatelessWidget {
  const _RosterTab({
    required this.team,
    required this.players,
    required this.gamesApi,
    required this.competitionId,
  });

  final Team team;
  final List<Player> players;
  final GamesApiService gamesApi;
  final int competitionId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (players.isEmpty) {
      return Center(
        child: Text(
          'No players on file',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final sorted = List<Player>.from(players)
      ..sort((a, b) {
        final ca = _rosterCategory(a.position);
        final cb = _rosterCategory(b.position);
        if (ca != cb) return ca.compareTo(cb);
        final fa = _finePositionOrder(a.position);
        final fb = _finePositionOrder(b.position);
        if (fa != fb) return fa.compareTo(fb);
        return a.jerseyNumber.compareTo(b.jerseyNumber);
      });

    final groups = <int, List<Player>>{};
    for (final p in sorted) {
      final c = _rosterCategory(p.position);
      groups.putIfAbsent(c, () => []).add(p);
    }
    final orders = groups.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        for (final order in orders) ...[
          _SectionTitle(
            title: _rosterCategoryTitle(order),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in groups[order]!)
                    SizedBox(
                      width: w,
                      child: _PlayerBox(
                        player: p,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PlayerCompetitionProfileScreen(
                                player: p,
                                team: team,
                                competitionId: competitionId,
                                gamesApi: gamesApi,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _PlayerPhotoSlot extends StatelessWidget {
  const _PlayerPhotoSlot({required this.player});

  final Player player;

  String _initials() {
    final a = player.firstName.trim().isNotEmpty
        ? player.firstName.trim()[0]
        : '';
    final b = player.lastName.trim().isNotEmpty
        ? player.lastName.trim()[0]
        : '';
    final s = ('$a$b').toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = player.pictureUrl?.trim();
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null && url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: 84,
                  height: 84,
                  alignment: Alignment.topCenter,
                  headers: _supabaseImageHeaders,
                  errorBuilder: (context, error, stackTrace) =>
                      _fallback(colorScheme),
                )
              : _fallback(colorScheme),
        ),
      ],
    );
  }

  Widget _fallback(ColorScheme colorScheme) {
    return Center(
      child: Text(
        _initials(),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 20,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

class _PlayerBox extends StatelessWidget {
  const _PlayerBox({required this.player, this.onTap});

  final Player player;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final exact = _exactPositionLabel(player.position);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                colorScheme.surfaceContainerLow,
                colorScheme.surfaceContainerHighest,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.onSurface.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -20,
                child: Text(
                  '${player.jerseyNumber}',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 110,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface.withValues(alpha: 0.05),
                    letterSpacing: -6,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: _PlayerPhotoSlot(player: player),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      player.fullName.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: colorScheme.onSurface,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exact.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (player.nationality.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        player.nationality.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _teamStatShootPct(int made, int att) {
  if (att <= 0) return 0;
  return (100 * made) / att;
}

class _TeamStatsTab extends StatelessWidget {
  const _TeamStatsTab({
    required this.team,
    required this.competitionId,
    required this.gamesApi,
  });

  final Team team;
  final int competitionId;
  final GamesApiService gamesApi;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<TeamSeasonStats>>(
      future: gamesApi.fetchTeamSeasonStats(competitionId: competitionId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: cs.primary));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.error),
              ),
            ),
          );
        }
        final list = snap.data ?? const <TeamSeasonStats>[];
        TeamSeasonStats? row;
        for (final r in list) {
          if (r.teamId == team.teamId) {
            row = r;
            break;
          }
        }
        if (row == null || row.gp == 0) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text(
                'Team stats',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Text(
                row == null
                    ? 'No season totals in this competition for ${team.teamName} yet.'
                    : 'Totals appear after this team plays a final or live game with a synced box score.',
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
              ),
            ],
          );
        }
        final s = row;
        final gp = s.gp;
        final gpg = gp > 0 ? gp : 1;
        final twoM = s.fgm - s.threePm < 0 ? 0 : s.fgm - s.threePm;
        final twoA = s.fga - s.threePa < 0 ? 0 : s.fga - s.threePa;
        final twoPct = _teamStatShootPct(twoM, twoA);
        final threePct = _teamStatShootPct(s.threePm, s.threePa);
        final ftPct = _teamStatShootPct(s.ftm, s.fta);
        final ppg = s.pts / gp;
        final rpg = s.reb / gp;
        final apg = s.ast / gp;
        final spg = s.stl / gp;
        final bpg = s.blk / gp;
        final tovPg = s.tov / gp;
        final pfPg = s.pf / gp;
        final drebPg = s.dreb / gp;
        final orebPg = s.oreb / gp;
        final eff = (s.pts + s.reb + s.ast + s.stl + s.blk - s.tov - s.pf) / gp;
        final decided = s.wins + s.losses;
        final recordLabel =
            decided > 0 ? '${s.wins}/${s.losses}' : (gp > 0 ? '—' : '0/0');

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Team stats',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'From team box scores in the selected competition',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TeamStatSummaryCard(
                    icon: Icons.sports_rounded,
                    headline: '$gp',
                    caption: 'GAMES',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TeamStatSummaryCard(
                    icon: Icons.emoji_events_outlined,
                    headline: recordLabel,
                    caption: 'RECORD',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TeamStatSummaryCard(
                    icon: Icons.stacked_line_chart_rounded,
                    headline: '${s.pts}',
                    subline: '${s.ptsAgainst} allowed',
                    caption: 'POINTS',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _TeamStatsSectionCard(
              title: 'GAMES',
              child: Column(
                children: [
                  _TeamStatsKvRow(label: 'Games played', value: '$gp'),
                  _TeamStatsKvRow(label: 'Record', value: recordLabel),
                  _TeamStatsKvHighlight(
                    label: 'Efficiency rating',
                    value: eff.toStringAsFixed(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TeamStatsSectionCard(
              title: 'SHOOTING PERCENTAGES',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TeamStatsShootRing(
                    scheme: cs,
                    label: '2 Points',
                    pct: twoPct,
                    made: twoM,
                    att: twoA,
                  ),
                  _TeamStatsShootRing(
                    scheme: cs,
                    label: '3 Points',
                    pct: threePct,
                    made: s.threePm,
                    att: s.threePa,
                  ),
                  _TeamStatsShootRing(
                    scheme: cs,
                    label: 'Free throws',
                    pct: ftPct,
                    made: s.ftm,
                    att: s.fta,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TeamStatsSectionCard(
              title: 'POINTS',
              child: Column(
                children: [
                  _TeamStatsKvRow(
                    label: 'Points per game',
                    value: ppg.toStringAsFixed(1),
                  ),
                  _TeamStatsKvRow(
                    label: '2 points',
                    value: '${(twoM / gpg).toStringAsFixed(1)} ($twoM)',
                  ),
                  _TeamStatsKvRow(
                    label: '3 points',
                    value:
                        '${(s.threePm / gpg).toStringAsFixed(1)} (${s.threePm})',
                  ),
                  _TeamStatsKvRow(
                    label: 'Free throws',
                    value: '${(s.ftm / gpg).toStringAsFixed(1)} (${s.ftm})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TeamStatsSectionCard(
              title: 'REBOUNDS',
              child: Column(
                children: [
                  _TeamStatsKvRow(
                    label: 'Rebounds per game',
                    value: '${rpg.toStringAsFixed(1)} (${s.reb})',
                  ),
                  _TeamStatsKvRow(
                    label: 'Defensive rebounds',
                    value: '${drebPg.toStringAsFixed(1)} (${s.dreb})',
                  ),
                  _TeamStatsKvRow(
                    label: 'Offensive rebounds',
                    value: '${orebPg.toStringAsFixed(1)} (${s.oreb})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TeamStatsSectionCard(
              title: 'OTHERS',
              child: Column(
                children: [
                  _TeamStatsKvRow(
                    label: 'Assists',
                    value: '${apg.toStringAsFixed(1)} (${s.ast})',
                  ),
                  _TeamStatsKvRow(
                    label: 'Steals',
                    value: '${spg.toStringAsFixed(2)} (${s.stl})',
                  ),
                  _TeamStatsKvRow(
                    label: 'Blocks',
                    value: '${bpg.toStringAsFixed(2)} (${s.blk})',
                  ),
                  _TeamStatsKvRow(
                    label: 'Turnovers',
                    value: '${tovPg.toStringAsFixed(1)} (${s.tov})',
                  ),
                  _TeamStatsKvRow(
                    label: 'Personal fouls',
                    value: pfPg.toStringAsFixed(1),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TeamStatSummaryCard extends StatelessWidget {
  const _TeamStatSummaryCard({
    required this.icon,
    required this.headline,
    required this.caption,
    this.subline,
  });

  final IconData icon;
  final String headline;
  final String caption;
  final String? subline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: cs.primary),
          const SizedBox(height: 8),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: cs.onSurface,
              height: 1.1,
            ),
          ),
          if (subline != null) ...[
            const SizedBox(height: 4),
            Text(
              subline!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                height: 1.2,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            caption.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamStatsSectionCard extends StatelessWidget {
  const _TeamStatsSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.9,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _TeamStatsKvRow extends StatelessWidget {
  const _TeamStatsKvRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamStatsKvHighlight extends StatelessWidget {
  const _TeamStatsKvHighlight({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamStatsShootRing extends StatelessWidget {
  const _TeamStatsShootRing({
    required this.scheme,
    required this.label,
    required this.pct,
    required this.made,
    required this.att,
  });

  final ColorScheme scheme;
  final String label;
  final double pct;
  final int made;
  final int att;

  @override
  Widget build(BuildContext context) {
    final p = (pct / 100).clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: CustomPaint(
            painter: _TeamStatsRingPainter(
              progress: p,
              color: scheme.primary,
            ),
            child: Center(
              child: Text(
                '${pct.round()}%',
                style: const TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$made OF $att',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TeamStatsRingPainter extends CustomPainter {
  _TeamStatsRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    final bg = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, bg);
    final sweep = 2 * 3.141592653589793 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -3.141592653589793 / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _TeamStatsRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _TrophiesTab extends StatelessWidget {
  const _TrophiesTab({required this.trophies});

  final List<TeamTrophySummary> trophies;

  static const _gold = Color(0xFFC9A227);
  static const _goldDeep = Color(0xFF8B6914);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backdrop = Color.lerp(
      colorScheme.surface,
      const Color(0xFFFFF9E8),
      0.35,
    )!;

    if (trophies.isEmpty) {
      return ColoredBox(
        color: backdrop,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _gold.withValues(alpha: 0.2),
                        _gold.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    size: 48,
                    color: _goldDeep.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Trophy room',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Titles and seasons will appear here once they’re recorded for this club.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: backdrop,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: trophies.length,
        itemBuilder: (context, index) {
          final t = trophies[index];
          final seasons = List<TrophySeason>.from(t.seasons)
            ..sort((a, b) => b.seasonStartYear.compareTo(a.seasonStartYear));
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.95),
              elevation: 0,
              shadowColor: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    shape: const RoundedRectangleBorder(),
                    collapsedShape: const RoundedRectangleBorder(),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE8C547), _gold],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFF3D2E00),
                        size: 26,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.trophyName,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              height: 1.2,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_goldDeep, Color(0xFFA67C0A)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: _goldDeep.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '${t.winCount}×',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle:
                        t.description != null &&
                            t.description!.trim().isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8, right: 4),
                            child: Text(
                              t.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : null,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Seasons',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: _goldDeep.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in seasons)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
