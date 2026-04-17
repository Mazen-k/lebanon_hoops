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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    final today = _dateOnly(DateTime.now());
    final lastBookable = today.add(const Duration(days: 10));
    var day = _dateOnly(_day);
    if (day.isBefore(today)) day = today;
    if (day.isAfter(lastBookable)) day = lastBookable;

    setState(() {
      _loading = true;
      _error = null;
      _day = day;
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

  double _hourlyPrice(bool halfCourt) {
    final base = playground.pricePerHour;
    if (halfCourt && playground.canHalfCourt) {
      return (base * 0.55 * 100).round() / 100;
    }
    return base;
  }

  Future<void> _confirmReservation(
    AvailabilitySlotDto slot, {
    required bool halfCourt,
    required VoidCallback closeSheet,
  }) async {
    if (!slot.canReserve) return;

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

    try {
      await _api.createReservation(userId: session.userId, availabilityId: slot.availabilityId);
      if (!mounted) return;
      closeSheet();
      if (!mounted) return;
      final sizeLabel = halfCourt && playground.canHalfCourt ? 'Half court' : 'Full court';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Booked ($sizeLabel). See you on the court.'),
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
    }
  }

  Future<void> _openBookingSummary(AvailabilitySlotDto slot) async {
    if (!slot.canReserve) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _BookingSummarySheet(
          court: court,
          playground: playground,
          day: _day,
          slot: slot,
          hourlyPrice: _hourlyPrice,
          onCancel: () => Navigator.of(sheetContext).pop(),
          onConfirm: (halfCourt) => _confirmReservation(
            slot,
            halfCourt: halfCourt,
            closeSheet: () => Navigator.of(sheetContext).pop(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayStart = _dateOnly(DateTime.now());
    final rentalDays = List.generate(11, (i) => todayStart.add(Duration(days: i)));

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Tap an open slot to see a summary and confirm.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: rentalDays.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = rentalDays[i];
                final same = d.year == _day.year && d.month == _day.month && d.day == _day.day;
                return _DateChip(
                  label: _rentalStripLabel(d, todayStart),
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
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.42,
                              ),
                              itemCount: _slots.length,
                              itemBuilder: (context, i) {
                                final s = _slots[i];
                                return _SlotTile(
                                  slot: s,
                                  onTap: () => _openBookingSummary(s),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSummarySheet extends StatefulWidget {
  const _BookingSummarySheet({
    required this.court,
    required this.playground,
    required this.day,
    required this.slot,
    required this.hourlyPrice,
    required this.onCancel,
    required this.onConfirm,
  });

  final CourtSummary court;
  final PlaygroundSummary playground;
  final DateTime day;
  final AvailabilitySlotDto slot;
  final double Function(bool halfCourt) hourlyPrice;
  final VoidCallback onCancel;
  final Future<void> Function(bool halfCourt) onConfirm;

  @override
  State<_BookingSummarySheet> createState() => _BookingSummarySheetState();
}

class _BookingSummarySheetState extends State<_BookingSummarySheet> {
  bool _halfCourt = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final price = widget.hourlyPrice(_halfCourt);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  'Booking summary',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.5,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                _SummaryLine(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: _formatFullDate(widget.day),
                ),
                const SizedBox(height: 12),
                _SummaryLine(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value: '${_formatHm(widget.slot.startTime)} – ${_formatHm(widget.slot.endTime)}',
                ),
                const SizedBox(height: 12),
                _SummaryLine(
                  icon: Icons.place_outlined,
                  label: 'Location',
                  value: widget.court.location,
                ),
                const SizedBox(height: 12),
                _SummaryLine(
                  icon: Icons.apartment_outlined,
                  label: 'Venue',
                  value: widget.court.courtName,
                ),
                const SizedBox(height: 12),
                _SummaryLine(
                  icon: Icons.sports_basketball_outlined,
                  label: 'Playground',
                  value: widget.playground.playgroundName,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${price.toStringAsFixed(2)} / hour',
                              style: const TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.onSurface,
                              ),
                            ),
                            if (widget.playground.canHalfCourt && _halfCourt)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Half-court estimate (venue may confirm)',
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.playground.canHalfCourt) ...[
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Half court',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Lower rate when the venue allows splitting the floor.',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                    ),
                    value: _halfCourt,
                    activeTrackColor: AppColors.primary.withAlpha((255 * 0.35).round()),
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return AppColors.primary;
                      return AppColors.outline;
                    }),
                    onChanged: _busy ? null : (v) => setState(() => _halfCourt = v),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.outlineVariant),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                        child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: _busy ? null : AppColors.signatureGradient,
                          color: _busy ? AppColors.surfaceDim : null,
                        ),
                        child: ElevatedButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    await widget.onConfirm(_halfCourt);
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppColors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                                )
                              : const Text(
                                  'Confirm booking',
                                  style: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w900),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
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
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 10,
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
    required this.onTap,
  });

  final AvailabilitySlotDto slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = slot.canReserve;
    return Opacity(
      opacity: ok ? 1 : 0.5,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: ok ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
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
                  ok ? 'Tap for summary' : 'Unavailable',
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

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _calendarDaysFromTo(DateTime from, DateTime to) {
  return _dateOnly(to).difference(_dateOnly(from)).inDays;
}

/// "Today" for the current day; weekday name for all future days in the strip.
String _rentalStripLabel(DateTime d, DateTime todayStart) {
  final diff = _calendarDaysFromTo(todayStart, d);
  if (diff == 0) return 'Today';
  return _weekdayShort(d);
}

String _weekdayShort(DateTime d) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(d.weekday - 1).clamp(0, 6)];
}

String _formatFullDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${_weekdayShort(d)}, ${months[d.month - 1]} ${d.day}, ${d.year}';
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
