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
    final name = TextEditingController();
    final price = TextEditingController();
    var half = false;
    var active = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New playground'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price / hour'),
                ),
                SwitchListTile(
                  title: const Text('Half court allowed'),
                  value: half,
                  onChanged: (v) => setD(() => half = v),
                ),
                SwitchListTile(
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final p = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and valid price required')),
      );
      return;
    }
    try {
      await _api.createPlayground(
        s.token,
        name: name.text.trim(),
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
    final name = TextEditingController(text: '${pg['playground_name'] ?? ''}');
    final price = TextEditingController(text: '${pg['price_per_hour'] ?? ''}');
    var half = pg['can_half_court'] == true;
    var active = pg['is_active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Edit playground'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price / hour'),
              ),
              SwitchListTile(
                title: const Text('Half court allowed'),
                value: half,
                onChanged: (v) => setD(() => half = v),
              ),
              SwitchListTile(
                title: const Text('Active'),
                value: active,
                onChanged: (v) => setD(() => active = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final pr = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || pr == null) return;
    try {
      await _api.patchPlayground(
        s.token,
        playgroundId: id,
        name: name.text.trim(),
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
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add photo URL'),
        content: TextField(
          controller: url,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !mounted || url.text.trim().isEmpty) return;
    try {
      await _api.addPlaygroundPhoto(s.token, playgroundId: playgroundId, photoUrl: url.text.trim());
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
    final date = TextEditingController();
    final start = TextEditingController(text: '17:00');
    final end = TextEditingController(text: '18:00');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add availability'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: date,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
            ),
            TextField(controller: start, decoration: const InputDecoration(labelText: 'Start (HH:MM)')),
            TextField(controller: end, decoration: const InputDecoration(labelText: 'End (HH:MM)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.createAvailability(
        s.token,
        playgroundId: playgroundId,
        availableDate: date.text.trim(),
        startTime: start.text.trim(),
        endTime: end.text.trim(),
      );
      await _loadAvailability(playgroundId);
      setState(() {});
    } on VendorAuthApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addPlayground,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Playground'),
      ),
      body: RefreshIndicator(
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
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: AppColors.signatureGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your venue',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.onPrimary.withAlpha((255 * 0.9).round()),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.location,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onPrimary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Signed in as ${s.username}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.onPrimary.withAlpha((255 * 0.85).round()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Playgrounds',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      if (_playgrounds.isEmpty)
                        Text(
                          'No playgrounds yet. Tap + Playground to add one.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
                        )
                      else
                        ..._playgrounds.map((pg) => _buildPlaygroundCard(context, pg)),
                    ],
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

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: ExpansionTile(
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
        title: Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        subtitle: Text('\$${price.toStringAsFixed(2)} / hr', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pg['can_half_court'] == true)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Half court allowed',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                Chip(
                  label: Text(pg['is_active'] == false ? 'Inactive' : 'Active'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: () => _savePlayground(pg),
                child: const Text('Edit details'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _addPhoto(id),
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Photo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Photos', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (photos.isEmpty)
            Text('No photos yet.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary))
          else
            ...photos.map((ph) {
              final pid = ph['photo_id'];
              final url = '${ph['photo_url'] ?? ''}';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                trailing: pid != null
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        onPressed: () => _deletePhoto(pid is int ? pid : (pid as num).toInt()),
                      )
                    : null,
              );
            }),
          const SizedBox(height: 16),
          if (_openTiles.contains(id)) ...[
            Row(
              children: [
                Text('Availability', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _availLoading.contains(id) ? null : () => _addSlot(id),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Slot'),
                ),
              ],
            ),
            if (_availLoading.contains(id))
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (!_availability.containsKey(id))
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Loading slots…',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                ),
              )
            else if (_availability[id]!.isEmpty)
              Text('No slots yet.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary))
            else
              ..._availability[id]!.map((slot) {
                final aid = _slotId(slot);
                final booked = slot['is_booked'] == true || slot['isBooked'] == true;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${slot['available_date']}  ${slot['start_time']}–${slot['end_time']}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: booked ? const Text('Booked — cannot delete') : null,
                  trailing: booked
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, color: AppColors.error),
                          onPressed: () => _deleteSlot(id, aid),
                        ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
