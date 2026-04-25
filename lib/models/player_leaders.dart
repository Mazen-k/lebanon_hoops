class PlayerLeaderRow {
  const PlayerLeaderRow({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.playerNumber,
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.headshotUrl,
    required this.gp,
    required this.value,
    required this.decimals,
  });

  final int rank;
  final int? playerId;
  final String playerName;
  final String playerNumber;
  final String? position;
  final int teamId;
  final String teamName;
  final String? teamLogo;
  final String? headshotUrl;
  final int gp;
  final double value;
  final int decimals;

  factory PlayerLeaderRow.fromJson(Map<String, dynamic> j) {
    return PlayerLeaderRow(
      rank: (j['rank'] as num?)?.toInt() ?? 0,
      playerId: (j['player_id'] as num?)?.toInt(),
      playerName: (j['player_name'] ?? '').toString(),
      playerNumber: (j['player_number'] ?? '').toString(),
      position: j['position']?.toString(),
      teamId: (j['team_id'] as num?)?.toInt() ?? 0,
      teamName: (j['team_name'] ?? '').toString(),
      teamLogo: j['team_logo']?.toString(),
      headshotUrl: j['headshot_url']?.toString(),
      gp: (j['gp'] as num?)?.toInt() ?? 0,
      value: (j['value'] as num?)?.toDouble() ?? 0,
      decimals: (j['decimals'] as num?)?.toInt() ?? 1,
    );
  }

  String get valueLabel => value.toStringAsFixed(decimals);

  String get positionLabel {
    final p = position?.trim();
    if (p == null || p.isEmpty) return '—';
    return p;
  }
}

class PlayerStatLeaderGroup {
  const PlayerStatLeaderGroup({
    required this.key,
    required this.title,
    required this.decimals,
    required this.ascending,
    required this.top3,
  });

  final String key;
  final String title;
  final int decimals;
  final bool ascending;
  final List<PlayerLeaderRow> top3;

  factory PlayerStatLeaderGroup.fromJson(Map<String, dynamic> j) {
    final raw = j['top3'];
    final list = <PlayerLeaderRow>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(PlayerLeaderRow.fromJson(e));
        } else if (e is Map) {
          list.add(PlayerLeaderRow.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return PlayerStatLeaderGroup(
      key: (j['key'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      decimals: (j['decimals'] as num?)?.toInt() ?? 1,
      ascending: j['ascending'] == true,
      top3: list,
    );
  }
}

class PlayerLeadersSummary {
  const PlayerLeadersSummary({
    required this.competitionId,
    required this.stats,
  });

  final int competitionId;
  final List<PlayerStatLeaderGroup> stats;

  factory PlayerLeadersSummary.fromJson(Map<String, dynamic> j) {
    final raw = j['stats'];
    final list = <PlayerStatLeaderGroup>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(PlayerStatLeaderGroup.fromJson(e));
        } else if (e is Map) {
          list.add(
            PlayerStatLeaderGroup.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return PlayerLeadersSummary(
      competitionId: (j['competition_id'] as num?)?.toInt() ?? 0,
      stats: list,
    );
  }
}

class PlayerLeadersDetail {
  const PlayerLeadersDetail({
    required this.competitionId,
    required this.stat,
    required this.title,
    required this.decimals,
    required this.ascending,
    required this.rows,
  });

  final int competitionId;
  final String stat;
  final String title;
  final int decimals;
  final bool ascending;
  final List<PlayerLeaderRow> rows;

  factory PlayerLeadersDetail.fromJson(Map<String, dynamic> j) {
    final raw = j['rows'];
    final list = <PlayerLeaderRow>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(PlayerLeaderRow.fromJson(e));
        } else if (e is Map) {
          list.add(PlayerLeaderRow.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return PlayerLeadersDetail(
      competitionId: (j['competition_id'] as num?)?.toInt() ?? 0,
      stat: (j['stat'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      decimals: (j['decimals'] as num?)?.toInt() ?? 1,
      ascending: j['ascending'] == true,
      rows: list,
    );
  }
}
