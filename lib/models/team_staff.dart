class TeamStaffMember {
  const TeamStaffMember({
    required this.staffId,
    required this.teamId,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.pictureUrl,
  });

  final int staffId;
  final int teamId;
  final String firstName;
  final String lastName;
  final String role;
  final String? pictureUrl;

  String get fullName => '$firstName $lastName'.trim();

  factory TeamStaffMember.fromJson(Map<String, dynamic> json) {
    final id = json['staff_id'] ?? json['staffId'];
    final tid = json['team_id'] ?? json['teamId'];
    if (id == null || tid == null) {
      throw FormatException('Expected staff_id and team_id: $json');
    }
    final int sid = id is int ? id : (id as num).toInt();
    final int teamParsed = tid is int ? tid : (tid as num).toInt();
    final pic = json['picture_url'] ?? json['pictureUrl'];
    return TeamStaffMember(
      staffId: sid,
      teamId: teamParsed,
      firstName: (json['first_name'] ?? json['firstName'] ?? '').toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      pictureUrl: pic?.toString().trim().isEmpty == true ? null : pic?.toString(),
    );
  }
}
