import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../data/team_repository.dart';
import '../../../models/catalog_card.dart';
import '../../../models/team.dart';
import '../../../services/catalog_api_service.dart';
import '../../../services/session_store.dart';
import '../../../services/wishlist_api_service.dart';
import '../../../theme/colors.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_filter_bar.dart';

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
          const SnackBar(content: Text('Wishlist saved'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save wishlist: $e'), behavior: SnackBarBehavior.floating),
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Edit wishlist'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CardCatalogFilterBar(
                      positionOptions: _positionOptions,
                      teams: _teams,
                      positionFilter: _positionFilter,
                      nationalityFilter: _nationalityFilter,
                      teamIdFilter: _teamIdFilter,
                      onPosition: (v) {
                        setState(() => _positionFilter = v);
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
                    SwitchListTile(
                      title: const Text('Only cards I don\'t own'),
                      subtitle: const Text('Hide cards already in your collection'),
                      value: _onlyMissing,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) {
                        setState(() => _onlyMissing = v);
                        _load();
                      },
                    ),
                    Expanded(
                      child: _visibleCards.isEmpty
                          ? Center(
                              child: Text(
                                'No cards match these filters.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.secondary),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onWishlist ? AppColors.primary : AppColors.outlineVariant,
              width: onWishlist ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 3),
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
                  color: AppColors.surfaceContainerHigh,
                  child: Center(child: Text(card.playerLabel, textAlign: TextAlign.center)),
                ),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: Material(
                  color: card.owned ? Colors.green.shade700 : AppColors.surface.withAlpha(230),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      card.owned ? 'OWNED' : 'NOT OWNED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: card.owned ? Colors.white : AppColors.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  onWishlist ? Icons.favorite : Icons.favorite_border,
                  color: onWishlist ? AppColors.primary : Colors.white,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
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
