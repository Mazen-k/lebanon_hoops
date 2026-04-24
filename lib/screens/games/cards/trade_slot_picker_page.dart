import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../data/team_repository.dart';
import '../../../models/collection_card.dart';
import '../../../models/team.dart';
import '../../../models/tradeable_instance.dart';
import '../../../services/cards_filter_options_service.dart';
import '../../../services/collection_api_service.dart';
import 'card_filter_options_merge.dart';
import '../../../services/session_store.dart';
import '../../../services/trade_api_service.dart'
    show TradeApiException, TradeApiService;
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_filter_bar.dart';
import 'card_game_ui_theme.dart';

/// Result of [TradeSlotPickerPage]: clear the slot or pick a [TradeableInstance].
class TradeSlotPickerResult {
  const TradeSlotPickerResult.clear() : instance = null, clearSlot = true;
  const TradeSlotPickerResult.card(this.instance) : clearSlot = false;

  final TradeableInstance? instance;
  final bool clearSlot;
}

/// Full-screen picker: same filters + 2-column grid as Duplicates / Collection.
class TradeSlotPickerPage extends StatefulWidget {
  const TradeSlotPickerPage({
    super.key,
    required this.slotIndex,
    required this.excludedInstanceIds,
  });

  final int slotIndex;
  final Set<int> excludedInstanceIds;

  @override
  State<TradeSlotPickerPage> createState() => _TradeSlotPickerPageState();
}

class _TradeSlotPickerPageState extends State<TradeSlotPickerPage> {
  final _collectionApi = CollectionApiService();
  final _tradeApi = TradeApiService();
  final _filterOpts = CardsFilterOptionsService();
  final _teamsRepo = const TeamRepository();

  List<CollectionCard> _cards = [];
  List<TradeableInstance> _tradeable = [];
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
      final cardsFuture = _collectionApi.fetchCollectionDuplicates(
        userId: userId,
      );
      final tradeFuture = _tradeApi.tradeableInstances(userId: userId);
      final cards = await cardsFuture;
      final trade = await tradeFuture;
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
      if (teams.isEmpty) {
        try {
          teams = await _teamsRepo.fetchTeams();
        } on TeamRepositoryException {
          teams = [];
        } catch (_) {
          teams = [];
        }
      }
      final mergedNat = mergeNationalityFilterOptions(
        nationalities,
        cards.map((c) => c.nationality),
      );
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _tradeable = trade;
        _teams = teams;
        _nationalityOptions = mergedNat;
        _loading = false;
      });
    } on CollectionApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } on TradeApiException catch (e) {
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
    return set.toList()..sort();
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
      final ic = (b.instanceCount ?? 0).compareTo(a.instanceCount ?? 0);
      if (ic != 0) return ic;
      final o = b.overall.compareTo(a.overall);
      if (o != 0) return o;
      return a.cardId.compareTo(b.cardId);
    });
    return list;
  }

  TradeableInstance? _instanceForCard(int cardId) {
    for (final t in _tradeable) {
      if (t.cardId == cardId &&
          !widget.excludedInstanceIds.contains(t.cardInstanceId)) {
        return t;
      }
    }
    return null;
  }

  void _onTapCard(CollectionCard card) {
    final inst = _instanceForCard(card.cardId);
    if (inst == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No tradeable copy for this card (or it is used in another slot).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(TradeSlotPickerResult.card(inst));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CardGameUiTheme.bg,
      appBar: AppBar(
        title: Text('Slot ${widget.slotIndex + 1} · Duplicates'),
        backgroundColor: CardGameUiTheme.bg,
        foregroundColor: CardGameUiTheme.onDark,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(const TradeSlotPickerResult.clear()),
            icon: const Icon(Icons.clear_rounded, size: 20),
            label: const Text('Clear slot'),
            style: TextButton.styleFrom(foregroundColor: CardGameUiTheme.gold),
          ),
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
          ? _PickerErrorBody(message: _error!, onRetry: _load)
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
                              'No duplicate cards yet.\nYou need at least two copies of the same card.',
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
                          itemBuilder: (context, i) {
                            final card = _visibleCards[i];
                            return _PickerCardTile(
                              card: card,
                              onSelect: () => _onTapCard(card),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _PickerCardImageFill extends StatelessWidget {
  const _PickerCardImageFill({required this.card});

  final CollectionCard card;

  @override
  Widget build(BuildContext context) {
    final placeholderStyle = TextStyle(
      color: CardGameUiTheme.onDark.withAlpha(170),
      fontSize: 12,
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

class _PickerCardTile extends StatelessWidget {
  const _PickerCardTile({required this.card, required this.onSelect});

  final CollectionCard card;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final count = card.instanceCount ?? 0;
    final badge = count >= 2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
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
              Positioned.fill(child: _PickerCardImageFill(card: card)),
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

class _PickerErrorBody extends StatelessWidget {
  const _PickerErrorBody({required this.message, required this.onRetry});

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
