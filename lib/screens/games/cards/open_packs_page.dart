import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../services/packs_api_service.dart';
import '../../../services/session_store.dart';
import 'pack_reveal_screen.dart';
import 'pack_shop_catalog.dart';

abstract final class _OpenPacksTheme {
  static const Color bg = Color(0xFF0A0A1A);
  static const Color panel = Color(0xFF1B1530);
  static const Color panelBorder = Color(0xFF3D2F55);
  static const Color gold = Color(0xFFFFD700);
  static const Color onDark = Color(0xFFF5F5FF);
  static const Color orangeGlow = Color(0xFFFF8C00);
}

class OpenPacksPage extends StatefulWidget {
  const OpenPacksPage({super.key});

  @override
  State<OpenPacksPage> createState() => _OpenPacksPageState();
}

class _OpenPacksPageState extends State<OpenPacksPage> {
  final _api = PacksApiService();
  bool _opening = false;

  Future<void> _openPack(PackShopItem pack) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final session = await SessionStore.instance.load();
      final userId = session?.userId ?? BackendConfig.devUserId;
      final cards = await _api.openPack(userId: userId, packId: pack.apiPackId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PackRevealScreen(cards: cards),
        ),
      );
    } on PacksApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _OpenPacksTheme.bg,
      appBar: AppBar(
        title: const Text('Open packs'),
        backgroundColor: _OpenPacksTheme.bg,
        foregroundColor: _OpenPacksTheme.onDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: kPackShopCatalog.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final pack = kPackShopCatalog[index];
          return _PackShopRow(
            pack: pack,
            busy: _opening,
            onTap: () => _openPack(pack),
          );
        },
      ),
    );
  }
}

class _PackShopRow extends StatelessWidget {
  const _PackShopRow({
    required this.pack,
    required this.busy,
    required this.onTap,
  });

  final PackShopItem pack;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _OpenPacksTheme.panel.withAlpha(230),
            border: Border.all(color: _OpenPacksTheme.panelBorder.withAlpha(180)),
            boxShadow: [
              BoxShadow(
                color: _OpenPacksTheme.orangeGlow.withAlpha(45),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 100,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ColoredBox(
                        color: _OpenPacksTheme.bg,
                        child: Image.asset(
                          pack.imageAssetPath,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 36,
                              color: Color(0xFF4A4060),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pack.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _OpenPacksTheme.onDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...pack.descriptionLines.map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  line,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _OpenPacksTheme.onDark.withAlpha(210),
                                    fontSize: 12.5,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(140),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _OpenPacksTheme.gold.withAlpha(100),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.monetization_on_rounded,
                                    size: 17,
                                    color: _OpenPacksTheme.gold,
                                  ),
                                  const SizedBox(width: 5),
                                  if (busy)
                                    const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _OpenPacksTheme.gold,
                                      ),
                                    )
                                  else
                                    Text(
                                      formatCoinsWithCommas(pack.priceCoins),
                                      style: const TextStyle(
                                        color: _OpenPacksTheme.gold,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
