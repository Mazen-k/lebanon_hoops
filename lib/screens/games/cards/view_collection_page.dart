import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../data/team_repository.dart';
import '../../../models/collection_card.dart';
import '../../../models/team.dart';
import '../../../services/collection_api_service.dart';
import '../../../services/session_store.dart';
import '../../../theme/colors.dart';
import '../../../util/card_image_url.dart';
import 'card_filter_bar.dart';

class ViewCollectionPage extends StatefulWidget {
  const ViewCollectionPage({super.key, this.duplicatesOnly = false});

  /// When true, only cards owned 2+ times; each tile shows ×N (instance count).
  final bool duplicatesOnly;

  @override
  State<ViewCollectionPage> createState() => _ViewCollectionPageState();
}

class _ViewCollectionPageState extends State<ViewCollectionPage> {
  final _api = CollectionApiService();
  final _teamsRepo = const TeamRepository();

  List<CollectionCard> _cards = [];
  List<Team> _teams = [];
  bool _loading = true;
  String? _error;

  String? _positionFilter;
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
      try {
        teams = await _teamsRepo.fetchTeams();
      } on TeamRepositoryException {
        teams = [];
      }
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _teams = teams;
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
    if (_nationalityFilter != null) {
      list = list.where((c) => CollectionCard.nationalityBucket(c.nationality) == _nationalityFilter).toList();
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.duplicatesOnly ? 'Duplicates' : 'Collection'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CardCatalogFilterBar(
                      positionOptions: _positionOptions,
                      teams: _teams,
                      positionFilter: _positionFilter,
                      nationalityFilter: _nationalityFilter,
                      teamIdFilter: _teamIdFilter,
                      onPosition: (v) => setState(() => _positionFilter = v),
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
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.secondary),
                                ),
                              ),
                            )
                          : _visibleCards.isEmpty
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
                                  itemBuilder: (context, i) => _CollectionCardTile(
                                        card: _visibleCards[i],
                                        showDuplicateBadge: widget.duplicatesOnly,
                                      ),
                                ),
                    ),
                  ],
                ),
    );
  }
}

class _CollectionCardTile extends StatelessWidget {
  const _CollectionCardTile({
    required this.card,
    required this.showDuplicateBadge,
  });

  final CollectionCard card;
  final bool showDuplicateBadge;

  @override
  Widget build(BuildContext context) {
    final url = displayableCardImageUrl(card.cardImage);
    final count = card.instanceCount ?? 0;
    final badge = showDuplicateBadge && count >= 2;

    Widget imageLayer;
    if (url != null) {
      imageLayer = Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: AppColors.surfaceContainerHigh,
          child: Center(
            child: Text(
              card.playerLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.secondary),
            ),
          ),
        ),
      );
    } else {
      imageLayer = ColoredBox(
        color: AppColors.surfaceContainerHigh,
        child: Center(
          child: Text(
            card.playerLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.secondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
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
          Positioned.fill(child: imageLayer),
          if (badge)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                elevation: 3,
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    '×$count',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ),
            ),
        ],
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
            Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.secondary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
