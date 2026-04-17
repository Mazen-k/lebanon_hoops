import 'package:flutter/material.dart';

import '../models/vendor_session.dart';
import '../services/vendor_auth_api_service.dart';
import '../theme/colors.dart';

/// Single hub for a court owner: playgrounds, photos, prices, availability.
class VendorCourtDashboardPage extends StatefulWidget {
  const VendorCourtDashboardPage({
    super.key,
    required this.session,
    required this.onSignedOut,
  });

  final VendorSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<VendorCourtDashboardPage> createState() => _VendorCourtDashboardPageState();
}

class _VendorCourtDashboardPageState extends State<VendorCourtDashboardPage> {
  final _api = VendorAuthApiService();
  List<Map<String, dynamic>> _playgrounds = [];
  final Map<int, List<Map<String, dynamic>>> _availability = {};
  final Set<int> _openTiles = {};
  final Set<int> _availLoading = {};
  bool _loading = true;
  String? _error;

  VendorSession get s => widget.session;

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
      final list = await _api.listPlaygrounds(s.token);
      if (!mounted) return;
      setState(() {
        _playgrounds = list;
        _availability.clear();
        _loading = false;
      });
    } on VendorAuthApiException catch (e) {
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

  Future<void> _loadAvailability(int playgroundId) async {
    setState(() => _availLoading.add(playgroundId));
    try {
      final slots = await _api.listAvailability(s.token, playgroundId: playgroundId);
      if (!mounted) return;
      setState(() {
        _availability[playgroundId] = slots;
        _availLoading.remove(playgroundId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _availLoading.remove(playgroundId);
        _availability[playgroundId] = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  int _pgId(Map<String, dynamic> m) {
    final v = m['playground_id'] ?? m['playgroundId'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.parse(v.toString());
  }

  int _slotId(Map<String, dynamic> slot) {
    final v = slot['availability_id'] ?? slot['availabilityId'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.parse(v.toString());
  }

  Future<void> _signOut() async {
    await widget.onSignedOut();
  }

  Future<void> _addPlayground() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    var half = false;
    var active = true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return _VendorSheetScaffold(
                title: 'New playground',
                subtitle: 'Name your court space and set the hourly rate. You can add photos and booking slots next.',
                icon: Icons.add_business_rounded,
                primaryLabel: 'Create playground',
                onPrimary: () {
                  final p = double.tryParse(priceCtrl.text.trim());
                  if (nameCtrl.text.trim().isEmpty || p == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter a name and a valid price.'), behavior: SnackBarBehavior.floating),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                onDismiss: () => Navigator.pop(ctx, false),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VendorTextField(
                      controller: nameCtrl,
                      label: 'Playground name',
                      hint: 'e.g. Main court, Training lane',
                      icon: Icons.sports_basketball_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    _VendorTextField(
                      controller: priceCtrl,
                      label: 'Price per hour',
                      hint: 'e.g. 65',
                      icon: Icons.payments_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 20),
                    _ModernSwitchRow(
                      title: 'Half court allowed',
                      subtitle: 'Fans can book half-floor sessions when enabled.',
                      value: half,
                      onChanged: (v) => setSheet(() => half = v),
                    ),
                    const SizedBox(height: 12),
                    _ModernSwitchRow(
                      title: 'Listed as active',
                      subtitle: 'Inactive playgrounds stay hidden from public booking.',
                      value: active,
                      onChanged: (v) => setSheet(() => active = v),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (ok != true || !mounted) {
      nameCtrl.dispose();
      priceCtrl.dispose();
      return;
    }
    final p = double.tryParse(priceCtrl.text.trim());
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    priceCtrl.dispose();
    if (name.isEmpty || p == null) return;

    try {
      await _api.createPlayground(
        s.token,
        name: name,
        pricePerHour: p,
        canHalfCourt: half,
        isActive: active,
      );
      await _load();
    } on VendorAuthApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _savePlayground(Map<String, dynamic> pg) async {
    final id = _pgId(pg);
    final nameCtrl = TextEditingController(text: '${pg['playground_name'] ?? ''}');
    final priceCtrl = TextEditingController(text: '${pg['price_per_hour'] ?? ''}');
    var half = pg['can_half_court'] == true;
    var active = pg['is_active'] != false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return _VendorSheetScaffold(
                title: 'Edit playground',
                subtitle: 'Update how this space appears to players.',
                icon: Icons.tune_rounded,
                primaryLabel: 'Save changes',
                onPrimary: () {
                  final pr = double.tryParse(priceCtrl.text.trim());
                  if (nameCtrl.text.trim().isEmpty || pr == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter a name and a valid price.'), behavior: SnackBarBehavior.floating),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                onDismiss: () => Navigator.pop(ctx, false),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VendorTextField(
                      controller: nameCtrl,
                      label: 'Playground name',
                      hint: 'Display name',
                      icon: Icons.sports_basketball_rounded,
                    ),
                    const SizedBox(height: 16),
                    _VendorTextField(
                      controller: priceCtrl,
                      label: 'Price per hour',
                      hint: 'USD',
                      icon: Icons.payments_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 20),
                    _ModernSwitchRow(
                      title: 'Half court allowed',
                      subtitle: 'Allow half-court pricing for this space.',
                      value: half,
                      onChanged: (v) => setSheet(() => half = v),
                    ),
                    const SizedBox(height: 12),
                    _ModernSwitchRow(
                      title: 'Active listing',
                      subtitle: 'Turn off to hide from the public app.',
                      value: active,
                      onChanged: (v) => setSheet(() => active = v),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (ok != true || !mounted) {
      nameCtrl.dispose();
      priceCtrl.dispose();
      return;
    }
    final nm = nameCtrl.text.trim();
    final pr = double.tryParse(priceCtrl.text.trim());
    nameCtrl.dispose();
    priceCtrl.dispose();
    if (nm.isEmpty || pr == null) return;

    try {
      await _api.patchPlayground(
        s.token,
        playgroundId: id,
        name: nm,
        pricePerHour: pr,
        canHalfCourt: half,
        isActive: active,
      );
      await _load();
    } on VendorAuthApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addPhoto(int playgroundId) async {
    final urlCtrl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: _VendorSheetScaffold(
            title: 'Add photo',
            subtitle: 'Paste a direct image URL (HTTPS). It will show in the public listing.',
            icon: Icons.add_photo_alternate_rounded,
            primaryLabel: 'Add to gallery',
            onPrimary: () {
              if (urlCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Paste an image URL.'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            onDismiss: () => Navigator.pop(ctx, false),
            child: _VendorTextField(
              controller: urlCtrl,
              label: 'Image URL',
              hint: 'https://…',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
          ),
        );
      },
    );

    if (ok != true || !mounted) {
      urlCtrl.dispose();
      return;
    }
    final url = urlCtrl.text.trim();
    urlCtrl.dispose();
    if (url.isEmpty) return;

    try {
      await _api.addPlaygroundPhoto(s.token, playgroundId: playgroundId, photoUrl: url);
      await _load();
    } on VendorAuthApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deletePhoto(int photoId) async {
    try {
      await _api.deletePhoto(s.token, photoId: photoId);
      await _load();
    } on VendorAuthApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addSlot(int playgroundId) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    var pickedDate = today;
    TimeOfDay? startT = const TimeOfDay(hour: 17, minute: 0);
    TimeOfDay? endT = const TimeOfDay(hour: 18, minute: 0);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              String dateLabel() {
                const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                return '${w[pickedDate.weekday - 1]}, ${m[pickedDate.month - 1]} ${pickedDate.day}, ${pickedDate.year}';
              }

              String timeLabel(TimeOfDay? t) {
                if (t == null) return 'Choose…';
                final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
                final mm = t.minute.toString().padLeft(2, '0');
                final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
                return '$h:$mm $ap';
              }

              Future<void> pickDate() async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: pickedDate,
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 365)),
                  builder: (c, child) {
                    return Theme(
                      data: Theme.of(c).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: AppColors.onPrimary,
                          surface: AppColors.surfaceContainerLowest,
                          onSurface: AppColors.onSurface,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (d != null) setSheet(() => pickedDate = DateTime(d.year, d.month, d.day));
              }

              Future<void> pickTime(bool isStart) async {
                final initial = isStart ? startT : endT;
                final t = await showTimePicker(
                  context: ctx,
                  initialTime: initial ?? const TimeOfDay(hour: 12, minute: 0),
                  builder: (c, child) {
                    return Theme(
                      data: Theme.of(c).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: AppColors.onPrimary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (t != null) {
                  setSheet(() {
                    if (isStart) {
                      startT = t;
                    } else {
                      endT = t;
                    }
                  });
                }
              }

              int toMin(TimeOfDay t) => t.hour * 60 + t.minute;

              return _VendorSheetScaffold(
                title: 'New booking slot',
                subtitle: 'Pick the calendar day, then start and end times for this playground.',
                icon: Icons.event_available_rounded,
                primaryLabel: 'Publish slot',
                onPrimary: () {
                  if (startT == null || endT == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Choose start and end times.'), behavior: SnackBarBehavior.floating),
                    );
                    return;
                  }
                  if (toMin(endT!) <= toMin(startT!)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('End time must be after start time.'), behavior: SnackBarBehavior.floating),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                onDismiss: () => Navigator.pop(ctx, false),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Date', style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _PickerTile(
                      icon: Icons.calendar_month_rounded,
                      label: dateLabel(),
                      hint: 'Tap to open calendar',
                      onTap: pickDate,
                    ),
                    const SizedBox(height: 20),
                    Text('Time window', style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.schedule_rounded,
                            label: 'Start',
                            value: timeLabel(startT),
                            onTap: () => pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.schedule_send_rounded,
                            label: 'End',
                            value: timeLabel(endT),
                            onTap: () => pickTime(false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (ok != true || !mounted) return;
    if (startT == null || endT == null) return;

    final dateStr = _apiDate(pickedDate);
    final st = _apiTime(startT!);
    final et = _apiTime(endT!);

    try {
      await _api.createAvailability(
        s.token,
        playgroundId: playgroundId,
        availableDate: dateStr,
        startTime: st,
        endTime: et,
      );
      await _loadAvailability(playgroundId);
      setState(() {});
    } on VendorAuthApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _apiTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _deleteSlot(int playgroundId, int availabilityId) async {
    try {
      await _api.deleteAvailability(s.token, availabilityId: availabilityId);
      await _loadAvailability(playgroundId);
      setState(() {});
    } on VendorAuthApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  List<Map<String, dynamic>> _parsePhotos(Map<String, dynamic> pg) {
    final raw = pg['photos'] ?? pg['photo_urls'];
    if (raw is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      } else if (e is String) {
        out.add({'photo_url': e});
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(s.courtName, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha((255 * 0.35).round()),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _loading ? null : _addPlayground,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add playground', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceContainerLow, AppColors.surface],
          ),
        ),
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: _loading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
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
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      children: [
                        _VenueHeroCard(session: s),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'YOUR PLAYGROUNDS',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_playgrounds.isEmpty)
                          _EmptyPlaygroundsCard(onAdd: _addPlayground)
                        else
                          ..._playgrounds.map((pg) => _buildPlaygroundCard(context, pg)),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildPlaygroundCard(BuildContext context, Map<String, dynamic> pg) {
    final theme = Theme.of(context);
    final id = _pgId(pg);
    final name = '${pg['playground_name'] ?? ''}';
    final price = (pg['price_per_hour'] is num) ? (pg['price_per_hour'] as num).toDouble() : double.tryParse('${pg['price_per_hour']}') ?? 0;
    final photos = _parsePhotos(pg);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outlineVariant.withAlpha((255 * 0.85).round())),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withAlpha((255 * 0.04).round()),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
              collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.signatureGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sports_basketball_rounded, color: AppColors.onPrimary, size: 26),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                  color: AppColors.onSurface,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '\$${price.toStringAsFixed(2)} / hour',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w600),
                ),
              ),
              iconColor: AppColors.primary,
              collapsedIconColor: AppColors.secondary,
              onExpansionChanged: (open) {
                setState(() {
                  if (open) {
                    _openTiles.add(id);
                  } else {
                    _openTiles.remove(id);
                  }
                });
                if (open) _loadAvailability(id);
              },
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (pg['can_half_court'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer.withAlpha((255 * 0.55).round()),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Half court allowed',
                              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    Chip(
                      avatar: Icon(
                        pg['is_active'] == false ? Icons.pause_circle_outline : Icons.check_circle_outline,
                        size: 18,
                        color: pg['is_active'] == false ? AppColors.secondary : AppColors.primary,
                      ),
                      label: Text(pg['is_active'] == false ? 'Inactive' : 'Active'),
                      backgroundColor: AppColors.surfaceContainerHighest.withAlpha((255 * 0.6).round()),
                      side: BorderSide.none,
                      labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _savePlayground(pg),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text('Edit'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addPhoto(id),
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                        label: const Text('Photo'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.outlineVariant),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Gallery', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (photos.isEmpty)
                  Text(
                    'No photos yet — add one so players recognize your space.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary, height: 1.35),
                  )
                else
                  ...photos.map((ph) {
                    final pid = ph['photo_id'];
                    final url = '${ph['photo_url'] ?? ''}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined, color: AppColors.secondary.withAlpha((255 * 0.8).round())),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              url,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          if (pid != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              onPressed: () => _deletePhoto(pid is int ? pid : (pid as num).toInt()),
                            ),
                        ],
                      ),
                    );
                  }),
                if (_openTiles.contains(id)) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('Availability', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _availLoading.contains(id) ? null : () => _addSlot(id),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Add slot'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_availLoading.contains(id))
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (!_availability.containsKey(id))
                    Text(
                      'Loading slots…',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                    )
                  else if (_availability[id]!.isEmpty)
                    Text(
                      'No published slots. Add times players can book.',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                    )
                  else
                    ..._availability[id]!.map((slot) {
                      final aid = _slotId(slot);
                      final booked = slot['is_booked'] == true || slot['isBooked'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: booked ? AppColors.surfaceDim.withAlpha((255 * 0.5).round()) : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.outlineVariant.withAlpha((255 * 0.6).round())),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              booked ? Icons.lock_clock_rounded : Icons.event_available_rounded,
                              color: booked ? AppColors.secondary : AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${slot['available_date']}',
                                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.onSurface),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${slot['start_time']} – ${slot['end_time']}',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
                                  ),
                                ],
                              ),
                            ),
                            if (!booked)
                              IconButton(
                                tooltip: 'Remove slot',
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                onPressed: () => _deleteSlot(id, aid),
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VenueHeroCard extends StatelessWidget {
  const _VenueHeroCard({required this.session});

  final VendorSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.signatureGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha((255 * 0.28).round()),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withAlpha((255 * 0.15).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.onPrimary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  session.courtName,
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    height: 1.1,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, color: AppColors.onPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.location,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.onPrimary.withAlpha((255 * 0.95).round()),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Owner · ${session.username}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onPrimary.withAlpha((255 * 0.88).round()),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaygroundsCard extends StatelessWidget {
  const _EmptyPlaygroundsCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.sports_basketball_rounded, size: 48, color: AppColors.primary.withAlpha((255 * 0.5).round())),
          const SizedBox(height: 16),
          Text(
            'No playgrounds yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first court or lane — then upload photos and publish bookable time slots.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add playground'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared chrome for vendor bottom sheets.
class _VendorSheetScaffold extends StatelessWidget {
  const _VendorSheetScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onDismiss,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: AppColors.signatureGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha((255 * 0.25).round()),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: AppColors.onPrimary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -0.6,
                                  height: 1.1,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDismiss,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.outlineVariant),
                        foregroundColor: AppColors.onSurface,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: AppColors.signatureGradient,
                      ),
                      child: ElevatedButton(
                        onPressed: onPrimary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          primaryLabel,
                          style: const TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorTextField extends StatelessWidget {
  const _VendorTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _ModernSwitchRow extends StatelessWidget {
  const _ModernSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary, height: 1.35)),
        value: value,
        activeTrackColor: AppColors.primary.withAlpha((255 * 0.35).round()),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.outline;
        }),
        onChanged: onChanged,
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      value ?? hint ?? '',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
