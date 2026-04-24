import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../models/collection_card.dart';
import '../../../models/team.dart';
import '../../../services/cards_filter_options_service.dart';
import '../../../services/collection_api_service.dart';
import '../../../services/session_store.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_filter_bar.dart';
import 'card_game_ui_theme.dart';

class ViewCollectionPage extends StatefulWidget {
  const ViewCollectionPage({super.key, this.duplicatesOnly = false});

  /// When true, only cards owned 2+ times; each tile shows ×N (instance count).
  final bool duplicatesOnly;

  @override
  State<ViewCollectionPage> createState() => _ViewCollectionPageState();
}

class _ViewCollectionPageState extends State<ViewCollectionPage> {
  final _api = CollectionApiService();
  final _filterOpts = CardsFilterOptionsService();

  List<CollectionCard> _cards = [];
  List<Team> _teams = [];
  List<String> _nationalityOptions = const [];
  bool _loading = true;
  String? _error;

  String? _positionFilter;
  String? _cardTypeFilter;
  String? _nationalityFilter;
  int? _teamIdFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = await SessionStore.instance.load();
    final userId = session?.userId ?? BackendConfig.devUserId;
    try {
      final cards = widget.duplicatesOnly
          ? await _api.fetchCollectionDuplicates(userId: userId)
          : await _api.fetchCollection(userId: userId);
      List<Team> teams = [];
      List<String> nationalities = const [];
      try {
        final fo = await _filterOpts.fetchFilterOptions();
        teams = fo.teams;
        nationalities = fo.nationalities;
      } on CardsFilterOptionsException {
        teams = [];
        nationalities = const [];
      } catch (_) {
        teams = [];
        nationalities = const [];
      }
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _teams = teams;
        _nationalityOptions = nationalities;
        _loading = false;
      });
    } on CollectionApiException catch (e) {
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

  List<String> get _positionOptions {
    final set = <String>{};
    for (final c in _cards) {
      final p = c.position.trim();
      if (p.isNotEmpty && p != '?') set.add(p);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<CollectionCard> get _visibleCards {
    var list = List<CollectionCard>.from(_cards);
    if (_positionFilter != null) {
      list = list.where((c) => c.position == _positionFilter).toList();
    }
    if (_cardTypeFilter != null) {
      list = list
          .where(
            (c) =>
                CollectionCard.normalizedCardType(c.cardType) ==
                _cardTypeFilter,
          )
          .toList();
    }
    if (_nationalityFilter != null) {
      list = list
          .where(
            (c) => CollectionCard.nationalityMatchesFilter(
              c.nationality,
              _nationalityFilter!,
            ),
          )
          .toList();
    }
    if (_teamIdFilter != null) {
      list = list.where((c) => c.teamId == _teamIdFilter).toList();
    }
    list.sort((a, b) {
      if (widget.duplicatesOnly) {
        final ic = (b.instanceCount ?? 0).compareTo(a.instanceCount ?? 0);
        if (ic != 0) return ic;
      }
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
        title: Text(widget.duplicatesOnly ? 'Duplicates' : 'Collection'),
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
          ? _ErrorBody(message: _error!, onRetry: _load)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardCatalogFilterBar(
                  cardGameStyle: true,
                  positionOptions: _positionOptions,
                  teams: _teams,
                  nationalityOptions: _nationalityOptions,
                  positionFilter: _positionFilter,
                  cardTypeFilter: _cardTypeFilter,
                  nationalityFilter: _nationalityFilter,
                  teamIdFilter: _teamIdFilter,
                  onPosition: (v) => setState(() => _positionFilter = v),
                  onCardType: (v) => setState(() => _cardTypeFilter = v),
                  onNationality: (v) => setState(() => _nationalityFilter = v),
                  onClub: (v) => setState(() => _teamIdFilter = v),
                ),
                Expanded(
                  child: _cards.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              widget.duplicatesOnly
                                  ? 'No duplicate cards yet.\nYou need at least two copies of the same card.'
                                  : 'No cards yet.\nOpen packs to build your collection.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: CardGameUiTheme.onDark.withAlpha(180),
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                          ),
                        )
                      : _visibleCards.isEmpty
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
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.72,
                              ),
                          itemCount: _visibleCards.length,
                          itemBuilder: (context, i) => _CollectionCardTile(
                            card: _visibleCards[i],
                            showDuplicateBadge: widget.duplicatesOnly,
                            onOpenPreview: () => _showCollectionCardPreview(
                              context,
                              _visibleCards[i],
                              showDuplicateBadge: widget.duplicatesOnly,
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

void _showCollectionCardPreview(
  BuildContext context,
  CollectionCard card, {
  required bool showDuplicateBadge,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withAlpha(210),
    builder: (ctx) {
      final w = MediaQuery.sizeOf(ctx).width;
      final cardW = (w * 0.88).clamp(260.0, 400.0);
      final count = card.instanceCount ?? 0;
      final badge = showDuplicateBadge && count >= 2;

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: cardW,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: CardGameUiTheme.gold.withAlpha(110),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CardGameUiTheme.orangeGlow.withAlpha(55),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                    spreadRadius: -4,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 0.72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: _CollectionCardImageFill(
                        card: card,
                        placeholderFontSize: 15,
                      ),
                    ),
                    if (badge)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          elevation: 6,
                          color: CardGameUiTheme.orangeGlow,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              '×$count',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              card.playerLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CardGameUiTheme.onDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                'OVR ${card.overall}',
                if (card.position.trim().isNotEmpty && card.position != '?')
                  card.position,
                if ((card.teamName ?? '').trim().isNotEmpty)
                  card.teamName!.trim(),
              ].join(' · '),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(175),
                fontSize: 13.5,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: CardGameUiTheme.onDark.withAlpha(230),
                side: BorderSide(color: CardGameUiTheme.gold.withAlpha(130)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Full-bleed card art (network or name placeholder).
class _CollectionCardImageFill extends StatelessWidget {
  const _CollectionCardImageFill({
    required this.card,
    this.placeholderFontSize = 12,
  });

  final CollectionCard card;
  final double placeholderFontSize;

  @override
  Widget build(BuildContext context) {
    final placeholderStyle = TextStyle(
      color: CardGameUiTheme.onDark.withAlpha(170),
      fontSize: placeholderFontSize,
      fontWeight: FontWeight.w600,
    );
    final placeholder = ColoredBox(
      color: CardGameUiTheme.panel,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            card.playerLabel,
            textAlign: TextAlign.center,
            style: placeholderStyle,
          ),
        ),
      ),
    );

    return BundledPlayCardImage(
      cardId: card.cardId,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fallbackImageUrl: card.cardImage,
      errorPlaceholder: placeholder,
    );
  }
}

class _CollectionCardTile extends StatelessWidget {
  const _CollectionCardTile({
    required this.card,
    required this.showDuplicateBadge,
    required this.onOpenPreview,
  });

  final CollectionCard card;
  final bool showDuplicateBadge;
  final VoidCallback onOpenPreview;

  @override
  Widget build(BuildContext context) {
    final count = card.instanceCount ?? 0;
    final badge = showDuplicateBadge && count >= 2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenPreview,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: CardGameUiTheme.gold.withAlpha(90),
              width: 1.2,
            ),
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
              Positioned.fill(child: _CollectionCardImageFill(card: card)),
              if (badge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    elevation: 4,
                    color: CardGameUiTheme.orangeGlow,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        '×$count',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

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
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: CardGameUiTheme.onDark.withAlpha(160),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
