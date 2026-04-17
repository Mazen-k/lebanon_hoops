import 'package:flutter/material.dart';

import '../models/court_reservation_models.dart';
import '../services/court_reservation_api_service.dart';
import '../services/session_store.dart';
import '../theme/colors.dart';

/// Loads [playground_availability] from API; books via [reservations].
class PlaygroundBookingPage extends StatefulWidget {
  const PlaygroundBookingPage({
    super.key,
    required this.court,
    required this.playground,
  });

  final CourtSummary court;
  final PlaygroundSummary playground;

  @override
  State<PlaygroundBookingPage> createState() => _PlaygroundBookingPageState();
}

class _PlaygroundBookingPageState extends State<PlaygroundBookingPage> {
  final _api = CourtReservationApiService();
  late DateTime _day = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  List<AvailabilitySlotDto> _slots = [];
  AvailabilitySlotDto? _picked;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    setState(() {
      _loading = true;
      _error = null;
      _picked = null;
    });
    try {
      final list = await _api.fetchAvailability(playgroundId: widget.playground.playgroundId, date: _day);
      if (!mounted) return;
      setState(() {
        _slots = list;
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

  CourtSummary get court => widget.court;
  PlaygroundSummary get playground => widget.playground;

  Future<void> _confirm() async {
    final slot = _picked;
    if (slot == null || !slot.canReserve) return;

    final session = await SessionStore.instance.load();
    if (!mounted) return;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Sign in first so we can attach your booking to your account.'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.createReservation(userId: session.userId, availabilityId: slot.availabilityId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Booked! See you on the court.'),
        ),
      );
      Navigator.of(context).pop();
    } on CourtReservationApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<DateTime> get _weekStrip {
    return List.generate(10, (i) => _day.subtract(const Duration(days: 3)).add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(playground.playgroundName, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              court.courtName,
              style: theme.textTheme.titleSmall?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _weekStrip.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = _weekStrip[i];
                final same = d.year == _day.year && d.month == _day.month && d.day == _day.day;
                return _DateChip(
                  label: _weekdayShort(d),
                  day: '${d.day}',
                  selected: same,
                  onTap: () {
                    setState(() => _day = DateTime(d.year, d.month, d.day));
                    _fetchSlots();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchSlots,
              child: _loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      ],
                    )
                  : _error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text(_error!, style: theme.textTheme.bodyLarge),
                            const SizedBox(height: 16),
                            FilledButton(onPressed: _fetchSlots, child: const Text('Retry')),
                          ],
                        )
                      : _slots.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 64),
                                Center(
                                  child: Text(
                                    'No slots on this day.\nPick another date or ask the venue to publish availability.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.secondary),
                                  ),
                                ),
                              ],
                            )
                          : GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.42,
                              ),
                              itemCount: _slots.length,
                              itemBuilder: (context, i) {
                                final s = _slots[i];
                                final sel = _picked?.availabilityId == s.availabilityId;
                                return _SlotTile(
                                  slot: s,
                                  selected: sel,
                                  onTap: () {
                                    if (!s.canReserve) return;
                                    setState(() => _picked = s);
                                  },
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _picked != null && _picked!.canReserve ? AppColors.signatureGradient : null,
              color: _picked == null || !_picked!.canReserve ? AppColors.surfaceDim : null,
            ),
            child: ElevatedButton(
              onPressed: (_picked != null && _picked!.canReserve && !_submitting) ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: AppColors.onPrimary,
                disabledForegroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(
                      _picked == null ? 'Select a time slot' : 'Confirm reservation',
                      style: const TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w900, letterSpacing: -0.2),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.signatureGradient : null,
          color: selected ? null : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.transparent : AppColors.outlineVariant),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha((255 * 0.18).round()),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onPrimary : AppColors.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 19,
                fontWeight: FontWeight.w900,
                height: 1,
                color: selected ? AppColors.onPrimary : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final AvailabilitySlotDto slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = slot.canReserve;
    return Opacity(
      opacity: ok ? 1 : 0.5,
      child: Material(
        color: selected ? AppColors.primary.withAlpha((255 * 0.08).round()) : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      ok ? 'Open' : 'Taken',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: ok ? AppColors.primary : AppColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Icon(ok ? Icons.event_available_rounded : Icons.block_rounded, size: 18, color: ok ? AppColors.primary : AppColors.secondary),
                  ],
                ),
                Text(
                  '${_formatHm(slot.startTime)} – ${_formatHm(slot.endTime)}',
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  ok ? 'Tap to select' : 'Unavailable',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _weekdayShort(DateTime d) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(d.weekday - 1).clamp(0, 6)];
}

String _formatHm(String hm) {
  final parts = hm.split(':');
  if (parts.length < 2) return hm;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final t = DateTime(2000, 1, 1, h, m);
  final ap = t.hour >= 12 ? 'PM' : 'AM';
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  return '$h12:$mm $ap';
}
