import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../models/cards_squad.dart';
import '../../../services/one_v_one_api_service.dart';
import '../../../services/session_store.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_game_ui_theme.dart';
import 'squad_halfcourt_board.dart';

class OneVOneRoomPage extends StatefulWidget {
  const OneVOneRoomPage({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<OneVOneRoomPage> createState() => _OneVOneRoomPageState();
}

class _OneVOneRoomPageState extends State<OneVOneRoomPage> with SingleTickerProviderStateMixin {
  final _api = OneVOneApiService();
  Timer? _poll;
  Timer? _tick;
  Map<String, dynamic>? _state;
  String? _error;
  int? _myUid;
  late final AnimationController _revealPulse;

  @override
  void initState() {
    super.initState();
    _revealPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _loadUser();
    _refresh();
    _poll = Timer.periodic(const Duration(milliseconds: 1200), (_) => _refresh(silent: true));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _state?['phase'] == 'pick_squad') setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _revealPulse.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final s = await SessionStore.instance.load();
    if (!mounted) return;
    setState(() => _myUid = s?.userId ?? BackendConfig.devUserId);
  }

  Future<int> _userId() async {
    final s = await SessionStore.instance.load();
    return s?.userId ?? BackendConfig.devUserId;
  }

  Future<void> _refresh({bool silent = false}) async {
    final uid = _myUid ?? await _userId();
    if (_myUid == null && mounted) setState(() => _myUid = uid);
    try {
      final st = await _api.getRoomState(code: widget.roomCode, userId: uid);
      if (!mounted) return;
      setState(() {
        _state = st;
        _error = null;
      });
    } on OneVOneApiException catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _error = '$e');
    }
  }

  Future<void> _leave() async {
    final uid = await _userId();
    try {
      await _api.leaveRoom(code: widget.roomCode, userId: uid);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  int _intMap(Map<dynamic, dynamic>? m, int uid) {
    if (m == null) return 0;
    final v = m['$uid'] ?? m[uid];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  int? _pickSecondsLeft() {
    final s = _state;
    if (s == null) return null;
    final d = s['squad_pick_deadline'];
    if (d == null) return null;
    final t = int.tryParse(d.toString()) ?? 0;
    final left = ((t - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    return left.clamp(0, 99);
  }

  CardsSquadPayload? _parseMySquad() {
    final raw = _state?['my_squad'];
    if (raw is! Map<String, dynamic>) return null;
    final inner = raw['squad'];
    if (inner is! Map<String, dynamic>) return null;
    try {
      return CardsSquadPayload.fromJson(inner);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickSquad(int n) async {
    final uid = await _userId();
    setState(() => _error = null);
    try {
      await _api.postSquadPick(code: widget.roomCode, userId: uid, squadNumber: n);
      await _refresh();
    } on OneVOneApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _onSlotBattleTap(String slot) async {
    final uid = await _userId();
    if (!mounted) return;
    final s = _state;
    if (s == null) return;
    if (s['is_my_lead_turn'] != true && s['is_my_respond_turn'] != true) return;
    if (s['is_my_lead_turn'] == true) {
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: CardGameUiTheme.panel,
          title: const Text('Choose action', style: TextStyle(color: CardGameUiTheme.onDark)),
          content: const Text(
            'Attack compares your ATK to the opponent’s DEF.\nDefend compares their ATK to your DEF.',
            style: TextStyle(color: CardGameUiTheme.onDark, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'attack'),
              child: const Text('Attack', style: TextStyle(color: CardGameUiTheme.gold, fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'defend'),
              child: const Text('Defend', style: TextStyle(color: CardGameUiTheme.gold, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (mode == null || !mounted) return;
      try {
        await _api.postLead(code: widget.roomCode, userId: uid, slot: slot, mode: mode);
        await _refresh();
      } on OneVOneApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (s['is_my_respond_turn'] == true) {
      try {
        await _api.postRespond(code: widget.roomCode, userId: uid, slot: slot);
        await _refresh();
      } on OneVOneApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leave();
      },
      child: Scaffold(
        backgroundColor: CardGameUiTheme.bg,
        appBar: AppBar(
          title: Text('Room ${widget.roomCode}'),
          backgroundColor: CardGameUiTheme.bg,
          foregroundColor: CardGameUiTheme.onDark,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _leave,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _refresh(),
            ),
          ],
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_error != null && _state == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: CardGameUiTheme.onDark)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final s = _state;
    if (s == null) {
      return const Center(child: CircularProgressIndicator(color: CardGameUiTheme.gold));
    }
    final uid = _myUid;
    if (uid == null) {
      return const Center(child: CircularProgressIndicator(color: CardGameUiTheme.gold));
    }
    final phase = s['phase']?.toString() ?? '';
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (phase == 'lobby') _lobbyBody(),
              if (phase == 'need_squads') _needSquadsBody(s),
              if (phase == 'pick_squad') _pickSquadBody(s, uid),
              if (phase == 'locked_squad') ...[
                _lockedSquadBody(),
                if (_parseMySquad() != null) ...[
                  const SizedBox(height: 10),
                  SquadHalfcourtBoard(
                    squad: _parseMySquad()!,
                    readOnly: true,
                    showCombatStats: true,
                  ),
                ],
              ],
              if (phase == 'battle' || phase == 'match_over') ...[
                _scoreboard(s, uid),
                const SizedBox(height: 12),
                if (phase == 'battle') _battleChrome(s, uid),
                if (phase == 'match_over') _matchOverBody(s, uid),
                const SizedBox(height: 8),
                if (_parseMySquad() != null)
                  SquadHalfcourtBoard(
                    squad: _parseMySquad()!,
                    readOnly: phase != 'battle' || s['battle_step'] == 'reveal',
                    showCombatStats: true,
                    onSlotTap: phase == 'battle' && s['battle_step'] != 'reveal' ? _onSlotBattleTap : null,
                  ),
              ],
            ],
          ),
        ),
        if (s['reveal'] is Map<String, dynamic>) _revealOverlay(Map<String, dynamic>.from(s['reveal'] as Map), uid),
      ],
    );
  }

  Widget _scoreboard(Map<String, dynamic> s, int uid) {
    final peer = s['peer_user_id'];
    final peerId = peer is int ? peer : int.tryParse(peer?.toString() ?? '');
    final mrw = s['match_round_wins'];
    final rpw = s['round_point_wins'];
    final mrMap = mrw is Map ? Map<dynamic, dynamic>.from(mrw) : null;
    final rpMap = rpw is Map ? Map<dynamic, dynamic>.from(rpw) : null;
    final myRounds = _intMap(mrMap, uid);
    final peerRounds = peerId != null ? _intMap(mrMap, peerId) : 0;
    final myPts = _intMap(rpMap, uid);
    final peerPts = peerId != null ? _intMap(rpMap, peerId) : 0;
    final names = s['usernames'];
    final nameMap = names is Map ? Map<dynamic, dynamic>.from(names) : const {};
    final myName = nameMap[uid]?.toString() ?? 'You';
    final peerName = peerId != null ? (nameMap[peerId]?.toString() ?? 'Opponent') : '…';

    return Column(
      children: [
        Text(
          'Match (best of 3 rounds) — first to 2 round wins',
          textAlign: TextAlign.center,
          style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(160), fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _scorePill('$myName · rounds', '$myRounds', true)),
            const SizedBox(width: 10),
            Expanded(child: _scorePill('$peerName · rounds', '$peerRounds', false)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'This round — first to 2 points',
          textAlign: TextAlign.center,
          style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(160), fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _scorePill('$myName · points', '$myPts', true)),
            const SizedBox(width: 10),
            Expanded(child: _scorePill('$peerName · points', '$peerPts', false)),
          ],
        ),
      ],
    );
  }

  Widget _scorePill(String title, String value, bool mine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: CardGameUiTheme.panel.withAlpha(240),
        border: Border.all(color: CardGameUiTheme.gold.withAlpha(mine ? 120 : 55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(150), fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: CardGameUiTheme.onDark, fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _battleChrome(Map<String, dynamic> s, int uid) {
    final step = s['battle_step']?.toString() ?? '';
    final ri = s['round_index'];
    final roundLabel = ri != null ? 'Round $ri' : '';
    if (step == 'reveal') return const SizedBox.shrink();
    final waitLead = s['waiting_opponent_lead'] == true;
    final waitResp = s['waiting_opponent_respond'] == true;
    final hint = s['opponent_action_hint'];
    String? hintLine;
    if (hint is Map) {
      final mode = hint['mode']?.toString() ?? '';
      final pos = hint['position']?.toString() ?? '';
      final verb = mode == 'attack' ? 'attacked' : 'defended';
      hintLine = 'Opponent chose to $verb with a $pos — pick a card to ${mode == 'attack' ? 'defend' : 'attack'}.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          roundLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CardGameUiTheme.gold, fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (waitLead)
          _banner('Waiting for opponent to pick a card', Icons.hourglass_top_rounded),
        if (waitResp)
          _banner('Waiting for opponent to answer your pick', Icons.hourglass_top_rounded),
        if (hintLine != null && (s['is_my_respond_turn'] == true)) _banner(hintLine, Icons.visibility_rounded),
        if (s['is_my_lead_turn'] == true)
          _banner('Your turn — tap a card, then choose Attack or Defend.', Icons.touch_app_rounded),
        if (s['is_my_respond_turn'] == true && hintLine == null)
          _banner('Your turn — tap a card to respond.', Icons.touch_app_rounded),
      ],
    );
  }

  Widget _banner(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: CardGameUiTheme.elevated.withAlpha(240),
          border: Border.all(color: CardGameUiTheme.gold.withAlpha(70)),
        ),
        child: Row(
          children: [
            Icon(icon, color: CardGameUiTheme.gold, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w600, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _revealOverlay(Map<String, dynamic> rev, int uid) {
    final leadUid = int.tryParse(rev['lead_uid']?.toString() ?? '') ?? 0;
    final respUid = int.tryParse(rev['respond_uid']?.toString() ?? '') ?? 0;
    final winner = rev['winner_uid'] != null ? int.tryParse(rev['winner_uid'].toString()) : null;
    final tie = rev['tie'] == true;
    final ls = rev['lead_score'];
    final rs = rev['respond_score'];
    final leadCard = int.tryParse(rev['lead_card_id']?.toString() ?? '0') ?? 0;
    final respCard = int.tryParse(rev['respond_card_id']?.toString() ?? '0') ?? 0;
    final lm = rev['lead_mode']?.toString() ?? '';
    final rm = rev['respond_mode']?.toString() ?? '';

    String headline;
    if (tie) {
      headline = 'Tie — no point';
    } else if (winner == uid) {
      headline = 'You win the point!';
    } else {
      headline = 'Opponent wins the point';
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _revealPulse,
        builder: (context, _) {
          final t = 0.92 + _revealPulse.value * 0.06;
          return ColoredBox(
            color: Colors.black.withAlpha(220),
            child: Center(
              child: Transform.scale(
                scale: t,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: CardGameUiTheme.panel,
                    border: Border.all(color: CardGameUiTheme.gold.withAlpha(140), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: CardGameUiTheme.orangeGlow.withAlpha(80),
                        blurRadius: 28,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CardGameUiTheme.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _revealCardColumn(
                            label: leadUid == uid ? 'You ($lm)' : 'Opponent ($lm)',
                            cardId: leadCard,
                            score: ls?.toString() ?? '—',
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('VS', style: TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w900)),
                          ),
                          _revealCardColumn(
                            label: respUid == uid ? 'You ($rm)' : 'Opponent ($rm)',
                            cardId: respCard,
                            score: rs?.toString() ?? '—',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Compared: ${lm == 'attack' ? 'ATK vs DEF' : 'ATK vs DEF'}',
                        style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(160), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _revealCardColumn({required String label, required int cardId, required String score}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BundledPlayCardImage(
            cardId: cardId,
            width: 88,
            height: 108,
            fit: BoxFit.cover,
            errorPlaceholder: ColoredBox(
              color: CardGameUiTheme.panel,
              child: Center(
                child: Text(
                  '#$cardId',
                  style: const TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          score,
          style: const TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ],
    );
  }

  Widget _lobbyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Share this code with your friend:\n${widget.roomCode}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CardGameUiTheme.onDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Waiting for opponent to join…',
          textAlign: TextAlign.center,
          style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(170), fontSize: 14),
        ),
      ],
    );
  }

  Widget _needSquadsBody(Map<String, dynamic> s) {
    final ready = s['squad_ready'];
    final map = ready is Map ? Map<dynamic, dynamic>.from(ready) : const {};
    final uid = _myUid!;
    final ok = map[uid] == true || map['$uid'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ok
              ? 'You have three full squads. Waiting for your opponent to finish all three squads.'
              : 'You need three complete squads (five cards each on squads 1, 2, and 3). Edit squads from the 1v1 hub, then pull to refresh.',
          style: const TextStyle(color: CardGameUiTheme.onDark, height: 1.4),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _refresh,
          child: const Text('I fixed my squads — refresh'),
        ),
      ],
    );
  }

  Widget _pickSquadBody(Map<String, dynamic> s, int uid) {
    final picked = s['squad_pick'];
    final map = picked is Map ? Map<dynamic, dynamic>.from(picked) : const {};
    final mine = map[uid] ?? map['$uid'];
    final sec = _pickSecondsLeft();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          mine != null
              ? 'You locked squad $mine. Waiting for opponent or countdown…'
              : 'Pick which squad to use (${sec ?? '—'}s)',
          style: const TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w700, fontSize: 15, height: 1.3),
        ),
        const SizedBox(height: 14),
        if (mine == null)
          Row(
            children: [
              for (final n in [1, 2, 3]) ...[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: n == 3 ? 0 : 8),
                    child: FilledButton(
                      onPressed: () => _pickSquad(n),
                      style: FilledButton.styleFrom(
                        backgroundColor: CardGameUiTheme.gold,
                        foregroundColor: const Color(0xFF1A120C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Squad $n'),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _lockedSquadBody() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        'Lineup locked — get ready to play.',
        textAlign: TextAlign.center,
        style: TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _matchOverBody(Map<String, dynamic> s, int uid) {
    final w = s['match_winner'];
    final wid = w != null ? int.tryParse(w.toString()) : null;
    final won = wid == uid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Text(
            won ? 'You won the match!' : 'You lost the match.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: won ? CardGameUiTheme.gold : CardGameUiTheme.onDark,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _leave,
            child: const Text('Back to 1v1'),
          ),
        ],
      ),
    );
  }
}
