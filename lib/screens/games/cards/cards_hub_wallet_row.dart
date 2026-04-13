import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../services/session_store.dart';
import '../../../services/user_wallet_api_service.dart';

/// Username (left) and card coins (right), for the cards hub body below the app bar.
class CardsHubWalletRow extends StatefulWidget {
  const CardsHubWalletRow({super.key});

  @override
  State<CardsHubWalletRow> createState() => _CardsHubWalletRowState();
}

class _CardsHubWalletRowState extends State<CardsHubWalletRow> {
  final _walletApi = UserWalletApiService();

  String _displayName = '';
  int? _coins;
  bool _loading = true;

  static const Color _fg = Color(0xFFF5F5FF);
  static const Color _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionStore.instance.load();
    final userId = session?.userId ?? BackendConfig.devUserId;
    final fromSession = session?.username.trim();
    setState(() {
      _displayName =
          (fromSession != null && fromSession.isNotEmpty) ? fromSession : 'Guest';
    });
    try {
      final w = await _walletApi.fetchWallet(userId: userId);
      if (!mounted) return;
      setState(() {
        if (fromSession == null || fromSession.isEmpty) {
          final u = w.username.trim();
          if (u.isNotEmpty) _displayName = u;
        }
        _coins = w.cardCoins;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coins ??= 0;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinsText = _loading ? '…' : '${_coins ?? 0}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _displayName.isEmpty ? 'Guest' : _displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _fg,
              ),
            ),
          ),
          Icon(Icons.monetization_on_rounded, color: _gold, size: 22),
          const SizedBox(width: 4),
          Text(
            coinsText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _gold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
