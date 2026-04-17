class TeamStadium {
  const TeamStadium({
    required this.stadiumId,
    required this.stadiumName,
    this.location,
    this.capacity,
    this.imageUrl,
  });

  final int stadiumId;
  final String stadiumName;
  final String? location;
  final int? capacity;
  /// When the API adds `stadium_image_url`, it maps here; otherwise null (UI shows placeholder).
  final String? imageUrl;

  factory TeamStadium.fromJson(Map<String, dynamic> json) {
    final id = json['stadium_id'] ?? json['stadiumId'];
    final name = json['stadium_name'] ?? json['stadiumName'];
    if (id == null || name == null) {
      throw FormatException('Expected stadium_id and stadium_name: $json');
    }
    final parsedId = id is int ? id : int.tryParse(id.toString());
    if (parsedId == null) throw FormatException('Invalid stadium_id: $id');
    final cap = json['capacity'] ?? json['stadium_capacity'];
    final capInt = cap == null ? null : (cap is int ? cap : int.tryParse(cap.toString()));
    final img = json['stadium_image_url'] ?? json['stadiumImageUrl'] ?? json['image_url'] ?? json['imageUrl'];
    return TeamStadium(
      stadiumId: parsedId,
      stadiumName: name.toString(),
      location: json['location']?.toString(),
      capacity: capInt,
      imageUrl: img?.toString().trim().isEmpty == true ? null : img?.toString(),
    );
  }
}
