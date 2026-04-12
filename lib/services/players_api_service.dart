import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/player.dart';
import '../models/team.dart';

class TeamWithPlayers {
  final Team team;
  final List<Player> players;
  const TeamWithPlayers({required this.team, required this.players});
}

class PlayersApiService {
  PlayersApiService({http.Client? client}) : _client = client;
  final http.Client? _client;

  Uri _uri(String path) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$normalized/$p');
  }

  Future<TeamWithPlayers> fetchTeamWithPlayers(int teamId) async {
    final own = _client ?? http.Client();
    try {
      final res = await own
          .get(_uri('api/teams/$teamId'), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Server error: ${res.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      final team = Team.fromJson(decoded['team'] as Map<String, dynamic>);
      final players = (decoded['players'] as List<dynamic>)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList();

      return TeamWithPlayers(team: team, players: players);
    } finally {
      if (_client == null) own.close();
    }
  }
}
