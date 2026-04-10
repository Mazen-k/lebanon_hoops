import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class StandingsScreen extends StatelessWidget {
  const StandingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 24, bottom: 128, left: 16, right: 16), // pt-20 pb-32 px-4
        child: Column(
          children: [
            _buildHeroTitle(context),
            _buildTabToggle(context),
            const SizedBox(height: 24), // spacing logic applied
            _buildPodiumColumn(context),
            const SizedBox(height: 32), // gap between left and right column on mobile
            _buildTableColumn(context),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHeroTitle(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 32, bottom: 48), // mt-8 mb-12
      padding: const EdgeInsets.all(32), // p-8
      decoration: BoxDecoration(
        color: AppColors.inverseSurface,
        borderRadius: BorderRadius.circular(12), // rounded-xl
        boxShadow: [
          BoxShadow(color: AppColors.onBackground.withAlpha((255 * 0.06).round()), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: -2)
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: -48, // -right-12
            bottom: -48, // -bottom-12
            child: Icon(
              Icons.leaderboard,
              size: 240, // text-[240px]
              color: Colors.white.withAlpha((255 * 0.1).round()), // opacity-10
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2023-2024 SEASON',
                style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryFixedDim, letterSpacing: 2.0), // text-xs uppercase
              ),
              const SizedBox(height: 8), // mb-2
              const Text(
                'LEAGUE\nSTANDINGS',
                style: TextStyle(fontFamily: 'Lexend', fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, fontStyle: FontStyle.italic, letterSpacing: -2.0, height: 1.0), // text-5xl tracking-tighter uppercase leading-none
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabToggle(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32), // mb-8
      padding: const EdgeInsets.all(6), // p-1.5
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12), // rounded-xl
        border: Border.all(color: AppColors.outlineVariant.withAlpha((255 * 0.1).round())), // border border-outline-variant/10
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), // py-3 px-6
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8), // rounded-lg
                boxShadow: [
                  BoxShadow(color: AppColors.onBackground.withAlpha((255 * 0.06).round()), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: -2)
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'REGULAR SEASON',
                style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5), // tracking-tight uppercase
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              alignment: Alignment.center,
              child: const Text(
                'PLAYOFFS',
                style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: -0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, color: AppColors.primary), // border-l-4 border-primary
            const SizedBox(width: 12), // pl-3
            const Text(
              'THE PODIUM',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onSurface, fontStyle: FontStyle.italic, letterSpacing: -0.5), // text-xl uppercase tracking-tight
            ),
          ],
        ),
        const SizedBox(height: 24), // space-y-6

        // Rank 1
        Container(
          padding: const EdgeInsets.all(24), // p-6
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight), // from-primary to-primary-container
            borderRadius: BorderRadius.circular(12), // rounded-xl
            boxShadow: [BoxShadow(color: AppColors.onBackground.withAlpha((255 * 0.06).round()), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: -2)], // athletic-shadow
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned(
                top: -8, // top-2 approximate mapping
                right: -8, // right-4
                child: Text(
                  '01',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 96, fontWeight: FontWeight.w900, color: Colors.white.withAlpha((255 * 0.2).round()), fontStyle: FontStyle.italic, height: 1.0), // text-8xl opacity-20
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80, // w-20
                        height: 80, // h-20
                        padding: const EdgeInsets.all(8), // p-2
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))], // shadow-lg
                        ),
                        child: Image.network('https://lh3.googleusercontent.com/aida-public/AB6AXuBqtaW_6xXQ2WaoLAE-6BvIhxt8llzNIMHsxZOWkYWq7y6kOpyKfxPAj3_Px11Azqwy4jQCgH7VEwTuKQwL1iq-Bk7lqoYczr64FR12VqOBOkQI2WE3ttktQFeHfyQnehy1Zh_eBAn6-l6E4mKlr47QcJphUFIF2qtoTKhSHPGPhNp2EupKw34Zj36-M2gu6fCScA1bSAWDD1JV6jF5MHcThvh3tNa0hYB7s3Huvtwv38xujIHGCvybrGZgwsHdoW4bOcub4wT9C107', fit: BoxFit.contain), // w-16 h-16
                      ),
                      const SizedBox(width: 16), // gap-4 leading to next element
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BEIRUT DISTRICT', style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withAlpha((255 * 0.8).round()), letterSpacing: 1.0)), // text-xs uppercase tracking-widest opacity-80
                          const Text('AL RIYADI', style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.0)), // text-2xl uppercase tracking-tighter
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // mb-4 mapped to gap
                  Container(
                    padding: const EdgeInsets.only(top: 16), // pt-4
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withAlpha((255 * 0.2).round())))), // border-t border-white/20
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('W-L RECORD', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withAlpha((255 * 0.7).round()))), // text-[10px] opacity-70
                            const Text('18 - 2', style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), // text-2xl
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WIN STREAK', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withAlpha((255 * 0.7).round()))),
                            const Text('W9', style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(width: 16), // to match grid equivalent space
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16), // gap-4
        // Rank 2
        _buildSmallPodiumCard('02', 'Sagesse SC', '16 - 4', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDWXm1GMkoj_R2jpehkVHCsLyISNDXoRufrfbr5l1ZbXU2r02FUY-YD4R5ovnMmkrBOpNcihrN0l2X9qr124JZRvmVEoQZSaNDVtYRduoobjv1uWE20f2-oIRV-G18xYFAp10I9dUVwDHnJWSThLWMQg_0S7F8BWyI99Y8O_xWk4EM0O2YWFSc5AW3NqmB-JICDZRrXPTAn7hMRTJaUE8d7MdrFACxCoyjKv444kksWmmWjPjUeBT7m76cICMUjWUeomiKG2SpFjjMW'),
        const SizedBox(height: 16), // gap-4
        // Rank 3
        _buildSmallPodiumCard('03', 'Beirut Club', '15 - 5', 'https://lh3.googleusercontent.com/aida-public/AB6AXuCakcX6Wf38zN8LR7LVNiQb8wdaZYtk1a8YMl3_7dKG8YK45ssTGg1HEhDDuAwCEpV1JVZTU9gKR53gDlcfpUsTbH27tqx2zJfBMCMj6PsutPg-GTdYIDmKYOUeuWs4KGVtfr33R2i-apWgZxYRX5SWhCrLGjyupYvxPMmnLE2nL0Ea8VfZ4pwfFoaAVin46lf70IEvc6rbX5XMjfs8mOF5XZsXiBSXgGNzc8vj8PFMFA2QFJzYV6MS2lSIoNmPUv9rr5EZi22qOLAg'),
      ],
    );
  }

  Widget _buildSmallPodiumCard(String rank, String name, String record, String imgUrl) {
    return Container(
      padding: const EdgeInsets.all(16), // p-4
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12), // rounded-xl
        boxShadow: [BoxShadow(color: AppColors.onBackground.withAlpha((255 * 0.06).round()), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: -2)], // athletic-shadow
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(rank, style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: AppColors.secondary.withAlpha((255 * 0.4).round()))), // text-2xl
              const SizedBox(width: 16), // gap-4
              Container(
                width: 48, // w-12
                height: 48, // h-12
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.contain), // w-12 rounded-full
                ),
              ),
              const SizedBox(width: 16), // gap-4
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface, height: 1.1)), // text-sm uppercase leading-tight
                  const SizedBox(height: 2),
                  Text(record, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)), // text-xs 
                ],
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildTableColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 4, height: 24, color: AppColors.primary),
                const SizedBox(width: 12),
                const Text(
                  'LEAGUE TABLE',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onSurface, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                ),
              ],
            ),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green.shade500, shape: BoxShape.circle)), // w-2 h-2
                const SizedBox(width: 4), // gap-1
                const Text('PLAYOFFS', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(width: 8), // gap-2 between items
                Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)), // w-2 slate-300
                const SizedBox(width: 4),
                const Text('OUT', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24), // mb-6
        Container(
          decoration: BoxDecoration(
            color: Colors.white, // surface-container-lowest
            borderRadius: BorderRadius.circular(16), // rounded-2xl
            boxShadow: [BoxShadow(color: AppColors.onBackground.withAlpha((255 * 0.06).round()), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: -2)], // athletic-shadow
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // px-6 py-4
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withAlpha((255 * 0.1).round()))),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 24, child: Text('RK', style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.secondary, letterSpacing: 1.0))),
                    Expanded(child: Text('TEAM', style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.secondary, letterSpacing: 1.0))),
                    SizedBox(width: 32, child: Text('W', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.secondary, letterSpacing: 1.0))),
                    SizedBox(width: 32, child: Text('L', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.secondary, letterSpacing: 1.0))),
                    SizedBox(width: 40, child: Text('PCT', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.secondary, letterSpacing: 1.0))),
                  ],
                ),
              ),
              // Normal rows
              _buildTableRow('04', 'Champville', '14', '6', '.700', 'https://lh3.googleusercontent.com/aida-public/AB6AXuC5vRL-pdp9uXOVPoQHZB0s1fASlSdK-v8-n2xbzhlSHaKZATeBf-LlsplALO-tWHdgcTec9qTQM8I3yh7tSjt1X-dV-EG7BvnvGTLHjZBCOqDDCqN7mbsHznFzWkni8mUZhDxN4pHYFGd9hPuMyCbCnGs8ZTfI_7sdzS9A0yAVbH_mTSbdF9O-2p3TrHfk0k_8hWbNNWB5Drxz2zJilmK8001mf9U_-ultC1m2wk_R5SN6MHsJrXB2QkqN4X0_pTHx4SA3gY_T568F', false, false),
              _buildTableRow('05', 'Homenetmen', '12', '8', '.600', 'https://lh3.googleusercontent.com/aida-public/AB6AXuCqVYQMdXspny20oMIbwAZQcdWz6Wy1BrvUIGbw2wkIxwNpijTNqIwlitBJcsgd1KEiykNnlv7d2khPjDLA6aWRumQ85iOm2nUnQ39SDbtQ-tEWSvB0Fk0zqWqh72THqPJ6J3DxLK8n2NmLyp-VS0r6ye_T5a0VnAeMfdeZ7pjsGSyXldVP0mE7fcbnGJku6XSsmQalRlnFXripzlGGHaQUtRqAyk39b-UTLSOrEPn_KCCYtal2VltbInnvbQ3uYbYwS1gtu7dYp2sO', false, false),
              _buildTableRow('06', 'Antranik', '11', '9', '.550', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDGKQwXs4sKj0d6sYkXLyVzrlxjbbWf4da365hbPoSvaY-08gMs4IPFgVz2gvfs_EBj-7gcrVifRg9gvWDrl_nfcBmLkrrsITUlCQvP2CpcnNAaIYK4fsTxUkPw1-dVuZ-GXeUdMDVeZDY4zx3bM1MRYHqFhtF_zuxY_i8-ChCRAlTXx4AbTX-B-C1Ri6XSXISz09rqy4Hy5Ok579fYjaa2eW3M6-unAXfJ_aRqXGCLKsnA0cDvk6nOjukJ-xI0yaSjBvKzIua-Z8Vo', true, false), // cutoff border
              _buildTableRow('07', 'Antonine', '10', '10', '.500', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDo3u-No1pOYqjlzQqxsF6ROINcr6zG3wd8d1vzXUX-tEurMhwvjrsdIEvSYgD3B09Db-KfYZnY77rbTs8DubFQYKd0kxANGn5LArOjALO8yW2lTCfavVQtYqjf0PWWcarkrWckpz-gWEmU8aQLtZfSL-buv4BoZnLiX60IKZ7_tqGim52QmObQ17UAqLaNVw6wqVhkO7dn4wwjcaEa-35jeUVcrZ-UHr0A2dYbXvNw_nlofGzCSwqanLfXrSBhgdKLhtfDzj76ODjw', false, false),
              _buildTableRow('08', 'NSA', '8', '12', '.400', 'https://lh3.googleusercontent.com/aida-public/AB6AXuCUNPEhRFsh_HKU_O9NQDPsgNyyCTKdMRBMkR42GkqfXwKzOB_j48uVHD7JdduY2z8WQdBZZOdEADUYglzU_6XMvKts3-mbFrwmhggTmFpBHPumVKB0hIdclVn9uSyJasjm31L-JKcR60CqdAFH_6-VyqMKMPTBFzlUcJSzYkvc_tDx-kyrjl2W9TxU2jhSVDOmauqr1XqnWpo9oZSt_tV05i7PaspKJYWQlptEmvXPWUwpvYkg8b-sgYrujowFDtlZyIobMWSP2944', false, false),
              
              // Cutoff Line
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // px-6 py-2
                color: AppColors.surfaceContainerLow,
                alignment: Alignment.center,
                child: Text('LOWER BRACKET', style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.secondary.withAlpha((255 * 0.4).round()), letterSpacing: 3.0)), // text-[9px]
              ),

              // Faded rows
              _buildTableRow('09', 'Atlas', '7', '13', '.350', 'https://lh3.googleusercontent.com/aida-public/AB6AXuCMUm33l8ctv4wgYDKBMYplDSAK_1UpwS3qDOE65TQNVxKddQD5IpSvMLy5iDxJEdrxsH_b4vaCu-w4ff94lFX0H2_249j0-_zT6npntGecCP2vGu3GWQcdn0glThZVfC53uVhdC1MCv8T7vNfmFfV7dznThmpfnSw0TGqRCy-zZI_3D9P13TRyt3RBHOh0LC8LEA9EAqDQhJSKnIK5AZSj2ByAVuiQCwJ3bsS33nokZR8yMCndho3h21V3bw8r7ad_bEnphBNqSqkP', false, true),
              _buildTableRow('10', 'Mayrouba', '5', '15', '.250', 'https://lh3.googleusercontent.com/aida-public/AB6AXuACAcpVTyJlZVLH9L1kDUD2kByn4hqbxrd-oRkvkIFcpP_QcvRiHZe1qI6qH6uZVh6b9mlS5m4TWRt7VM5IMfE_HSQAGlvRkLplWxxsSkdaBtUmej3TzWhk4DlhWGNzcertszmA-x64qB8i_Md5t8IMFPin-JDx9nUYfLFxseVSWRBOfavXxOCsvEeGj_Gz9RW8FrVC2e5yWFPvQ11dp5RcR5rNIov40nnT3YTbADSCCrSh2XEcpWMK7lC73jhsxTa50uuYf4S9I8cr', false, true),
              _buildTableRow('11', 'Byblos', '3', '17', '.150', 'https://lh3.googleusercontent.com/aida-public/AB6AXuD25JWA65osQdZcKunbuTOr0fJlF9fFaUN2fsGYTOHSdz0QFLPrGP7l-VteYx7h7V2YUBAKFtEWmnjpcSZwaes0P6E78ZsDDuLwJzm1dt635uWu1qGCkrkb43t03aZ5BtnCmem3_GI6v89C9-BEBEfiT7P2scQqHAo-supjfk_I2qU4jsi8vxrNrrePCc1I4036XNaVjPwXdbrhZA72rFhzDJ-Q4zQDWLKyIz2Ww_3O2OjgTvYQYfq7jI0nqiEPYkFGaArxAEyqaIXD', false, true),
              _buildTableRow('12', 'Hoops Club', '2', '18', '.100', 'https://lh3.googleusercontent.com/aida-public/AB6AXuAa3remVXe1HWgOsplfpktuzu3IR1CTWkMR6lsdbHiNdR8S1gDmoFAygyw6eDv0Iv3W74OujLYRwKJ-m4EngxyODMdn0x9hQGv-VKgpKz87Bzqp6CE6kwxGZtk5bGkmZyZJFQ8sfHouar7MvmLvW-7PRgNIwwc6CDfrLuBNHR1HQUqbXCGg2CCtL_3jwBWa5J40RSB24iFaQKzBvsnjuhdNv3JHt54SGXUdyCrqUzmRIdN378SpKyGL_Ct7FRWKqrPed4aZARdL2CJ1', false, true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(String rk, String team, String w, String l, String pct, String imgUrl, bool isCutoff, bool isFaded) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerLow), // divide-y divide-surface-container-low
          left: isCutoff ? BorderSide(color: Colors.green.shade500, width: 4) : BorderSide.none, // border-l-4 border-green-500
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), // px-6 py-5
      child: Opacity(
        opacity: isFaded ? 0.6 : 1.0, // opacity-60
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(rk, style: const TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: AppColors.secondary)), // col-span-1
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 40, // w-10
                    height: 40, // h-10
                    padding: const EdgeInsets.all(6), // p-1.5
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8), // rounded-lg
                    ),
                    child: Image.network(imgUrl, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 16), // gap-4
                  Text(team, style: const TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.5)), // text-sm tracking-tight
                ],
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(w, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
            ),
            SizedBox(
              width: 32,
              child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
            ),
            SizedBox(
              width: 40,
              child: Text(pct, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.onSurface)), // text-xs font-black
            ),
          ],
        ),
      ),
    );
  }
}
