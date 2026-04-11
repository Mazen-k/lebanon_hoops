import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/opened_card.dart';

class PacksApiException implements Exception {
  PacksApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PacksApiService {
  PacksApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$normalized/$p');
  }

  static bool _looksLikeHtmlError(String body) {
    final t = body.trimLeft().toLowerCase();
    return t.startsWith('<!doctype') || t.startsWith('<html');
  }

  Future<http.Response> _postOpen(http.Client own, Uri uri, int userId) {
    return own
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'userId': userId,
            'packId': 'standard',
          }),
        )
        .timeout(const Duration(seconds: 30));
  }

  Future<List<OpenedCard>> openStandardPack({required int userId}) async {
    final configured = BackendConfig.packsOpenPath;
    final fallback =
        configured == 'packs/open' ? 'api/packs/open' : (configured == 'api/packs/open' ? 'packs/open' : null);

    final own = _client ?? http.Client();
    try {
      http.Response res = await _postOpen(own, _uri(configured), userId);

      final bodyPreview = utf8.decode(res.bodyBytes, allowMalformed: true);
      final looksWrong = _looksLikeHtmlError(bodyPreview) ||
          bodyPreview.toLowerCase().contains('cannot post');
      final shouldRetryFallback =
          res.statusCode == 404 || (res.statusCode >= 400 && looksWrong);

      if (shouldRetryFallback && fallback != null) {
        res = await _postOpen(own, _uri(fallback), userId);
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final errBody = utf8.decode(res.bodyBytes, allowMalformed: true);
        String msg = 'Pack open failed (${res.statusCode}) at ${res.request?.url}';
        if (_looksLikeHtmlError(errBody) || errBody.toLowerCase().contains('cannot post')) {
          msg =
              'Wrong server or route: got HTML/text instead of JSON. Point API_BASE_URL at your Node API (folder api, port 3000), run `npm start`, then restart the app. If routes live under /api, use: --dart-define=API_PACKS_OPEN_PATH=api/packs/open';
        }
        try {
          final err = jsonDecode(utf8.decode(res.bodyBytes));
          if (err is Map && err['error'] != null) msg = err['error'].toString();
        } catch (_) {
          if (res.body.isNotEmpty && !_looksLikeHtmlError(errBody)) msg = res.body;
        }
        throw PacksApiException(msg);
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw PacksApiException('Invalid pack response');
      }
      final list = decoded['cards'];
      if (list is! List<dynamic>) {
        throw PacksApiException('Response missing cards array');
      }
      return list
          .map((e) {
            if (e is! Map<String, dynamic>) {
              throw PacksApiException('Invalid card object');
            }
            return OpenedCard.fromJson(e);
          })
          .toList();
    } finally {
      if (_client == null) {
        own.close();
      }
    }
  }
}
