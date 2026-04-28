import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../models/cards_squad.dart';
import '../../../models/collection_card.dart';
import '../../../models/sbc_challenge.dart';
import '../../../services/collection_api_service.dart';
import '../../../services/sbc_api_service.dart';
import '../../../services/session_store.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_game_ui_theme.dart';
import 'squad_halfcourt_board.dart';

String? _sbcRoleForSlotKey(String slotKey) {
  return const {'pg': 'PG', 'sg': 'SG', 'sf': 'SF', 'pf': 'PF', 'c': 'C'}[slotKey];
}

String? _normalizeRosterPosition(String raw) {
  final t = raw.trim().toUpperCase().replaceAll('.', '').replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty || t == '?') return null;
  const direct = {'PG', 'SG', 'SF', 'PF', 'C'};
  if (direct.contains(t)) return t;
  const long = <String, String>{
    'POINT GUARD': 'PG',
    'SHOOTING GUARD': 'SG',
    'SMALL FORWARD': 'SF',
    'POWER FORWARD': 'PF',
    'CENTER': 'C',
    'CENTRE': 'C',
  };
  if (long.containsKey(t)) return long[t];
  if (t.contains('POINT') && t.contains('GUARD')) return 'PG';
  if (t.contains('SHOOTING') && t.contains('GUARD')) return 'SG';
  if (t.contains('SMALL') && t.contains('FORWARD')) return 'SF';
  if (t.contains('POWER') && t.contains('FORWARD')) return 'PF';
  return null;
}

bool _collectionCardFitsSbcSlot(CollectionCard c, String slotKey) {
  final need = _sbcRoleForSlotKey(slotKey);
  final code = _normalizeRosterPosition(c.position);
  return need != null && code != null && code == need;
}

class SbcPage extends StatefulWidget {
  const SbcPage({super.key});

  @override
  State<SbcPage> createState() => _SbcPageState();
}

class _SbcPageState extends State<SbcPage> {
  final _sbcApi = SbcApiService();
  final _collectionApi = CollectionApiService();
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<SbcChallenge> _challenges = const [];
  int? _selectedSbcId;
  CardsSquadPayload _lineup = CardsSquadPayload.draft(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int> _userId() async {
    final s = await SessionStore.instance.load();
    return s?.userId ?? BackendConfig.devUserId;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await _userId();
      final challenges = await _sbcApi.fetchChallenges(userId: uid);
      if (!mounted) return;
      setState(() {
        _challenges = challenges;
        _selectedSbcId = challenges.isEmpty ? null : challenges.first.sbcId;
        _lineup = CardsSquadPayload.draft(0);
        _loading = false;
      });
    } on SbcApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  SbcChallenge? get _selectedChallenge {
    final id = _selectedSbcId;
    if (id == null) return null;
    for (final c in _challenges) {
      if (c.sbcId == id) return c;
    }
    return null;
  }

  Future<void> _pickSlot(String slotKey) async {
    if (_submitting) return;
    List<CollectionCard> cards;
    try {
      final uid = await _userId();
      cards = await _collectionApi.fetchCollection(userId: uid);
    } on CollectionApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!mounted) return;
    final role = _sbcRoleForSlotKey(slotKey);
    final eligible = cards.where((c) => _collectionCardFitsSbcSlot(c, slotKey)).toList()
      ..sort((a, b) {
        final byOvr = b.overall.compareTo(a.overall);
        if (byOvr != 0) return byOvr;
        return a.cardId.compareTo(b.cardId);
      });
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(role == null ? 'No cards match this slot.' : 'No $role cards in your collection.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final hasCard = !_lineup.slots[slotKey]!.isEmpty;
    final picked = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.58,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: CardGameUiTheme.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: CardGameUiTheme.gold.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CardGameUiTheme.onDark.withAlpha(60),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      'Assign ${_sbcRoleForSlotKey(slotKey) ?? slotKey.toUpperCase()}',
                      style: const TextStyle(
                        color: CardGameUiTheme.onDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (hasCard)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, 'clear'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CardGameUiTheme.onDark.withAlpha(220),
                          side: BorderSide(color: CardGameUiTheme.gold.withAlpha(100)),
                        ),
                        child: const Text('Clear this slot'),
                      ),
                    ),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: eligible.length,
                      itemBuilder: (_, i) {
                        final c = eligible[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx, c.cardId),
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: CardGameUiTheme.gold.withAlpha(70)),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    BundledPlayCardImage(
                                      cardId: c.cardId,
                                      fit: BoxFit.cover,
                                      fallbackImageUrl: c.cardImage,
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                        color: Colors.black.withAlpha(170),
                                        child: Text(
                                          c.playerLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted || picked == null) return;
    if (picked == 'clear') {
      final roleLabel = _sbcRoleForSlotKey(slotKey) ?? '?';
      setState(() {
        _lineup = _lineup.copyWith(slots: {
          ..._lineup.slots,
          slotKey: CardsSquadSlotCard(cardId: -1, position: roleLabel, firstName: '', lastName: ''),
        });
      });
      return;
    }
    if (picked is! int) return;
    final c = eligible.firstWhere((e) => e.cardId == picked);
    setState(() {
      _lineup = _lineup.copyWith(slots: {
        ..._lineup.slots,
        slotKey: CardsSquadSlotCard(
          cardId: c.cardId,
          position: c.position,
          firstName: c.firstName,
          lastName: c.lastName,
          overall: c.overall,
          attack: c.attack,
          defend: c.defend,
          teamName: c.teamName,
          cardImage: c.cardImage,
        ),
      });
    });
  }

