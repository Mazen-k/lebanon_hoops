import '../models/sign_up_data.dart';
import '../models/user_session.dart';

abstract class AuthService {
  Future<UserSession> login({required String usernameOrEmail, required String password});

  Future<UserSession> signUp(SignUpData data);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
