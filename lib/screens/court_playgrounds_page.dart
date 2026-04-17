import 'package:flutter/material.dart';

import '../models/court_reservation_models.dart';
import '../services/court_reservation_api_service.dart';
import '../theme/colors.dart';
import 'playground_booking_page.dart';

/// Shows all playgrounds for one court (from API).
class CourtPlaygroundsPage extends StatefulWidget {
  const CourtPlaygroundsPage({
    super.key,
    required this.courtId,
    required this.initialSummary,
  });

  final int courtId;
  final CourtSummary initialSummary;

  @override
  State<CourtPlaygroundsPage> createState() => _CourtPlaygroundsPageState();
}

class _CourtPlaygroundsPageState extends State<CourtPlaygroundsPage> {
  final _api = CourtReservationApiService();
  late CourtSummary _court = widget.initialSummary;
  List<PlaygroundSummary> _playgrounds = [];
  bool _loading = true;
  String? _error;

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
    try {
      final r = await _api.fetchCourtPlaygrounds(widget.courtId);
      if (!mounted) return;
      setState(() {
        _court = r.court;
        _playgrounds = r.playgrounds;
        _loading = false;
      });
    } on CourtReservationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _court.courtName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        color: colorScheme.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _CourtHeroBanner(court: _court),
              ),
            ),
            if (_loading)
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_playgrounds.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No playgrounds listed for this venue yet.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.secondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.separated(
                  itemCount: _playgrounds.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final p = _playgrounds[i];
                    return _PlaygroundCard(
                      playground: p,
                      onBook: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlaygroundBookingPage(
                              court: _court,
                              playground: p,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CourtHeroBanner extends StatelessWidget {
  const _CourtHeroBanner({required this.court});

  final CourtSummary court;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: colorScheme.signatureGradient,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha((255 * 0.28).round()),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Playgrounds',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimary.withAlpha((255 * 0.88).round()),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            court.courtName,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, color: colorScheme.onPrimary, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  court.location,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withAlpha((255 * 0.92).round()),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (court.phoneNumber != null && court.phoneNumber!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone_outlined, color: colorScheme.onPrimary, size: 20),
                const SizedBox(width: 6),
                Text(
                  court.phoneNumber!.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withAlpha((255 * 0.92).round()),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaygroundCard extends StatelessWidget {
  const _PlaygroundCard({required this.playground, required this.onBook});

  final PlaygroundSummary playground;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final photos = playground.photoUrls;

    return Material(
      color: colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 168,
            child: photos.isEmpty
                ? Container(
                    color: colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(Icons.image_not_supported_outlined, size: 40, color: colorScheme.secondary.withAlpha((255 * 0.6).round())),
                  )
                : PageView.builder(
                    itemCount: photos.length,
                    itemBuilder: (context, i) => Image.network(
                      photos[i],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, _) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined, color: colorScheme.secondary),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        playground.playgroundName,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${playground.pricePerHour.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('/ hour', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.secondary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!playground.isActive)
                      Chip(
                        label: const Text('Inactive'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: colorScheme.errorContainer,
                        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.onErrorContainer),
                      )
                    else
                      Chip(
                        label: const Text('Open'),
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(Icons.check_circle_outline, size: 18, color: colorScheme.primary),
                        backgroundColor: colorScheme.primary.withAlpha((255 * 0.08).round()),
                        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.primary),
                      ),
                    if (playground.canHalfCourt)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withAlpha((255 * 0.55).round()),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 20, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Half court allowed',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: playground.isActive ? onBook : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('View times & book', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
