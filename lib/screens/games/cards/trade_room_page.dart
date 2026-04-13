import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../models/tradeable_instance.dart';
import '../../../services/session_store.dart';
import '../../../services/trade_api_service.dart';
import '../../../theme/colors.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;

class TradeRoomPage extends StatefulWidget {
  const TradeRoomPage({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<TradeRoomPage> createState() => _TradeRoomPageState();
}

class _TradeRoomPageState extends State<TradeRoomPage> with SingleTickerProviderStateMixin {
  final _api = TradeApiService();
  Timer? _poll;
  Map<String, dynamic>? _state;
  String? _error;
  List<TradeableInstance>? _tradeable;
  bool _readyBusy = false;
  bool _finalizeBusy = false;
  int? _myUid;
  late final AnimationController _pulse;
  /// After we finalize, partner may complete the trade; next 404 is treated as success, not "left".
  bool _awaitingCompleted404 = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<int> _userId() async {
    final s = await SessionStore.instance.load();
    return s?.userId ?? BackendConfig.devUserId;
  }

  bool _mapFlag(dynamic m, int uid) {
    if (m is! Map) return false;
    final k = uid.toString();
    final v = m[k] ?? m[uid];
    return v == true;
  }

  int? _peerUserId() {
    final p = _state?['peer_user_id'];
    if (p == null) return null;
    if (p is int) return p;
    return int.tryParse(p.toString());
  }

  bool _bothLockedIn() {
    final peer = _peerUserId();
    final me = _myUid;
    if (peer == null || me == null) return false;
    return _mapFlag(_state?['ready_confirm'], me) && _mapFlag(_state?['ready_confirm'], peer);
  }

  bool _iAmReady() => _myUid != null && _mapFlag(_state?['ready_confirm'], _myUid!);
  bool _peerReady() {
    final p = _peerUserId();
    return p != null && _mapFlag(_state?['ready_confirm'], p);
  }

  bool _iAmFinalized() => _myUid != null && _mapFlag(_state?['final_confirm'], _myUid!);
  bool _peerFinalized() {
    final p = _peerUserId();
    return p != null && _mapFlag(_state?['final_confirm'], p);
  }

  void _syncPulseAnimation() {
    if (!mounted) return;
    final waitingPeerLock = _iAmReady() && !_peerReady() && _peerUserId() != null;
    final waitingPeerFinalize = _iAmFinalized() && !_peerFinalized() && _peerUserId() != null;
    final show = waitingPeerLock || waitingPeerFinalize;
    if (show) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      if (_pulse.isAnimating) {
        _pulse.stop();
        _pulse.value = 1;
      }
    }
  }

  Future<void> _leaveRoom() async {
    try {
      final uid = await _userId();
      await _api.leaveRoom(code: widget.roomCode, userId: uid);
    } catch (_) {
      /* room may already be gone */
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      final uid = await _userId();
      final s = await _api.getRoomState(code: widget.roomCode, userId: uid);
      if (!mounted) return;
      setState(() {
        _state = s;
        _myUid = uid;
        _error = null;
      });
      _syncPulseAnimation();
    } on TradeApiException catch (e) {
      if (!mounted) return;
      if (e.message.contains('not found')) {
        _poll?.cancel();
        if (mounted) {
          if (_awaitingCompleted404) {
            await _onTradeCompleted();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trade closed — partner left.')),
            );
            Navigator.of(context).pop();
          }
        }
        return;
      }
      if (!silent) setState(() => _error = e.message);
    } catch (e) {
      if (!silent && mounted) setState(() => _error = e.toString());
    }
  }

  List<int?> _parseInstanceSlots(dynamic list) {
    final out = <int?>[null, null, null];
    if (list is! List) return out;
    for (var i = 0; i < 3 && i < list.length; i++) {
      final el = list[i];
      if (el == null) continue;
      if (el is Map) {
        final v = el['card_instance_id'] ?? el['cardInstanceId'];
        if (v != null) out[i] = int.tryParse(v.toString());
      }
    }
    return out;
  }

