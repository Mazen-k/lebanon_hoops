import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/games_api_service.dart';
import '../widgets/boxscore_expanded_stat_panel.dart';

const _supabaseImageHeaders = {
  'apikey': SupabaseConfig.anonKey,
  'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
};

const _headerBlue = Color(0xFF1E4A8C);
const _accentRed = Color(0xFFE31C23);
const _pageBg = Color(0xFFF0F2F5);

/// Full-screen player profile for one competition (PROFILE / GAME LOG).
class PlayerCompetitionProfileScreen extends StatefulWidget {
  const PlayerCompetitionProfileScreen({
    super.key,
    required this.player,
    required this.team,
    required this.competitionId,
    required this.gamesApi,
  });

  final Player player;
  final Team team;
  final int competitionId;
  final GamesApiService gamesApi;

  @override
  State<PlayerCompetitionProfileScreen> createState() =>
      _PlayerCompetitionProfileScreenState();
}

class _PlayerCompetitionProfileScreenState
    extends State<PlayerCompetitionProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileHeader(
            topPadding: topPad,
            player: widget.player,
            team: widget.team,
            tabController: _tabController,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ProfileTabBody(
                  player: widget.player,
                  team: widget.team,
                  competitionId: widget.competitionId,
                  gamesApi: widget.gamesApi,
                ),
                _GameLogTabBody(
                  competitionId: widget.competitionId,
                  playerId: widget.player.playerId,
                  gamesApi: widget.gamesApi,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.topPadding,
    required this.player,
    required this.team,
    required this.tabController,
    required this.onBack,
  });

  final double topPadding;
  final Player player;
  final Team team;
  final TabController tabController;
  final VoidCallback onBack;

  String _positionLine() {
    final pos = _exactPositionLabel(player.position);
    return '${team.teamName} — $pos';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? scheme.surface : Colors.white,
      child: Stack(
        children: [
          // Large faded jersey number background
          Positioned(
            right: -10,
            bottom: -30,
            child: Opacity(
              opacity: isDark ? 0.08 : 0.04,
              child: Text(
                '${player.jerseyNumber}',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 160,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  height: 1,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topPadding + 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: isDark ? scheme.primary : _headerBlue,
                      iconSize: 22,
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _HeaderPhoto(player: player),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.fullName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _positionLine(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: scheme.onSurface.withValues(alpha: 0.65),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _TeamLogoColumn(
                            logoUrl: team.logoUrl,
                            abbrev: _positionAbbrev(player.position),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: _accentRed,
                unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.4),
                indicatorColor: _accentRed,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
                tabs: const [
                  Tab(text: 'PROFILE'),
                  Tab(text: 'GAME LOG'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPhoto extends StatelessWidget {
  const _HeaderPhoto({required this.player});

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
    final url = player.pictureUrl?.trim();
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08), width: 2),
            color: scheme.onSurface.withValues(alpha: 0.05),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null && url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  headers: _supabaseImageHeaders,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      _initials(),
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    _initials(),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '${player.jerseyNumber}',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamLogoColumn extends StatelessWidget {
  const _TeamLogoColumn({required this.logoUrl, required this.abbrev});

  final String? logoUrl;
  final String abbrev;

  @override
  Widget build(BuildContext context) {
    final u = logoUrl?.trim();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: u != null && u.isNotEmpty
              ? Image.network(u, fit: BoxFit.contain)
              : Icon(Icons.shield_outlined, color: scheme.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

class _ProfileTabBody extends StatelessWidget {
  const _ProfileTabBody({
    required this.player,
    required this.team,
    required this.competitionId,
    required this.gamesApi,
  });

  final Player player;
  final Team team;
  final int competitionId;
  final GamesApiService gamesApi;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: gamesApi.fetchPlayerCompetitionStats(
        competitionId: competitionId,
        playerId: player.playerId,
      ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        final data = snap.data ?? const <String, dynamic>{};
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BioCard(player: player),
              const SizedBox(height: 14),
              _ProfileStatsContent(team: team, data: data),
            ],
          ),
        );
      },
    );
  }
}

class _BioCard extends StatelessWidget {
  const _BioCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final nat = player.nationality.trim();
    final dob = (player.dateOfBirth ?? '').trim();
    final h = (player.height ?? '').trim();
    final hand = (player.dominantHand ?? '').trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PLAYER INFO',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1,
              color: cs.onSurfaceVariant,
            ),
          ),
          const Divider(height: 20),
          row('Nationality', nat),
          row('Date of birth', dob),
          row('Height', h),
          row('Dominant hand', hand),
        ],
      ),
    );
  }
}

class _ProfileStatsContent extends StatelessWidget {
  const _ProfileStatsContent({required this.team, required this.data});

