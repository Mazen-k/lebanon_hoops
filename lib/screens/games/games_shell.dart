import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/main_app_drawer.dart';
import '../../widgets/menu_placeholder_page.dart';
import 'cards/cards_game_hub_page.dart';

/// Games hub: own bottom bar (Cards, Fantasy, Predictor, Redeem, 2× coming soon).
class GamesShell extends StatefulWidget {
  const GamesShell({super.key, this.onSignOut});

  final Future<void> Function()? onSignOut;

  @override
  State<GamesShell> createState() => _GamesShellState();
}

class _GamesShellState extends State<GamesShell> {
  int _index = 0;

  static const _labels = [
    'Cards',
    'Fantasy',
    'Predictor',
    'Redeem',
    'Coming soon',
    'Coming soon',
  ];

  late final List<Widget> _gamesPages;

  static const Color _cardsHubBg = Color(0xFF0A0A1A);
  static const Color _cardsHubFg = Color(0xFFF5F5FF);

  @override
  void initState() {
    super.initState();
    _gamesPages = [
      const MenuPlaceholderPage(title: 'Fantasy', subtitle: 'Fantasy games — content coming soon.'),
      const MenuPlaceholderPage(title: 'Predictor', subtitle: 'Predictions — content coming soon.'),
      const MenuPlaceholderPage(title: 'Redeem', subtitle: 'Redeem rewards — content coming soon.'),
      const MenuPlaceholderPage(title: 'Coming soon', subtitle: 'New game mode in development.'),
      const MenuPlaceholderPage(title: 'Coming soon', subtitle: 'New game mode in development.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cardsTab = _index == 0;
    return Scaffold(
      backgroundColor: cardsTab ? _cardsHubBg : AppColors.surface,
      appBar: AppBar(
        centerTitle: !cardsTab,
        title: cardsTab
            ? const Text(
                'Card Game',
                style: TextStyle(fontWeight: FontWeight.w700),
              )
            : Text(_labels[_index]),
        backgroundColor: cardsTab ? _cardsHubBg : AppColors.surface,
        foregroundColor: cardsTab ? _cardsHubFg : AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (scaffoldContext) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
          ),
        ),
      ),
      drawer: MainAppDrawer(
        hostContext: context,
        variant: MainDrawerVariant.gamesSection,
        onSignOut: widget.onSignOut,
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const CardsGameHubPage(),
          ..._gamesPages,
        ],
      ),
      bottomNavigationBar: cardsTab
          ? null
          : Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withAlpha((255 * 0.9).round()),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withAlpha((255 * 0.05).round()),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.secondary,
                selectedLabelStyle:
                    Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                unselectedLabelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.style_outlined), label: 'Cards'),
                  BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), label: 'Fantasy'),
                  BottomNavigationBarItem(icon: Icon(Icons.query_stats_outlined), label: 'Predictor'),
                  BottomNavigationBarItem(icon: Icon(Icons.redeem_outlined), label: 'Redeem'),
                  BottomNavigationBarItem(icon: Icon(Icons.hourglass_empty_rounded), label: 'Coming soon'),
                  BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded), label: 'Coming soon'),
                ],
              ),
            ),
    );
  }
}