  int? _cardIdInSlot(dynamic el) {
    if (el is! Map) return null;
    final v = el['card_id'] ?? el['cardId'];
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  bool _alreadyOfferingCard(int cardId) {
    final ys = _state?['your_slots'];
    if (ys is! List) return false;
    for (final el in ys) {
      final cid = _cardIdInSlot(el);
      if (cid == cardId) return true;
    }
    return false;
  }

  Map<String, dynamic>? _slotMap(dynamic el) {
    if (el is Map) return Map<String, dynamic>.from(el);
    return null;
  }

  Future<void> _loadTradeable() async {
    final uid = await _userId();
    final list = await _api.tradeableInstances(userId: uid);
    if (mounted) setState(() => _tradeable = list);
  }

  Future<void> _onTradeCompleted() async {
    _poll?.cancel();
    if (!mounted) return;
    setState(() => _awaitingCompleted404 = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trade complete'),
        content: const Text('Cards have been exchanged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _lockInOffer() async {
    setState(() => _readyBusy = true);
    try {
      final uid = await _userId();
      final status = await _api.confirmReady(code: widget.roomCode, userId: uid);
      if (!mounted) return;
      if (status == 'both_ready') {
        await _refresh();
      } else {
        await _refresh();
      }
    } on TradeApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _readyBusy = false);
    }
  }

  Future<void> _openFinalizeAreYouSure() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Finalize trade?'),
            content: const Text(
              'This cannot be undone. The cards currently locked in by both players will be swapped.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, finalize')),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    setState(() => _finalizeBusy = true);
    try {
      final uid = await _userId();
      final status = await _api.confirmFinalize(code: widget.roomCode, userId: uid);
      if (!mounted) return;
      if (status == 'completed') {
        await _onTradeCompleted();
      } else {
        if (status == 'waiting_peer_finalize' && mounted) {
          setState(() => _awaitingCompleted404 = true);
        }
        await _refresh();
      }
    } on TradeApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _finalizeBusy = false);
    }
  }

  void _showPeerWishlist() {
    final raw = _state?['peer_wishlist'];
    if (raw is! List || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards on their wishlist (or still connecting).')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("${_state?['peer_username'] ?? 'Player'}'s wishlist"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.separated(
              itemCount: raw.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (c, i) {
                final row = Map<String, dynamic>.from(raw[i] as Map);
                final fn = row['first_name']?.toString() ?? '';
                final ln = row['last_name']?.toString() ?? '';
                final name = '$fn $ln'.trim().isEmpty ? 'Card #${row['card_id']}' : '$fn $ln'.trim();
                final dup = row['you_have_duplicate'] == true || row['you_have_duplicate'] == 't';
                final cardId = int.tryParse(row['card_id']?.toString() ?? '') ?? 0;
                return ListTile(
                  enabled: dup,
                  onTap: dup
                      ? () async {
                          Navigator.pop(ctx);
                          await _tryAddWishlistCardToOffer(cardId, messenger);
                        }
                      : null,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: BundledPlayCardImage(
                      cardId: cardId,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorPlaceholder: const Icon(Icons.image_not_supported, size: 28),
                    ),
                  ),
                  title: Text(name),
                  trailing: dup
                      ? const Icon(Icons.add_circle_outline, color: AppColors.primary)
                      : null,
                  subtitle: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(dup ? 'Tap to add to your offer' : 'No duplicate to trade'),
                        backgroundColor: dup ? Colors.green.shade100 : AppColors.surfaceContainerHigh,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: dup ? Colors.green.shade900 : AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Future<void> _tryAddWishlistCardToOffer(int cardId, ScaffoldMessengerState messenger) async {
    if (cardId <= 0) return;
    if (_alreadyOfferingCard(cardId)) {
      messenger.showSnackBar(const SnackBar(content: Text('That card is already in your offer.')));
      return;
    }
    await _loadTradeable();
    if (!mounted) return;
    final current = _parseInstanceSlots(_state?['your_slots']);
    final used = <int>{};
    for (final id in current) {
      if (id != null) used.add(id);
    }
    var emptyIndex = -1;
    for (var i = 0; i < 3; i++) {
      if (current[i] == null) {
        emptyIndex = i;
        break;
      }
    }
    if (emptyIndex < 0) {
      messenger.showSnackBar(const SnackBar(content: Text('All your slots are full. Clear a slot first.')));
      return;
    }
    TradeableInstance? pick;
    for (final t in _tradeable ?? <TradeableInstance>[]) {
      if (t.cardId == cardId && !used.contains(t.cardInstanceId)) {
        pick = t;
        break;
      }
    }
    if (pick == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No duplicate instance available for that card.')));
      return;
    }
    final uid = await _userId();
    final slots = List<int?>.from(current);
    slots[emptyIndex] = pick.cardInstanceId;
    try {
      await _api.putOffer(code: widget.roomCode, userId: uid, slots: slots);
      if (mounted) setState(() => _awaitingCompleted404 = false);
      await _refresh();
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Added ${pick.label} to slot ${emptyIndex + 1}.')));
      }
    } on TradeApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickSlotFixed(int index) async {
    await _loadTradeable();
    if (!mounted) return;
    final all = _tradeable ?? [];
    final current = _parseInstanceSlots(_state?['your_slots']);
    final used = <int>{};
    for (var i = 0; i < 3; i++) {
      if (i != index && current[i] != null) used.add(current[i]!);
    }
    final choices = all.where((t) => !used.contains(t.cardInstanceId)).toList();

    final result = await showModalBottomSheet<_PickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Slot ${index + 1} — pick a duplicate (optional)',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Clear this slot'),
                onTap: () => Navigator.pop(ctx, const _PickResult.clear()),
              ),
              const Divider(),
              SizedBox(
                height: 280,
                child: choices.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No tradeable duplicates. Open packs or get duplicates first.'),
                      )
                    : ListView.builder(
                        itemCount: choices.length,
                        itemBuilder: (c, i) {
                          final t = choices[i];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: BundledPlayCardImage(
                                cardId: t.cardId,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorPlaceholder: const Icon(Icons.style, size: 28),
                              ),
                            ),
                            title: Text(t.label),
                            subtitle: Text('OVR ${t.overall}'),
                            onTap: () => Navigator.pop(ctx, _PickResult.card(t)),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;
    final uid = await _userId();
    final slots = List<int?>.from(current);
    if (result.clearSlot) {
      slots[index] = null;
    } else if (result.instance != null) {
      slots[index] = result.instance!.cardInstanceId;
    }

    try {
      await _api.putOffer(code: widget.roomCode, userId: uid, slots: slots);
      if (mounted) setState(() => _awaitingCompleted404 = false);
      await _refresh();
    } on TradeApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _handlePop() async {
    await _leaveRoom();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final peerName = _state?['peer_username']?.toString();
    final theirSlots = _state?['their_slots'];
    final yourSlots = _state?['your_slots'];

    final waitingPeerLock = _iAmReady() && !_peerReady() && _peerUserId() != null;
    final waitingPeerFinalize = _iAmFinalized() && !_peerFinalized() && _peerUserId() != null;
    final showPulse = waitingPeerLock || waitingPeerFinalize;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text('Trade · ${widget.roomCode}'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.onSurface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handlePop,
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _refresh()),
          ],
        ),
        body: _error != null && _state == null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      peerName != null ? '$peerName offers' : 'Waiting for partner…',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(3, (i) {
                        final m = theirSlots is List && i < theirSlots.length ? _slotMap(theirSlots[i]) : null;
                        return Expanded(child: _TradeSlotTile(map: m, label: 'Their ${i + 1}', onTap: null));
                      }),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: peerName == null ? null : _showPeerWishlist,
                      icon: const Icon(Icons.list_alt_rounded),
                      label: const Text("View partner's wishlist"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'You offer — up to 3 duplicates (optional)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(3, (i) {
                        final m = yourSlots is List && i < yourSlots.length ? _slotMap(yourSlots[i]) : null;
                        return Expanded(
                          child: _TradeSlotTile(
                            map: m,
                            label: 'Your ${i + 1}',
                            onTap: () => _pickSlotFixed(i),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    if (showPulse)
                      FadeTransition(
                        opacity: CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  waitingPeerFinalize
                                      ? 'You finalized — waiting for your partner to confirm…'
                                      : 'You locked in — waiting for your partner to lock in…',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (showPulse) const SizedBox(height: 16),
                    if (!_bothLockedIn()) ...[
                      FilledButton(
                        onPressed: (_readyBusy || _peerUserId() == null || _iAmReady())
                            ? null
                            : _lockInOffer,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primary,
                        ),
                        child: _readyBusy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                              )
                            : Text(_iAmReady() ? 'Offer locked in' : 'Lock in my offer'),
                      ),
                      if (_iAmReady() && !_peerReady())
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'You can change cards anytime; editing your offer clears both lock-ins.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                    if (_bothLockedIn()) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Both players locked in. Each must finalize below (with a final confirmation).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: (_finalizeBusy || _iAmFinalized()) ? null : _openFinalizeAreYouSure,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                        child: _finalizeBusy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_iAmFinalized() ? 'You finalized' : 'Finalize trade…'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Leave closes the trade for both players. Only duplicate cards can be offered.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PickResult {
  const _PickResult.card(this.instance) : clearSlot = false;
  const _PickResult.clear() : instance = null, clearSlot = true;

  final TradeableInstance? instance;
  final bool clearSlot;
}

class _TradeSlotTile extends StatelessWidget {
  const _TradeSlotTile({required this.map, required this.label, required this.onTap});

  final Map<String, dynamic>? map;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardId = map == null ? 0 : int.tryParse(map!['card_id']?.toString() ?? '') ?? 0;
    final child = map == null
        ? ColoredBox(
            color: AppColors.surfaceContainerHigh,
            child: Center(
              child: Text(
                onTap != null ? '+\nTap' : '—',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.secondary),
              ),
            ),
          )
        : BundledPlayCardImage(
            cardId: cardId,
            fit: BoxFit.cover,
            errorPlaceholder: ColoredBox(
              color: AppColors.surfaceContainerHigh,
              child: Center(
                child: Text(
                  '#${map!['card_id']}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondary)),
          const SizedBox(height: 4),
          AspectRatio(
            aspectRatio: 0.72,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
