import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class UserWalletApiException implements Exception {
  UserWalletApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class UserWallet {
  const UserWallet({required this.username, required this.cardCoins});

  final String username;
  final int cardCoins;

  factory UserWallet.fromJson(Map<String, dynamic> json) {
    final coins = json['card_coins'] ?? json['cardCoins'];
    return UserWallet(
      username: (json['username'] ?? '').toString(),
      cardCoins: coins is int ? coins : int.tryParse(coins?.toString() ?? '') ?? 0,
    );
  }
}

class UserWalletApiService {
  UserWalletApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path, int userId) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$p');
    return u.replace(queryParameters: {
      ...u.queryParameters,
      'user_id': '$userId',
    });
  }

  static bool _looksLikeHtmlError(String body) {
    final t = body.trimLeft().toLowerCase();
    return t.startsWith('<!doctype') || t.startsWith('<html');
  }

  Future<UserWallet> fetchWallet({required int userId}) async {
    final configured = BackendConfig.userWalletPath;
    final fallback = configured == 'user/wallet' ? 'api/user/wallet' : null;

    final own = _client ?? http.Client();
    try {
      Future<http.Response> send(String path) {
        return own
            .get(_uri(path, userId), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 20));
      }

      http.Response res = await send(configured);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      final retry =
          res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtmlError(preview));
      if (retry && fallback != null) {
        res = await send(fallback);
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        var msg = 'Wallet request failed (${res.statusCode})';
        final body = utf8.decode(res.bodyBytes, allowMalformed: true);
        if (!_looksLikeHtmlError(body)) {
          try {
            final err = jsonDecode(body);
            if (err is Map && err['error'] != null) msg = err['error'].toString();
          } catch (_) {
            if (body.isNotEmpty) msg = body;
          }
        }
        throw UserWalletApiException(msg);
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw UserWalletApiException('Invalid wallet response');
      }
      return UserWallet.fromJson(decoded);
    } finally {
      if (_client == null) {
        own.close();
      }
    }
  }
}
