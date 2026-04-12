class Player {
  final int playerId;
  final int jerseyNumber;
  final String firstName;
  final String lastName;
  final String nationality;
  final String position;

  const Player({
    required this.playerId,
    required this.jerseyNumber,
    required this.firstName,
    required this.lastName,
    required this.nationality,
    required this.position,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      playerId: json['player_id'] as int,
      jerseyNumber: json['jersey_number'] as int,
      firstName: json['first_name'] as String? ?? 'Unknown',
      lastName: json['last_name'] as String? ?? '',
      nationality: json['nationality'] as String? ?? '',
      position: json['position'] as String? ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}
