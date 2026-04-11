class Team {
  final int teamId;
  final String teamName;

  const Team({required this.teamId, required this.teamName});

  /// Parses rows from `SELECT team_id, team_name FROM teams` (JSON from your API).
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
    return Team(teamId: parsedId, teamName: name.toString());
  }
}
