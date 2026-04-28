import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/sbc_challenge.dart';

class SbcApiException implements Exception {
  SbcApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SbcApiService {
  SbcApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _baseUri(String path, [Map<String, String>? query]) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$p');
    return query == null ? u : u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  static bool _looksLikeHtmlError(String body) {
    final t = body.trimLeft().toLowerCase();
    return t.startsWith('<!doctype') || t.startsWith('<html');
  }

  Future<List<SbcChallenge>> fetchChallenges({required int userId}) async {
    final path = BackendConfig.sbcChallengesPath;
    final alt = path.startsWith('api/') ? path.substring(4) : 'api/$path';
    final own = _client ?? http.Client();
    try {
      Future<http.Response> getP(String p) => own
          .get(
            _baseUri(p, {'user_id': '$userId'}),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 25));
      var res = await getP(path);
      final firstBody = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtmlError(firstBody))) {
        res = await getP(alt);
      }
      final bodyStr = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        var msg = 'SBC load failed (${res.statusCode})';
        try {
          final err = jsonDecode(bodyStr);
          if (err is Map && err['error'] != null) msg = err['error'].toString();
        } catch (_) {
          if (bodyStr.isNotEmpty) msg = bodyStr;
        }
        throw SbcApiException(msg);
      }
      final decoded = jsonDecode(bodyStr);
      if (decoded is! Map<String, dynamic>) {
        throw SbcApiException('Invalid SBC response');
      }
      final raw = decoded['challenges'];
      if (raw is! List) {
        throw SbcApiException('SBC response missing challenges list');
      }
      return raw
          .whereType<Map>()
          .map((e) => SbcChallenge.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<SbcSubmitResult> submitChallenge({
    required int userId,
    required int sbcId,
    required Map<String, int> slots,
  }) async {
    final path = BackendConfig.sbcSubmitPath;
    final alt = path.startsWith('api/') ? path.substring(4) : 'api/$path';
    final own = _client ?? http.Client();
    final body = {
      'user_id': userId,
      'sbc_id': sbcId,
      'slots': slots,
    };
    try {
      Future<http.Response> postP(String p) => own
          .post(
            _baseUri(p),
            headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      var res = await postP(path);
      final firstBody = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtmlError(firstBody))) {
        res = await postP(alt);
      }
      final bodyStr = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        var msg = 'SBC submit failed (${res.statusCode})';
        try {
          final err = jsonDecode(bodyStr);
          if (err is Map && err['error'] != null) msg = err['error'].toString();
        } catch (_) {
          if (bodyStr.isNotEmpty) msg = bodyStr;
        }
        throw SbcApiException(msg);
      }
      final decoded = jsonDecode(bodyStr);
      if (decoded is! Map<String, dynamic>) {
        throw SbcApiException('Invalid SBC submit response');
      }
      return SbcSubmitResult.fromJson(decoded);
    } finally {
      if (_client == null) own.close();
    }
  }
}
