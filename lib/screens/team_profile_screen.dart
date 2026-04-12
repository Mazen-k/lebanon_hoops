import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/players_api_service.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'ticket_selection_screen.dart';

class TeamProfileScreen extends StatefulWidget {
  const TeamProfileScreen({super.key});

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  final _service = PlayersApiService();
  TeamWithPlayers? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Team ID 1 = Riyadi (only team in database)
      final data = await _service.fetchTeamWithPlayers(1);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.secondary),
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.secondary), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final team = _data!.team;
    final players = _data!.players;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 96),
          child: Column(
            children: [
              _buildHero(context, team),
              Transform.translate(
                offset: const Offset(0, -32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildBentoStats(context),
                ),
              ),
              const SizedBox(height: 32),
              _buildActiveRoster(context, players),
              const SizedBox(height: 64),
              _buildUpcomingMatch(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, Team team) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 353,
          width: double.infinity,
          color: AppColors.inverseSurface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: 0.4,
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBFM6UaZ4BYrn98mmU9GsvvqyMjV2lXadgyAg_w6kNhIWz6qAcuR-EOKKKUHsbaKPqGA6z061oGfQX0WeG7CUSNU90xgSyOobta-zBWC4ct1O2Z3dpTnlpW0OxVna4G-e7QLVv_L5Z5wXSWcNKz8VVlx7y5D7XQoyyggOaVQJ8flF-Ss76NhDqENw4uYi4uiV8f4qA5nsJGMsKzQA7fq93EqzLLC-qB_8qfCiVVRx6SX0A7jWkmlK-qOTMg9dmsltWbFjTGovjn53di',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.inverseSurface, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.0, 0.4],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 353,
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 48),
          alignment: Alignment.bottomLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Transform.rotate(
                angle: -3 * 3.14159 / 180,
                child: Container(
                  width: 128,
                  height: 128,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha((255 * 0.25).round()), blurRadius: 25, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDJna9D3GFVp-RWSAph8qKdMkfr-dtof9y-XzDbJsQnaLVAKtI_fzWmVH6YPYGBbF5qkuRJaGH1DU0DHeqj-Tf4Hdi1rljY8Jcgy7AN4_6FUUYI430A9gZ_9HXFkskykzYir9xr86Y8DujZpYWnhISiRa_dAYj9q_CaZRS6gwKgkc3z7mdnbUM1EWbyimtO2LvexPzGidHRxLz7ywQI21yjRiz9bpHM8OW6q0i_2Ht0zYwAq_JGX3bT6APa6vMK_mldvYxjO4YyKLZm',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LEBANESE BASKETBALL LEAGUE',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      team.teamName.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        letterSpacing: -2.0,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Beirut, Lebanon',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryFixedDim,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBentoStats(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatBox(label: 'PPG', value: '94.2', sub: '↑ 2.4 vs last season', borderColor: AppColors.primary, subColor: AppColors.primary)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatBox(label: 'RPG', value: '42.8', sub: 'Ranked #1 in League', borderColor: AppColors.secondary, subColor: AppColors.secondary)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatBox(label: 'APG', value: '21.5', sub: 'Best in postseason', borderColor: AppColors.primary, subColor: AppColors.primary)),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.inverseSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 2, offset: const Offset(0, 1))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('RECORD', style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.surfaceVariant, letterSpacing: 1.0)),
                    const SizedBox(height: 4),
                    const Text('18-2', style: TextStyle(fontFamily: 'Lexend', fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(5, (index) => Align(
                        widthFactor: 0.75,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.green.shade500,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.inverseSurface, width: 2),
                          ),
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox({required String label, required String value, required String sub, required Color borderColor, required Color subColor}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontFamily: 'Lexend', fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.onSurface, height: 1.0)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: subColor)),
        ],
      ),
    );
  }

  Widget _buildActiveRoster(BuildContext context, List<Player> players) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACTIVE ROSTER',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: AppColors.onSurface,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(height: 6, width: 96, color: AppColors.primary),
                ],
              ),
              const Row(
                children: [
                  Text('VIEW FULL STATS', style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.0)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (players.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No players found', style: TextStyle(color: AppColors.secondary)),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < players.length; i++) ...[
                  if (i > 0) const SizedBox(height: 32),
                  _buildRosterCard(player: players[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRosterCard({required Player player}) {
    final posLabel = _positionLabel(player.position);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            top: 16,
            right: 16,
            child: Text(
              '#${player.jerseyNumber}',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 72,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.transparent,
                shadows: const [
                  Shadow(offset: Offset(-1, -1), color: Color(0x33BB0013)),
                  Shadow(offset: Offset(1, -1), color: Color(0x33BB0013)),
                  Shadow(offset: Offset(1, 1), color: Color(0x33BB0013)),
                  Shadow(offset: Offset(-1, 1), color: Color(0x33BB0013)),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 32.0, left: 24.0, right: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      posLabel,
                      style: const TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player.fullName.toUpperCase(),
                      style: const TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.5, height: 1.1),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          player.nationality.isNotEmpty ? player.nationality : 'Lebanese',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                        const SizedBox(width: 16),
                        Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.outlineVariant, shape: BoxShape.circle)),
                        const SizedBox(width: 16),
                        Text(
                          '#${player.jerseyNumber}',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 80,
                width: double.infinity,
                color: AppColors.surfaceContainerHighest,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.analytics, color: Colors.white, size: 20),
                      ),
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

  String _positionLabel(String pos) {
    switch (pos.toUpperCase()) {
      case 'PG': return 'POINT GUARD';
      case 'SG': return 'SHOOTING GUARD';
      case 'SF': return 'SMALL FORWARD';
      case 'PF': return 'POWER FORWARD';
      case 'C': return 'CENTER';
      default: return pos.toUpperCase().isNotEmpty ? pos.toUpperCase() : 'PLAYER';
    }
  }

  Widget _buildUpcomingMatch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inverseSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        child: Column(
          children: [
            const Text(
              'NEXT BATTLE',
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryFixedDim, letterSpacing: 3.0),
            ),
            const SizedBox(height: 8),
            const Text(
              'THE BEIRUT DERBY',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, fontStyle: FontStyle.italic, height: 1.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Sagesse vs Al Riyadi • Friday, 20:30',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.surfaceVariant),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAtowaD-5NJaSgJmmqdxchrI6jnsvnkquZEQaKdujOgSSR8XYxy4sZV-f_9vSR631FbtjZ4bCjM6Pc9g6ksH6I0zFYdgOTEe7lxSyaRegKAp6pdLOEFWb6tOklm0fx_D79xmH09RbnmtbfwqYbn7bCgU5rCBiCgqd_YDlaQyxrrbZb89C8yx_ywOsd2c4aRnKL0INFJTUD53u0SKdKfJeWIzMQLihsSilwAWg99owpRz1vnv0f3tD7Xzcg55G_tXQ20rMlcZv6jQHRi',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 32),
                const Text(
                  'VS',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white54, fontStyle: FontStyle.italic),
                ),
                const SizedBox(width: 32),
                Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBku3xZnMiES2-G5KUeCAPog3jqLPfKO1x8EjDnG0AxJ9g3Sicv3cyb7e-Z5Bg4pDnpJO8X_DjIae8xpLrCk7en-AZsY2d5hUiERvHYPk9-1W6KnNV1WXFSw2q_OAwJCI4ZAGwlJkLSxr_1_4n5Y0E5uC6Lnfo8CN39-cdbyWjoGfyW53y3QwHy6PHcq2IOYlv3TH7n-BLUtm7lvIKCxdYU-vD-KkBVtqSvyG2_9ULUji-E1Z2Vig_pPyPAMAohKKvzdUjHKQtB0lKh',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TicketSelectionScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'GET TICKETS',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
