class Player {
  final int playerId;
  final int jerseyNumber;
  final String firstName;
  final String lastName;
  final String nationality;
  final String position;
  final String? pictureUrl;
  final String? dominantHand;
  final String? dateOfBirth;
  final String? height;

  const Player({
    required this.playerId,
    required this.jerseyNumber,
    required this.firstName,
    required this.lastName,
    required this.nationality,
    required this.position,
    this.pictureUrl,
    this.dominantHand,
    this.dateOfBirth,
    this.height,
  });

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    final pic = json['image'] ??
        json['player_image'] ??
        json['picture_url'] ??
        json['pictureUrl'] ??
        json['player_image_url'] ??
        json['playerImageUrl'];
    return Player(
      playerId: _asInt(json['player_id']),
      jerseyNumber: _asInt(json['jersey_number']),
      firstName: json['first_name'] as String? ?? 'Unknown',
      lastName: json['last_name'] as String? ?? '',
      nationality: json['nationality'] as String? ?? '',
      position: json['position'] as String? ?? '',
      pictureUrl: pic?.toString().trim().isEmpty == true ? null : pic?.toString(),
      dominantHand: json['dominant_hand']?.toString(),
      dateOfBirth: json['dob']?.toString(),
      height: json['height']?.toString() ?? json['height_cm']?.toString(),
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}
