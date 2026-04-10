import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'court_booking_screen.dart';
import 'ticket_selection_screen.dart';

class TeamProfileScreen extends StatelessWidget {
  const TeamProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 24, bottom: 96), // pt-16 pb-24
        child: Column(
          children: [
            _buildHero(context),
            Transform.translate(
              offset: const Offset(0, -32), // -mt-8
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildBentoStats(context),
              ),
            ),
            const SizedBox(height: 32), // 64 original mt-16 minus 32 from translate
            _buildActiveRoster(context),
            const SizedBox(height: 64), // mt-16
            _buildUpcomingMatch(context),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 353, // h-[353px]
          width: double.infinity,
          color: AppColors.inverseSurface, // Base color
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: 0.4, // absolute inset-0 opacity-40
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBFM6UaZ4BYrn98mmU9GsvvqyMjV2lXadgyAg_w6kNhIWz6qAcuR-EOKKKUHsbaKPqGA6z061oGfQX0WeG7CUSNU90xgSyOobta-zBWC4ct1O2Z3dpTnlpW0OxVna4G-e7QLVv_L5Z5wXSWcNKz8VVlx7y5D7XQoyyggOaVQJ8flF-Ss76NhDqENw4uYi4uiV8f4qA5nsJGMsKzQA7fq93EqzLLC-qB_8qfCiVVRx6SX0A7jWkmlK-qOTMg9dmsltWbFjTGovjn53di',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.inverseSurface, Colors.transparent], // bg-gradient-to-t from-inverse-surface via-transparent to-transparent
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
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 48), // container mx-auto px-6 pb-12
          alignment: Alignment.bottomLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Transform.rotate(
                angle: -3 * 3.14159 / 180, // -rotate-3
                child: Container(
                  width: 128, // w-32
                  height: 128, // h-32
                  padding: const EdgeInsets.all(16), // p-4
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha((255 * 0.25).round()), blurRadius: 25, offset: const Offset(0, 10)) // shadow-2xl equivalent
                    ],
                  ),
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDJna9D3GFVp-RWSAph8qKdMkfr-dtof9y-XzDbJsQnaLVAKtI_fzWmVH6YPYGBbF5qkuRJaGH1DU0DHeqj-Tf4Hdi1rljY8Jcgy7AN4_6FUUYI430A9gZ_9HXFkskykzYir9xr86Y8DujZpYWnhISiRa_dAYj9q_CaZRS6gwKgkc3z7mdnbUM1EWbyimtO2LvexPzGidHRxLz7ywQI21yjRiz9bpHM8OW6q0i_2Ht0zYwAq_JGX3bT6APa6vMK_mldvYxjO4YyKLZm',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 24), // gap-6
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2 py-0.5
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4), // rounded-sm
                      ),
                      child: const Text(
                        'LEBANESE BASKETBALL LEAGUE',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0), // tracking-widest
                      ),
                    ),
                    const SizedBox(height: 8), // mb-2 context mapped
                    const Text(
                      'AL RIYADI',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 48, // text-5xl
                        fontWeight: FontWeight.w900, // font-black
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        letterSpacing: -2.0, // tracking-tighter
                        height: 1.0, // leading-none
                      ),
                    ),
                    const SizedBox(height: 8), // mt-2
                    const Text(
                      'Beirut, Lebanon',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 20, // text-xl
                        fontWeight: FontWeight.w500, // font-medium
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryFixedDim,
                        letterSpacing: -0.5, // tracking-tight
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
            const SizedBox(width: 16), // gap-4
            Expanded(child: _buildStatBox(label: 'RPG', value: '42.8', sub: 'Ranked #1 in League', borderColor: AppColors.secondary, subColor: AppColors.secondary)),
          ],
        ),
        const SizedBox(height: 16), // gap-4
        Row(
          children: [
            Expanded(child: _buildStatBox(label: 'APG', value: '21.5', sub: 'Best in postseason', borderColor: AppColors.primary, subColor: AppColors.primary)),
            const SizedBox(width: 16), // gap-4
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24), // p-6
                decoration: BoxDecoration(
                  color: AppColors.inverseSurface,
                  borderRadius: BorderRadius.circular(12), // rounded-xl
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 2, offset: const Offset(0, 1))], // shadow-sm
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('RECORD', style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.surfaceVariant, letterSpacing: 1.0)), // text-xs font-bold uppercase tracking-widest
                    const SizedBox(height: 4), // mt-1
                    const Text('18-2', style: TextStyle(fontFamily: 'Lexend', fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)), // text-3xl font-black mt-1
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(5, (index) => Align(
                        widthFactor: 0.75, // flex -space-x-2 overlap map
                        child: Container(
                          width: 24, // w-6
                          height: 24, // h-6
                          decoration: BoxDecoration(
                            color: Colors.green.shade500, // bg-green-500
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.inverseSurface, width: 2), // border-2 border-inverse-surface
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
      padding: const EdgeInsets.all(24), // p-6
      decoration: BoxDecoration(
        color: Colors.white, // surface-container-lowest
        borderRadius: BorderRadius.circular(12), // rounded-xl
        border: Border(left: BorderSide(color: borderColor, width: 4)), // border-l-4
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 2, offset: const Offset(0, 1))], // shadow-sm
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: 1.0), // text-xs uppercase tracking-widest
          ),
          const SizedBox(height: 4), // mt-1
          Text(
            value,
            style: const TextStyle(fontFamily: 'Lexend', fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.onSurface, height: 1.0), // text-4xl mt-1
          ),
          const SizedBox(height: 4), // mt-1
          Text(
            sub,
            style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: subColor), // text-[10px] font-bold mt-1
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRoster(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0), // px-6
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
                      fontSize: 30, // text-3xl
                      fontWeight: FontWeight.w900, // font-black
                      fontStyle: FontStyle.italic,
                      color: AppColors.onSurface,
                      letterSpacing: -1.0, // tracking-tighter
                    ),
                  ),
                  const SizedBox(height: 4), // mt-1
                  Container(height: 6, width: 96, color: AppColors.primary), // h-1.5 w-24 bg-primary mt-1
                ],
              ),
              const Row(
                children: [
                  Text(
                    'VIEW FULL STATS',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.0), // text-xs font-bold uppercase tracking-widest
                  ),
                  SizedBox(width: 4), // gap-1
                  Icon(Icons.arrow_forward, size: 14, color: AppColors.primary), // text-sm
                ],
              ),
            ],
          ),
          const SizedBox(height: 32), // mb-8
          Column(
            children: [
              _buildRosterCard(
                num: '25',
                pos: 'GUARD',
                name: 'WAEL ARAKJI',
                h: '1.93m',
                w: '85kg',
                imgUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA9CsSnnkiLv33i_995FPSn2tFa6qEEeYyY4wz2ynG0KXqd6E8Mc-1LBYId4MVLrVQr2dbtCzAWnPWGJPx6sdjvoIoCSeI2GfcD-RbXD_vLbybOiX0LKOiQHdLZNK8INf-hwFNt_YeJ8xXu9NTgHx6CvDgDy9ZEmNCrDweLvJYmBcabYzv0IHG5lfSbpiS5471fLFO0YujN3l5jDMpV_PahKQfTub5chLvY0XNt0WPCtJgbtelEgEqLRwUrwEV94MBjW0tAY_D-LBBt',
                statLabel: 'PPG',
                statValue: '22.4',
              ),
              const SizedBox(height: 32), // gap-8
              _buildRosterCard(
                num: '11',
                pos: 'FORWARD',
                name: 'AMIR SAOUD',
                h: '1.88m',
                w: '80kg',
                imgUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCdYix0vWqUXYK4BG5u-fx3iZjLFuxMnIf1K74psnWHaFKo9klWVr2XKtdFZ3aCUzkkJLJjAp3Qd2m8X_n_phdPx5EsdWodl9B3sKeYELl__b6bmCU-CmF7oSFkz-b4Iq0F9tVl2QMTbh3lJOqZx9Yv9VaPlPS2olTTaK9oAujYOC74ZbNVkmiqR3IwC1h4TrTgvkDdx-bixxT7tRCxuibgo4A36Yi9nnJ34wWqLjqB-4cv-ipF_Asm8mLg20Ng4TrcCG4GXP1dyEq1',
                statLabel: 'PPG',
                statValue: '18.7',
              ),
              const SizedBox(height: 32),
              _buildRosterCard(
                num: '07',
                pos: 'CENTER',
                name: 'ISMAIL AHMED',
                h: '2.05m',
                w: '110kg',
                imgUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA7eaR4n-oyyqYjlw_6m9MbkMpyfAGXF9DszOT1rj73ikkTkVrDYJGAvKntqrh-POsyGoI08zuUHNTu2ro8P_IBSdVNlWhskr8DohhG53X7uCruGKHzL3d34J2uKOVeN0cbn4ayzMaI-o_MFo1yhu1rRo6srF8uJbpQHUy1Yv8shnOsVtvxYyzyOkxYVh9nPMv3sH4KkdjyHvoYZxetP23q-Rh3wv8AT8AqLvE2NCxAOr8XC8IzpOkFdAOm4jyCwZua60JA2FDhgFJf',
                statLabel: 'RPG',
                statValue: '11.2',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRosterCard({required String num, required String pos, required String name, required String h, required String w, required String imgUrl, required String statLabel, required String statValue}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            top: 16, // top-4
            right: 16, // right-4
            child: Text(
              num,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 72, // 7xl
                fontWeight: FontWeight.w900, // font-black
                fontStyle: FontStyle.italic,
                color: Colors.transparent,
                shadows: const [
                  Shadow(offset: Offset(-1, -1), color: Color(0x33BB0013)), // player-number-bg fake stroke
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
                padding: const EdgeInsets.only(top: 32.0, left: 24.0, right: 24.0), // px-6 pt-8
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pos,
                      style: const TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.0), // text-xs font-black tracking-widest
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: const TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.5, height: 1.1), // text-2xl font-extrabold tracking-tight
                    ),
                    const SizedBox(height: 16), // mt-4
                    Row(
                      children: [
                        Text(h, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)), // text-xs font-bold
                        const SizedBox(width: 16), // gap-4
                        Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.outlineVariant, shape: BoxShape.circle)), // w-1 h-1
                        const SizedBox(width: 16),
                        Text(w, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16), // mt-4
              SizedBox(
                height: 256, // h-64
                width: double.infinity,
                child: Stack(
                  children: [
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ]), // grayscale
                      child: Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter, // object-top
                        width: double.infinity,
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.surfaceContainerLow, Colors.transparent], // bg-gradient-to-t
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    // Hidden analytical text exposed statically for app
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            children: [
                              Text(statLabel, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: 1.0)),
                              Text(statValue, style: const TextStyle(fontFamily: 'Lexend', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary, height: 1.0)),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.analytics, color: Colors.white, size: 20),
                          ),
                        ],
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

  Widget _buildUpcomingMatch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0), // px-6
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inverseSurface,
          borderRadius: BorderRadius.circular(16), // rounded-2xl
        ),
        padding: const EdgeInsets.all(32), // p-8
        width: double.infinity,
        child: Column(
          children: [
            const Text(
              'NEXT BATTLE',
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryFixedDim, letterSpacing: 3.0), // tracking-[0.3em] font-black text-[10px]
            ),
            const SizedBox(height: 8), // mt-2
            const Text(
              'THE BEIRUT DERBY',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, fontStyle: FontStyle.italic, height: 1.0), // text-3xl font-black italic mt-2
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4), // mt-1
            const Text(
              'Sagesse vs Al Riyadi • Friday, 20:30',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.surfaceVariant), // font-medium text-surface-variant
            ),
            const SizedBox(height: 32), // gap-8 map
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAtowaD-5NJaSgJmmqdxchrI6jnsvnkquZEQaKdujOgSSR8XYxy4sZV-f_9vSR631FbtjZ4bCjM6Pc9g6ksH6I0zFYdgOTEe7lxSyaRegKAp6pdLOEFWb6tOklm0fx_D79xmH09RbnmtbfwqYbn7bCgU5rCBiCgqd_YDlaQyxrrbZb89C8yx_ywOsd2c4aRnKL0INFJTUD53u0SKdKfJeWIzMQLihsSilwAWg99owpRz1vnv0f3tD7Xzcg55G_tXQ20rMlcZv6jQHRi',
                  width: 64, // w-16
                  height: 64, // h-16
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 32), // gap-8 map
                const Text(
                  'VS',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white54, fontStyle: FontStyle.italic), // text-white opacity-50 font-black text-4xl
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
              width: double.infinity, // stretch button block width
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), // px-8 py-4 mapped precisely
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // rounded-xl
                  elevation: 0,
                ),
                child: const Text(
                  'GET TICKETS',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0), // font-black tracking-widest
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
