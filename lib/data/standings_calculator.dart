/// One row of the standings table, aggregated from finished games.
///
/// `leaguePoints` follows the FIBA convention the user asked for:
/// every game played is worth 1 point, wins get a bonus → `wins * 2 + losses`.
class StandingRow {
  const StandingRow({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.wins,
    required this.losses,
    required this.pointsFor,
    required this.pointsAgainst,
  });

  final String teamId;
  final String teamName;
  final String? teamLogo;
  final int wins;
  final int losses;
  final int pointsFor;
  final int pointsAgainst;

  int get gamesPlayed => wins + losses;
  int get diff => pointsFor - pointsAgainst;
  int get leaguePoints => wins * 2 + losses;

  StandingRow _add({bool? win, required int scored, required int conceded}) {
    return StandingRow(
      teamId: teamId,
      teamName: teamName,
      teamLogo: teamLogo,
      wins: wins + ((win ?? false) ? 1 : 0),
      losses: losses + ((win == false) ? 1 : 0),
      pointsFor: pointsFor + scored,
      pointsAgainst: pointsAgainst + conceded,
    );
  }
}

/// Aggregates a `/games` payload into a sorted [StandingRow] list.
///
/// Only games with both scores present are counted (i.e. games that were
/// actually played). Ties in league points are broken by point differential,
/// then total points scored, then team name.
List<StandingRow> computeStandings(Iterable<Map<String, dynamic>> gameRows) {
  final byId = <String, StandingRow>{};

  String? asStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int? asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  bool hasPlayed(Map<String, dynamic> g) {
    final hs = asInt(g['home_score'] ?? g['homeScore']);
    final as = asInt(g['away_score'] ?? g['awayScore']);
    return hs != null && as != null;
  }

  void touch(
    String id,
    String name,
    String? logo, {
    required bool win,
    required int scored,
    required int conceded,
  }) {
    final existing = byId[id];
    final base =
        existing ??
        StandingRow(
          teamId: id,
          teamName: name,
          teamLogo: logo,
          wins: 0,
          losses: 0,
          pointsFor: 0,
          pointsAgainst: 0,
        );
    // Prefer a non-null logo if we see one later.
    final merged =
        (existing != null && existing.teamLogo == null && logo != null)
        ? StandingRow(
            teamId: base.teamId,
            teamName: base.teamName,
            teamLogo: logo,
            wins: base.wins,
            losses: base.losses,
            pointsFor: base.pointsFor,
            pointsAgainst: base.pointsAgainst,
          )
        : base;
    byId[id] = merged._add(win: win, scored: scored, conceded: conceded);
  }

  for (final g in gameRows) {
    if (!hasPlayed(g)) continue;

    final homeId = asStr(g['home_team_id'] ?? g['homeTeamId']);
    final awayId = asStr(g['away_team_id'] ?? g['awayTeamId']);
    if (homeId == null || awayId == null) continue;

    final homeName =
        asStr(g['home_team_name'] ?? g['homeTeamName']) ?? 'Team $homeId';
    final awayName =
        asStr(g['away_team_name'] ?? g['awayTeamName']) ?? 'Team $awayId';
    final homeLogo = asStr(g['home_team_logo'] ?? g['homeTeamLogo']);
    final awayLogo = asStr(g['away_team_logo'] ?? g['awayTeamLogo']);

    final hs = asInt(g['home_score'] ?? g['homeScore'])!;
    final as = asInt(g['away_score'] ?? g['awayScore'])!;
    if (hs == as) continue; // basketball rarely ties; skip to be safe.

    final homeWon = hs > as;
    touch(homeId, homeName, homeLogo, win: homeWon, scored: hs, conceded: as);
    touch(awayId, awayName, awayLogo, win: !homeWon, scored: as, conceded: hs);
  }

  final rows = byId.values.toList();
  rows.sort((a, b) {
    final byPts = b.leaguePoints.compareTo(a.leaguePoints);
    if (byPts != 0) return byPts;
    final byDiff = b.diff.compareTo(a.diff);
    if (byDiff != 0) return byDiff;
    final byPf = b.pointsFor.compareTo(a.pointsFor);
    if (byPf != 0) return byPf;
    return a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase());
  });
  return rows;
}
