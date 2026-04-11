import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/catalog_card.dart';

class CatalogApiException implements Exception {
  CatalogApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CatalogApiService {
  CatalogApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path, Map<String, String> query) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$p');
    return u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  static bool _looksLikeHtml(String body) {
    final t = body.trimLeft().toLowerCase();
    return t.startsWith('<!doctype') || t.startsWith('<html');
  }

  Future<List<CatalogCard>> fetchCatalog({
    required int userId,
    String? position,
    String? nationality,
    int? teamId,
    bool onlyMissing = false,
  }) async {
    final configured = BackendConfig.catalogPath;
    final fallback = configured.startsWith('api/')
        ? configured.substring(4)
        : 'api/$configured';

    final query = <String, String>{
      'user_id': '$userId',
      if (position != null && position.isNotEmpty) 'position': position,
      if (nationality != null && nationality.isNotEmpty) 'nationality': nationality,
      if (teamId != null) 'team_id': '$teamId',
      if (onlyMissing) 'only_missing': '1',
    };

    final own = _client ?? http.Client();
    try {
      Future<http.Response> getPath(String path) {
        return own
            .get(_uri(path, query), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 30));
      }

      http.Response res = await getPath(configured);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      final bad = _looksLikeHtml(preview) || preview.toLowerCase().contains('cannot get');
      if (res.statusCode == 404 || (res.statusCode >= 400 && bad)) {
        res = await getPath(fallback);
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw CatalogApiException('Catalog failed (${res.statusCode})');
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw CatalogApiException('Invalid catalog JSON');
      final list = decoded['cards'];
      if (list is! List<dynamic>) throw CatalogApiException('Missing cards array');
      return list
          .map((e) => CatalogCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } finally {
      if (_client == null) own.close();
    }
  }
}
