/// Normalized row from `GET /games` for fixture list UI.
class GameFixtureView {
  const GameFixtureView({
    required this.matchId,
    required this.metaLine,
    required this.leagueLabel,
    required this.homeName,
    required this.awayName,
    required this.isPast,
    this.homeScore,
    this.awayScore,
    this.centerLabel,
    this.homeLogoUrl,
    this.awayLogoUrl,
    this.venue,
  });

  final int matchId;
  final String metaLine;
  final String leagueLabel;
  final String homeName;
  final String awayName;
  final bool isPast;
  final int? homeScore;
  final int? awayScore;
  final String? centerLabel;
  final String? homeLogoUrl;
  final String? awayLogoUrl;
  final String? venue;

  factory GameFixtureView.fromGamesApiRow(Map<String, dynamic> json) {
    int? optInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    final matchId = optInt(json['match_id'] ?? json['matchId']) ?? 0;
    final status = (json['status'] ?? json['raw_status'] ?? '').toString().toLowerCase();
    final isPast = status == 'final';
    final dateText = (json['date_time_text'] ?? json['dateTimeText'] ?? '').toString().trim();
    final venue = (json['venue'] ?? '').toString().trim();
    final metaLine = dateText.isNotEmpty ? dateText : (venue.isNotEmpty ? venue : 'Match #$matchId');
    final home = (json['home_team_name'] ?? json['homeTeamName'] ?? 'Home').toString();
    final away = (json['away_team_name'] ?? json['awayTeamName'] ?? 'Away').toString();
    final homeScore = optInt(json['home_score'] ?? json['homeScore']);
    final awayScore = optInt(json['away_score'] ?? json['awayScore']);
    final homeRaw = json['home_team_logo']?.toString() ?? json['homeTeamLogo']?.toString();
    final awayRaw = json['away_team_logo']?.toString() ?? json['awayTeamLogo']?.toString();
    final homeLogo = homeRaw != null && homeRaw.trim().isNotEmpty ? homeRaw.trim() : null;
    final awayLogo = awayRaw != null && awayRaw.trim().isNotEmpty ? awayRaw.trim() : null;

    String? center;
    if (!isPast) {
      if (status == 'live') {
        center = 'LIVE';
      } else {
        center = dateText.isNotEmpty ? dateText : 'TBC';
      }
    }

    return GameFixtureView(
      matchId: matchId,
      metaLine: metaLine,
      leagueLabel: 'LBL',
      homeName: home,
      awayName: away,
      isPast: isPast,
      homeScore: homeScore,
      awayScore: awayScore,
      centerLabel: center,
      homeLogoUrl: homeLogo,
      awayLogoUrl: awayLogo,
      venue: venue.isEmpty ? null : venue,
    );
  }
}
