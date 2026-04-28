import 'package:flutter/material.dart';
import 'dart:math';

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
import 'view_collection_page.dart';

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
  bool _loading = true;
  String? _error;
  List<SbcChallenge> _challenges = const [];

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
            onPressed: _loading ? null : _load,
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
              : _buildList(),
    );
  }

  Widget _buildList() {
    if (_challenges.isEmpty) {
      return Center(
        child: Text(
          'No active SBC challenges right now.',
          style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(180)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: _challenges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final challenge = _challenges[index];
        return _SbcChallengeRow(
          challenge: challenge,
          onTap: challenge.completed
              ? null
              : () async {
            await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => _SbcChallengeDetailPage(challenge: challenge),
            ),
            );
            if (context.mounted) _load();
          },
        );
      },
    );
  }
}

class _SbcChallengeRow extends StatelessWidget {
  const _SbcChallengeRow({
    required this.challenge,
    required this.onTap,
  });

  final SbcChallenge challenge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: challenge.completed ? 0.72 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: CardGameUiTheme.panel.withAlpha(230),
            border: Border.all(color: CardGameUiTheme.panelBorder.withAlpha(180)),
            boxShadow: [
              BoxShadow(
                color: CardGameUiTheme.orangeGlow.withAlpha(45),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 100,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ColoredBox(
                        color: CardGameUiTheme.bg,
                        child: BundledPlayCardImage(
                          cardId: challenge.rewardCard.cardId,
                          fit: BoxFit.cover,
                          fallbackImageUrl: challenge.rewardCard.cardImage,
                          errorPlaceholder: const Center(
                            child: Icon(
                              Icons.stars_rounded,
                              size: 36,
                              color: Color(0xFF4A4060),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge.sbcName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CardGameUiTheme.onDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              challenge.description?.trim().isNotEmpty == true
                                  ? challenge.description!.trim()
                                  : 'Complete this SBC to claim the reward card.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: CardGameUiTheme.onDark.withAlpha(210),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Reward: ${challenge.rewardCard.playerLabel}',
                          style: TextStyle(
                            color: CardGameUiTheme.gold.withAlpha(240),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (challenge.completed)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Completed',
                              style: TextStyle(
                                color: Color(0xFF4CD964),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _SbcRequirementProgress {
  const _SbcRequirementProgress({
    required this.requirement,
    required this.matchedCount,
    required this.done,
  });

  final SbcRequirement requirement;
  final int matchedCount;
  final bool done;
}

class _SbcChallengeDetailPage extends StatefulWidget {
  const _SbcChallengeDetailPage({required this.challenge});

  final SbcChallenge challenge;

  @override
  State<_SbcChallengeDetailPage> createState() => _SbcChallengeDetailPageState();
}

class _SbcChallengeDetailPageState extends State<_SbcChallengeDetailPage> {
  final _sbcApi = SbcApiService();
  final _collectionApi = CollectionApiService();
  bool _loadingCollection = true;
  bool _submitting = false;
  List<CollectionCard> _collection = const [];
  Map<int, CollectionCard> _collectionByCardId = const {};
  CardsSquadPayload _lineup = CardsSquadPayload.draft(0);
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<int> _userId() async {
    final s = await SessionStore.instance.load();
    return s?.userId ?? BackendConfig.devUserId;
  }

  Future<void> _loadCollection() async {
    setState(() => _loadingCollection = true);
    try {
      final uid = await _userId();
      final cards = await _collectionApi.fetchCollectionDuplicates(userId: uid);
      final map = <int, CollectionCard>{for (final c in cards) c.cardId: c};
      if (!mounted) return;
      setState(() {
        _collection = cards;
        _collectionByCardId = map;
        _loadingCollection = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCollection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  List<_SbcRequirementProgress> _progressList() {
    final selected = CardsSquadPayload.slotOrder
        .map((k) => _lineup.slots[k]!.cardId)
        .where((id) => id > 0)
        .map((id) => _collectionByCardId[id])
        .whereType<CollectionCard>()
        .toList();
    final out = <_SbcRequirementProgress>[];
    for (final req in widget.challenge.requirements) {
      final type = req.requirementType.trim().toUpperCase();
      final need = req.minCount <= 0 ? 1 : req.minCount;
      var matched = 0;
      if (type == 'PLAYER_REQUIRED' && req.requiredValue != null) {
        matched = selected.where((c) => c.playerId == req.requiredValue).length;
      } else if (type == 'TEAM' && req.requiredValue != null) {
        matched = selected.where((c) => c.teamId == req.requiredValue).length;
      }
      out.add(_SbcRequirementProgress(
        requirement: req,
        matchedCount: matched,
        done: matched >= need,
      ));
    }
    return out;
  }

  bool get _allSlotsFilled => CardsSquadPayload.slotOrder.every((k) => !_lineup.slots[k]!.isEmpty);

  bool get _allRequirementsMet => _progressList().every((p) => p.done);

  String _requirementName(SbcRequirement req) {
    final resolved = (req.resolvedName ?? '').trim();
    if (resolved.isNotEmpty) return resolved;
    final text = (req.requiredText ?? '').trim();
    if (text.isNotEmpty && !RegExp(r'^\d+$').hasMatch(text)) return text;
    final type = req.requirementType.trim().toUpperCase();
    if (type == 'PLAYER_REQUIRED') return 'Player #${req.requiredValue ?? '?'}';
    if (type == 'TEAM') return 'Team #${req.requiredValue ?? '?'}';
    return req.requirementType;
  }

  Future<void> _pickSlot(String slotKey) async {
    if (_submitting || _loadingCollection) return;
    final role = _sbcRoleForSlotKey(slotKey);
    final eligible = _collection.where((c) => _collectionCardFitsSbcSlot(c, slotKey)).toList()
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
                                      errorPlaceholder: ColoredBox(
                                        color: CardGameUiTheme.panel,
                                        child: Center(
                                          child: Text(
                                            c.playerLabel,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: CardGameUiTheme.onDark,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
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

  Future<void> _submitSbc() async {
    if (widget.challenge.completed || !_allSlotsFilled || !_allRequirementsMet || _submitting) return;
    setState(() => _submitting = true);
    try {
      final uid = await _userId();
      final result = await _sbcApi.submitChallenge(
        userId: uid,
        sbcId: widget.challenge.sbcId,
        slots: {for (final k in CardsSquadPayload.slotOrder) k: _lineup.slots[k]!.cardId},
      );
      if (!mounted) return;
      setState(() {
        _lineup = CardsSquadPayload.draft(0);
        _submitting = false;
      });
      final goBackToList = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          fullscreenDialog: true,
          builder: (_) => _SbcRewardRevealPage(
            rewardCard: widget.challenge.rewardCard,
            rewardCardId: result.rewardCardId,
          ),
        ),
      );
      if (goBackToList == true && mounted) {
        Navigator.of(context).pop();
      }
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

  Future<void> _autoCompleteSquad() async {
    if (_loadingCollection || _submitting || widget.challenge.completed) return;

    final slots = CardsSquadPayload.slotOrder;
    final slotCandidates = <String, List<CollectionCard>>{};
    for (final slot in slots) {
      final candidates = _collection.where((c) => _collectionCardFitsSbcSlot(c, slot)).toList();
      candidates.shuffle(_random);
      slotCandidates[slot] = candidates;
    }
    if (slots.any((s) => (slotCandidates[s] ?? const []).isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-complete failed: some positions have no eligible duplicate cards.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final reqs = widget.challenge.requirements.where((r) {
      final t = r.requirementType.trim().toUpperCase();
      return (t == 'PLAYER_REQUIRED' || t == 'TEAM') && r.requiredValue != null && r.minCount > 0;
    }).toList();

    int scoreCard(CollectionCard c, Map<int, CollectionCard> assignedBySlotIndex) {
      var score = 0;
      for (final r in reqs) {
        final t = r.requirementType.trim().toUpperCase();
        final need = r.minCount;
        var matched = 0;
        for (final a in assignedBySlotIndex.values) {
          if (t == 'PLAYER_REQUIRED' && a.playerId == r.requiredValue) matched++;
          if (t == 'TEAM' && a.teamId == r.requiredValue) matched++;
        }
        final stillNeeded = need - matched;
        if (stillNeeded <= 0) continue;
        if (t == 'PLAYER_REQUIRED' && c.playerId == r.requiredValue) score += 10;
        if (t == 'TEAM' && c.teamId == r.requiredValue) score += 6;
      }
      return score;
    }

    bool canStillMeetRequirements(Map<int, CollectionCard> assignedBySlotIndex, int nextSlotIdx) {
      for (final r in reqs) {
        final t = r.requirementType.trim().toUpperCase();
        final need = r.minCount;
        var matched = 0;
        for (final a in assignedBySlotIndex.values) {
          if (t == 'PLAYER_REQUIRED' && a.playerId == r.requiredValue) matched++;
          if (t == 'TEAM' && a.teamId == r.requiredValue) matched++;
        }
        var possibleFuture = 0;
        for (var i = nextSlotIdx; i < slots.length; i++) {
          final sc = slotCandidates[slots[i]] ?? const <CollectionCard>[];
          final canMatch = sc.any((c) {
            if (t == 'PLAYER_REQUIRED') return c.playerId == r.requiredValue;
            if (t == 'TEAM') return c.teamId == r.requiredValue;
            return false;
          });
          if (canMatch) possibleFuture++;
        }
        if (matched + possibleFuture < need) return false;
      }
      return true;
    }

    bool allRequirementsMet(Map<int, CollectionCard> assignedBySlotIndex) {
      for (final r in reqs) {
        final t = r.requirementType.trim().toUpperCase();
        final need = r.minCount;
        var matched = 0;
        for (final a in assignedBySlotIndex.values) {
          if (t == 'PLAYER_REQUIRED' && a.playerId == r.requiredValue) matched++;
          if (t == 'TEAM' && a.teamId == r.requiredValue) matched++;
        }
        if (matched < need) return false;
      }
      return true;
    }

    final assignedBySlotIndex = <int, CollectionCard>{};

    bool dfs(int idx) {
      if (idx >= slots.length) {
        return allRequirementsMet(assignedBySlotIndex);
      }
      final slot = slots[idx];
      final candidates = [...(slotCandidates[slot] ?? const <CollectionCard>[])];
      candidates.sort((a, b) => scoreCard(b, assignedBySlotIndex).compareTo(scoreCard(a, assignedBySlotIndex)));
      for (final c in candidates) {
        assignedBySlotIndex[idx] = c;
        if (!canStillMeetRequirements(assignedBySlotIndex, idx + 1)) {
          assignedBySlotIndex.remove(idx);
          continue;
        }
        if (dfs(idx + 1)) return true;
        assignedBySlotIndex.remove(idx);
      }
      return false;
    }

    final ok = dfs(0);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid auto-complete lineup found for current requirements.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final newSlots = <String, CardsSquadSlotCard>{};
    for (var i = 0; i < slots.length; i++) {
      final slotKey = slots[i];
      final c = assignedBySlotIndex[i]!;
      newSlots[slotKey] = CardsSquadSlotCard(
        cardId: c.cardId,
        position: c.position,
        firstName: c.firstName,
        lastName: c.lastName,
        overall: c.overall,
        attack: c.attack,
        defend: c.defend,
        teamName: c.teamName,
        cardImage: c.cardImage,
      );
    }
    if (!mounted) return;
    setState(() {
      _lineup = _lineup.copyWith(slots: newSlots);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SBC lineup auto-completed.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.challenge.rewardCard;
    final progress = _progressList();
    final canSubmit = !widget.challenge.completed && !_submitting && _allSlotsFilled && _allRequirementsMet;
    return Scaffold(
      backgroundColor: CardGameUiTheme.bg,
      appBar: AppBar(
        title: Text(widget.challenge.sbcName),
        backgroundColor: CardGameUiTheme.bg,
        foregroundColor: CardGameUiTheme.onDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.challenge.description?.trim().isNotEmpty == true
                  ? widget.challenge.description!.trim()
                  : 'Complete this SBC to claim the reward card.',
              style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(185), fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            if (widget.challenge.completed)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C3A25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CD964).withAlpha(180)),
                ),
                child: const Text(
                  'You already completed this SBC.',
                  style: TextStyle(
                    color: Color(0xFFB7FFC9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
                        errorPlaceholder: ColoredBox(
                          color: CardGameUiTheme.panel,
                          child: Center(
                            child: Text(
                              reward.playerLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: CardGameUiTheme.onDark,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
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
            ...progress.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      p.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: p.done ? const Color(0xFF4CD964) : CardGameUiTheme.gold.withAlpha(180),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_requirementName(p.requirement)} (${p.matchedCount}/${p.requirement.minCount})',
                        style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(205), fontSize: 12.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Build your SBC squad (position-locked).',
              style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(165), fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            if (_loadingCollection)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: CircularProgressIndicator(color: CardGameUiTheme.gold),
                ),
              )
            else
              SquadHalfcourtBoard(
                squad: _lineup,
                readOnly: _submitting,
                onSlotTap: _pickSlot,
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: (_loadingCollection || _submitting || widget.challenge.completed) ? null : _autoCompleteSquad,
              style: OutlinedButton.styleFrom(
                foregroundColor: CardGameUiTheme.gold,
                side: BorderSide(color: CardGameUiTheme.gold.withAlpha(180)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Auto-complete'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canSubmit ? _submitSbc : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: CardGameUiTheme.gold,
                foregroundColor: const Color(0xFF1A120C),
              ),
              child: Text(_submitting ? 'Submitting...' : 'Submit SBC'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SbcRewardRevealPage extends StatefulWidget {
  const _SbcRewardRevealPage({
    required this.rewardCard,
    required this.rewardCardId,
  });

  final SbcRewardCard rewardCard;
  final int rewardCardId;

  @override
  State<_SbcRewardRevealPage> createState() => _SbcRewardRevealPageState();
}

class _SbcRewardRevealPageState extends State<_SbcRewardRevealPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _spin;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _spin = Tween<double>(begin: 3.6 * 3.1415926535897932, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CardGameUiTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SBC Completed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CardGameUiTheme.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You unlocked ${widget.rewardCard.playerLabel}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CardGameUiTheme.onDark.withAlpha(220),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(_spin.value),
                      child: Transform.scale(
                        scale: _scale.value,
                        child: Opacity(opacity: _fade.value, child: child),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: CardGameUiTheme.orangeGlow.withAlpha(80),
                          blurRadius: 28,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: 240,
                        height: 320,
                        child: BundledPlayCardImage(
                          cardId: widget.rewardCardId,
                          fit: BoxFit.cover,
                          fallbackImageUrl: widget.rewardCard.cardImage,
                          errorPlaceholder: ColoredBox(
                            color: CardGameUiTheme.panel,
                            child: Center(
                              child: Text(
                                widget.rewardCard.playerLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: CardGameUiTheme.onDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ViewCollectionPage()),
                  );
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: CardGameUiTheme.gold,
                  foregroundColor: const Color(0xFF1A120C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Go to Collection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

