import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../services/packs_api_service.dart';
import '../../../services/session_store.dart';
import '../../../services/user_wallet_api_service.dart';
import 'pack_reveal_screen.dart';
import 'pack_shop_catalog.dart';

abstract final class _OpenPacksTheme {
  static const Color bg = Color(0xFF0A0A1A);
  static const Color panel = Color(0xFF1B1530);
  static const Color panelBorder = Color(0xFF3D2F55);
  static const Color gold = Color(0xFFFFD700);
  static const Color onDark = Color(0xFFF5F5FF);
  static const Color orangeGlow = Color(0xFFFF8C00);
  static const Color segmentBg = Color(0xFF161022);
}

/// Coin bundles available in the store.
const List<({int coins, String priceUsd})> kCoinShopOffers = [
  (coins: 5, priceUsd: r'$1.99'),
  (coins: 10, priceUsd: r'$2.74'),
  (coins: 20, priceUsd: r'$7.19'),
  (coins: 40, priceUsd: r'$14.14'),
  (coins: 80, priceUsd: r'$28.19'),
];

class OpenPacksPage extends StatefulWidget {
  const OpenPacksPage({super.key});

  @override
  State<OpenPacksPage> createState() => _OpenPacksPageState();
}

class _OpenPacksPageState extends State<OpenPacksPage> {
  final _api = PacksApiService();
  final _walletApi = UserWalletApiService();
  final PageController _pageController = PageController();

  bool _opening = false;
  int _pageIndex = 0;

  int? _cardCoins;
  bool _walletLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() => _walletLoading = true);
    final session = await SessionStore.instance.load();
    final userId = session?.userId ?? BackendConfig.devUserId;
    try {
      final w = await _walletApi.fetchWallet(userId: userId);
      if (mounted) {
        setState(() {
          _cardCoins = w.cardCoins;
          _walletLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cardCoins ??= 0;
          _walletLoading = false;
        });
      }
    }
  }

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
      await _loadWallet();
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

  Future<void> _buyCoins(int coins) async {
    final session = await SessionStore.instance.load();
    final userId = session?.userId ?? BackendConfig.devUserId;
    try {
      final wallet = await _walletApi.buyCoins(userId: userId, coins: coins);
      if (!mounted) return;
      setState(() => _cardCoins = wallet.cardCoins);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchased $coins coins successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on UserWalletApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goToPage(int index) {
    if (index == _pageIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _OpenPacksTheme.bg,
      appBar: AppBar(
        title: const Text('Store'),
        backgroundColor: _OpenPacksTheme.bg,
        foregroundColor: _OpenPacksTheme.onDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                const Spacer(),
                Icon(
                  Icons.monetization_on_rounded,
                  size: 22,
                  color: _OpenPacksTheme.gold,
                ),
                const SizedBox(width: 6),
                Text(
                  _walletLoading ? '…' : '${_cardCoins ?? 0}',
                  style: const TextStyle(
                    color: _OpenPacksTheme.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _StoreSectionTabs(
              pageIndex: _pageIndex,
              onSelect: _goToPage,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: [
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                _CoinShopPage(
                  onBuyTap: _buyCoins,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two visible sections: **Packs** and **Buy Coins**. Selected = gold underline + tinted fill.
class _StoreSectionTabs extends StatelessWidget {
  const _StoreSectionTabs({
    required this.pageIndex,
    required this.onSelect,
  });

  final int pageIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _OpenPacksTheme.segmentBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _OpenPacksTheme.panelBorder.withAlpha(160)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Row(
          children: [
            Expanded(
              child: _StoreSectionTab(
                label: 'Packs',
                selected: pageIndex == 0,
                onTap: () => onSelect(0),
              ),
            ),
            Container(
              width: 1,
              height: 44,
              color: _OpenPacksTheme.panelBorder.withAlpha(120),
            ),
            Expanded(
              child: _StoreSectionTab(
                label: 'Buy Coins',
                selected: pageIndex == 1,
                onTap: () => onSelect(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreSectionTab extends StatelessWidget {
  const _StoreSectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? _OpenPacksTheme.gold.withAlpha(36) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: selected ? _OpenPacksTheme.gold : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? _OpenPacksTheme.onDark
                  : _OpenPacksTheme.onDark.withAlpha(150),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinShopPage extends StatelessWidget {
  const _CoinShopPage({required this.onBuyTap});

  final ValueChanged<int> onBuyTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Buy card coins',
          style: TextStyle(
            color: _OpenPacksTheme.onDark.withAlpha(230),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ...kCoinShopOffers.map(
          (o) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CoinOfferRow(
              coins: o.coins,
              priceUsd: o.priceUsd,
              onBuyTap: onBuyTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoinOfferRow extends StatelessWidget {
  const _CoinOfferRow({
    required this.coins,
    required this.priceUsd,
    required this.onBuyTap,
  });

  final int coins;
  final String priceUsd;
  final ValueChanged<int> onBuyTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onBuyTap(coins),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _OpenPacksTheme.panel.withAlpha(230),
            border: Border.all(color: _OpenPacksTheme.panelBorder.withAlpha(180)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.monetization_on_rounded, color: _OpenPacksTheme.gold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$coins coins',
                    style: const TextStyle(
                      color: _OpenPacksTheme.onDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  priceUsd,
                  style: TextStyle(
                    color: _OpenPacksTheme.gold.withAlpha(240),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => onBuyTap(coins),
                  style: TextButton.styleFrom(
                    foregroundColor: _OpenPacksTheme.orangeGlow,
                  ),
                  child: const Text('Buy'),
                ),
              ],
            ),
          ),
        ),
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
