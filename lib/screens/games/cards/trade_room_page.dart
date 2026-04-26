import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../models/tradeable_instance.dart';
import '../../../services/session_store.dart';
import '../../../services/trade_api_service.dart';
import '../../../services/user_wallet_api_service.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_game_ui_theme.dart';
import 'trade_slot_picker_page.dart';

/// Pacwyn-inspired online trade chrome (dark + neon accents).
abstract final class _TradeRoomVisual {
  static const Color bg = Color(0xFF0B0B10);
  static const Color panel = Color(0xFF16161F);
  static const Color panelLine = Color(0xFF2A2A38);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color cyan = Color(0xFF00D4FF);
  static const Color gold = Color(0xFFFFD700);
  static const Color onMuted = Color(0xFFB8B8C8);
}

/// Preset quick chat lines (server stores `preset` key only).
abstract final class _TradeQuickPhrases {
  static const List<String> presetsInOrder = [
    'hello',
    'cards_only',
    'coins_only',
    'how_much',
    'make_offer',
    'look_wishlist',
    'sorry_no_match',
    'more_coins',
  ];

  static const Map<String, String> phrase = {
    'hello': 'Hello',
    'cards_only': 'I only need cards',
    'coins_only': 'I only need coins',
    'how_much': 'How much do you want?',
    'make_offer': 'Make your offer',
    'look_wishlist': 'Look at my wishlist',
    'sorry_no_match': "Sorry, I don't have what you want",
    'more_coins': 'Please add more coins',
  };

  static bool isValid(String preset) => phrase.containsKey(preset);

  static String textFor(String preset) => phrase[preset] ?? preset;
}

class TradeRoomPage extends StatefulWidget {
  const TradeRoomPage({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<TradeRoomPage> createState() => _TradeRoomPageState();
}

class _TradeRoomPageState extends State<TradeRoomPage>
    with SingleTickerProviderStateMixin {
  final _api = TradeApiService();
  final _walletApi = UserWalletApiService();
  Timer? _poll;
  Map<String, dynamic>? _state;
  String? _error;
  List<TradeableInstance>? _tradeable;
  bool _readyBusy = false;
  bool _autoSummaryOpened = false;
  bool _summaryRouteOpen = false;
  int? _myUid;
  late final AnimationController _pulse;

  /// After we finalize, partner may complete the trade; next 404 is treated as success, not "left".
  bool _awaitingCompleted404 = false;
  int? _cardCoins;
  bool _walletLoading = true;

  final _coinsCtrl = TextEditingController(text: '0');
  final _coinsFocus = FocusNode();
  Timer? _coinsDebounce;
  bool _suppressCoinsListener = false;

  Timer? _quickMsgBubbleTimer;
  int? _bubbleFromUserId;
  String? _bubblePreset;
  String? _bubbleFromUsername;
  String? _lastQuickMsgSignature;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _coinsCtrl.addListener(_onCoinsTextChanged);
    _refresh();
    _loadWallet();
    _poll = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _quickMsgBubbleTimer?.cancel();
    _coinsDebounce?.cancel();
    _coinsCtrl.removeListener(_onCoinsTextChanged);
    _coinsCtrl.dispose();
    _coinsFocus.dispose();
    _poll?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _onCoinsTextChanged() {
    if (_suppressCoinsListener) return;
    _coinsDebounce?.cancel();
    _coinsDebounce = Timer(
      const Duration(milliseconds: 650),
      _flushCoinsToServer,
    );
  }

  Future<void> _flushCoinsToServer() async {
    if (!mounted) return;
    if (_iAmReady()) return;
    var v = int.tryParse(_coinsCtrl.text.trim());
    v ??= 0;
    final maxC = _cardCoins ?? 999999999;
    if (v < 0) v = 0;
    if (v > maxC) v = maxC;
    if (_suppressCoinsListener) return;
    final uid = await _userId();
    try {
      await _api.putTradeCoins(code: widget.roomCode, userId: uid, coins: v);
      await _refresh(silent: true);
    } on TradeApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {}
  }

  void _syncCoinsControllerFromState() {
    if (_coinsFocus.hasFocus) return;
    final c = _state?['your_coins'];
    final v = c is int ? c : int.tryParse(c?.toString() ?? '') ?? 0;
    final t = '$v';
    if (_coinsCtrl.text != t) {
      _suppressCoinsListener = true;
      _coinsCtrl.text = t;
      _suppressCoinsListener = false;
    }
  }

  List<String?> _parseSlotReactions(dynamic list) {
    final out = <String?>[null, null, null];
    if (list is! List) return out;
    for (var i = 0; i < 3 && i < list.length; i++) {
      final v = list[i];
      if (v == null) continue;
      final s = v.toString().toLowerCase();
      if (s == 'up' || s == 'down') out[i] = s;
    }
    return out;
  }

  Future<void> _setPeerSlotReaction(int slotIndex, String vote) async {
    final cur = _parseSlotReactions(
      _state?['your_reactions_on_peer_slots'],
    )[slotIndex];
    final next = cur == vote ? 'clear' : vote;
    final uid = await _userId();
    try {
      await _api.postSlotReaction(
        code: widget.roomCode,
        userId: uid,
        slotIndex: slotIndex,
        reaction: next,
      );
      await _refresh(silent: true);
    } on TradeApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<int> _userId() async {
    final s = await SessionStore.instance.load();
    return s?.userId ?? BackendConfig.devUserId;
  }

  Future<void> _loadWallet() async {
    setState(() => _walletLoading = true);
    final userId = await _userId();
    try {
      final w = await _walletApi.fetchWallet(userId: userId);
      if (mounted) {
        setState(() {
          _cardCoins = w.cardCoins;
          _walletLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cardCoins ??= 0;
          _walletLoading = false;
        });
      }
    }
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
    return _mapFlag(_state?['ready_confirm'], me) &&
        _mapFlag(_state?['ready_confirm'], peer);
  }

  bool _iAmReady() =>
      _myUid != null && _mapFlag(_state?['ready_confirm'], _myUid!);
  bool _peerReady() {
    final p = _peerUserId();
    return p != null && _mapFlag(_state?['ready_confirm'], p);
  }

  String? _summaryChoiceForUid(int? uid) {
    if (uid == null) return null;
    final m = _state?['summary_choice'];
    if (m is! Map) return null;
    final k = uid.toString();
    final v = m[k] ?? m[uid];
    if (v == null) return null;
    return v.toString().toLowerCase();
  }

  String? _mySummaryChoice() => _summaryChoiceForUid(_myUid);
  String? _peerSummaryChoice() => _summaryChoiceForUid(_peerUserId());

  void _scheduleSummaryDialogIfNeeded() {
    if (!mounted) return;
    if (!_bothLockedIn() || _peerUserId() == null) {
      _autoSummaryOpened = false;
      return;
    }
    if (_autoSummaryOpened || _summaryRouteOpen) return;
    _autoSummaryOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_bothLockedIn() || _peerUserId() == null) {
        _autoSummaryOpened = false;
        return;
      }
      if (_summaryRouteOpen) {
        _autoSummaryOpened = false;
        return;
      }
      unawaited(_showTradeSummaryDialog());
    });
  }

