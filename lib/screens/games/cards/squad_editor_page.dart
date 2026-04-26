import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../models/cards_squad.dart';
import '../../../models/collection_card.dart';
import '../../../services/cards_squad_api_service.dart';
import '../../../services/collection_api_service.dart' show CollectionApiException, CollectionApiService;
import '../../../services/session_store.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_game_ui_theme.dart';
import 'squad_halfcourt_board.dart';

String? _squadRoleForSlotKey(String slotKey) {
  return const {'pg': 'PG', 'sg': 'SG', 'sf': 'SF', 'pf': 'PF', 'c': 'C'}[slotKey];
}

/// Same rules as API `normalizeDbBasketballPosition` — must match lineup slot.
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

bool _collectionCardFitsSquadSlot(CollectionCard c, String slotKey) {
  final need = _squadRoleForSlotKey(slotKey);
  final code = _normalizeRosterPosition(c.position);
  return need != null && code != null && code == need;
}

/// Half-court editor: PG, SG, SF, PF, C mapped to `cards_squad` columns.
class SquadEditorPage extends StatefulWidget {
  const SquadEditorPage({super.key, required this.squadNumber});

  final int squadNumber;

  @override
  State<SquadEditorPage> createState() => _SquadEditorPageState();
}

class _SquadEditorPageState extends State<SquadEditorPage> {
  final _squadApi = CardsSquadApiService();
  final _collectionApi = CollectionApiService();

  bool _loading = true;
  String? _error;
  CardsSquadPayload? _squad;
  bool _saving = false;
  bool _persisted = false;
  bool _dirty = false;
  /// Card ids already assigned on this user's other squads (from GET); hide from picker.
  List<int> _reservedInOtherSquads = const [];

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
    final userId = await _userId();
    try {
      final r = await _squadApi.fetchSquad(userId: userId, squadNumber: widget.squadNumber);
      if (!mounted) return;
      if (r.needInstances) {
        setState(() {
          _squad = null;
          _reservedInOtherSquads = const [];
          _loading = false;
          _error = 'Squad data is unavailable. Update the app or try again.';
        });
        return;
      }
      if (!r.exists) {
        setState(() {
          _squad = CardsSquadPayload.draft(widget.squadNumber);
          _reservedInOtherSquads = r.reservedCardIdsInOtherSquads;
          _persisted = false;
          _dirty = false;
          _loading = false;
        });
        return;
      }
      setState(() {
        _squad = r.squad;
        _reservedInOtherSquads = r.reservedCardIdsInOtherSquads;
        _persisted = true;
        _dirty = false;
        _loading = false;
      });
    } on CardsSquadApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _rename() async {
    final squad = _squad;
    if (squad == null) return;
    final ctrl = TextEditingController(text: squad.squadName);
    String? newName;
    try {
      newName = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withAlpha(200),
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: CardGameUiTheme.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: CardGameUiTheme.gold.withAlpha(100)),
          ),
          title: const Text(
            'Squad name',
            style: TextStyle(color: CardGameUiTheme.onDark, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: ctrl,
            maxLength: 100,
            style: const TextStyle(color: CardGameUiTheme.onDark),
            decoration: InputDecoration(
              counterStyle: TextStyle(color: CardGameUiTheme.onDark.withAlpha(160)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: CardGameUiTheme.gold.withAlpha(90)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CardGameUiTheme.gold, width: 1.4),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(200))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save', style: TextStyle(color: CardGameUiTheme.gold, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    } finally {
      ctrl.dispose();
    }
    if (newName == null || newName.isEmpty) return;
    if (newName == squad.squadName) return;
    if (!mounted) return;
    setState(() {
      _squad = squad.copyWith(squadName: newName);
      if (_persisted) _dirty = true;
    });
  }

