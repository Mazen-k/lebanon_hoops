import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/backend_config.dart';
import '../../../services/session_store.dart';
import '../../../services/trade_api_service.dart';
import '../../../theme/colors.dart';
import 'trade_room_page.dart';

class TradeLobbyPage extends StatefulWidget {
  const TradeLobbyPage({super.key});

  @override
  State<TradeLobbyPage> createState() => _TradeLobbyPageState();
}

class _TradeLobbyPageState extends State<TradeLobbyPage> {
  final _api = TradeApiService();
  final _codeCtrl = TextEditingController();
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
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Room created'),
          content: SelectableText(
            'Share this code with the other player:\n\n$code',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TradeRoomPage(roomCode: code)),
      );
    } on TradeApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TradeRoomPage(roomCode: raw)),
      );
    } on TradeApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Trade lobby'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create a room and share the code, or join with a code from your trading partner.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: const Text('Create trade room'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
            const SizedBox(height: 32),
            Text('Join room', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              // Allow a–z so mobile keyboards work; join path uppercases to match server codes.
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. AB3K9M',
                labelText: 'Room code (letters & numbers)',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _busy ? null : _join,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Join room'),
            ),
          ],
        ),
      ),
    );
  }
}
