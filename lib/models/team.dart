class Team {
  final int teamId;
  final String teamName;
  final String? logoUrl;
  final String? city;
  final String? about;

  const Team({
    required this.teamId,
    required this.teamName,
    this.logoUrl,
    this.city,
    this.about,
  });

  /// Parses rows from `SELECT team_id, team_name ... FROM teams` (JSON from your API).
  factory Team.fromJson(Map<String, dynamic> json) {
    final id = json['team_id'] ?? json['teamId'] ?? json['id'];
    final name = json['team_name'] ?? json['teamName'] ?? json['name'] ?? json['title'];
    if (id == null || name == null) {
      throw FormatException('Expected team_id and team_name in team JSON: $json');
    }
    final parsedId = id is int ? id : int.tryParse(id.toString());
    if (parsedId == null) {
      throw FormatException('Invalid team_id: $id');
    }
    final logo = json['team_logo_url'] ?? json['teamLogoUrl'] ?? json['logo_url'] ?? json['logoUrl'] ?? json['team_logos'];
    final city = json['city'] ?? json['home_city'] ?? json['homeCity'];
    final about = json['about'] ?? json['description'] ?? json['club_summary'] ?? json['clubSummary'];
    return Team(
      teamId: parsedId,
      teamName: name.toString(),
      logoUrl: logo?.toString().trim().isEmpty == true ? null : logo?.toString(),
      city: city?.toString(),
      about: about?.toString(),
    );
  }
}
