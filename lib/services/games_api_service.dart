import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class GamesApiException implements Exception {
  GamesApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GamesApiService {
  GamesApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _rootUri(String suffix, [Map<String, String>? query]) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final s = suffix.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$s');
    return query == null ? u : u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  List<String> _pair(String prefix) {
    if (prefix.startsWith('api/')) return [prefix, prefix.substring(4)];
    return [prefix, 'api/$prefix'];
  }

  /// Games for a competition (e.g. Lebanese league `42001`).
  Future<List<Map<String, dynamic>>> fetchGames({int? competitionId}) async {
    final q = <String, String>{};
    if (competitionId != null) q['competition_id'] = '$competitionId';
    final paths = _pair('games');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .get(_rootUri(p, q.isEmpty ? null : q), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 25));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw GamesApiException('Games list failed (${res.statusCode})');
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is! List) return [];
        return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      throw GamesApiException('Games route not found');
    } finally {
      if (_client == null) own.close();
    }
  }
}
