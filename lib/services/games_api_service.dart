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

  /// Distinct `games.week` values for a competition (ascending). Empty if none set.
  Future<List<int>> fetchGameWeeks({required int competitionId}) async {
    final q = <String, String>{'competition_id': '$competitionId'};
    final paths = _pair('games/weeks');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .get(_rootUri(p, q), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 25));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw GamesApiException('Game weeks failed (${res.statusCode})');
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is! Map) return [];
        final raw = d['weeks'];
        if (raw is! List) return [];
        final out = <int>[];
        for (final e in raw) {
          final n = e is int ? e : int.tryParse(e.toString());
          if (n != null) out.add(n);
        }
        out.sort();
        return out;
      }
      throw GamesApiException('Game weeks route not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  /// Games for a competition (e.g. Lebanese league `42001`). Optional [week] filters `games.week`.
  Future<List<Map<String, dynamic>>> fetchGames({int? competitionId, int? week}) async {
    final q = <String, String>{};
    if (competitionId != null) q['competition_id'] = '$competitionId';
    if (week != null) q['week'] = '$week';
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

  /// Full box score: `games` + `team_boxscores` + `player_boxscores` + `game_events` (play-by-play).
  Future<Map<String, dynamic>> fetchBoxscore({required int matchId}) async {
    final paths = _pair('games/$matchId/boxscore');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .get(_rootUri(p), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 25));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var msg = 'Box score failed (${res.statusCode})';
          try {
            final m = jsonDecode(utf8.decode(res.bodyBytes));
            if (m is Map && m['error'] != null) msg = m['error'].toString();
          } catch (_) {}
          throw GamesApiException(msg);
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is Map<String, dynamic>) return d;
        if (d is Map) return Map<String, dynamic>.from(d);
        throw GamesApiException('Invalid box score JSON');
      }
      throw GamesApiException('Box score route not found');
    } finally {
      if (_client == null) own.close();
    }
  }
}
