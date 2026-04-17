import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/team.dart';
import '../models/team_trophy.dart';
import '../services/players_api_service.dart';
import 'ticket_selection_screen.dart';

/// Demo schedule until games are wired to the API.
class _DemoFixture {
  const _DemoFixture({
    required this.title,
    required this.subtitle,
    required this.isPast,
    this.resultLabel,
  });

  final String title;
  final String subtitle;
  final bool isPast;
  final String? resultLabel;
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
        title: '$clubName vs Hoops United',
        subtitle: 'Fri, Apr 18 · 8:30 PM · Home arena',
        isPast: false,
      ),
      _DemoFixture(
        title: 'City BC vs $clubName',
        subtitle: 'Wed, Apr 23 · 7:00 PM · Away',
        isPast: false,
      ),
      _DemoFixture(
        title: '$clubName vs North Stars',
        subtitle: 'Sat, Apr 5 · 6:00 PM · Home arena',
        isPast: true,
        resultLabel: 'W 92–84',
      ),
      _DemoFixture(
        title: 'Capital Lions vs $clubName',
        subtitle: 'Sun, Mar 22 · 5:15 PM · Away',
        isPast: true,
        resultLabel: 'L 71–78',
      ),
      _DemoFixture(
        title: '$clubName vs Mariners',
        subtitle: 'Thu, Mar 13 · 9:00 PM · Neutral site',
        isPast: true,
        resultLabel: 'W 101–96',
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
                    _OverviewTab(team: data.team, players: data.players, trophies: data.trophies),
                    _FixturesTab(
                      teamName: data.team.teamName,
                      fixtures: _demoFixtures(data.team.teamName),
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

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.team,
    required this.players,
    required this.trophies,
  });

  final Team team;
  final List<Player> players;
  final List<TeamTrophySummary> trophies;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trophyTitles = trophies.length;
    final totalWins = trophies.fold<int>(0, (a, t) => a + t.winCount);
    final byPos = <String, int>{};
    for (final p in players) {
      final key = p.position.trim().isEmpty ? '—' : p.position.trim().toUpperCase();
      byPos[key] = (byPos[key] ?? 0) + 1;
    }
    final posLine = byPos.entries.isEmpty
        ? 'Roster positions will show here once players are assigned.'
        : byPos.entries.map((e) => '${e.key}: ${e.value}').join(' · ');

    final custom = team.about?.trim();
    final blurb = custom != null && custom.isNotEmpty
        ? custom
        : '${team.teamName} competes in the Lebanese Basketball League. '
            'This page brings together fixtures, the full roster grouped by role, '
            'and every trophy the club has lifted — season by season.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('At a glance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _OverviewCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatRow(icon: Icons.groups_rounded, label: 'Squad size', value: '${players.length} players'),
              const Divider(height: 24),
              _StatRow(icon: Icons.emoji_events_rounded, label: 'Trophy types', value: '$trophyTitles'),
              const Divider(height: 24),
              _StatRow(icon: Icons.stars_rounded, label: 'Total titles', value: '$totalWins'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _OverviewCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: TextStyle(fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
              const SizedBox(height: 10),
              Text(blurb, style: TextStyle(height: 1.45, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              Text('Positions', style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
              const SizedBox(height: 6),
              Text(posLine, style: TextStyle(height: 1.4, color: colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 22, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Sample schedule for $teamName',
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 8),
        if (upcoming.isNotEmpty) ...[
          _SectionTitle(title: 'Upcoming', colorScheme: colorScheme),
          const SizedBox(height: 8),
          ...upcoming.map((f) => _FixtureTile(fixture: f, onGetTickets: onGetTickets)),
        ],
        const SizedBox(height: 20),
        if (past.isNotEmpty) ...[
          _SectionTitle(title: 'Past results', colorScheme: colorScheme),
          const SizedBox(height: 8),
          ...past.map((f) => _FixtureTile(fixture: f, onGetTickets: null)),
        ],
      ],
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

class _FixtureTile extends StatelessWidget {
  const _FixtureTile({required this.fixture, this.onGetTickets});

  final _DemoFixture fixture;
  final VoidCallback? onGetTickets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: !fixture.isPast && onGetTickets != null ? onGetTickets : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  fixture.isPast ? Icons.history_rounded : Icons.event_rounded,
                  color: fixture.isPast ? colorScheme.onSurfaceVariant : colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fixture.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        fixture.subtitle,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (fixture.resultLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      fixture.resultLabel!,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  )
                else if (onGetTickets != null)
                  Text(
                    'Tickets',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: colorScheme.primary,
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

int _rosterGroupOrder(String position) {
  final raw = position.trim().toUpperCase();
  if (raw == 'PG' || raw.contains('POINT')) return 0;
  if (raw == 'SG' || raw.contains('SHOOTING')) return 1;
  if (raw == 'SF' || raw.contains('SMALL')) return 2;
  if (raw == 'PF' || raw.contains('POWER')) return 3;
  if (raw == 'C' || raw == 'CENTER' || raw.contains('CENTER')) return 4;
  return 5;
}

String _rosterGroupTitle(int order) {
  switch (order) {
    case 0:
      return 'Point guards';
    case 1:
      return 'Shooting guards';
    case 2:
      return 'Small forwards';
    case 3:
      return 'Power forwards';
    case 4:
      return 'Centers';
    default:
      return 'Other';
  }
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
        final oa = _rosterGroupOrder(a.position);
        final ob = _rosterGroupOrder(b.position);
        if (oa != ob) return oa.compareTo(ob);
        return a.jerseyNumber.compareTo(b.jerseyNumber);
      });

    final groups = <int, List<Player>>{};
    for (final p in sorted) {
      final o = _rosterGroupOrder(p.position);
      groups.putIfAbsent(o, () => []).add(p);
    }
    final orders = groups.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        for (final order in orders) ...[
          _SectionTitle(title: _rosterGroupTitle(order), colorScheme: colorScheme),
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
        _SectionTitle(title: 'Coaching staff', colorScheme: colorScheme),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Coaching staff is not in the database yet. This section will list coaches when data is available.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _PlayerBox extends StatelessWidget {
  const _PlayerBox({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pos = player.position.trim().isEmpty ? '—' : player.position.trim().toUpperCase();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
      ),
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
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pos,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.2),
          ),
          if (player.nationality.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              player.nationality,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrophiesTab extends StatelessWidget {
  const _TrophiesTab({required this.trophies});

  final List<TeamTrophySummary> trophies;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (trophies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No trophies recorded for this club yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      itemCount: trophies.length,
      itemBuilder: (context, index) {
        final t = trophies[index];
        final seasons = List<TrophySeason>.from(t.seasons)
          ..sort((a, b) => b.seasonStartYear.compareTo(a.seasonStartYear));
        return Card(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    t.trophyName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '×${t.winCount}',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: t.description != null && t.description!.trim().isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      t.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : null,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in seasons)
                      Chip(
                        label: Text(s.label),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
