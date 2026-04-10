import 'package:flutter/material.dart';
import '../theme/colors.dart';

class FantasyScreen extends StatelessWidget {
  const FantasyScreen({super.key});

  // ── Mock Data ─────────────────────────────────────────────
  static const List<Map<String, dynamic>> _players = [
    {'name': 'Wael Arakji', 'team': 'Al Riyadi Beirut', 'pos': 'Starting G', 'jersey': '23', 'fpts': '34.2', 'stats': {'PTS': '22', 'AST': '8', 'REB': '4'}, 'isPrimary': true},
    {'name': 'Ali Haidar', 'team': 'Sagesse SC', 'pos': 'Starting F', 'jersey': '11', 'fpts': '28.5', 'stats': {'PTS': '18', 'AST': '2', 'REB': '11'}, 'isPrimary': false},
    {'name': 'Ater Majok', 'team': 'Dynamo Lebanon', 'pos': 'Starting C', 'jersey': '07', 'fpts': '41.8', 'stats': {'PTS': '14', 'BLK': '5', 'REB': '15'}, 'isPrimary': false},
  ];

  static const List<Map<String, String>> _standings = [
    {'rank': '01', 'team': 'Baabda Bears', 'wl': '10-2', 'pts': '1645'},
    {'rank': '02', 'team': 'Cedar Giants', 'wl': '9-3', 'pts': '1592'},
    {'rank': '03', 'team': 'Byblos Kings', 'wl': '8-4', 'pts': '1550'},
    {'rank': '04', 'team': 'Beirut Bolts', 'wl': '7-5', 'pts': '1488'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 128, left: 16, right: 16), // px-4 py-8
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroMatchup(),
              const SizedBox(height: 24), // gap-6

              // ── My Active Lineup ────────────────────────
              _buildSectionHeader('My Active Lineup', 'Gameday Live'),
              const SizedBox(height: 24), // gap-6
              ..._players.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 16), // gap-4
                child: _buildPlayerCard(p),
              )),
              _buildDraftCard(),
              const SizedBox(height: 24), // gap-6

              // ── Trade Center Banner ─────────────────────
              _buildTradeBanner(),
              const SizedBox(height: 24), // gap-6

              // ── League Standings ────────────────────────
              _buildLeagueStandings(),
              const SizedBox(height: 24), // gap-6

              // ── Injury Alert ────────────────────────────
              _buildInjuryAlert(),
              const SizedBox(height: 24), // gap-6

              // ── Recent Transactions ─────────────────────
              _buildRecentTransactions(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero Section: Matchup of the Week ─────────────────────
  Widget _buildHeroMatchup() {
    return Container(
      padding: const EdgeInsets.all(32), // p-8
      decoration: BoxDecoration(
        color: AppColors.inverseSurface,
        borderRadius: BorderRadius.circular(12), // rounded-xl
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha((255 * 0.25).round()), blurRadius: 25, offset: const Offset(0, 10)), // shadow-2xl
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-3 py-1
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8), // rounded-lg
            ),
            child: const Text(
              'Matchup of the Week',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0), // text-[10px] uppercase tracking-widest
            ),
          ),
          const SizedBox(height: 16), // mb-4

          // Title
          RichText(
            text: const TextSpan(
              style: TextStyle(fontFamily: 'Lexend', fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0), // text-4xl font-black leading-none
              children: [
                TextSpan(text: 'CEDAR GIANTS '),
                TextSpan(text: 'VS', style: TextStyle(color: AppColors.primary, fontStyle: FontStyle.italic)),
                TextSpan(text: ' BEIRUT BOLTS'),
              ],
            ),
          ),
          const SizedBox(height: 24), // mb-6

          // Scores
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Score',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey.shade500, letterSpacing: -0.5), // text-xs text-slate-400 tracking-tighter
                  ),
                  const Text(
                    '142.5',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white), // text-4xl font-black
                  ),
                ],
              ),
              const SizedBox(width: 24), // gap-6
              Container(height: 48, width: 1, color: Colors.grey.shade700), // h-12 w-px bg-slate-700
              const SizedBox(width: 24), // gap-6
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Opponent',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey.shade500, letterSpacing: -0.5), // text-xs text-slate-400
                  ),
                  Text(
                    '128.2',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 36, fontWeight: FontWeight.w900, color: Colors.grey.shade500), // text-4xl font-black text-slate-400
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.signatureGradient,
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                    boxShadow: [BoxShadow(color: AppColors.primary.withAlpha((255 * 0.3).round()), blurRadius: 15, offset: const Offset(0, 4))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24), // py-4 px-6
                        child: Center(
                          child: Text(
                            'EDIT LINEUP',
                            style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0), // font-bold uppercase tracking-wide
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16), // gap-4
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B), // bg-slate-800
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                    border: Border.all(color: const Color(0xFF334155)), // border border-slate-700
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24), // py-4 px-6
                        child: Center(
                          child: Text(
                            'TRADE PLAYERS',
                            style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0), // font-bold uppercase tracking-wide
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────
  Widget _buildSectionHeader(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: AppColors.onSurface, letterSpacing: -1.0), // text-2xl font-extrabold italic tracking-tighter
        ),
        Text(
          trailing,
          style: const TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary), // text-sm font-bold text-primary uppercase
        ),
      ],
    );
  }

  // ── Player Card ───────────────────────────────────────────
  Widget _buildPlayerCard(Map<String, dynamic> player) {
    final bool isPrimary = player['isPrimary'] as bool;
    final Map<String, String> stats = Map<String, String>.from(player['stats'] as Map);

    return Container(
      padding: const EdgeInsets.all(16), // p-4
      decoration: BoxDecoration(
        color: Colors.white, // bg-surface-container-lowest
        borderRadius: BorderRadius.circular(12), // rounded-xl
        border: Border(
          bottom: BorderSide(
            color: isPrimary ? AppColors.primary : const Color(0xFFE2E8F0), // border-primary or border-slate-200
            width: 4,
          ),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Jersey number watermark
          Positioned(
            right: -16,
            bottom: -8,
            child: Text(
              player['jersey'] as String,
              style: TextStyle(fontFamily: 'Lexend', fontSize: 80, fontWeight: FontWeight.w900, color: AppColors.onSurface.withAlpha((255 * 0.05).round())), // text-8xl opacity-10
            ),
          ),
          // Main content
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2 py-0.5
                        decoration: BoxDecoration(
                          color: isPrimary ? AppColors.primaryFixed : AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(8), // rounded-lg
                        ),
                        child: Text(
                          player['pos'] as String,
                          style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: isPrimary ? AppColors.primary : AppColors.secondary), // text-xs font-bold uppercase
                        ),
                      ),
                      const SizedBox(height: 8), // mb-2
                      Text(
                        player['name'] as String,
                        style: const TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface, height: 1.1), // text-xl font-bold leading-tight
                      ),
                      Text(
                        player['team'] as String,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500), // text-xs text-slate-500 font-medium
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        player['fpts'] as String,
                        style: const TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.onSurface), // text-2xl font-black
                      ),
                      Text(
                        'FPTS',
                        style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400), // text-[10px] uppercase text-slate-400 font-bold
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16), // mt-4
              Row(
                children: stats.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 16), // gap-4
                  child: Column(
                    children: [
                      Text(
                        e.key,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400), // text-[10px] uppercase text-slate-400 font-bold
                      ),
                      Text(
                        e.value,
                        style: const TextStyle(fontFamily: 'Lexend', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface), // font-headline font-bold
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Draft Utility Player Card ─────────────────────────────
  Widget _buildDraftCard() {
    return Container(
      padding: const EdgeInsets.all(16), // p-4
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // bg-slate-50
        borderRadius: BorderRadius.circular(12), // rounded-xl
        border: Border.all(
          color: const Color(0xFFE2E8F0), // border-slate-200
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 36, color: Colors.grey.shade300), // text-4xl text-slate-300
          const SizedBox(height: 8), // mb-2
          Text(
            'DRAFT UTILITY PLAYER',
            style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade400), // text-sm font-bold uppercase text-slate-400
          ),
        ],
      ),
    );
  }

  // ── Trade Center Banner ───────────────────────────────────
  Widget _buildTradeBanner() {
    return Container(
      padding: const EdgeInsets.all(24), // p-6
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 4, offset: const Offset(0, 1))],
                ),
                child: const Icon(Icons.swap_horiz, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16), // gap-4
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trade Analysis Available',
                      style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface, letterSpacing: -0.5), // font-bold uppercase text-sm tracking-tight
                    ),
                    Text(
                      'Your F Ater Majok has high market value this week.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey.shade500), // text-xs text-slate-500
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onSurface,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24), // px-6 py-2
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // rounded-lg
                elevation: 0,
              ),
              child: const Text(
                'EXPLORE TRADES',
                style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2.0), // text-xs font-bold uppercase tracking-widest
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── League Standings ──────────────────────────────────────
  Widget _buildLeagueStandings() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // rounded-xl
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // px-6 py-4
            color: AppColors.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'League Standings',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: AppColors.onSurface, letterSpacing: -0.5), // font-extrabold italic text-sm tracking-tight
                ),
                Text(
                  'WEEK 12',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500), // text-[10px] font-bold uppercase text-slate-500
                ),
              ],
            ),
          ),
          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // px-4 py-2
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('TEAM', style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400)), // text-[10px] uppercase text-slate-400
                ),
                Expanded(
                  flex: 1,
                  child: Center(child: Text('W-L', style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400))),
                ),
                Expanded(
                  flex: 1,
                  child: Align(alignment: Alignment.centerRight, child: Text('PTS', style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400))),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)), // border-slate-100
          // Table rows
          ...List.generate(_standings.length, (index) {
            final s = _standings[index];
            final isUser = s['rank'] == '02';
            return Container(
              color: isUser ? const Color(0xFFFEF2F2).withAlpha((255 * 0.5).round()) : Colors.transparent, // bg-red-50/50
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // px-4 py-3
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Text(
                          s['rank']!,
                          style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: isUser ? AppColors.primary : Colors.grey.shade300), // font-black text-xs italic
                        ),
                        const SizedBox(width: 12), // gap-3
                        Text(
                          s['team']!,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: isUser ? AppColors.primary : AppColors.onSurface), // font-bold
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(child: Text(s['wl']!, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500))),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(alignment: Alignment.centerRight, child: Text(s['pts']!, style: const TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold))),
                  ),
                ],
              ),
            );
          }),
          // View Full Table button
          Padding(
            padding: const EdgeInsets.all(16), // p-4
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF1F5F9)), // border border-slate-100
                borderRadius: BorderRadius.circular(8), // rounded-lg
              ),
              child: Center(
                child: Text(
                  'VIEW FULL TABLE',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 2.0), // text-[10px] uppercase tracking-widest text-slate-400
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Injury Alert Card ─────────────────────────────────────
  Widget _buildInjuryAlert() {
    return Container(
      padding: const EdgeInsets.all(24), // p-6
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(Icons.medical_services, size: 120, color: Colors.white.withAlpha((255 * 0.1).round())), // opacity-10 text-[120px]
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2 py-0.5
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((255 * 0.2).round()), // bg-white/20
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'INJURY ALERT',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0), // text-[10px] font-bold uppercase tracking-widest
                ),
              ),
              const SizedBox(height: 16), // mb-4
              const Text(
                'OMARI SPELLMAN DOUBTFUL FOR TONIGHT',
                style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white, height: 1.1), // text-xl font-black italic leading-tight
              ),
              const SizedBox(height: 8), // mb-2
              Text(
                'The Sagesse star center is struggling with a calf strain. Immediate swap recommended.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.red.shade100, height: 1.5), // text-xs text-red-100 leading-relaxed
              ),
              const SizedBox(height: 16), // mb-4
              Row(
                children: const [
                  Text(
                    'Read Report',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), // text-xs font-bold uppercase
                  ),
                  SizedBox(width: 4), // gap-1
                  Icon(Icons.arrow_forward, size: 16, color: Colors.white), // text-sm
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Recent Transactions ───────────────────────────────────
  Widget _buildRecentTransactions() {
    return Container(
      padding: const EdgeInsets.all(24), // p-6
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT TRANSACTIONS',
            style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 2.0), // text-xs font-bold uppercase tracking-widest text-slate-500
          ),
          const SizedBox(height: 16), // mb-4
          _buildTransactionRow(Colors.green, 'Added S. El Darwich', '2h ago'),
          const SizedBox(height: 16), // space-y-4
          _buildTransactionRow(Colors.red, 'Dropped J. Arledge', '2h ago'),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(Color dotColor, String text, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12), // gap-3
            Text(
              text,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface), // text-xs font-bold
            ),
          ],
        ),
        Text(
          time,
          style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.grey.shade400), // text-[10px] text-slate-400
        ),
      ],
    );
  }
}
