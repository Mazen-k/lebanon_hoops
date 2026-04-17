import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/team_staff.dart';
import '../models/team_stadium.dart';
import '../models/team_trophy.dart';

class TeamWithPlayers {
  final Team team;
  final List<Player> players;
  final List<TeamTrophySummary> trophies;
  final TeamStadium? stadium;
  final List<TeamStaffMember> staff;

  const TeamWithPlayers({
    required this.team,
    required this.players,
    this.trophies = const [],
    this.stadium,
    this.staff = const [],
  });
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
      final trophiesRaw = decoded['trophies'];
      final trophies = trophiesRaw is List<dynamic>
          ? trophiesRaw
              .map((t) => TeamTrophySummary.fromJson(Map<String, dynamic>.from(t as Map)))
              .toList()
          : <TeamTrophySummary>[];

      TeamStadium? stadium;
      final stadiumRaw = decoded['stadium'];
      if (stadiumRaw is Map) {
        try {
          stadium = TeamStadium.fromJson(Map<String, dynamic>.from(stadiumRaw));
        } catch (_) {
          stadium = null;
        }
      }

      final staffRaw = decoded['staff'];
      final staff = staffRaw is List<dynamic>
          ? staffRaw
              .map((e) => TeamStaffMember.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : <TeamStaffMember>[];

      return TeamWithPlayers(
        team: team,
        players: players,
        trophies: trophies,
        stadium: stadium,
        staff: staff,
      );
    } finally {
      if (_client == null) own.close();
    }
  }
}
