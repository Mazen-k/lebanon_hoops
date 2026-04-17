import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/team.dart';
import '../models/team_staff.dart';
import '../models/team_stadium.dart';
import '../models/team_trophy.dart';
import '../services/players_api_service.dart';
import 'ticket_selection_screen.dart';

/// Demo schedule until games are wired to the API (reference-style match cards).
class _DemoFixture {
  const _DemoFixture({
    required this.metaLine,
    required this.leagueLabel,
    required this.homeName,
    required this.awayName,
    this.homeScore,
    this.awayScore,
    required this.isPast,
    this.centerLabel,
  });

  final String metaLine;
  final String leagueLabel;
  final String homeName;
  final String awayName;
  final int? homeScore;
  final int? awayScore;
  final bool isPast;
  /// Shown in the center for upcoming games (e.g. time).
  final String? centerLabel;
}

class TeamProfileScreen extends StatefulWidget {
  const TeamProfileScreen({super.key, required this.teamId});

  final int teamId;

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  final _service = PlayersApiService();
  TeamWithPlayers? _data;
  bool _loading = true;
  String? _error;

  static const _tabLabels = ['Overview', 'Fixtures', 'Roster', 'Trophies'];

  @override
  void initState() {
    super.initState();
    _load();
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

  List<_DemoFixture> _demoFixtures(String clubName) {
    return [
      _DemoFixture(
        metaLine: 'MON, OCT 20, 2025 — ROUND 1',
        leagueLabel: 'Lebanon Basketball League',
        homeName: clubName,
        awayName: 'Tadamon Hrajel',
        homeScore: 118,
        awayScore: 83,
        isPast: true,
      ),
      _DemoFixture(
        metaLine: 'SAT, OCT 25, 2025 — ROUND 2',
        leagueLabel: 'Lebanon Basketball League',
        homeName: 'Sagesse',
        awayName: clubName,
        homeScore: 76,
        awayScore: 91,
        isPast: true,
      ),
      _DemoFixture(
        metaLine: 'WED, NOV 5, 2025 — ROUND 4',
        leagueLabel: 'Lebanon Basketball League',
        homeName: clubName,
        awayName: 'Champville',
        homeScore: 102,
        awayScore: 97,
        isPast: true,
      ),
      _DemoFixture(
        metaLine: 'FRI, APR 18, 2026 — ROUND 12',
        leagueLabel: 'Lebanon Basketball League',
        homeName: clubName,
        awayName: 'Hoops United',
        isPast: false,
        centerLabel: '8:30 PM',
      ),
      _DemoFixture(
        metaLine: 'WED, APR 23, 2026 — ROUND 13',
        leagueLabel: 'Lebanon Basketball League',
        homeName: 'Beirut Club',
        awayName: clubName,
        isPast: false,
        centerLabel: '7:00 PM',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
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
                Icon(Icons.wifi_off_rounded, size: 48, color: colorScheme.secondary),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: colorScheme.secondary), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data!;
    final demoFx = _demoFixtures(data.team.teamName);
    _DemoFixture? firstUpcoming;
    for (final f in demoFx) {
      if (!f.isPast) {
        firstUpcoming = f;
        break;
      }
    }

    return DefaultTabController(
      length: 4,
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
                          MaterialPageRoute<void>(builder: (_) => const TicketSelectionScreen()),
                        );
                      },
                    ),
                    _FixturesTab(
                      teamName: data.team.teamName,
                      fixtures: demoFx,
                      onGetTickets: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => const TicketSelectionScreen()),
                        );
                      },
                    ),
                    _RosterTab(players: data.players),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          ),
          _ClubLogo(initials: initials, logoUrl: team.logoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.teamName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lebanese Basketball League',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _ClubLogo extends StatelessWidget {
  const _ClubLogo({required this.initials, this.logoUrl});

  final String initials;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final url = logoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(context, size),
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
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 26,
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
      if (r == 'head coach' || (r.contains('head') && r.contains('coach') && !r.contains('assistant'))) {
        return m;
      }
    } else if (roleKey == 'assistant_coach') {
      if ((r.contains('assistant') && r.contains('coach')) || r.contains('assistant')) return m;
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
  });

  final Team team;
  final List<TeamTrophySummary> trophies;
  final TeamStadium? stadium;
  final List<TeamStaffMember> staff;
  final _DemoFixture? upcoming;
  final VoidCallback onOpenTickets;

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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
          _OverviewUpcomingMatchCard(fixture: upcoming!, onTap: onOpenTickets)
        else
          _OverviewCard(
            child: Row(
              children: [
                Icon(Icons.event_busy_rounded, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No upcoming fixtures scheduled right now.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.35),
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
              Divider(height: 20, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
              _StaffLeadershipRow(
                sectionTitle: 'Head coach',
                icon: Icons.sports_rounded,
                member: _pickStaffByRole(staff, 'head_coach'),
                colorScheme: colorScheme,
              ),
              Divider(height: 20, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
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
                child: Icon(Icons.emoji_events_rounded, color: colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalTrophyWins',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9)),
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
        _OverviewStadiumCard(teamName: team.teamName, stadium: stadium, colorScheme: colorScheme),
      ],
    );
  }
}

class _OverviewUpcomingMatchCard extends StatelessWidget {
  const _OverviewUpcomingMatchCard({required this.fixture, required this.onTap});

  final _DemoFixture fixture;
  final VoidCallback onTap;

  static const _accentGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardBg = colorScheme.surfaceContainerLowest;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: _accentGreen,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(18)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fixture.metaLine.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                fixture.leagueLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Text(
                                      fixture.homeName,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _TeamCrestBadge(teamName: fixture.homeName, size: 34),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: [
                                  Text(
                                    'NEXT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    fixture.centerLabel ?? '—',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  _TeamCrestBadge(teamName: fixture.awayName, size: 34),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fixture.awayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap for tickets',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
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
                    errorBuilder: (context, error, stackTrace) => _placeholderAvatar(),
                  )
                : _placeholderAvatar(),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sectionTitle, style: TextStyle(fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
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
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                    errorBuilder: (context, error, stackTrace) => _stadiumPlaceholder(context),
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
                        Icon(Icons.place_outlined, size: 18, color: colorScheme.primary),
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
                        Icon(Icons.event_seat_outlined, size: 18, color: colorScheme.primary),
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
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}k'.replaceAll('.0k', 'k');
    return c.toString();
  }

  Widget _stadiumPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 40, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
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
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _FixturesTab extends StatelessWidget {
  const _FixturesTab({
    required this.teamName,
    required this.fixtures,
    required this.onGetTickets,
  });

  final String teamName;
  final List<_DemoFixture> fixtures;
  final VoidCallback onGetTickets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final upcoming = fixtures.where((f) => !f.isPast).toList();
    final past = fixtures.where((f) => f.isPast).toList();
    final listBg = Color.lerp(colorScheme.surface, colorScheme.surfaceContainerHighest, 0.55)!;

    void openFixtureMenu() {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                title: const Text('Match details'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Icon(Icons.notifications_active_outlined, color: colorScheme.primary),
                title: const Text('Remind me'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: listBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Text(
            'Schedule preview for $teamName',
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          if (upcoming.isNotEmpty) ...[
            _FixtureSectionLabel('Upcoming', colorScheme),
            const SizedBox(height: 10),
            ...upcoming.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LeagueFixtureCard(
                  fixture: f,
                  onMenu: openFixtureMenu,
                  onCardTap: onGetTickets,
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
                child: _LeagueFixtureCard(
                  fixture: f,
                  onMenu: openFixtureMenu,
                  onCardTap: null,
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

/// Reference UI: green spine, meta + league pill, home — score — away.
class _LeagueFixtureCard extends StatelessWidget {
  const _LeagueFixtureCard({
    required this.fixture,
    required this.onMenu,
    this.onCardTap,
  });

  final _DemoFixture fixture;
  final VoidCallback onMenu;
  final VoidCallback? onCardTap;

  static const _accentGreen = Color(0xFF22C55E);
  static const _menuBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardBg = Theme.of(context).brightness == Brightness.dark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLowest;
    final metaStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.35,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
    );
    final leaguePillStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: fixture.isPast ? null : onCardTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: _accentGreen,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(18)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                fixture.metaLine.toUpperCase(),
                                style: metaStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                fixture.leagueLabel.toUpperCase(),
                                style: leaguePillStyle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 10,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Text(
                                      fixture.homeName,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _TeamCrestBadge(teamName: fixture.homeName, size: 36),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: SizedBox(
                                width: 72,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      fixture.isPast ? 'FT' : 'NEXT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (fixture.isPast &&
                                        fixture.homeScore != null &&
                                        fixture.awayScore != null)
                                      Text(
                                        '${fixture.homeScore} : ${fixture.awayScore}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                          letterSpacing: 0.5,
                                          color: colorScheme.onSurface,
                                        ),
                                      )
                                    else
                                      Text(
                                        fixture.centerLabel ?? '—',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 10,
                              child: Row(
                                children: [
                                  _TeamCrestBadge(teamName: fixture.awayName, size: 36),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fixture.awayName,
                                      textAlign: TextAlign.left,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
                              icon: const Icon(Icons.more_vert_rounded, color: _menuBlue, size: 22),
                              onPressed: onMenu,
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
    );
  }
}

class _TeamCrestBadge extends StatelessWidget {
  const _TeamCrestBadge({required this.teamName, this.size = 40});

  final String teamName;
  final double size;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _tint(ColorScheme scheme) {
    var h = 0.0;
    for (final c in teamName.codeUnits) {
      h = (h + c) * 1.618 % 360;
    }
    return HSLColor.fromAHSL(1, h, 0.42, 0.48).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = _tint(scheme);
    final initials = _initials(teamName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [tint, Color.lerp(tint, scheme.surface, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.28,
          fontWeight: FontWeight.w900,
          color: scheme.onPrimary,
        ),
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

String _abbrevPosition(String position) {
  final raw = position.trim().toUpperCase();
  if (raw.isEmpty) return '—';
  if (raw == 'PG' || raw == 'SG' || raw == 'SF' || raw == 'PF' || raw == 'C') return raw;
  if (raw.contains('POINT')) return 'PG';
  if (raw.contains('SHOOTING')) return 'SG';
  if (raw.contains('SMALL')) return 'SF';
  if (raw.contains('POWER')) return 'PF';
  if (raw.contains('CENTER')) return 'C';
  return raw.length <= 3 ? raw : raw.substring(0, 3);
}

String _exactPositionLabel(String position) {
  final raw = position.trim().toUpperCase();
  if (raw.isEmpty) return 'Position TBD';
  if (raw == 'PG' || (raw.contains('POINT') && raw.contains('GUARD'))) return 'Point Guard';
  if (raw == 'SG' || (raw.contains('SHOOTING') && raw.contains('GUARD'))) return 'Shooting Guard';
  if (raw == 'SF' || raw.contains('SMALL')) return 'Small Forward';
  if (raw == 'PF' || raw.contains('POWER')) return 'Power Forward';
  if (raw == 'C' || raw == 'CENTER' || (raw.contains('CENTER') && !raw.contains('FORWARD'))) {
    return 'Center';
  }
  if (raw.contains('POINT')) return 'Point Guard';
  if (raw.contains('SHOOTING')) return 'Shooting Guard';
  if (raw.contains('SMALL')) return 'Small Forward';
  if (raw.contains('POWER')) return 'Power Forward';
  return position.trim().isEmpty ? 'Position TBD' : position.trim();
}

class _RosterTab extends StatelessWidget {
  const _RosterTab({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (players.isEmpty) {
      return Center(
        child: Text('No players on file', style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
          _SectionTitle(title: _rosterCategoryTitle(order), colorScheme: colorScheme),
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
                      child: _PlayerBox(player: p),
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
    final a = player.firstName.trim().isNotEmpty ? player.firstName.trim()[0] : '';
    final b = player.lastName.trim().isNotEmpty ? player.lastName.trim()[0] : '';
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null && url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: 56,
                  height: 56,
                  errorBuilder: (context, error, stackTrace) => _fallback(colorScheme),
                )
              : _fallback(colorScheme),
        ),
        const SizedBox(height: 4),
        Text(
          'Photo',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          ),
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
  const _PlayerBox({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final abbrev = _abbrevPosition(player.position);
    final exact = _exactPositionLabel(player.position);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlayerPhotoSlot(player: player),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${player.jerseyNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        abbrev,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  player.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  exact,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
                if (player.nationality.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    player.nationality,
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrophiesTab extends StatelessWidget {
  const _TrophiesTab({required this.trophies});

  final List<TeamTrophySummary> trophies;

  static const _gold = Color(0xFFC9A227);
  static const _goldDeep = Color(0xFF8B6914);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backdrop = Color.lerp(colorScheme.surface, const Color(0xFFFFF9E8), 0.35)!;

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
                      colors: [_gold.withValues(alpha: 0.2), _gold.withValues(alpha: 0.05)],
                    ),
                  ),
                  child: Icon(Icons.emoji_events_outlined, size: 48, color: _goldDeep.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 18),
                Text(
                  'Trophy room',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Titles and seasons will appear here once they’re recorded for this club.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.45),
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
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
                      child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF3D2E00), size: 26),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_goldDeep, Color(0xFFA67C0A)]),
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
                    subtitle: t.description != null && t.description!.trim().isNotEmpty
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _gold.withValues(alpha: 0.35)),
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
