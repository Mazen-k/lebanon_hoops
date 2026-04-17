import 'package:flutter/material.dart';

import '../models/court_reservation_models.dart';
import '../services/court_reservation_api_service.dart';
import '../theme/colors.dart';
import 'court_playgrounds_page.dart';

/// Lists courts from the API with search; tap opens playgrounds for that facility.
class CourtReservationPage extends StatefulWidget {
  const CourtReservationPage({super.key});

  @override
  State<CourtReservationPage> createState() => _CourtReservationPageState();
}

class _CourtReservationPageState extends State<CourtReservationPage> {
  final _search = TextEditingController();
  final _api = CourtReservationApiService();
  final _focus = FocusNode();

  List<CourtSummary> _courts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourts();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadCourts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.fetchCourts();
      if (!mounted) return;
      setState(() {
        _courts = list;
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

  List<CourtSummary> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _courts;
    return _courts
        .where(
          (c) => c.courtName.toLowerCase().contains(q) || c.location.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Court reservation'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surfaceContainerLow,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find your run',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.8,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search venues, then open a court to see its playgrounds.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.secondary, height: 1.35),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: _GlassSearchField(
                  controller: _search,
                  focusNode: _focus,
                  onClear: () {
                    _search.clear();
                    setState(() {});
                  },
                ),
              ),
              if (!_loading && _error == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.sports_basketball_rounded, size: 18, color: colorScheme.primary.withAlpha((255 * 0.85).round())),
                      const SizedBox(width: 6),
                      Text(
                        '${_visible.length} venue${_visible.length == 1 ? '' : 's'}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: colorScheme.primary,
                  onRefresh: _loadCourts,
                  child: _buildBody(theme, colorScheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: colorScheme.primary)),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.cloud_off_rounded, size: 56, color: colorScheme.secondary.withAlpha((255 * 0.5).round())),
          const SizedBox(height: 16),
          Text(
            'Could not load courts',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.secondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadCourts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      );
    }
    final rows = _visible;
    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 52, color: colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    _search.text.trim().isEmpty ? 'No courts yet' : 'No matches',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _search.text.trim().isEmpty
                        ? 'Add rows to `courts` in your database, or run DB/court_reservation_schema.sql.'
                        : 'Try another name or clear the search field.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final c = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _CourtVenueCard(
            court: c,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CourtPlaygroundsPage(courtId: c.courtId, initialSummary: c),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GlassSearchField extends StatelessWidget {
  const _GlassSearchField({
    required this.controller,
    required this.focusNode,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Material(
          color: colorScheme.surfaceContainerLowest.withAlpha((255 * 0.92).round()),
          elevation: 0,
          shadowColor: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withAlpha((255 * 0.06).round()),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search court name or area…',
                hintStyle: TextStyle(color: colorScheme.secondary.withAlpha((255 * 0.85).round())),
                prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onClear,
                      ),
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CourtVenueCard extends StatelessWidget {
  const _CourtVenueCard({required this.court, required this.onTap});

  final CourtSummary court;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final url = court.logoUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: colorScheme.surfaceContainerLowest,
            border: Border.all(color: colorScheme.outlineVariant.withAlpha((255 * 0.65).round())),
            boxShadow: [
              BoxShadow(
                color: colorScheme.onSurface.withAlpha((255 * 0.04).round()),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _CourtLogo(url: url, name: court.courtName),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        court.courtName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.place_outlined, size: 18, color: colorScheme.secondary.withAlpha((255 * 0.9).round())),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              court.location,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.secondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withAlpha((255 * 0.45).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourtLogo extends StatelessWidget {
  const _CourtLogo({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final letter = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: colorScheme.signatureGradient,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha((255 * 0.25).round()),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.trim().isNotEmpty
          ? Image.network(
              url!.trim(),
              fit: BoxFit.cover,
              width: 64,
              height: 64,
              errorBuilder: (context, error, _) => _LogoFallback(letter: letter),
            )
          : _LogoFallback(letter: letter),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}