  bool get _allSlotsFilled => CardsSquadPayload.slotOrder.every((k) => !_lineup.slots[k]!.isEmpty);

  Map<String, int> get _slotIntsForApi => {
        for (final k in CardsSquadPayload.slotOrder) k: _lineup.slots[k]!.cardId,
      };

  String _reqLabel(SbcRequirement r) {
    final t = r.requirementType.trim().toUpperCase();
    if (t == 'TEAM') {
      final who = (r.requiredText ?? '').trim().isNotEmpty ? r.requiredText!.trim() : 'team ${r.requiredValue ?? ''}';
      return 'At least ${r.minCount} from $who';
    }
    if (t == 'PLAYER_REQUIRED') {
      final who = (r.requiredText ?? '').trim().isNotEmpty ? r.requiredText!.trim() : 'player ${r.requiredValue ?? ''}';
      return 'Include at least ${r.minCount} of $who';
    }
    return '${r.requirementType} x${r.minCount}';
  }

  Future<void> _submitSbc() async {
    final challenge = _selectedChallenge;
    if (challenge == null || !_allSlotsFilled || _submitting) return;
    setState(() => _submitting = true);
    try {
      final uid = await _userId();
      final result = await _sbcApi.submitChallenge(
        userId: uid,
        sbcId: challenge.sbcId,
        slots: _slotIntsForApi,
      );
      if (!mounted) return;
      setState(() {
        _lineup = CardsSquadPayload.draft(0);
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SBC complete. Reward card #${result.rewardCardId} added to your collection.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on SbcApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CardGameUiTheme.bg,
      appBar: AppBar(
        title: const Text('SBC'),
        backgroundColor: CardGameUiTheme.bg,
        foregroundColor: CardGameUiTheme.onDark,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _loading || _submitting ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CardGameUiTheme.gold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(220)),
                    ),
                  ),
                )
              : _buildLoaded(),
    );
  }

  Widget _buildLoaded() {
    if (_challenges.isEmpty) {
      return Center(
        child: Text(
          'No active SBC challenges right now.',
          style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(180)),
        ),
      );
    }
    final challenge = _selectedChallenge!;
    final reward = challenge.rewardCard;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: CardGameUiTheme.panel.withAlpha(235),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CardGameUiTheme.gold.withAlpha(90)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedSbcId,
                dropdownColor: CardGameUiTheme.panel,
                isExpanded: true,
                style: const TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w700),
                items: _challenges
                    .map((c) => DropdownMenuItem<int>(
                          value: c.sbcId,
                          child: Text(c.sbcName, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedSbcId = v;
                          _lineup = CardsSquadPayload.draft(0);
                        });
                      },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            challenge.description?.trim().isNotEmpty == true
                ? challenge.description!.trim()
                : 'Complete the requirement rules to claim the reward card.',
            style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(180), fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CardGameUiTheme.panel.withAlpha(225),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CardGameUiTheme.gold.withAlpha(75)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 74,
                    child: BundledPlayCardImage(
                      cardId: reward.cardId,
                      fit: BoxFit.cover,
                      fallbackImageUrl: reward.cardImage,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reward',
                        style: TextStyle(color: CardGameUiTheme.gold, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reward.playerLabel,
                        style: const TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${reward.position} ${reward.teamName ?? ''}'.trim(),
                        style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(170), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...challenge.requirements.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18, color: CardGameUiTheme.gold.withAlpha(210)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _reqLabel(r),
                      style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(200), fontSize: 12.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Build your SBC squad (position-locked).',
            style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(165), fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          SquadHalfcourtBoard(
            squad: _lineup,
            readOnly: _submitting,
            onSlotTap: _pickSlot,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting || !_allSlotsFilled ? null : _submitSbc,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: CardGameUiTheme.gold,
              foregroundColor: const Color(0xFF1A120C),
            ),
            child: Text(_submitting ? 'Submitting...' : 'Complete SBC'),
          ),
        ],
      ),
    );
  }
}