  void _syncQuickMessageBubble() {
    if (!mounted) return;
    final m = _state?['last_quick_message'];
    if (m is! Map) {
      return;
    }
    final fromRaw = m['from_user_id'] ?? m['fromUserId'];
    final from = fromRaw is int ? fromRaw : int.tryParse(fromRaw?.toString() ?? '');
    final preset = m['preset']?.toString();
    final sentRaw = m['sent_at'] ?? m['sentAt'];
    final sent = sentRaw is int ? sentRaw : int.tryParse(sentRaw?.toString() ?? '');
    final name =
        m['from_username']?.toString() ?? m['fromUsername']?.toString() ?? 'Player';
    if (from == null || preset == null || sent == null) return;
    if (!_TradeQuickPhrases.isValid(preset)) return;
    final ageMs = DateTime.now().millisecondsSinceEpoch - sent;
    if (ageMs < 0 || ageMs > 12000) return;

    final sig = '$from-$sent-$preset';
    if (sig == _lastQuickMsgSignature) return;
    _lastQuickMsgSignature = sig;

    _quickMsgBubbleTimer?.cancel();
    setState(() {
      _bubbleFromUserId = from;
      _bubblePreset = preset;
      _bubbleFromUsername = name;
    });
    _quickMsgBubbleTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _bubbleFromUserId = null;
        _bubblePreset = null;
        _bubbleFromUsername = null;
      });
    });
  }

  Future<void> _showQuickMessagePicker() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(210),
      builder: (ctx) {
        final maxW = min(400.0, MediaQuery.sizeOf(context).width - 28);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: Container(
            width: maxW,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
            decoration: BoxDecoration(
              color: _TradeRoomVisual.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _TradeRoomVisual.cyan.withAlpha(110),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Quick message',
                        style: TextStyle(
                          color: CardGameUiTheme.onDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: CardGameUiTheme.onDark,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 10),
                  child: Text(
                    'Tap a line — it appears next to your side for your partner.',
                    style: TextStyle(
                      color: CardGameUiTheme.onDark.withAlpha(150),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _TradeQuickPhrases.presetsInOrder.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 72,
                  ),
                  itemBuilder: (context, i) {
                    final preset = _TradeQuickPhrases.presetsInOrder[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            final uid = await _userId();
                            await _api.postQuickMessage(
                              code: widget.roomCode,
                              userId: uid,
                              preset: preset,
                            );
                            if (mounted) await _refresh(silent: true);
                          } on TradeApiException catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(100),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _TradeRoomVisual.panelLine.withAlpha(200),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Center(
                              child: Text(
                                _TradeQuickPhrases.textFor(preset),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CardGameUiTheme.onDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _syncPulseAnimation() {
    if (!mounted) return;
    final waitingPeerLock =
        _iAmReady() && !_peerReady() && _peerUserId() != null;
    final waitingPeerAccept = _bothLockedIn() &&
        _peerUserId() != null &&
        _mySummaryChoice() == 'accept' &&
        _peerSummaryChoice() != 'accept';
    final show = waitingPeerLock || waitingPeerAccept;
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
      _syncCoinsControllerFromState();
      _syncPulseAnimation();
      _scheduleSummaryDialogIfNeeded();
      _syncQuickMessageBubble();
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

  Future<void> _loadTradeable() async {
    final uid = await _userId();
    final list = await _api.tradeableInstances(userId: uid);
    if (mounted) setState(() => _tradeable = list);
  }

  Future<void> _onTradeCompleted() async {
    _poll?.cancel();
    if (!mounted) return;
    setState(() => _awaitingCompleted404 = false);
    await _loadWallet();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trade complete'),
        content: const Text('Cards and agreed coins have been exchanged.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _lockInOffer() async {
    setState(() => _readyBusy = true);
    try {
      final uid = await _userId();
      final status = await _api.confirmReady(
        code: widget.roomCode,
        userId: uid,
      );
      if (!mounted) return;
      if (status == 'both_ready') {
        await _refresh();
      } else {
        await _refresh();
      }
    } on TradeApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _readyBusy = false);
    }
  }

  Future<void> _unconfirmOffer() async {
    setState(() => _readyBusy = true);
    try {
      final uid = await _userId();
      await _api.postUnconfirm(code: widget.roomCode, userId: uid);
      if (!mounted) return;
      await _refresh();
    } on TradeApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _readyBusy = false);
    }
  }

  Future<void> _showTradeSummaryDialog() async {
    if (!mounted || !_bothLockedIn() || _summaryRouteOpen) return;
    _summaryRouteOpen = true;
    var dialogBusy = false;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              Future<void> pick(String choice) async {
                if (dialogBusy) return;
                dialogBusy = true;
                setLocal(() {});
                try {
                  final uid = await _userId();
                  final status = await _api.postSummaryChoice(
                    code: widget.roomCode,
                    userId: uid,
                    choice: choice,
                  );
                  if (!ctx.mounted) return;
                  if (status == 'returned_to_trading') {
                    Navigator.of(ctx).pop();
                    await _refresh();
                    return;
                  }
                  if (status == 'waiting_peer_accept') {
                    Navigator.of(ctx).pop();
                    if (mounted) {
                      setState(() => _awaitingCompleted404 = true);
                      await _refresh();
                    }
                    return;
                  }
                  if (status == 'completed') {
                    Navigator.of(ctx).pop();
                    await _onTradeCompleted();
                    return;
                  }
                  await _refresh();
                } on TradeApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                } finally {
                  dialogBusy = false;
                  if (ctx.mounted) setLocal(() {});
                }
              }

              final yourCoins = _state?['your_coins'];
              final peerCoins = _state?['peer_coins'];
              final yc = yourCoins is int
                  ? yourCoins
                  : int.tryParse(yourCoins?.toString() ?? '') ?? 0;
              final pc = peerCoins is int
                  ? peerCoins
                  : int.tryParse(peerCoins?.toString() ?? '') ?? 0;

              return AlertDialog(
                backgroundColor: _TradeRoomVisual.panel,
                title: const Text(
                  'Trade summary',
                  style: TextStyle(color: CardGameUiTheme.onDark),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'You give: $yc card coins and the cards in your slots.\n'
                        'They give: $pc card coins and the cards in their slots.',
                        style: TextStyle(
                          color: CardGameUiTheme.onDark.withAlpha(220),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Both must tap Accept to complete. Modify sends you both back to edit offers.',
                        style: TextStyle(
                          color: CardGameUiTheme.onDark.withAlpha(160),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: dialogBusy ? null : () => pick('modify'),
                    child: const Text('Modify'),
                  ),
                  FilledButton(
                    onPressed: dialogBusy ? null : () => pick('accept'),
                    child: dialogBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      _summaryRouteOpen = false;
      if (mounted) setState(() {});
    }
  }

  void _showPeerWishlist() {
    final raw = _state?['peer_wishlist'];
    if (raw is! List || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cards on their wishlist (or still connecting).'),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) rows.add(Map<String, dynamic>.from(e));
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(210),
      builder: (ctx) => _PeerWishlistTradeGridDialog(
        peerUsername: _state?['peer_username']?.toString() ?? 'Player',
        rows: rows,
        onCardTap: (cardId) async {
          final ok = await _tryAddWishlistCardToOffer(cardId, messenger);
          if (ok && ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  /// Returns `true` when a card was added to the offer successfully.
  Future<bool> _tryAddWishlistCardToOffer(
    int cardId,
    ScaffoldMessengerState messenger,
  ) async {
    if (cardId <= 0) return false;
    if (_iAmReady()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Remove your confirmation before changing your offer.'),
        ),
      );
      return false;
    }
    if (_alreadyOfferingCard(cardId)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That card is already in your offer.')),
      );
      return false;
    }
    await _loadTradeable();
    if (!mounted) return false;
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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('All your slots are full. Clear a slot first.'),
        ),
      );
      return false;
    }
    TradeableInstance? pick;
    for (final t in _tradeable ?? <TradeableInstance>[]) {
      if (t.cardId == cardId && !used.contains(t.cardInstanceId)) {
        pick = t;
        break;
      }
    }
    if (pick == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No duplicate instance available for that card.'),
        ),
      );
      return false;
    }
    final uid = await _userId();
    final slots = List<int?>.from(current);
    slots[emptyIndex] = pick.cardInstanceId;
    try {
      await _api.putOffer(code: widget.roomCode, userId: uid, slots: slots);
      if (mounted) setState(() => _awaitingCompleted404 = false);
      await _refresh();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Added ${pick.label} to slot ${emptyIndex + 1}.'),
          ),
        );
      }
      return true;
    } on TradeApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    }
  }

  Future<void> _pickSlotFixed(int index) async {
    if (_iAmReady()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remove your confirmation before changing slots.'),
        ),
      );
      return;
    }
    final current = _parseInstanceSlots(_state?['your_slots']);
    final used = <int>{};
    for (var i = 0; i < 3; i++) {
      if (i != index && current[i] != null) used.add(current[i]!);
    }

    final result = await Navigator.of(context).push<TradeSlotPickerResult?>(
      MaterialPageRoute<TradeSlotPickerResult?>(
        builder: (_) => TradeSlotPickerPage(
          slotIndex: index,
          excludedInstanceIds: Set<int>.from(used),
        ),
      ),
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
    final yourName = _state?['your_username']?.toString() ?? 'You';
    final yourMsg = _state?['your_msg']?.toString() ?? 'Best cards Please';
    final peerMsg = _state?['peer_msg']?.toString() ?? '';
    final peerOnYou = _parseSlotReactions(
      _state?['peer_reactions_on_your_slots'],
    );
    final youOnPeer = _parseSlotReactions(
      _state?['your_reactions_on_peer_slots'],
    );
    final peerCoinsRaw = _state?['peer_coins'];
    final peerCoins = peerCoinsRaw is int
        ? peerCoinsRaw
        : int.tryParse(peerCoinsRaw?.toString() ?? '') ?? 0;

    final waitingPeerLock =
        _iAmReady() && !_peerReady() && _peerUserId() != null;
    final waitingPeerAccept = _bothLockedIn() &&
        _peerUserId() != null &&
        _mySummaryChoice() == 'accept' &&
        _peerSummaryChoice() != 'accept';
    final showPulse = waitingPeerLock || waitingPeerAccept;    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        backgroundColor: _TradeRoomVisual.bg,
        appBar: AppBar(
          backgroundColor: _TradeRoomVisual.bg,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: _handlePop,
            icon: const Icon(Icons.close_rounded),
            color: CardGameUiTheme.onDark,
          ),
          title: Text(
            'ONLINE TRADING',
            style: TextStyle(
              color: CardGameUiTheme.onDark.withAlpha(230),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: 1.2,
            ),
          ),
          actions: [
            Icon(
              Icons.monetization_on_rounded,
              size: 20,
              color: _TradeRoomVisual.gold,
            ),
            const SizedBox(width: 4),
            Text(
              _walletLoading ? '…' : '${_cardCoins ?? 0}',
              style: const TextStyle(
                color: _TradeRoomVisual.gold,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            IconButton(
              onPressed: () async {
                await _refresh();
                await _loadWallet();
              },
              icon: const Icon(Icons.refresh_rounded),
              color: CardGameUiTheme.onDark,
            ),
          ],
        ),
        body: SafeArea(
          child: _error != null && _state == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _TradePlayerColumn(
                                    alignEnd: true,
                                    accentName: _TradeRoomVisual.cyan,
                                    playerName: peerName ?? 'Waiting…',
                                    message: peerMsg.isEmpty ? '—' : peerMsg,
                                    slots: theirSlots,
                                    reactions: youOnPeer,
                                    reactionsInteractive:
                                        peerName != null && !_iAmReady(),
                                    onVoteSlot: _setPeerSlotReaction,
                                    onSlotTap: null,
                                    coinLabel: 'OPPONENT GIVES COINS',
                                    peerCoinsText: '$peerCoins',
                                    sideConfirmed:
                                        peerName != null && _peerReady(),
                                  ),
                                  if (_bubblePreset != null &&
                                      _bubbleFromUserId != null &&
                                      _bubbleFromUserId == _peerUserId())
                                    Positioned(
                                      left: 8,
                                      right: 8,
                                      bottom: 6,
                                      child: _TradeQuickChatBubble(
                                        senderLabel:
                                            '${_bubbleFromUsername ?? 'Player'} · quick message',
                                        message: _TradeQuickPhrases.textFor(
                                          _bubblePreset!,
                                        ),
                                        accentPeerSide: true,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          _TradeCenterRail(
                            onWishlist:
                                peerName == null ? null : _showPeerWishlist,
                            onMessage: _showQuickMessagePicker,
                          ),
                          const SizedBox(height: 2),

                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _TradePlayerColumn(
                                    alignEnd: false,
                                    accentName: _TradeRoomVisual.neonGreen,
                                    playerName: yourName,
                                    message: yourMsg,
                                    slots: yourSlots,
                                    reactions: peerOnYou,
                                    reactionsInteractive: false,
                                    onVoteSlot: null,
                                    onSlotTap: _iAmReady()
                                        ? null
                                        : (i) => _pickSlotFixed(i),
                                    coinLabel: 'YOU GIVE COINS',
                                    coinsEditor: IgnorePointer(
                                      ignoring: _iAmReady(),
                                      child: TextField(
                                        controller: _coinsCtrl,
                                        focusNode: _coinsFocus,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: CardGameUiTheme.onDark,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        cursorColor: _TradeRoomVisual.gold,
                                        decoration:
                                            _tradeCoinInputDecoration(),
                                      ),
                                    ),
                                    sideConfirmed: _iAmReady(),
                                    onUnconfirm: peerName != null && _iAmReady()
                                        ? _unconfirmOffer
                                        : null,
                                  ),
                                  if (_bubblePreset != null &&
                                      _bubbleFromUserId != null &&
                                      _bubbleFromUserId == _myUid)
                                    Positioned(
                                      left: 8,
                                      right: 8,
                                      top: 4,
                                      child: _TradeQuickChatBubble(
                                        senderLabel: 'You · quick message',
                                        message: _TradeQuickPhrases.textFor(
                                          _bubblePreset!,
                                        ),
                                        accentPeerSide: false,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showPulse)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _pulse,
                            curve: Curves.easeInOut,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _TradeRoomVisual.panel,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _TradeRoomVisual.cyan.withAlpha(90),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _TradeRoomVisual.cyan,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    waitingPeerAccept
                                        ? 'You accepted — waiting for partner…'
                                        : 'You locked in — waiting for partner…',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: CardGameUiTheme.onDark,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),

                      child: _TradeConfirmBar(
                        bothLocked: _bothLockedIn(),
                        readyBusy: _readyBusy,
                        iAmReady: _iAmReady(),
                        peerReady: _peerReady(),
                        peerPresent: peerName != null,
                        onLockIn: _lockInOffer,
                        onOpenSummary: _showTradeSummaryDialog,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                      child: Text(
                        'Close (top left) ends the trade for both. Only duplicate cards can be offered.',
                        style: TextStyle(
                          color: CardGameUiTheme.onDark.withAlpha(120),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }


  InputDecoration _tradeCoinInputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: _TradeRoomVisual.panel,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: _TradeRoomVisual.panelLine.withAlpha(220),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _TradeRoomVisual.gold, width: 1.4),
      ),
    );
  }
}

typedef _TradeVoteCallback = Future<void> Function(int slotIndex, String vote);

class _TradePlayerColumn extends StatelessWidget {
  const _TradePlayerColumn({
    required this.alignEnd,
    required this.accentName,
    required this.playerName,
    required this.message,
    required this.slots,
    required this.reactions,
    required this.reactionsInteractive,
    this.onVoteSlot,
    this.onSlotTap,
    required this.coinLabel,
    this.coinsEditor,
    this.peerCoinsText,
    this.sideConfirmed = false,
    this.onUnconfirm,
  });

  final bool alignEnd;
  final Color accentName;
  final String playerName;
  final String message;
  final dynamic slots;
  final List<String?> reactions;
  final bool reactionsInteractive;
  final _TradeVoteCallback? onVoteSlot;
  final void Function(int slotIndex)? onSlotTap;
  final String coinLabel;
  final Widget? coinsEditor;
  final String? peerCoinsText;
  final bool sideConfirmed;
  final VoidCallback? onUnconfirm;

  Map<String, dynamic>? _slotMap(dynamic el) {
    if (el is Map) return Map<String, dynamic>.from(el);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),

          decoration: BoxDecoration(
            color: _TradeRoomVisual.panel.withAlpha(200),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _TradeRoomVisual.panelLine.withAlpha(180)),
          ),
          child: Column(
            crossAxisAlignment: alignEnd
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
            Text(
              playerName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accentName,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.4,
              ),
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

            decoration: BoxDecoration(
              color: Colors.black.withAlpha(90),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _TradeRoomVisual.panelLine.withAlpha(160),
              ),
            ),
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(210),
                fontSize: 11,
                height: 1.2,
              ),
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            ),
          ),
          const SizedBox(height: 3),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 3,
                      right: i == 2 ? 0 : 3,
                    ),
                    child: _TradeSlotRow(
                      slotMap: slots is List && i < slots.length
                          ? _slotMap(slots[i])
                          : null,
                      reaction: i < reactions.length ? reactions[i] : null,
                      reactionsInteractive: reactionsInteractive,
                      onVoteUp: reactionsInteractive && onVoteSlot != null
                          ? () => onVoteSlot!(i, 'up')
                          : null,
                      onVoteDown: reactionsInteractive && onVoteSlot != null
                          ? () => onVoteSlot!(i, 'down')
                          : null,
                      onSlotTap: onSlotTap != null ? () => onSlotTap!(i) : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),

          Text(
            coinLabel,
            style: TextStyle(
              color: _TradeRoomVisual.onMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 2),

          if (coinsEditor != null)
            coinsEditor!
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),

              decoration: BoxDecoration(
                color: Colors.black.withAlpha(100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _TradeRoomVisual.panelLine.withAlpha(160),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: _TradeRoomVisual.gold,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    peerCoinsText ?? '0',
                    style: const TextStyle(
                      color: CardGameUiTheme.onDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
        if (sideConfirmed)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _TradeRoomVisual.neonGreen.withAlpha(34),
                ),
              ),
            ),
          ),
        if (onUnconfirm != null && sideConfirmed)
          Positioned(
            top: 6,
            left: alignEnd ? null : 8,
            right: alignEnd ? 8 : null,
            child: Material(
              color: Colors.black.withAlpha(200),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onUnconfirm,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Text(
                    'Remove confirmation',
                    style: TextStyle(
                      color: CardGameUiTheme.onDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TradeSlotRow extends StatelessWidget {
  const _TradeSlotRow({
    required this.slotMap,
    required this.reaction,
    required this.reactionsInteractive,
    this.onVoteUp,
    this.onVoteDown,
    this.onSlotTap,
  });

  final Map<String, dynamic>? slotMap;
  final String? reaction;
  final bool reactionsInteractive;
  final VoidCallback? onVoteUp;
  final VoidCallback? onVoteDown;
  final VoidCallback? onSlotTap;

  @override
  Widget build(BuildContext context) {
    final hasCard = slotMap != null;
    final cardId = hasCard
        ? int.tryParse(slotMap!['card_id']?.toString() ?? '') ?? 0
        : 0;

    final slot = LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = w * 1.4;
        return SizedBox(
          width: w,
          height: h,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSlotTap,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasCard
                        ? _TradeRoomVisual.gold.withAlpha(140)
                        : _TradeRoomVisual.panelLine,
                    width: hasCard ? 1.4 : 1,
                  ),
                  color: Colors.black.withAlpha(120),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: !hasCard
                      ? Center(
                          child: Text(
                            onSlotTap != null ? '+\nTap' : '—',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CardGameUiTheme.onDark.withAlpha(100),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        )
                        : BundledPlayCardImage(
                            cardId: cardId,
                            fit: BoxFit.contain,

                          errorPlaceholder: Center(
                            child: Text(
                              '#$cardId',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );

    final reactionRow = !hasCard
        ? const SizedBox.shrink()
        : _TradeReactionColumn(
            interactive: reactionsInteractive,
            state: reaction,
            onUp: onVoteUp,
            onDown: onVoteDown,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        slot,
        if (hasCard) ...[
          const SizedBox(height: 2),

          Center(child: reactionRow),
        ],
      ],
    );
  }
}

class _TradeReactionColumn extends StatelessWidget {
  const _TradeReactionColumn({
    required this.interactive,
    required this.state,
    this.onUp,
    this.onDown,
  });

  final bool interactive;
  final String? state;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    if (!interactive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.thumb_up_alt_outlined,
            size: 16,
            color: state == 'up'
                ? _TradeRoomVisual.neonGreen
                : Colors.white24,
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.thumb_down_alt_outlined,
            size: 16,
            color: state == 'down' ? const Color(0xFFFF4444) : Colors.white24,
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundThumb(selected: state == 'up', positive: true, onTap: onUp),
        const SizedBox(width: 8),
        _RoundThumb(
          selected: state == 'down',
          positive: false,
          onTap: onDown,
        ),
      ],
    );
  }
}

class _RoundThumb extends StatelessWidget {
  const _RoundThumb({
    required this.selected,
    required this.positive,
    required this.onTap,
  });

  final bool selected;
  final bool positive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = positive
        ? _TradeRoomVisual.neonGreen
        : const Color(0xFFFF4444);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? active : Colors.white38,
              width: selected ? 2 : 1.1,
            ),
            color: selected ? active.withAlpha(55) : Colors.black.withAlpha(80),
          ),
          child: Icon(
            positive
                ? Icons.thumb_up_alt_rounded
                : Icons.thumb_down_alt_rounded,
            size: 14,
            color: selected ? active : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _TradeCenterRail extends StatelessWidget {
  const _TradeCenterRail({required this.onWishlist, required this.onMessage});

  final VoidCallback? onWishlist;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PillAction(
            color: _TradeRoomVisual.gold,
            icon: Icons.grid_view_rounded,
            onTap: onWishlist,
            dimmed: onWishlist == null,
          ),
          const SizedBox(width: 20),
          _PillAction(
            color: _TradeRoomVisual.cyan,
            icon: Icons.chat_bubble_outline_rounded,
            onTap: onMessage,
            dimmed: false,
          ),
        ],
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.color,
    required this.icon,
    required this.onTap,
    required this.dimmed,
  });

  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = dimmed ? color.withAlpha(90) : color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: dimmed ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: c.withAlpha(dimmed ? 40 : 100),
            border: Border.all(
              color: c.withAlpha(dimmed ? 60 : 200),
              width: 1.4,
            ),
            boxShadow: dimmed
                ? null
                : [
                    BoxShadow(
                      color: c.withAlpha(70),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: Icon(
            icon,
            color: dimmed ? Colors.white38 : Colors.black87,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Two-column scrollable grid: peer wishlist + how many you own / whether you can trade.
class _PeerWishlistTradeGridDialog extends StatelessWidget {
  const _PeerWishlistTradeGridDialog({
    required this.peerUsername,
    required this.rows,
    required this.onCardTap,
  });

  final String peerUsername;
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(int cardId) onCardTap;

  static int _ownCount(Map<String, dynamic> row) {
    final v = row['you_own_count'] ?? row['youOwnCount'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  static bool _canTrade(Map<String, dynamic> row) {
    final d = row['you_have_duplicate'];
    return d == true || d == 't';
  }

  static int _overall(Map<String, dynamic> row) {
    final v = row['overall'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.78;
    final w = min(520.0, MediaQuery.sizeOf(context).width - 16);
    final sorted = List<Map<String, dynamic>>.from(rows)
      ..sort((a, b) => _overall(b).compareTo(_overall(a)));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: CardGameUiTheme.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: CardGameUiTheme.gold.withAlpha(100),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: CardGameUiTheme.orangeGlow.withAlpha(50),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$peerUsername\'s wishlist',
                          style: const TextStyle(
                            color: CardGameUiTheme.onDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'You own counts include all copies. Tap when you have 2+ to trade.',
                          style: TextStyle(
                            color: CardGameUiTheme.onDark.withAlpha(150),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: CardGameUiTheme.onDark,
                  ),
                ],
              ),
            ),
            Expanded(
              child: sorted.isEmpty
                  ? Center(
                      child: Text(
                        'No wishlist cards.',
                        style: TextStyle(
                          color: CardGameUiTheme.onDark.withAlpha(180),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: sorted.length,
                      itemBuilder: (context, i) {
                        final row = sorted[i];
                        final cardId =
                            int.tryParse(row['card_id']?.toString() ?? '') ?? 0;
                        final fn = row['first_name']?.toString() ?? '';
                        final ln = row['last_name']?.toString() ?? '';
                        final name = '$fn $ln'.trim().isEmpty
                            ? 'Card #$cardId'
                            : '$fn $ln'.trim();
                        final own = _ownCount(row);
                        final can = _canTrade(row);
                        return _WishlistTradeTile(
                          cardId: cardId,
                          name: name,
                          overall: _overall(row),
                          ownCount: own,
                          canTrade: can,
                          onTap: can
                              ? () async {
                                  await onCardTap(cardId);
                                }
                              : null,
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

class _WishlistTradeTile extends StatelessWidget {
  const _WishlistTradeTile({
    required this.cardId,
    required this.name,
    required this.overall,
    required this.ownCount,
    required this.canTrade,
    this.onTap,
  });

  final int cardId;
  final String name;
  final int overall;
  final int ownCount;
  final bool canTrade;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: canTrade ? 1 : 0.55,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CardGameUiTheme.gold.withAlpha(canTrade ? 100 : 45),
                width: 1.2,
              ),
              boxShadow: [
                if (canTrade)
                  BoxShadow(
                    color: CardGameUiTheme.orangeGlow.withAlpha(30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: BundledPlayCardImage(
                    cardId: cardId,
                    fit: BoxFit.cover,
                    errorPlaceholder: ColoredBox(
                      color: CardGameUiTheme.panel,
                      child: Center(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CardGameUiTheme.onDark.withAlpha(170),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    elevation: 3,
                    color: ownCount >= 2
                        ? CardGameUiTheme.orangeGlow
                        : Colors.black.withAlpha(170),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '×$ownCount',
                        style: TextStyle(
                          color: ownCount >= 2 ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 22, 6, 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(220),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'OVR $overall · Own $ownCount${canTrade ? '' : ' · need 2+'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: canTrade
                                ? Colors.greenAccent
                                : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TradeConfirmBar extends StatelessWidget {
  const _TradeConfirmBar({
    required this.bothLocked,
    required this.readyBusy,
    required this.iAmReady,
    required this.peerReady,
    required this.peerPresent,
    required this.onLockIn,
    required this.onOpenSummary,
  });

  final bool bothLocked;
  final bool readyBusy;
  final bool iAmReady;
  final bool peerReady;
  final bool peerPresent;
  final VoidCallback onLockIn;
  final Future<void> Function() onOpenSummary;

  String _label() {
    if (!bothLocked) {
      if (!peerPresent) return 'WAITING…';
      if (iAmReady && !peerReady) return 'WAITING FOR PARTNER';
      if (iAmReady) return 'LOCKED IN';
      return 'CONFIRM';
    }
    return 'OPEN SUMMARY';
  }

  VoidCallback? _onPressed() {
    if (!bothLocked) {
      if (readyBusy || !peerPresent || iAmReady) return null;
      return onLockIn;
    }
    if (readyBusy) return null;
    return () {
      unawaited(onOpenSummary());
    };
  }

  @override
  Widget build(BuildContext context) {
    final busy = readyBusy;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _TradeRoomVisual.neonGreen, width: 2),
        color: _TradeRoomVisual.panel.withAlpha(180),
      ),
      child: TextButton(
        onPressed: _onPressed(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          foregroundColor: _TradeRoomVisual.neonGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: busy
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _TradeRoomVisual.neonGreen,
                ),
              )
            : Text(
                _label(),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.4,
                ),
              ),
      ),
    );
  }
}

class _TradeQuickChatBubble extends StatelessWidget {
  const _TradeQuickChatBubble({
    required this.senderLabel,
    required this.message,
    required this.accentPeerSide,
  });

  final String senderLabel;
  final String message;
  final bool accentPeerSide;

  @override
  Widget build(BuildContext context) {
    final accent =
        accentPeerSide ? _TradeRoomVisual.cyan : _TradeRoomVisual.neonGreen;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _TradeRoomVisual.panel.withAlpha(252),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withAlpha(200), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(140),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 17, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    senderLabel.toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: CardGameUiTheme.onDark,
                fontWeight: FontWeight.w600,
                height: 1.35,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
