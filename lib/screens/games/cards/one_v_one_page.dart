import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/backend_config.dart';
import '../../../services/one_v_one_api_service.dart';
import '../../../services/session_store.dart';
import 'card_game_ui_theme.dart';
import 'one_v_one_room_page.dart';
import 'squad_editor_page.dart';

/// Head-to-head card battles hub (friend rooms + squads).
class OneVOnePage extends StatefulWidget {
  const OneVOnePage({super.key});

  @override
  State<OneVOnePage> createState() => _OneVOnePageState();
}

class _OneVOnePageState extends State<OneVOnePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CardGameUiTheme.bg,
      appBar: AppBar(
        title: const Text('1v1'),
        backgroundColor: CardGameUiTheme.bg,
        foregroundColor: CardGameUiTheme.onDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: _OneVOneTopTileDisabled(
                    icon: Icons.shuffle_rounded,
                    title: 'Random game',
                    subtitle: 'Quick match vs a random opponent',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OneVOneTopTile(
                    icon: Icons.group_rounded,
                    title: 'Play against a friend',
                    subtitle: 'Room code — best of 3 rounds',
                    onTap: () => _showFriendRoomDialog(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'Your squads',
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(220),
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You need three full lineups (five cards each) to play friend 1v1.',
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(140),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            _SquadEditRow(
              squadIndex: 1,
              onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SquadEditorPage(squadNumber: 1)),
                  ),
            ),
            const SizedBox(height: 10),
            _SquadEditRow(
              squadIndex: 2,
              onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SquadEditorPage(squadNumber: 2)),
                  ),
            ),
            const SizedBox(height: 10),
            _SquadEditRow(
              squadIndex: 3,
              onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SquadEditorPage(squadNumber: 3)),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFriendRoomDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _FriendOneVOneDialog(parentContext: context),
    );
  }
}

class _OneVOneTopTile extends StatelessWidget {
  const _OneVOneTopTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: CardGameUiTheme.panel.withAlpha(240),
            border: Border.all(
              color: CardGameUiTheme.gold.withAlpha(85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: CardGameUiTheme.orangeGlow.withAlpha(28),
                blurRadius: 12,
                offset: const Offset(0, 5),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: CardGameUiTheme.gold.withAlpha(220)),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CardGameUiTheme.onDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: CardGameUiTheme.onDark.withAlpha(130),
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same visual language as trade hub top tiles, non-interactive.
class _OneVOneTopTileDisabled extends StatelessWidget {
  const _OneVOneTopTileDisabled({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.72,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: CardGameUiTheme.panel.withAlpha(240),
          border: Border.all(
            color: CardGameUiTheme.gold.withAlpha(55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: CardGameUiTheme.orangeGlow.withAlpha(22),
              blurRadius: 12,
              offset: const Offset(0, 5),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: CardGameUiTheme.gold.withAlpha(200)),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CardGameUiTheme.onDark,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(130),
                fontSize: 11.5,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(
                color: CardGameUiTheme.orangeGlow.withAlpha(200),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendOneVOneDialog extends StatefulWidget {
  const _FriendOneVOneDialog({required this.parentContext});

  final BuildContext parentContext;

  @override
  State<_FriendOneVOneDialog> createState() => _FriendOneVOneDialogState();
}

class _FriendOneVOneDialogState extends State<_FriendOneVOneDialog> {
  final _codeCtrl = TextEditingController();
  final _api = OneVOneApiService();
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<int> _userId() async {
    final s = await SessionStore.instance.load();
    return s?.userId ?? BackendConfig.devUserId;
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final uid = await _userId();
      final code = await _api.createRoom(userId: uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      final parent = widget.parentContext;
      if (!parent.mounted) return;
      await showDialog<void>(
        context: parent,
        builder: (ctx) => AlertDialog(
          backgroundColor: CardGameUiTheme.panel,
          title: const Text('Room created', style: TextStyle(color: CardGameUiTheme.onDark)),
          content: SelectableText(
            'Share this code:\n\n$code',
            style: const TextStyle(
              color: CardGameUiTheme.onDark,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: CardGameUiTheme.gold)),
            ),
          ],
        ),
      );
      if (!parent.mounted) return;
      Navigator.of(parent).push<void>(
        MaterialPageRoute<void>(builder: (_) => OneVOneRoomPage(roomCode: code)),
      );
    } on OneVOneApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final raw = _codeCtrl.text.trim().toUpperCase();
    if (raw.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the room code')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final uid = await _userId();
      await _api.joinRoom(code: raw, userId: uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      final parent = widget.parentContext;
      if (parent.mounted) {
        Navigator.of(parent).push<void>(
          MaterialPageRoute<void>(builder: (_) => OneVOneRoomPage(roomCode: raw)),
        );
      }
    } on OneVOneApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          color: CardGameUiTheme.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CardGameUiTheme.gold.withAlpha(100)),
          boxShadow: [
            BoxShadow(
              color: CardGameUiTheme.orangeGlow.withAlpha(40),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Play a friend',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CardGameUiTheme.onDark,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Both players need three full squads. Match is best of 3 rounds; each round is first to 2 points.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(150), fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A120C)),
                    )
                  : const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Create room'),
              style: FilledButton.styleFrom(
                backgroundColor: CardGameUiTheme.gold,
                foregroundColor: const Color(0xFF1A120C),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Join with a code',
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(200),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              style: const TextStyle(color: CardGameUiTheme.onDark, letterSpacing: 1.2),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
              decoration: InputDecoration(
                hintText: 'e.g. AB3K9M',
                hintStyle: TextStyle(color: CardGameUiTheme.onDark.withAlpha(100)),
                labelText: 'Room code',
                labelStyle: TextStyle(color: CardGameUiTheme.onDark.withAlpha(180)),
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
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _busy ? null : _join,
              style: OutlinedButton.styleFrom(
                foregroundColor: CardGameUiTheme.gold,
                side: const BorderSide(color: CardGameUiTheme.gold),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Join room'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(180))),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquadEditRow extends StatelessWidget {
  const _SquadEditRow({
    required this.squadIndex,
    required this.onTap,
  });

  final int squadIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: CardGameUiTheme.panel.withAlpha(240),
            border: Border.all(
              color: CardGameUiTheme.gold.withAlpha(85),
              width: 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: CardGameUiTheme.orangeGlow.withAlpha(30),
                blurRadius: 12,
                offset: const Offset(0, 5),
                spreadRadius: -3,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: CardGameUiTheme.elevated,
                  border: Border.all(color: CardGameUiTheme.gold.withAlpha(70)),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: CardGameUiTheme.gold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Edit squad $squadIndex',
                  style: const TextStyle(
                    color: CardGameUiTheme.onDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: CardGameUiTheme.onDark.withAlpha(160),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
