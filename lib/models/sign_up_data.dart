/// Maps to `users` (server stores `password_hash`).
class SignUpData {
  final String username;
  final String email;
  final String password;
  final String? phoneNumber;
  final int? favoriteTeamId;

  const SignUpData({
    required this.username,
    required this.email,
    required this.password,
    this.phoneNumber,
    this.favoriteTeamId,
  });
}
