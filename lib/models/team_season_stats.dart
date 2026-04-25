/// One row from `GET /games/team-stats?competition_id=…` (games + box scores).
class TeamSeasonStats {
  const TeamSeasonStats({
    required this.teamId,
    required this.teamName,
    this.teamLogoUrl,
    required this.gp,
    required this.pts,
    required this.reb,
    required this.ast,
    required this.fgm,
    required this.fga,
    required this.threePm,
    required this.threePa,
    required this.ftm,
    required this.fta,
    required this.oreb,
    required this.dreb,
    required this.stl,
    required this.blk,
  });

  final int teamId;
  final String teamName;
  final String? teamLogoUrl;
  final int gp;
  final int pts;
  final int reb;
  final int ast;
  final int fgm;
  final int fga;
  final int threePm;
  final int threePa;
  final int ftm;
  final int fta;
  final int oreb;
  final int dreb;
  final int stl;
  final int blk;

  static int _i(dynamic v, [int d = 0]) {
    if (v == null) return d;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString().trim()) ?? d;
  }

  factory TeamSeasonStats.fromJson(Map<String, dynamic> j) {
    final logo = j['team_logo'] ?? j['teamLogo'] ?? j['team_logo_url'];
    final logoStr = logo?.toString().trim();
    return TeamSeasonStats(
      teamId: _i(j['team_id'] ?? j['teamId']),
      teamName: (j['team_name'] ?? j['teamName'] ?? '').toString(),
      teamLogoUrl: (logoStr != null && logoStr.isNotEmpty) ? logoStr : null,
      gp: _i(j['gp']),
      pts: _i(j['pts']),
      reb: _i(j['reb']),
      ast: _i(j['ast']),
      fgm: _i(j['fgm']),
      fga: _i(j['fga']),
      threePm: _i(j['three_pm'] ?? j['threePm']),
      threePa: _i(j['three_pa'] ?? j['threePa']),
      ftm: _i(j['ftm']),
      fta: _i(j['fta']),
      oreb: _i(j['oreb']),
      dreb: _i(j['dreb']),
      stl: _i(j['stl']),
      blk: _i(j['blk']),
    );
  }
}
