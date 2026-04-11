import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/team.dart';

class TeamRepositoryException implements Exception {
  TeamRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Loads teams from your API (Postgres `BasketballApp`, table `teams`).
///
/// `GET` [resolved teams URL] — see [BackendConfig.apiBaseUrl] and [BackendConfig.teamsPath].
///
/// Accepts JSON:
/// - `[{ "team_id": 1, "team_name": "..." }, ...]`, or
/// - `{ "teams": [ ... ] }` / `{ "data": [ ... ] }`
class TeamRepository {
  const TeamRepository();

  Uri _teamsUri() {
    final base = BackendConfig.apiBaseUrl.trim();
    final baseUri = Uri.parse(base.endsWith('/') ? base.substring(0, base.length - 1) : base);
    final path = BackendConfig.teamsPath.trim().replaceAll(RegExp(r'^/+'), '');
    final segments = [...baseUri.pathSegments.where((s) => s.isNotEmpty), ...path.split('/')];
    return baseUri.replace(pathSegments: segments);
  }

  Map<String, dynamic>? _asJsonObject(dynamic item) {
    if (item is Map<String, dynamic>) return item;
    if (item is Map) {
      return item.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// Pass [client] in tests; otherwise a one-shot client is used and closed.
  Future<List<Team>> fetchTeams({http.Client? client}) async {
    final uri = _teamsUri();
    final ownClient = client ?? http.Client();
    try {
      late http.Response res;
      try {
        res = await ownClient
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        throw TeamRepositoryException(
          'Could not reach teams API at $uri.\n'
          '• Android emulator: use --dart-define=API_BASE_URL=http://10.0.2.2:PORT (not localhost).\n'
          '• If the route is /api/teams: --dart-define=API_TEAMS_PATH=api/teams\n'
          '($e)',
        );
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw TeamRepositoryException(
          'Teams request failed (${res.statusCode}) at $uri\n${res.body.isNotEmpty ? res.body : ""}',
        );
      }

      final dynamic decoded = jsonDecode(utf8.decode(res.bodyBytes));
      final List<dynamic> rawList;
      if (decoded is List<dynamic>) {
        rawList = decoded;
      } else if (decoded is Map) {
        final map = _asJsonObject(decoded);
        if (map == null) {
          throw TeamRepositoryException('Teams JSON root must be a list or object.');
        }
        final inner = map['teams'] ?? map['data'] ?? map['results'] ?? map['rows'];
        if (inner is! List<dynamic>) {
          throw TeamRepositoryException(
            'Expected a JSON array or an object with a "teams", "data", "results", or "rows" array. '
            'Keys found: ${map.keys.join(", ")}',
          );
        }
        rawList = inner;
      } else {
        throw TeamRepositoryException('Unexpected JSON for teams: ${decoded.runtimeType}');
      }

      final teams = <Team>[];
      final skipped = <String>[];
      for (final item in rawList) {
        final m = _asJsonObject(item);
        if (m == null) continue;
        try {
          teams.add(Team.fromJson(m));
        } on FormatException catch (e) {
          skipped.add(e.message);
        }
      }

      if (teams.isEmpty && rawList.isNotEmpty) {
        throw TeamRepositoryException(
          'API returned ${rawList.length} row(s) but none matched team_id + team_name. '
          'First item: ${rawList.first}. ${skipped.isNotEmpty ? skipped.first : ""}',
        );
      }

      teams.sort((a, b) => a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase()));
      return teams;
    } finally {
      if (client == null) {
        ownClient.close();
      }
    }
  }
}
