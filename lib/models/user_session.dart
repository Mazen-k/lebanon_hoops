class UserSession {
  final int userId;
  final String username;
  final String email;

  const UserSession({
    required this.userId,
    required this.username,
    required this.email,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final idVal = json['user_id'] ?? json['userId'];
    final userId = idVal is int ? idVal : int.parse(idVal.toString());
    return UserSession(
      userId: userId,
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }
}
