import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/competition_selector_bar.dart';
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
  final Set<int> _reminderIndices = {};
  AnimationController? _pulseController;

  final List<Map<String, dynamic>> _liveGamesData = [
    {
      'isLive': true,
      'status': '4TH QUARTER - 2:14',
      'team1Code': 'SAG',
      'team2Code': 'RIY',
      'score1': '88',
      'score2': '82',
      'team1Img':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBeZhnyferj-0miau0a5BOEYCYhBmM9gCvWP3yHRNpv4Si_AcCoU0lwRW7hLmOevY0Eh_o5C2SjXiuZvB-mthKA1pjq9xWSFS7cc-Qk7IRAVpNjhnm8PG6w7_3tNwh-Sl5nKXeT6JZdltRtBsTJdE833AYv6oHj0RJhhPUYrEiv4cSC8cDKGT9t-2suTaGZPXApcZGC_rmuEmMD48AsRckdOW45rdhqvUzdyGx8EwRW4Xg3vUUy8JbsAzpgZRhSectMoKG739zI0JXd',
      'team2Img':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDUecrR3vIHtF6cEprw8zD9yiavYsEputoDcXvW3aymeq9zxNr7N0gT0JNnvYlTq1w8kL6dO0-TzUcscfOF7sXBqdH2uahMaTqx84a5W9wWDePp05ovXdizqswItr1LO4fnIzU92PTvfl1RZA3Rz9bfWDtVHnG0bepiIscjUd3ccJ9Gvs4iNDt8b4tZ8ZyHPMrUNS4hcKA_88kMNPJFI7HZt3FiEjpITO3u3jPfaBjtgJmf24irUBo2Uwu_vtZAPX0v39Ea3AY9c47u',
    },
    {
      'isLive': false,
      'status': 'HALF TIME',
      'badgeText': 'LBL CUP',
      'team1Code': 'BEI',
      'team2Code': 'ANT',
      'score1': '45',
      'score2': '41',
      'team1Img':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCERcE_itviUqsRb4ZzCp7yfhuHNph9wsobGv6kVpsuTtUd8qvqgDt7ee0bVFYpPTIF1KTSC3l0r0_bmMo-TbnQZjfsDjHDo1SvjHmwfxZGfkPqe_vzpfe9Go3xoOrbw_vRLsU5aINidXAWHGxnOYn2B4wTrJO0qe0qX_Op9RAyg56oNfYWPypXOp0TKVFSZbS4sFFJmtOpxJWY0Cds1ZGdi8Vq-PU1xuXM5oMZ6yQh5s2S02bsVs9uOMaoEiGGx-blUeVpOkk1QxdK',
      'team2Img':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBlopqXV-bzBWo8tkLEFGT2CZdR__srY_xmWXCunT3IVHmXrNeeGF66Ghre_S4hAdoKumBCvt089Vt3ZpUKmRqGV_7YwONWaNevJ3dFOX_q7w68D9zLyRVM3kneOmRbWV4K7MVqMFKCkPOrQp5MukJgPZVmYF1JNpLDw67VgQRe13qUy_uKjHwbyClZ2BNiTq76HxqQXjEMeAFtHQ7MnYe7bomTVAq2s2gCmV7Wkl1H6dczKDPKvaOnyRLlg1MhbDVBZPGKQZBUTG7P',
    },
  ];

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

  @override
  void dispose() {
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
          padding: const EdgeInsets.only(top: kToolbarHeight, bottom: 128),
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

    if (_liveGamesData.isEmpty) {
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
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _liveGamesData.length,
            itemBuilder: (context, index) {
              final game = _liveGamesData[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildLiveGameCard(
                  context: context,
                  isLive: game['isLive'],
                  status: game['status'],
                  badgeText: game['badgeText'],
                  team1Code: game['team1Code'],
                  team2Code: game['team2Code'],
                  score1: game['score1'],
                  score2: game['score2'],
                  team1Img: game['team1Img'],
                  team2Img: game['team2Img'],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLiveGameCard({
    required BuildContext context,
    required bool isLive,
    required String status,
    String? badgeText,
    required String team1Code,
    required String team2Code,
    required String score1,
    required String score2,
    required String team1Img,
    required String team2Img,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isLive
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainerHigh;
    final textColor = colorScheme.onSurface;
    final statusColor = colorScheme.onSurface.withAlpha(179);
    final vsColor = colorScheme.primary;

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Entering Live Game Center for $team1Code vs $team2Code...',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colorScheme.primary,
          ),
        );
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withAlpha(13),
          ), // border-white/5
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: statusColor,
                  ),
                ),
                if (isLive)
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
                  )
                else if (badgeText != null)
                  Text(
                    badgeText.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.secondary,
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
        SizedBox(
          height: 260,
          child: ListView.separated(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 4),
            scrollDirection: Axis.horizontal,
            itemCount: 2,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final isFirst = index == 0;
              return _buildTicketCard(
                context: context,
                index: index,
                date: isFirst
                    ? 'FRIDAY, OCT 27 • 20:30'
                    : 'SATURDAY, OCT 28 • 17:00',
                venue: isFirst ? 'MANARA ARENA' : 'NOUHAD NAWFAL',
                team1Code: isFirst ? 'CHA' : 'HOM',
                team2Code: isFirst ? 'HOO' : 'MAR',
                team1Img: isFirst
                    ? 'https://lh3.googleusercontent.com/aida-public/AB6AXuCC8faf2GNMciTs72ELic_OLq0juj6BuREhykpM_PhNjZdj8BOq5ejI53lPu86sGeG0Zl4FIPJ5jAIdgbWVyDMh5uLNm_T5K8ug3RRCiy70m6eGLoBjSSjEi7d6Znw4-VB4HhssfQhCodN2sHX2h-sJ_680_-AyR9F5eLzPpogREB6TRGZ895X3yU6FElkIkyTqisjzIfgLLoNIt2BP4aiQrdATFsFOEXeaTkB8DLhalYxVTtYIx82GVRuOfeMLlI0CVfOh5TEuLDvO'
                    : 'https://lh3.googleusercontent.com/aida-public/AB6AXuCbmKctCxM-iMB-fPCQtRfUVsgKTy8Ao-TsaNvTzu4aRoZkVQs7T6_eU9P1u_w6HpJNnxDSHDwKkUhU4yNDz-7_CjK4uDm1sE5p-GfmTEktewnoMf2apJSjbVVq_RJ56tos1fyBeKGObnxzuU-iHk7uoz4e7aKYhCb_pDsCU2by78McdFSfr8T9Sdrt__hVWOSKtuI2L7TubBz6_s-DLb7ST3PkxPd947xUmWPiNaPOLvWagB0IwalNRYBBDa6QIp3cSVcsfJxwWuue',
                team2Img: isFirst
                    ? 'https://lh3.googleusercontent.com/aida-public/AB6AXuAVD8YnSRXkJBW1AJgFJWKBzxHNxNfcNoYlZhR7lX4guB8PnpXpubsq6Y6KjY_GAI5xhmvaZqGtWTCjOapNzD143ubCZKNwfAFrsV7Xaai99-eP8Gxh2j81AKLi94DOesbbUx5mozmMmDy7P81KURtyAamRiZNZddnr-rVJ2FV5-M9z9FoOMGEfUeP-lb2R5X7sj3k4Up6wnyOvjcqwz3EoCliG7nmYryeuykSJtD7YbrdLC45tBh1nhzjUNavqox8OBfGqauF8s0LG'
                    : 'https://lh3.googleusercontent.com/aida-public/AB6AXuBaJQ43dOwdhnO4oj_FKLk16rShhynZcT3KNNu6S-ayVpZ9enBInG2Nx2FrJdv4SaJ_8zhE06woLaXhKb0j_G6IDmhSA4jeDjno4LDVpUxL32MyVnf1UrjiEerl3CUOQC13K6J2ZSbKZGYNQIxx0JkgyAuMTLKckVq51U3FEDOX-Equ8-Oie4MBWFtKPqB8pkk0XbrIMBRpQeZ_L5c3j7B9oKdtePGBo4oSW8ysWi_oxIObk8fgatYhNy7jzGZpU97g1NovRYOFoR08',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard({
    required BuildContext context,
    required int index,
    required String date,
    required String venue,
    required String team1Code,
    required String team2Code,
    required String team1Img,
    required String team2Img,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReminded = _reminderIndices.contains(index);

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
                        _reminderIndices.remove(index);
                      } else {
                        _reminderIndices.add(index);
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
