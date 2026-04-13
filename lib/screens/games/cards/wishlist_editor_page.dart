import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../data/team_repository.dart';
import '../../../models/catalog_card.dart';
import '../../../models/team.dart';
import '../../../services/catalog_api_service.dart';
import '../../../services/session_store.dart';
import '../../../services/wishlist_api_service.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_filter_bar.dart';
import 'card_game_ui_theme.dart';

class WishlistEditorPage extends StatefulWidget {
  const WishlistEditorPage({super.key});

  @override
  State<WishlistEditorPage> createState() => _WishlistEditorPageState();
}

class _WishlistEditorPageState extends State<WishlistEditorPage> {
  final _catalogApi = CatalogApiService();
  final _wishlistApi = WishlistApiService();
  final _teamsRepo = const TeamRepository();

  List<CatalogCard> _cards = [];
  List<Team> _teams = [];
  final Set<int> _wishlistIds = {};
  bool _loading = true;
  String? _error;
  Timer? _saveDebounce;

  String? _positionFilter;
  String? _cardTypeFilter;
  String? _nationalityFilter;
  int? _teamIdFilter;
  bool _onlyMissing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _saveDebounce?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = await SessionStore.instance.load();
    final userId = session?.userId ?? BackendConfig.devUserId;
    try {
      List<Team> teams = [];
      try {
        teams = await _teamsRepo.fetchTeams();
      } on TeamRepositoryException {
        teams = [];
      }
      List<int>? wishIds;
      try {
        wishIds = await _wishlistApi.getWishlist(userId: userId);
      } catch (_) {
        wishIds = null;
      }
      final cards = await _catalogApi.fetchCatalog(
        userId: userId,
        position: _positionFilter,
        nationality: _nationalityFilter,
        teamId: _teamIdFilter,
        cardType: _cardTypeFilter,
        onlyMissing: _onlyMissing,
      );
      final resolvedWish = wishIds ??
          cards.where((c) => c.onWishlist).map((c) => c.cardId).toList();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _cards = cards;
        _wishlistIds
          ..clear()
          ..addAll(resolvedWish);
        _loading = false;
      });
    } on CatalogApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _flushWishlist);
  }

  Future<void> _flushWishlist() async {
    final session = await SessionStore.instance.load();
    final userId = session?.userId ?? BackendConfig.devUserId;
    try {
      final list = _wishlistIds.toList()..sort();
      await _wishlistApi.putWishlist(userId: userId, cardIds: list);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Wishlist saved'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: CardGameUiTheme.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: CardGameUiTheme.gold.withAlpha(120)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save wishlist: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: CardGameUiTheme.panel,
          ),
        );
      }
    }
  }

  void _toggleCard(int cardId) {
    setState(() {
      if (_wishlistIds.contains(cardId)) {
        _wishlistIds.remove(cardId);
      } else {
        _wishlistIds.add(cardId);
      }
    });
    _scheduleSave();
  }

  List<String> get _positionOptions {
    final set = <String>{};
    for (final c in _cards) {
      final p = c.position.trim();
      if (p.isNotEmpty && p != '?') set.add(p);
    }
    return set.toList()..sort();
  }

  List<CatalogCard> get _visibleCards {
    var list = List<CatalogCard>.from(_cards);
    list.sort((a, b) {
      final o = b.overall.compareTo(a.overall);
      if (o != 0) return o;
      return a.cardId.compareTo(b.cardId);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CardGameUiTheme.bg,
      appBar: AppBar(
        title: const Text('Edit wishlist'),
        backgroundColor: CardGameUiTheme.bg,
        foregroundColor: CardGameUiTheme.onDark,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: CardGameUiTheme.gold),
            )
          : _error != null
              ? _WishlistErrorBody(message: _error!, onRetry: _load)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CardCatalogFilterBar(
                      cardGameStyle: true,
                      positionOptions: _positionOptions,
                      teams: _teams,
                      positionFilter: _positionFilter,
                      cardTypeFilter: _cardTypeFilter,
                      nationalityFilter: _nationalityFilter,
                      teamIdFilter: _teamIdFilter,
                      onPosition: (v) {
                        setState(() => _positionFilter = v);
                        _load();
                      },
                      onCardType: (v) {
                        setState(() => _cardTypeFilter = v);
                        _load();
                      },
                      onNationality: (v) {
                        setState(() => _nationalityFilter = v);
                        _load();
                      },
                      onClub: (v) {
                        setState(() => _teamIdFilter = v);
                        _load();
                      },
                    ),
                    _OnlyMissingToggleBar(
                      value: _onlyMissing,
                      onChanged: _loading
                          ? null
                          : (v) {
                              setState(() => _onlyMissing = v);
                              _load();
                            },
                    ),
                    Expanded(
                      child: _visibleCards.isEmpty
                          ? Center(
                              child: Text(
                                'No cards match these filters.',
                                style: TextStyle(
                                  color: CardGameUiTheme.onDark.withAlpha(180),
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.72,
                              ),
                              itemCount: _visibleCards.length,
                              itemBuilder: (context, i) {
                                final c = _visibleCards[i];
                                final on = _wishlistIds.contains(c.cardId);
                                return _WishlistCatalogTile(
                                  card: c,
                                  onWishlist: on,
                                  onTap: () => _toggleCard(c.cardId),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

/// Styled like the card-game chrome; keeps “only cards I don’t own” as a compact bar + switch.
class _OnlyMissingToggleBar extends StatelessWidget {
  const _OnlyMissingToggleBar({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CardGameUiTheme.elevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Only cards I don\'t own',
                    style: TextStyle(
                      color: value ? CardGameUiTheme.gold : CardGameUiTheme.onDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hide cards already in your collection',
                    style: TextStyle(
                      color: CardGameUiTheme.onDark.withAlpha(140),
                      fontSize: 11.5,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SwitchTheme(
              data: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return CardGameUiTheme.gold;
                  }
                  return CardGameUiTheme.onDark.withAlpha(200);
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return CardGameUiTheme.gold.withAlpha(90);
                  }
                  return CardGameUiTheme.panelBorder.withAlpha(180);
                }),
              ),
              child: Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistCatalogTile extends StatelessWidget {
  const _WishlistCatalogTile({
    required this.card,
    required this.onWishlist,
    required this.onTap,
  });

  final CatalogCard card;
  final bool onWishlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        onWishlist ? CardGameUiTheme.gold : CardGameUiTheme.gold.withAlpha(90);
    final borderWidth = onWishlist ? 2.0 : 1.2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: CardGameUiTheme.orangeGlow.withAlpha(35),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BundledPlayCardImage(
                cardId: card.cardId,
                fit: BoxFit.cover,
                errorPlaceholder: ColoredBox(
                  color: CardGameUiTheme.panel,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        card.playerLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CardGameUiTheme.onDark.withAlpha(170),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: _OwnedPill(owned: card.owned),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  onWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: onWishlist ? CardGameUiTheme.gold : CardGameUiTheme.onDark.withAlpha(220),
                  shadows: const [
                    Shadow(blurRadius: 6, color: Colors.black87),
                    Shadow(blurRadius: 2, color: Colors.black54),
                  ],
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Matches duplicate-pack “×N” energy: orange pill + black label for owned; gold-outline pill for missing.
class _OwnedPill extends StatelessWidget {
  const _OwnedPill({required this.owned});

  final bool owned;

  @override
  Widget build(BuildContext context) {
    if (owned) {
      return Material(
        elevation: 4,
        color: CardGameUiTheme.orangeGlow,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'OWNED',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CardGameUiTheme.elevated.withAlpha(230),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CardGameUiTheme.gold.withAlpha(100), width: 1),
      ),
      child: Text(
        'NEED',
        style: TextStyle(
          color: CardGameUiTheme.onDark.withAlpha(230),
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _WishlistErrorBody extends StatelessWidget {
  const _WishlistErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: CardGameUiTheme.onDark.withAlpha(160)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(220),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: CardGameUiTheme.gold,
                side: const BorderSide(color: CardGameUiTheme.gold, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
