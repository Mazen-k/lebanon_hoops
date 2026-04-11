import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/sign_up_data.dart';
import '../models/user_session.dart';
import 'auth_service.dart';

class AuthApiService implements AuthService {
  AuthApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$normalized/$p');
  }

  static bool _looksWrongBody(String body) {
    final t = body.trimLeft().toLowerCase();
    return t.startsWith('<!doctype') ||
        t.startsWith('<html') ||
        body.toLowerCase().contains('cannot post');
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final own = _client ?? http.Client();
    try {
      Future<http.Response> send(String p) {
        return own
            .post(
              _uri(p),
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 25));
      }

      http.Response res = await send(path);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      final retry =
          res.statusCode == 404 || (res.statusCode >= 400 && _looksWrongBody(preview));
      if (retry) {
        res = await send('api/$path');
      }
      return res;
    } finally {
      if (_client == null) {
        own.close();
      }
    }
  }

  UserSession _parseSession(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      var msg = 'Request failed (${res.statusCode})';
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (_looksWrongBody(body)) {
        msg =
            'Auth server not reachable or wrong URL. Point API_BASE_URL at your Node API (npm start in /api).';
      } else {
        try {
          final err = jsonDecode(body);
          if (err is Map && err['error'] != null) msg = err['error'].toString();
        } catch (_) {
          if (body.isNotEmpty) msg = body;
        }
      }
      throw AuthException(msg);
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) throw AuthException('Invalid auth response');
    return UserSession.fromJson(decoded);
  }

  @override
  Future<UserSession> login({required String usernameOrEmail, required String password}) async {
    final res = await _post(
      BackendConfig.authLoginPath,
      {
        'usernameOrEmail': usernameOrEmail.trim(),
        'password': password,
      },
    );
    return _parseSession(res);
  }

  @override
  Future<UserSession> signUp(SignUpData data) async {
    final body = <String, dynamic>{
      'username': data.username,
      'email': data.email,
      'password': data.password,
      if (data.phoneNumber != null) 'phone_number': data.phoneNumber,
      if (data.favoriteTeamId != null) 'favorite_team_id': data.favoriteTeamId,
    };
    final res = await _post(BackendConfig.authRegisterPath, body);
    return _parseSession(res);
  }
}