  Future<void> _pickSlot(String slotKey) async {
    final squad = _squad;
    if (squad == null || _saving) return;
    final userId = await _userId();
    List<CollectionCard> cards;
    try {
      cards = await _collectionApi.fetchCollection(userId: userId);
    } on CollectionApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    if (!mounted) return;
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your collection is empty. Open packs first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final role = _squadRoleForSlotKey(slotKey);
    final byPosition = cards.where((c) => _collectionCardFitsSquadSlot(c, slotKey)).toList();
    if (byPosition.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            role == null
                ? 'No cards match this slot.'
                : 'No $role cards in your collection for this slot.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final eligible = byPosition.where((c) => !_reservedInOtherSquads.contains(c.cardId)).toList();
    if (eligible.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            role == null
                ? 'No cards available (all matching cards are on another squad).'
                : 'No available $role cards — each is already assigned to another squad.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    eligible.sort((a, b) {
      final byOvr = b.overall.compareTo(a.overall);
      if (byOvr != 0) return byOvr;
      return a.cardId.compareTo(b.cardId);
    });
    final hasCard = !squad.slots[slotKey]!.isEmpty;
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
                      'Assign ${_slotLabel(slotKey)} (${_squadRoleForSlotKey(slotKey) ?? ''})',
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
                                          style: TextStyle(
                                            color: CardGameUiTheme.onDark.withAlpha(180),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
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
    if (!mounted) return;
    if (picked == null) return;
    if (picked == 'clear') {
      if (!mounted) return;
      setState(() {
        _squad = squad.copyWith(slots: {...squad.slots, slotKey: _emptySlotCard(slotKey)});
        if (_persisted) _dirty = true;
      });
      return;
    }
    if (picked is! int) return;
    final c = eligible.firstWhere((e) => e.cardId == picked);
    if (!mounted) return;
    setState(() {
      _squad = squad.copyWith(slots: {...squad.slots, slotKey: _slotFromCollection(c)});
      if (_persisted) _dirty = true;
    });
  }

  CardsSquadSlotCard _slotFromCollection(CollectionCard c) {
    return CardsSquadSlotCard(
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

  CardsSquadSlotCard _emptySlotCard(String slotKey) {
    final role = _squadRoleForSlotKey(slotKey) ?? '?';
    return CardsSquadSlotCard(cardId: -1, position: role, firstName: '', lastName: '');
  }

  bool _allSlotsFilled(CardsSquadPayload s) {
    return CardsSquadPayload.slotOrder.every((k) => !s.slots[k]!.isEmpty);
  }

  Map<String, int> _slotIntsForApi(CardsSquadPayload s) {
    return {
      for (final k in CardsSquadPayload.slotOrder) k: s.slots[k]!.cardId <= 0 ? -1 : s.slots[k]!.cardId,
    };
  }

  Future<void> _createSquadInDb() async {
    final s = _squad;
    if (s == null || _saving || !_allSlotsFilled(s)) return;
    setState(() => _saving = true);
    final userId = await _userId();
    try {
      final slots = {for (final k in CardsSquadPayload.slotOrder) k: s.slots[k]!.cardId};
      final updated = await _squadApi.createSquad(
        userId: userId,
        squadNumber: widget.squadNumber,
        squadName: s.squadName,
        slots: slots,
      );
      if (mounted) {
        setState(() {
          _squad = updated;
          _persisted = true;
          _dirty = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Squad created.'), behavior: SnackBarBehavior.floating),
        );
      }
    } on CardsSquadApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _saveSquadToDb() async {
    final s = _squad;
    if (s == null || !_persisted || !_dirty || _saving) return;
    setState(() => _saving = true);
    final userId = await _userId();
    try {
      final updated = await _squadApi.patchSquad(
        userId: userId,
        squadNumber: widget.squadNumber,
        squadName: s.squadName,
        slots: _slotIntsForApi(s),
      );
      if (mounted) {
        setState(() {
          _squad = updated;
          _dirty = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Squad saved.'), behavior: SnackBarBehavior.floating),
        );
      }
    } on CardsSquadApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  static String _slotLabel(String key) {
    return switch (key) {
      'pg' => 'PG',
      'sg' => 'SG',
      'sf' => 'SF',
      'pf' => 'PF',
      'c' => 'C',
      _ => key.toUpperCase(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CardGameUiTheme.bg,
      appBar: AppBar(
        title: Text('Squad ${widget.squadNumber}'),
        backgroundColor: CardGameUiTheme.bg,
        foregroundColor: CardGameUiTheme.onDark,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: CardGameUiTheme.gold),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: _saving ? null : _load,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CardGameUiTheme.gold))
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : _buildEditor(context),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final squad = _squad!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _saving ? null : _rename,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: CardGameUiTheme.panel.withAlpha(240),
                  border: Border.all(color: CardGameUiTheme.gold.withAlpha(85)),
                  boxShadow: [
                    BoxShadow(
                      color: CardGameUiTheme.orangeGlow.withAlpha(28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Squad name',
                            style: TextStyle(
                              color: CardGameUiTheme.onDark.withAlpha(150),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            squad.squadName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: CardGameUiTheme.onDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_rounded, color: CardGameUiTheme.gold.withAlpha(_saving ? 80 : 220)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Half court — tap a position to assign a card from your collection.',
            style: TextStyle(
              color: CardGameUiTheme.onDark.withAlpha(155),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SquadHalfcourtBoard(
            squad: squad,
            readOnly: _saving,
            onSlotTap: _pickSlot,
          ),
          const SizedBox(height: 20),
          if (!_persisted) ...[
            FilledButton(
              onPressed: (_saving || !_allSlotsFilled(squad)) ? null : _createSquadInDb,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: CardGameUiTheme.gold,
                foregroundColor: const Color(0xFF1A120C),
              ),
              child: Text(_saving ? 'Creating...' : 'Create squad'),
            ),
            const SizedBox(height: 10),
            Text(
              'Fill all five positions, then create your squad in the database.',
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(140),
                fontSize: 12,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            FilledButton(
              onPressed: (_saving || !_dirty) ? null : _saveSquadToDb,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: CardGameUiTheme.gold,
                foregroundColor: const Color(0xFF1A120C),
              ),
              child: Text(_saving ? 'Saving...' : 'Save squad'),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap Save after you change the lineup or rename the squad.',
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(140),
                fontSize: 12,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: CardGameUiTheme.onDark.withAlpha(160)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(220), fontSize: 15, height: 1.35),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: CardGameUiTheme.gold,
                side: const BorderSide(color: CardGameUiTheme.gold, width: 1.5),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
