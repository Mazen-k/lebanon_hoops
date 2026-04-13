import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class WishlistApiException implements Exception {
  WishlistApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Card ids + optional trading line from `wishlists.msg` (server, max 50 chars).
class WishlistSnapshot {
  const WishlistSnapshot({required this.cardIds, required this.msg});

  final List<int> cardIds;
  final String msg;
}

class WishlistApiService {
  WishlistApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$p');
    return query == null
        ? u
        : u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  static String _normalizeMsg(dynamic raw) {
    if (raw == null) return 'Best cards Please';
    final s = raw.toString().trim();
    if (s.isEmpty) return 'Best cards Please';
    return s.length > 50 ? s.substring(0, 50) : s;
  }

  Future<WishlistSnapshot> fetchWishlist({required int userId}) async {
    final path = BackendConfig.wishlistPath;
    final alt = path.startsWith('api/') ? path.substring(4) : 'api/$path';
    final own = _client ?? http.Client();
    try {
      Future<http.Response> getP(String p) => own
          .get(
            _uri(p, {'user_id': '$userId'}),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));

      var res = await getP(path);
      if (res.statusCode == 404) res = await getP(alt);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        var msg =
            'Wishlist GET failed (${res.statusCode}) at ${res.request?.url}';
        try {
          final m = jsonDecode(
            utf8.decode(res.bodyBytes, allowMalformed: true),
          );
          if (m is Map && m['error'] != null) msg = m['error'].toString();
        } catch (_) {
          final preview = utf8
              .decode(res.bodyBytes, allowMalformed: true)
              .trim();
          if (preview.isNotEmpty && preview.length < 200)
            msg = '$msg — $preview';
        }
        throw WishlistApiException(msg);
      }
      final decoded = jsonDecode(
        utf8.decode(res.bodyBytes, allowMalformed: true),
      );
      if (decoded is! Map)
        throw WishlistApiException(
          'Invalid wishlist response (not JSON object)',
        );
      final ids = decoded['card_ids'] ?? decoded['cardIds'];
      final out = <int>[];
      if (ids != null) {
        if (ids is! List) {
          throw WishlistApiException(
            'Wishlist response missing card_ids array',
          );
        }
        for (final e in ids) {
          final n = int.tryParse(e.toString());
          if (n != null) out.add(n);
        }
      }
      return WishlistSnapshot(cardIds: out, msg: _normalizeMsg(decoded['msg']));
    } finally {
      if (_client == null) own.close();
    }
  }

  /// Card ids only; use [fetchWishlist] when you need [WishlistSnapshot.msg].
  Future<List<int>> getWishlist({required int userId}) async =>
      (await fetchWishlist(userId: userId)).cardIds;

  Future<void> putWishlist({
    required int userId,
    required List<int> cardIds,
    String? msg,
  }) async {
    final path = BackendConfig.wishlistPath;
    final alt = path.startsWith('api/') ? path.substring(4) : 'api/$path';
    final own = _client ?? http.Client();
    try {
      final body = <String, dynamic>{'user_id': userId, 'card_ids': cardIds};
      if (msg != null) body['msg'] = msg;

      Future<http.Response> putP(String p) => own
          .put(
            _uri(p),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      var res = await putP(path);
      if (res.statusCode == 404) res = await putP(alt);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        var errMsg = 'Wishlist save failed (${res.statusCode})';
        try {
          final m = jsonDecode(utf8.decode(res.bodyBytes));
          if (m is Map && m['error'] != null) errMsg = m['error'].toString();
        } catch (_) {}
        throw WishlistApiException(errMsg);
      }
    } finally {
      if (_client == null) own.close();
    }
  }

  /// Updates `wishlists.msg` only (max 50 characters on server).
  Future<void> patchWishlistMessage({
    required int userId,
    required String msg,
  }) async {
    final path = BackendConfig.wishlistPath;
    final alt = path.startsWith('api/') ? path.substring(4) : 'api/$path';
    final own = _client ?? http.Client();
    var trimmed = msg.trim();
    if (trimmed.length > 50) trimmed = trimmed.substring(0, 50);
    if (trimmed.isEmpty) trimmed = 'Best cards Please';
    final payload = jsonEncode({'user_id': userId, 'msg': trimmed});
    try {
      Future<http.Response> patchP(String p) => own
          .patch(
            _uri(p),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 20));

      var res = await patchP(path);
      if (res.statusCode == 404) res = await patchP(alt);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        var errMsg = 'Wishlist message save failed (${res.statusCode})';
        try {
          final m = jsonDecode(
            utf8.decode(res.bodyBytes, allowMalformed: true),
          );
          if (m is Map && m['error'] != null) errMsg = m['error'].toString();
        } catch (_) {}
        throw WishlistApiException(errMsg);
      }
    } finally {
      if (_client == null) own.close();
    }
  }
}
