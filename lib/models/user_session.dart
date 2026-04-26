class UserSession {
  final int userId;
  final String username;
  final String email;
  /// UUID from auth.users — null for sessions restored from legacy SharedPreferences cache.
  final String? authId;

  const UserSession({
    required this.userId,
    required this.username,
    required this.email,
    this.authId,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final idVal = json['user_id'] ?? json['userId'];
    final userId = idVal is int ? idVal : int.parse(idVal.toString());
    return UserSession(
      userId: userId,
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      authId: json['auth_id']?.toString(),
    );
  }
}
