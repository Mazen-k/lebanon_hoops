import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../data/team_repository.dart';
import '../models/team.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final _teamsRepo = const TeamRepository();
  List<Team> _teams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await _teamsRepo.fetchTeams();
      if (mounted) setState(() { _teams = teams; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
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
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 128, left: 16, right: 16),
          child: Column(
            children: [
              _buildHeroTitle(context),
              _buildTabToggle(context),
              const SizedBox(height: 24),
              _buildPodiumColumn(context, _teams.isNotEmpty ? _teams.first.teamName : 'AL RIYADI'),
              const SizedBox(height: 32),
              _buildTableColumn(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroTitle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(13)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            bottom: -40,
            child: Icon(
              Icons.leaderboard,
              size: 260,
              color: colorScheme.primary.withAlpha(20),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '2023-2024 SEASON',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'LEAGUE\nSTANDINGS',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.5,
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Track the road to the playoffs as the top 12 teams battle for supremacy.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.white.withAlpha(179),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabToggle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 32), // mb-8
      padding: const EdgeInsets.all(6), // p-1.5
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12), // rounded-xl
        border: Border.all(color: colorScheme.outlineVariant.withAlpha((255 * 0.1).round())), // border border-outline-variant/10
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), // py-3 px-6
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8), // rounded-lg
                boxShadow: [
                  BoxShadow(color: colorScheme.onSurface.withAlpha((255 * 0.06).round()), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: -2)
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
              child: Text(
                'PLAYOFFS',
                style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.secondary, letterSpacing: -0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(BuildContext context, String teamName) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 24, decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Text(
              'THE PODIUM',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.w900, color: colorScheme.onSurface, fontStyle: FontStyle.italic, letterSpacing: -0.5),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Rank 1
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(13)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned(
                top: -10,
                right: -10,
                child: Text(
                  '01',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 96, fontWeight: FontWeight.w900, color: colorScheme.primary.withAlpha(26), fontStyle: FontStyle.italic, height: 1.0),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(230), // slight translucency
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withAlpha(51)),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Image.network('https://lh3.googleusercontent.com/aida-public/AB6AXuBqtaW_6xXQ2WaoLAE-6BvIhxt8llzNIMHsxZOWkYWq7y6kOpyKfxPAj3_Px11Azqwy4jQCgH7VEwTuKQwL1iq-Bk7lqoYczr64FR12VqOBOkQI2WE3ttktQFeHfyQnehy1Zh_eBAn6-l6E4mKlr47QcJphUFIF2qtoTKhSHPGPhNp2EupKw34Zj36-M2gu6fCScA1bSAWDD1JV6jF5MHcThvh3tNa0hYB7s3Huvtwv38xujIHGCvybrGZgwsHdoW4bOcub4wT9C107', fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BEIRUT DISTRICT', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.primary, letterSpacing: 1.0)),
                          Text(teamName.toUpperCase(), style: const TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.0)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withAlpha(13)))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('W-L RECORD', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                            const Text('18 - 2', style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WIN STREAK', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                            const Text('W9', style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Rank 2
        _buildSmallPodiumCard(context, '02', 'Sagesse SC', '16 - 4', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDWXm1GMkoj_R2jpehkVHCsLyISNDXoRufrfbr5l1ZbXU2r02FUY-YD4R5ovnMmkrBOpNcihrN0l2X9qr124JZRvmVEoQZSaNDVtYRduoobjv1uWE20f2-oIRV-G18xYFAp10I9dUVwDHnJWSThLWMQg_0S7F8BWyI99Y8O_xWk4EM0O2YWFSc5AW3NqmB-JICDZRrXPTAn7hMRTJaUE8d7MdrFACxCoyjKv444kksWmmWjPjUeBT7m76cICMUjWUeomiKG2SpFjjMW'),
        const SizedBox(height: 16),
        // Rank 3
        _buildSmallPodiumCard(context, '03', 'Beirut Club', '15 - 5', 'https://lh3.googleusercontent.com/aida-public/AB6AXuCakcX6Wf38zN8LR7LVNiQb8wdaZYtk1a8YMl3_7dKG8YK45ssTGg1HEhDDuAwCEpV1JVZTU9gKR53gDlcfpUsTbH27tqx2zJfBMCMj6PsutPg-GTdYIDmKYOUeuWs4KGVtfr33R2i-apWgZxYRX5SWhCrLGjyupYvxPMmnLE2nL0Ea8VfZ4pwfFoaAVin46lf70IEvc6rbX5XMjfs8mOF5XZsXiBSXgGNzc8vj8PFMFA2QFJzYV6MS2lSIoNmPUv9rr5EZi22qOLAg'),
      ],
    );
  }

  Widget _buildSmallPodiumCard(BuildContext context, String rank, String name, String record, String imgUrl) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(rank, style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: colorScheme.primary.withAlpha(51))),
              const SizedBox(width: 16),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(51)),
                ),
                padding: const EdgeInsets.all(4),
                child: Image.network(imgUrl, fit: BoxFit.contain),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.toUpperCase(), style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w800, color: colorScheme.onSurface, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text(record, style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                ],
              ),
            ],
          ),
          Icon(Icons.chevron_right, color: colorScheme.secondary, size: 20),
        ],
      ),
    );
  }

  Widget _buildTableColumn(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 4, height: 24, decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Text(
                  'LEAGUE TABLE',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.w900, color: colorScheme.onSurface, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                ),
              ],
            ),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green.shade500, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('PLAYOFFS', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                const SizedBox(width: 8),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.white.withAlpha(51), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('OUT', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(13)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  border: Border(bottom: BorderSide(color: Colors.white.withAlpha(13))),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text('RK', style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.secondary, letterSpacing: 1.0))),
                    Expanded(child: Text('TEAM', style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.secondary, letterSpacing: 1.0))),
                    SizedBox(width: 32, child: Text('W', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.secondary, letterSpacing: 1.0))),
                    SizedBox(width: 32, child: Text('L', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.secondary, letterSpacing: 1.0))),
                    SizedBox(width: 40, child: Text('PCT', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.secondary, letterSpacing: 1.0))),
                  ],
                ),
              ),
              _buildTableRow(context, '04', 'Champville', '14', '6', '.700', 'https://lh3.googleusercontent.com/aida-public/AB6AXuC5vRL-pdp9uXOVPoQHZB0s1fASlSdK-v8-n2xbzhlSHaKZATeBf-LlsplALO-tWHdgcTec9qTQM8I3yh7tSjt1X-dV-EG7BvnvGTLHjZBCOqDDCqN7mbsHznFzWkni8mUZhDxN4pHYFGd9hPuMyCbCnGs8ZTfI_7sdzS9A0yAVbH_mTSbdF9O-2p3TrHfk0k_8hWbNNWB5Drxz2zJilmK8001mf9U_-ultC1m2wk_R5SN6MHsJrXB2QkqN4X0_pTHx4SA3gY_T568F', false, false),
              _buildTableRow(context, '05', 'Homenetmen', '12', '8', '.600', 'https://lh3.googleusercontent.com/aida-public/AB6AXuCqVYQMdXspny20oMIbwAZQcdWz6Wy1BrvUIGbw2wkIxwNpijTNqIwlitBJcsgd1KEiykNnlv7d2khPjDLA6aWRumQ85iOm2nUnQ39SDbtQ-tEWSvB0Fk0zqWqh72THqPJ6J3DxLK8n2NmLyp-VS0r6ye_T5a0VnAeMfdeZ7pjsGSyXldVP0mE7fcbnGJku6XSsmQalRlnFXripzlGGHaQUtRqAyk39b-UTLSOrEPn_KCCYtal2VltbInnvbQ3uYbYwS1gtu7dYp2sO', false, false),
              _buildTableRow(context, '06', 'Antranik', '11', '9', '.550', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDGKQwXs4sKj0d6sYkXLyVzrlxjbbWf4da365hbPoSvaY-08gMs4IPFgVz2gvfs_EBj-7gcrVifRg9gvWDrl_nfcBmLkrrsITUlCQvP2CpcnNAaIYK4fsTxUkPw1-dVuZ-GXeUdMDVeZDY4zx3bM1MRYHqFhtF_zuxY_i8-ChCRAlTXx4AbTX-B-C1Ri6XSXISz09rqy4Hy5Ok579fYjaa2eW3M6-unAXfJ_aRqXGCLKsnA0cDvk6nOjukJ-xI0yaSjBvKzIua-Z8Vo', true, false),
              _buildTableRow(context, '07', 'Antonine', '10', '10', '.500', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDo3u-No1pOYqjlzQqxsF6ROINcr6zG3wd8d1vzXUX-tEurMhwvjrsdIEvSYgD3B09Db-KfYZnY77rbTs8DubFQYKd0kxANGn5LArOjALO8yW2lTCfavVQtYqjf0PWWcarkrWckpz-gWEmU8aQLtZfSL-buv4BoZnLiX60IKZ7_tqGim52QmObQ17UAqLaNVw6wqVhkO7dn4wwjcaEa-35jeUVcrZ-UHr0A2dYbXvNw_nlofGzCSwqanLfXrSBhgdKLhtfDzj76ODjw', false, false),
              _buildTableRow(context, '08', 'NSA', '8', '12', '.400', 'https://lh3.googleusercontent.com/aida-public/AB6AXuCUNPEhRFsh_HKU_O9NQDPsgNyyCTKdMRBMkR42GkqfXwKzOB_j48uVHD7JdduY2z8WQdBZZOdEADUYglzU_6XMvKts3-mbFrwmhggTmFpBHPumVKB0hIdclVn9uSyJasjm31L-JKcR60CqdAFH_6-VyqMKMPTBFzlUcJSzYkvc_tDx-kyrjl2W9TxU2jhSVDOmauqr1XqnWpo9oZSt_tV05i7PaspKJYWQlptEmvXPWUwpvYkg8b-sgYrujowFDtlZyIobMWSP2944', false, false),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                color: colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Text('LOWER BRACKET', style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w900, color: colorScheme.secondary.withAlpha(102), letterSpacing: 3.0)),
              ),

              _buildTableRow(context, '09', 'Atlas', '7', '13', '.350', 'https://lh3.googleusercontent.com/aida-public/AB6AXuCMUm33l8ctv4wgYDKBMYplDSAK_1UpwS3qDOE65TQNVxKddQD5IpSvMLy5iDxJEdrxsH_b4vaCu-w4ff94lFX0H2_249j0-_zT6npntGecCP2vGu3GWQcdn0glThZVfC53uVhdC1MCv8T7vNfmFfV7dznThmpfnSw0TGqRCy-zZI_3D9P13TRyt3RBHOh0LC8LEA9EAqDQhJSKnIK5AZSj2ByAVuiQCwJ3bsS33nokZR8yMCndho3h21V3bw8r7ad_bEnphBNqSqkP', false, true),
              _buildTableRow(context, '10', 'Mayrouba', '5', '15', '.250', 'https://lh3.googleusercontent.com/aida-public/AB6AXuACAcpVTyJlZVLH9L1kDUD2kByn4hqbxrd-oRkvkIFcpP_QcvRiHZe1qI6qH6uZVh6b9mlS5m4TWRt7VM5IMfE_HSQAGlvRkLplWxxsSkdaBtUmej3TzWhk4DlhWGNzcertszmA-x64qB8i_Md5t8IMFPin-JDx9nUYfLFxseVSWRBOfavXxOCsvEeGj_Gz9RW8FrVC2e5yWFPvQ11dp5RcR5rNIov40nnT3YTbADSCCrSh2XEcpWMK7lC73jhsxTa50uuYf4S9I8cr', false, true),
              _buildTableRow(context, '11', 'Byblos', '3', '17', '.150', 'https://lh3.googleusercontent.com/aida-public/AB6AXuD25JWA65osQdZcKunbuTOr0fJlF9fFaUN2fsGYTOHSdz0QFLPrGP7l-VteYx7h7V2YUBAKFtEWmnjpcSZwaes0P6E78ZsDDuLwJzm1dt635uWu1qGCkrkb43t03aZ5BtnCmem3_GI6v89C9-BEBEfiT7P2scQqHAo-supjfk_I2qU4jsi8vxrNrrePCc1I4036XNaVjPwXdbrhZA72rFhzDJ-Q4zQDWLKyIz2Ww_3O2OjgTvYQYfq7jI0nqiEPYkFGaArxAEyqaIXD', false, true),
              _buildTableRow(context, '12', 'Hoops Club', '2', '18', '.100', 'https://lh3.googleusercontent.com/aida-public/AB6AXuAa3remVXe1HWgOsplfpktuzu3IR1CTWkMR6lsdbHiNdR8S1gDmoFAygyw6eDv0Iv3W74OujLYRwKJ-m4EngxyODMdn0x9hQGv-VKgpKz87Bzqp6CE6kwxGZtk5bGkmZyZJFQ8sfHouar7MvmLvW-7PRgNIwwc6CDfrLuBNHR1HQUqbXCGg2CCtL_3jwBWa5J40RSB24iFaQKzBvsnjuhdNv3JHt54SGXUdyCrqUzmRIdN378SpKyGL_Ct7FRWKqrPed4aZARdL2CJ1', false, true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(BuildContext context, String rk, String team, String w, String l, String pct, String imgUrl, bool isCutoff, bool isFaded) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(13)),
          left: isCutoff ? BorderSide(color: Colors.green.shade500, width: 4) : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Opacity(
        opacity: isFaded ? 0.4 : 1.0,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(rk, style: TextStyle(fontFamily: 'Lexend', fontSize: 13, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: colorScheme.secondary)),
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(isFaded ? 200 : 230),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withAlpha(51)),
                    ),
                    child: Image.network(imgUrl, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 16),
                  Text(team, style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.w800, color: colorScheme.onSurface, letterSpacing: -0.5)),
                ],
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(w, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ),
            SizedBox(
              width: 32,
              child: Text(l, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ),
            SizedBox(
              width: 40,
              child: Text(pct, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Lexend', fontSize: 11, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}
