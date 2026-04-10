import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'ticket_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 128), // pt-4 pb-32
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: AppColors.primary, size: 28),
                      onPressed: () {},
                      splashRadius: 24,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildLiveGamesSection(context),
              const SizedBox(height: 32), // mb-8 (4*8) mapped to 32
              _buildBreakingNewsSection(context),
              const SizedBox(height: 40), // mb-10
              _buildUpcomingBattlesSection(context),
              const SizedBox(height: 40), // mb-10
              _buildTopPerformersSection(context),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketSelectionScreen())),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: const CircleBorder(),
        elevation: 8, // shadow-lg
        child: const Icon(Icons.confirmation_number),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
            ),
            padding: const EdgeInsets.only(left: 12), // pl-3 (3*4)
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 24, // text-2xl
                fontWeight: FontWeight.w800, // font-extrabold
                fontStyle: FontStyle.italic,
                letterSpacing: -1.0, // tracking-tighter
                height: 1.0, // tighten vertically relative to native
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildLiveGamesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'LIVE LBL GAMES',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // px-2 py-1
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha((255 * 0.1).round()), // bg-primary/10
              borderRadius: BorderRadius.circular(16), // rounded-full (pill)
            ),
            child: Row(
              children: [
                Container(
                  width: 8, // w-2
                  height: 8, // h-2
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4), // gap-1
                const Text(
                  'LIVE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12, // text-xs
                    fontWeight: FontWeight.bold, // font-bold
                    color: AppColors.primary, // text-primary
                    letterSpacing: 0.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16), // mb-4
        SizedBox(
          height: 156, // Accurate height block
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24), // px-6
            children: [
              _buildLiveGameCard(
                context: context,
                isLive: true,
                status: '4TH QUARTER - 2:14',
                team1Code: 'SAG',
                team2Code: 'RIY',
                score1: '88',
                score2: '82',
                team1Img: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBeZhnyferj-0miau0a5BOEYCYhBmM9gCvWP3yHRNpv4Si_AcCoU0lwRW7hLmOevY0Eh_o5C2SjXiuZvB-mthKA1pjq9xWSFS7cc-Qk7IRAVpNjhnm8PG6w7_3tNwh-Sl5nKXeT6JZdltRtBsTJdE833AYv6oHj0RJhhPUYrEiv4cSC8cDKGT9t-2suTaGZPXApcZGC_rmuEmMD48AsRckdOW45rdhqvUzdyGx8EwRW4Xg3vUUy8JbsAzpgZRhSectMoKG739zI0JXd',
                team2Img: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDUecrR3vIHtF6cEprw8zD9yiavYsEputoDcXvW3aymeq9zxNr7N0gT0JNnvYlTq1w8kL6dO0-TzUcscfOF7sXBqdH2uahMaTqx84a5W9wWDePp05ovXdizqswItr1LO4fnIzU92PTvfl1RZA3Rz9bfWDtVHnG0bepiIscjUd3ccJ9Gvs4iNDt8b4tZ8ZyHPMrUNS4hcKA_88kMNPJFI7HZt3FiEjpITO3u3jPfaBjtgJmf24irUBo2Uwu_vtZAPX0v39Ea3AY9c47u',
              ),
              const SizedBox(width: 16), // gap-4
              _buildLiveGameCard(
                context: context,
                isLive: false,
                status: 'HALF TIME',
                badgeText: 'LBL CUP',
                team1Code: 'BEI',
                team2Code: 'ANT',
                score1: '45',
                score2: '41',
                team1Img: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCERcE_itviUqsRb4ZzCp7yfhuHNph9wsobGv6kVpsuTtUd8qvqgDt7ee0bVFYpPTIF1KTSC3l0r0_bmMo-TbnQZjfsDjHDo1SvjHmwfxZGfkPqe_vzpfe9Go3xoOrbw_vRLsU5aINidXAWHGxnOYn2B4wTrJO0qe0qX_Op9RAyg56oNfYWPypXOp0TKVFSZbS4sFFJmtOpxJWY0Cds1ZGdi8Vq-PU1xuXM5oMZ6yQh5s2S02bsVs9uOMaoEiGGx-blUeVpOkk1QxdK',
                team2Img: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBlopqXV-bzBWo8tkLEFGT2CZdR__srY_xmWXCunT3IVHmXrNeeGF66Ghre_S4hAdoKumBCvt089Vt3ZpUKmRqGV_7YwONWaNevJ3dFOX_q7w68D9zLyRVM3kneOmRbWV4K7MVqMFKCkPOrQp5MukJgPZVmYF1JNpLDw67VgQRe13qUy_uKjHwbyClZ2BNiTq76HxqQXjEMeAFtHQ7MnYe7bomTVAq2s2gCmV7Wkl1H6dczKDPKvaOnyRLlg1MhbDVBZPGKQZBUTG7P',
              ),
            ],
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
    final bgColor = isLive ? AppColors.inverseSurface : AppColors.surfaceContainerHighest;
    final textColor = isLive ? AppColors.inverseOnSurface : AppColors.onSurface;
    final statusColor = isLive ? AppColors.inverseOnSurface.withAlpha((255 * 0.7).round()) : AppColors.onSurface.withAlpha((255 * 0.7).round()); // opacity-70
    final vsColor = isLive ? AppColors.primary : const Color(0xFFCBD5E1); // slate-300

    return Container(
      width: 280, // min-w-[280px]
      padding: const EdgeInsets.all(20), // p-5
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12), // rounded-xl
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
                  fontSize: 10, // text-[10px]
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0, // tracking-widest (10% of 10px approx 1.0)
                  color: statusColor,
                ),
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2 py-0.5
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4), // rounded
                  ),
                  child: const Text(
                    'Live',
                    style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 12, fontWeight: FontWeight.normal), // mapped approx
                  ),
                )
              else if (badgeText != null)
                Text(
                  badgeText,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10, // text-[10px] inside badge context
                    fontWeight: FontWeight.bold, // font-bold
                    color: AppColors.secondary, // text-secondary
                    letterSpacing: 0.0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16), // gap-4 
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
                      fontSize: 30, // text-3xl
                      fontWeight: FontWeight.w900, // font-black
                      color: textColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 16), // gap-4 inside score
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
    );
  }

  Widget _buildTeamColumn(BuildContext context, String code, Color textColor, String imgUrl) {
    return Column(
      children: [
        Container(
          width: 48, // w-12
          height: 48, // h-12
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 4, offset: const Offset(0, 1)) // shadow-sm
            ],
          ),
          padding: const EdgeInsets.all(8), // p-2
          child: Image.network(imgUrl, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.shield, color: AppColors.secondary, size: 24)),
        ),
        const SizedBox(height: 8), // gap-2
        Text(
          code,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 12, // text-xs
            fontWeight: FontWeight.bold, // font-bold
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakingNewsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0), // px-6
      child: Container(
        height: 400, // h-[400px]
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.onBackground, // bg-on-background
          borderRadius: BorderRadius.circular(16), // rounded-2xl
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Opacity(
              opacity: 0.7, // absolute inset-0 opacity-70
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuCU9MgtLh0Evk_CTs2FKxcCqiKBY4O_K8gyorHPiIje40vJG4ahm-7hnAS-iD9PMyiOtskELCm26E6hoKHsdPxG9uT6rxR7AstGOvL-LEYxzUwU8oUTGAiaXS7fK7ctoHfZ6fEK4IaXaDZjBm7Gbqlusy8pb6V14LFC26b1zE5Q3GjT0wWd0uxE4ufojHPT2ZRP6a8Vd_pxPkzWDwIFWuxRtG-8H4Jyny6cxx-WFSrE2AF9ttSSkejN-V7YZjxQY-XWvtlkRxshMEK-',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.black45, Colors.transparent], // bg-gradient-to-t from-black via-black/40 to-transparent
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32), // p-8
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-3 py-1
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4), // rounded
                    ),
                    child: const Text(
                      'BREAKING NEWS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white, 
                        fontSize: 10, // text-[10px]
                        fontWeight: FontWeight.w900, // font-black
                        letterSpacing: 1.0, // tracking-widest
                      ),
                    ),
                  ),
                  const SizedBox(height: 12), // gap-3 equivalent
                  const Text(
                    'WAEL ARAKJI LEADS RIYADI TO THRILLING OVERTIME VICTORY',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 30, // text-3xl
                      color: Colors.white,
                      fontWeight: FontWeight.w900, // font-black
                      fontStyle: FontStyle.italic,
                      height: 1.0, // leading-none
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The Lebanese point guard dropped 34 points in a historic performance at the Saeb Salam Arena tonight.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14, // text-sm
                      color: Colors.white70, // text-white/80 equivalent mapped
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12), // mt-2 approx
                  Row(
                    children: [
                      Container(width: 32, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))), // w-8 h-1
                      const SizedBox(width: 8), // gap-2
                      Container(width: 8, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))), // w-2 h-1
                      const SizedBox(width: 8),
                      Container(width: 8, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBattlesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'UPCOMING BATTLES',
          trailing: const Text(
            'VIEW SCHEDULE',
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.primary,
              fontSize: 12, // text-xs
              fontWeight: FontWeight.bold, // font-bold
              letterSpacing: -0.5, // tracking-tighter hover:underline effect mapped via standard flutter TextDecoration
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16), // mb-4
        SizedBox(
          height: 250, // Height bound manually, aligns well 
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24), // px-6
            scrollDirection: Axis.horizontal,
            itemCount: 2,
            separatorBuilder: (context, index) => const SizedBox(width: 16), // gap-4
            itemBuilder: (context, index) {
              final isFirst = index == 0;
              return _buildTicketCard(
                context: context,
                date: isFirst ? 'FRIDAY, OCT 27 • 20:30' : 'SATURDAY, OCT 28 • 17:00',
                venue: isFirst ? 'MANARA ARENA' : 'NOUHAD NAWFAL',
                team1Code: isFirst ? 'CHA' : 'HOM',
                team2Code: isFirst ? 'HOO' : 'MAR',
                team1Img: isFirst ? 'https://lh3.googleusercontent.com/aida-public/AB6AXuCC8faf2GNMciTs72ELic_OLq0juj6BuREhykpM_PhNjZdj8BOq5ejI53lPu86sGeG0Zl4FIPJ5jAIdgbWVyDMh5uLNm_T5K8ug3RRCiy70m6eGLoBjSSjEi7d6Znw4-VB4HhssfQhCodN2sHX2h-sJ_680_-AyR9F5eLzPpogREB6TRGZ895X3yU6FElkIkyTqisjzIfgLLoNIt2BP4aiQrdATFsFOEXeaTkB8DLhalYxVTtYIx82GVRuOfeMLlI0CVfOh5TEuLDvO' : 'https://lh3.googleusercontent.com/aida-public/AB6AXuCbmKctCxM-iMB-fPCQtRfUVsgKTy8Ao-TsaNvTzu4aRoZkVQs7T6_eU9P1u_w6HpJNnxDSHDwKkUhU4yNDz-7_CjK4uDm1sE5p-GfmTEktewnoMf2apJSjbVVq_RJ56tos1fyBeKGObnxzuU-iHk7uoz4e7aKYhCb_pDsCU2by78McdFSfr8T9Sdrt__hVWOSKtuI2L7TubBz6_s-DLb7ST3PkxPd947xUmWPiNaPOLvWagB0IwalNRYBBDa6QIp3cSVcsfJxwWuue',
                team2Img: isFirst ? 'https://lh3.googleusercontent.com/aida-public/AB6AXuAVD8YnSRXkJBW1AJgFJWKBzxHNxNfcNoYlZhR7lX4guB8PnpXpubsq6Y6KjY_GAI5xhmvaZqGtWTCjOapNzD143ubCZKNwfAFrsV7Xaai99-eP8Gxh2j81AKLi94DOesbbUx5mozmMmDy7P81KURtyAamRiZNZddnr-rVJ2FV5-M9z9FoOMGEfUeP-lb2R5X7sj3k4Up6wnyOvjcqwz3EoCliG7nmYryeuykSJtD7YbrdLC45tBh1nhzjUNavqox8OBfGqauF8s0LG' : 'https://lh3.googleusercontent.com/aida-public/AB6AXuBaJQ43dOwdhnO4oj_FKLk16rShhynZcT3KNNu6S-ayVpZ9enBInG2Nx2FrJdv4SaJ_8zhE06woLaXhKb0j_G6IDmhSA4jeDjno4LDVpUxL32MyVnf1UrjiEerl3CUOQC13K6J2ZSbKZGYNQIxx0JkgyAuMTLKckVq51U3FEDOX-Equ8-Oie4MBWFtKPqB8pkk0XbrIMBRpQeZ_L5c3j7B9oKdtePGBo4oSW8ysWi_oxIObk8fgatYhNy7jzGZpU97g1NovRYOFoR08',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard({
    required BuildContext context,
    required String date,
    required String venue,
    required String team1Code,
    required String team2Code,
    required String team1Img,
    required String team2Img,
  }) {
    return Container(
      width: 300, // min-w-[300px]
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // rounded-xl
        border: Border.all(color: const Color(0xFFF1F5F9)), // border-slate-100
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 2, offset: const Offset(0, 1)) // shadow-sm
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), // p-4
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.white)), // border-b border-white
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.secondary), // text-[10px] font-black uppercase
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2 py-0.5
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4), // rounded
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 2, offset: const Offset(0, 1))], // shadow-sm
                  ),
                  child: Text(
                    venue,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
               padding: const EdgeInsets.all(24), // p-6
               child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // justify-around approx native map
                children: [
                  _buildTicketTeam(context, team1Code, team1Img),
                  const Text(
                    'VS',
                    style: TextStyle(
                      fontFamily: 'Lexend', // mapped to brand specific italic
                      fontSize: 20, // text-xl
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900, // font-black
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  _buildTicketTeam(context, team2Code, team2Img),
                ],
              ),
            ),
          ),
          Material(
            color: AppColors.primary,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketSelectionScreen())),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16), // py-4
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.confirmation_number, color: Colors.white, size: 14), // text-sm icon size approx 14
                    SizedBox(width: 8), // gap-2
                    Text(
                      'BUY TICKETS',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 14, // text-sm
                        color: Colors.white,
                        fontWeight: FontWeight.bold, // font-bold
                        letterSpacing: 1.0, // tracking-widest
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56, // w-14
          height: 56, // h-14
          decoration: const BoxDecoration(
            color: AppColors.surface, // bg-surface
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(8), // p-2
          margin: const EdgeInsets.only(bottom: 8), // mb-2
          child: Image.network(imgUrl, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.shield, color: AppColors.secondary, size: 28)),
        ),
        Text(
          code,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 14, // text-sm
            fontWeight: FontWeight.w800, // font-extrabold
          ),
        ),
      ],
    );
  }

  Widget _buildTopPerformersSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0), // px-6
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'TOP PERFORMERS'),
          const SizedBox(height: 24), // mb-6
          // Main performer
          Container(
            height: 224, // h-56
            width: double.infinity,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16), // rounded-2xl
              gradient: const LinearGradient(
                colors: [AppColors.surfaceContainerLow, AppColors.surfaceContainerHighest],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 1), // border-white
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -16, // -mr-4
                  bottom: -40, // -mb-10
                  child: Text(
                    '23',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 120, // text-[120px]
                      fontWeight: FontWeight.w900, // font-black
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary.withAlpha((255 * 0.05).round()), // text-primary/5
                      height: 1.0,
                    ),
                  ),
                ),
                Positioned(
                  right: -20, // right-[-20px]
                  top: 0,
                  bottom: 0,
                  width: 180, // w-1/2 approx bounds
                  child: Opacity(
                    opacity: 0.9,
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDIzsjzrOvYPWBDZsnhO7BpxSHRAC90apP10GjUVN1_Mkbt7YR5RjeENChGJ1AdDwL7Qzs0lqnHX7gvrxV5ERKZj6sXSG0zdKhNbP1GuUHxGWGTInKmMm1hG3txybGHc3Qw3cnrfsTnMNaNjf_08KiF2HWdLMTvXpzGch-yhVPA373AbEZr3F9qJwFz2NAIXOEbPwCwa5AFC3uuWr9KRMrH_tkNJXF9AFo7iyCSYSOspDHYFClQsA0YqTCkDHHLAoaoh-QSDLzPEun2',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerLeft, // object-left
                      errorBuilder: (c,e,s) => const Icon(Icons.person, size: 100, color: AppColors.secondary),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0), // p-6
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PLAYER OF THE WEEK',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12, // text-xs
                              color: AppColors.primary, // text-primary
                              fontWeight: FontWeight.w900, // font-black
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1.0, // tracking-widest
                            ),
                          ),
                          const SizedBox(height: 4), // mt-1
                          const Text(
                            'SERGIO\nEL DARWICH',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 24, // text-2xl
                              fontWeight: FontWeight.w900, // font-black
                              color: AppColors.onSurface,
                              height: 1.0, // leading-none
                            ),
                          ),
                          const SizedBox(height: 4), // mt-1
                          const Text(
                            'BEIRUT CLUB • GUARD',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildStat('PTS', '28.4', false),
                          const SizedBox(width: 16), // gap-4 
                          _buildStat('AST', '6.2', true),
                          const SizedBox(width: 16), // gap-4
                          _buildStat('REB', '5.8', true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16), // gap-4 from grid
          Row(
            children: [
              Expanded(child: _buildSecondaryPerformer('Omari Spellman', 'Rebounds Leader', '14.3', 'RPG', 'https://lh3.googleusercontent.com/aida-public/AB6AXuBGkL957XYsrycUmC-N_7vejj9y4jFXS9pXb74WJSNyMW3VSm8GRtIse6uSng_hWepCONIh80CLfQE54WmUDJ-_nbnKegpHBlHkv_t9RByTCG0FGC4vxfx89SRQdPNOYmeOg-RlVZDi5IbOZkFeGNFroj4-N1vxLwu0l_GCXNb80Dw69Ubmt2r25UTt7-rMtlYvdLbFRLo_HjXuz6BE2Rnz-oXEbkrp7Rni_6fQI0SCpIkIoz3IOncehQ71xlZr8KDqn4uLTFk-zD2p')),
              const SizedBox(width: 16), // gap-4
              Expanded(child: _buildSecondaryPerformer('Ali Mezher', 'Assists Leader', '8.9', 'APG', 'https://lh3.googleusercontent.com/aida-public/AB6AXuCRr_ol2LJioV3KhfH-1HZc3hw7nBKIaEptbKc9l3bFSLHsTKRZtCmwxNBLhiII57FBTReMI_V9HeJjha7rXZ-PZxcbFZki6ddl5RFSiSROTkUHrCeuRvDDuCOjIQ4AgmzJR1qieUQX7xBz-SJUXRS0otz35g90wggZU4UmaBMKe427lP3qMe7QkSkYlGnZvXi8lnXKkkUFS1IVkop7yKYKdmvsWRohaVOVzvKJmGfR_WBETAeOv5PQEjJhfF6y5vpt7EQg6S__9k35')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, bool borderLeft) {
    return Container(
      padding: EdgeInsets.only(left: borderLeft ? 16 : 0), // pl-4 (16px) left only based on HTML
      decoration: BoxDecoration(
        border: borderLeft ? const Border(left: BorderSide(color: Color(0xFFCBD5E1))) : null, // border-slate-300
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary)), // text-[10px] uppercase
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'Lexend', height: 1.0), // text-xl font-black
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryPerformer(String name, String sublabel, String stat, String statLabel, String imgUrl) {
    return Container(
      padding: const EdgeInsets.all(20), // p-5
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(color: const Color(0xFFF1F5F9)), // border-slate-100
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 2, offset: const Offset(0, 1)) // shadow-sm
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
                width: 40, // w-10
                height: 40, // h-10
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9), // bg-slate-100
                  shape: BoxShape.circle,
                ),
                child: Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.person, color: AppColors.secondary)),
              ),
              const Text('#1', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)), // text-lg font-black
            ],
          ),
          const SizedBox(height: 12), // gap-3
          Text(
            name,
            style: const TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w800), // text-xs font-extrabold uppercase
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.secondary), // text-[10px] font-medium
          ),
          const SizedBox(height: 12), // map gap inside card layout flow
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stat,
                style: const TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, height: 1.0), // text-2xl font-black
              ),
              const SizedBox(width: 4), // gap-1
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0), // pb-1 scale approx
                child: Text(
                  statLabel,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold), // text-[10px] uppercase font-bold
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
