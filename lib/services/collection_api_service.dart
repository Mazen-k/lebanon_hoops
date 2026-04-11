import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/collection_card.dart';

class CollectionApiException implements Exception {
  CollectionApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CollectionApiService {
  CollectionApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path, int userId, [Map<String, String>? extraQuery]) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$p');
    return u.replace(queryParameters: {
      ...u.queryParameters,
      'user_id': '$userId',
      ...?extraQuery,
    });
  }

  static bool _looksLikeHtmlError(String body) {
    final t = body.trimLeft().toLowerCase();
    return t.startsWith('<!doctype') || t.startsWith('<html');
  }

  Future<List<CollectionCard>> fetchCollection({required int userId}) {
    final configured = BackendConfig.collectionPath;
    final fallback = configured == 'collection'
        ? 'api/collection'
        : (configured == 'api/collection' ? 'collection' : null);
    return _fetchCards(
      configured: configured,
      fallback: fallback,
      userId: userId,
      label: 'Collection',
      extraQuery: null,
    );
  }

  /// Uses the **same URL as [fetchCollection]** plus `duplicates_only=1` so it works
  /// whenever collection works (no separate `/collection-duplicates` route required).
  Future<List<CollectionCard>> fetchCollectionDuplicates({required int userId}) {
    final configured = BackendConfig.collectionPath;
    final fallback = configured == 'collection'
        ? 'api/collection'
        : (configured == 'api/collection' ? 'collection' : null);
    return _fetchCards(
      configured: configured,
      fallback: fallback,
      userId: userId,
      label: 'Duplicates',
      extraQuery: const {'duplicates_only': '1'},
    );
  }

  Future<List<CollectionCard>> _fetchCards({
    required String configured,
    required String? fallback,
    required int userId,
    required String label,
    required Map<String, String>? extraQuery,
  }) async {
    final own = _client ?? http.Client();
    try {
      Future<http.Response> send(String path) {
        return own
            .get(
              _uri(path, userId, extraQuery),
              headers: const {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 25));
      }

      http.Response res = await send(configured);
      final bodyPreview = utf8.decode(res.bodyBytes, allowMalformed: true);
      final looksWrong = _looksLikeHtmlError(bodyPreview);
      final shouldRetry = res.statusCode == 404 || (res.statusCode >= 400 && looksWrong);
      if (shouldRetry && fallback != null) {
        res = await send(fallback);
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        var msg = '$label failed (${res.statusCode})';
        final errBody = utf8.decode(res.bodyBytes, allowMalformed: true);
        if (_looksLikeHtmlError(errBody)) {
          msg = '$label API not reachable. Check API_BASE_URL and `npm start` in /api.';
        } else {
          try {
            final err = jsonDecode(errBody);
            if (err is Map && err['error'] != null) msg = err['error'].toString();
          } catch (_) {
            if (errBody.isNotEmpty) msg = errBody;
          }
        }
        throw CollectionApiException(msg);
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw CollectionApiException('Invalid $label response');
      }
      final list = decoded['cards'];
      if (list is! List<dynamic>) {
        throw CollectionApiException('Response missing cards array');
      }
      return list.map((e) {
        if (e is! Map<String, dynamic>) {
          throw CollectionApiException('Invalid card in $label');
        }
        return CollectionCard.fromJson(e);
      }).toList();
    } finally {
      if (_client == null) {
        own.close();
      }
    }
  }
}