  final Team team;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final gp = (data['gp'] as num?)?.toInt() ?? 0;
    final per = Map<String, dynamic>.from(
      (data['per_game'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final totals = Map<String, dynamic>.from(
      (data['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final shooting = Map<String, dynamic>.from(
      (data['shooting'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    double d(String k) => (per[k] as num?)?.toDouble() ?? 0;
    int ti(String k) => (totals[k] as num?)?.toInt() ?? 0;
    double sd(String k) => (shooting[k] as num?)?.toDouble() ?? 0;
    int si(String k) => (shooting[k] as num?)?.toInt() ?? 0;

    final ppg = d('ppg');
    final rpg = d('rpg');
    final apg = d('apg');
    final spg = d('spg');
    final bpg = d('bpg');
    final mpg = d('mpg');
    final eff = d('eff_rating');
    final tpmPg = d('tpm_pg');
    final twoMPg = d('two_m_pg');
    final ftmPg = d('ftm_pg');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryStripCard(
          teamName: team.teamName,
          logoUrl: team.logoUrl,
          pts: ppg,
          reb: rpg,
          ast: apg,
          stl: spg,
          blk: bpg,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'GAMES',
          child: Column(
            children: [
              _kv('Games played', '$gp'),
              _kv('Minutes per game', mpg.toStringAsFixed(1)),
              _kvHighlight(context, 'Efficiency rating', eff.toStringAsFixed(1)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'SHOOTING PERCENTAGES',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShootRing(
                label: '2 Points',
                pct: sd('two_pct'),
                made: si('two_made'),
                att: si('two_attempted'),
              ),
              _ShootRing(
                label: '3 Points',
                pct: sd('three_pct'),
                made: si('three_made'),
                att: si('three_attempted'),
              ),
              _ShootRing(
                label: 'Free throws',
                pct: sd('ft_pct'),
                made: si('ft_made'),
                att: si('ft_attempted'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'POINTS',
          child: Column(
            children: [
              _kv('Points per game', ppg.toStringAsFixed(1)),
              _kv('2 points', '${twoMPg.toStringAsFixed(2)} (${ti('two_m')})'),
              _kv('3 points', '${tpmPg.toStringAsFixed(1)} (${ti('tpm')})'),
              _kv('Free throws', '${ftmPg.toStringAsFixed(2)} (${ti('ftm')})'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'REBOUNDS',
          child: Column(
            children: [
              _kv('Rebounds per game', '${rpg.toStringAsFixed(2)} (${ti('reb')})'),
              _kv(
                'Defensive rebounds',
                '${gp > 0 ? (ti('dreb') / gp).toStringAsFixed(2) : '0.00'} (${ti('dreb')})',
              ),
              _kv(
                'Offensive rebounds',
                '${gp > 0 ? (ti('oreb') / gp).toStringAsFixed(2) : '0.00'} (${ti('oreb')})',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'OTHERS',
          child: Column(
            children: [
              _kv('Assists per game', apg.toStringAsFixed(1)),
              _kv('Steals per game', spg.toStringAsFixed(1)),
              _kv('Blocks per game', bpg.toStringAsFixed(1)),
              _kv('Turnovers per game', d('tov_pg').toStringAsFixed(1)),
              _kv('Fouls per game', d('pf_pg').toStringAsFixed(1)),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          v,
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

Widget _kvHighlight(BuildContext context, String k, String v) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? cs.primaryContainer 
                : Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            v,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? cs.onPrimaryContainer 
                  : Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
              letterSpacing: 0.8,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _SummaryStripCard extends StatelessWidget {
  const _SummaryStripCard({
    required this.teamName,
    required this.logoUrl,
    required this.pts,
    required this.reb,
    required this.ast,
    required this.stl,
    required this.blk,
  });

  final String teamName;
  final String? logoUrl;
  final double pts;
  final double reb;
  final double ast;
  final double stl;
  final double blk;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final u = logoUrl?.trim();
    Widget mini(String label, double v) {
      return Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              v.toStringAsFixed(v >= 10 ? 0 : 1),
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: u != null && u.isNotEmpty
                    ? Image.network(u, fit: BoxFit.contain)
                    : const Icon(Icons.shield_outlined, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              mini('PTS', pts),
              mini('REB', reb),
              mini('AST', ast),
              mini('STL', stl),
              mini('BLK', blk),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShootRing extends StatelessWidget {
  const _ShootRing({
    required this.label,
    required this.pct,
    required this.made,
    required this.att,
  });

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
            painter: _RingPainter(
              progress: p,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.primary
                  : _headerBlue,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

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
    final sweep = 2 * 3.1415926535 * progress;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -3.1415926535 / 2, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _GameLogTabBody extends StatelessWidget {
  const _GameLogTabBody({
    required this.competitionId,
    required this.playerId,
    required this.gamesApi,
  });

  final int competitionId;
  final int playerId;
  final GamesApiService gamesApi;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: gamesApi.fetchPlayerCompetitionStats(
        competitionId: competitionId,
        playerId: playerId,
      ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final data = snap.data ?? const <String, dynamic>{};
        final raw = data['games'];
        final games = raw is List
            ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];
        if (games.isEmpty) {
          return Center(
            child: Text(
              'No games in this competition yet',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        final scheme = Theme.of(context).colorScheme;
        return ColoredBox(
          color: scheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 5, child: Text('TEAM', style: _tableHead.copyWith(color: scheme.onSurfaceVariant))),
                    SizedBox(
                      width: _gameLogStatColW,
                      child: Text('MIN', textAlign: TextAlign.center, style: _tableHead.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    SizedBox(
                      width: _gameLogStatColW,
                      child: Text('PTS', textAlign: TextAlign.center, style: _tableHead.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    SizedBox(
                      width: _gameLogStatColW,
                      child: Text('REB', textAlign: TextAlign.center, style: _tableHead.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    SizedBox(
                      width: _gameLogStatColW,
                      child: Text('AST', textAlign: TextAlign.center, style: _tableHead.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    const SizedBox(width: _gameLogTrailingW),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: games.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
                  itemBuilder: (context, i) => _GameLogRow(g: games[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _tableHead = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.4,
);

/// Same widths as [GameBoxscoreScreen] player row (`_CompactStatValue` = 40).
const double _gameLogStatColW = 40;
const double _gameLogTrailingW = 36;

class _GameLogRow extends StatefulWidget {
  const _GameLogRow({required this.g});

  final Map<String, dynamic> g;

  @override
  State<_GameLogRow> createState() => _GameLogRowState();
}

class _GameLogRowState extends State<_GameLogRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = widget.g;
    final name = (g['opponent_team_name'] as String?)?.trim() ?? '—';
    final logo = (g['opponent_team_logo'] as String?)?.trim();
    final stats = parseBoxscoreStatTotals(g['stats']);
    final mins = boxscoreMinutesDisplay(stats);
    final pts = boxscoreStatValue(stats, 'Pts');
    final reb = boxscoreStatValue(stats, 'REB');
    final ast = boxscoreStatValue(stats, 'AST');

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        onExpansionChanged: (value) => setState(() => _expanded = value),
        tilePadding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
              flex: 5,
              child: Row(
                children: [
                  _TinyLogo(url: logo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _GameLogStatCell(value: mins),
            _GameLogStatCell(value: pts),
            _GameLogStatCell(value: reb),
            _GameLogStatCell(value: ast),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: BoxscoreExpandedStatPanel(scheme: scheme, stats: stats),
          ),
        ],
      ),
    );
  }
}

class _GameLogStatCell extends StatelessWidget {
  const _GameLogStatCell({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _gameLogStatColW,
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

class _TinyLogo extends StatelessWidget {
  const _TinyLogo({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: u != null && u.isNotEmpty
          ? Image.network(u, fit: BoxFit.contain)
          : Icon(Icons.sports_basketball, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
    );
  }
}

String _exactPositionLabel(String position) {
  final raw = position.trim().toUpperCase();
  if (raw.isEmpty) return 'Position TBD';
  if (raw.contains('GUARD') && raw.contains('POINT')) return 'Point Guard';
  if (raw.contains('GUARD') && raw.contains('SHOOT')) return 'Shooting Guard';
  if (raw.contains('FORWARD') && raw.contains('SMALL')) return 'Small Forward';
  if (raw.contains('FORWARD') && raw.contains('POWER')) return 'Power Forward';
  if (raw.contains('CENTER') && !raw.contains('FORWARD')) return 'Center';
  if (raw.contains('POINT')) return 'Point Guard';
  if (raw.contains('SHOOTING')) return 'Shooting Guard';
  if (raw.contains('SMALL')) return 'Small Forward';
  if (raw.contains('POWER')) return 'Power Forward';
  return position.trim().isEmpty ? 'Position TBD' : position.trim();
}

String _positionAbbrev(String position) {
  final raw = position.trim().toUpperCase();
  if (raw.contains('POINT')) return 'PG';
  if (raw.contains('SHOOTING')) return 'SG';
  if (raw.contains('SMALL')) return 'SF';
  if (raw.contains('POWER')) return 'PF';
  if (raw.contains('CENTER')) return 'C';
  if (raw.contains('GUARD')) return 'G';
  if (raw.contains('FORWARD')) return 'F';
  final t = position.trim();
  if (t.length <= 3) return t.toUpperCase();
  return t.substring(0, 2).toUpperCase();
}
