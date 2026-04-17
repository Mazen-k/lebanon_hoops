import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/vendor_session.dart';

class VendorAuthApiException implements Exception {
  VendorAuthApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class VendorAuthApiService {
  VendorAuthApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$normalized/$p');
  }

  (String, String) _pair(String path) {
    if (path.startsWith('api/')) return (path, path.substring(4));
    return (path, 'api/$path');
  }

  Map<String, String> _bearer(String token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static bool _looksLikeHtml(String body) {
    final t = body.trimLeft().toLowerCase();
    return t.startsWith('<!doctype') || t.startsWith('<html');
  }

  static String? _errBody(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] != null) return j['error'].toString();
    } catch (_) {}
    return null;
  }

  Future<VendorSession> courtLogin({required String username, required String password}) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair('auth/court-login');
    try {
      Future<http.Response> send(String p) {
        return own
            .post(
              _uri(p),
              headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
              body: jsonEncode({'username': username.trim(), 'password': password}),
            )
            .timeout(const Duration(seconds: 25));
      }

      http.Response res = await send(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) {
        res = await send(b);
      }
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw VendorAuthApiException(_errBody(body) ?? 'Court login failed (${res.statusCode})', statusCode: res.statusCode);
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw VendorAuthApiException('Invalid response');
      return VendorSession.fromJson(decoded);
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<List<Map<String, dynamic>>> listPlaygrounds(String token) async {
    final res = await _authGet('vendor/playgrounds', token);
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw VendorAuthApiException(_errBody(body) ?? 'Failed to load playgrounds', statusCode: res.statusCode);
    }
    final j = jsonDecode(body);
    if (j is! Map) return [];
    final list = j['playgrounds'];
    if (list is! List) return [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createPlayground(
    String token, {
    required String name,
    required double pricePerHour,
    bool canHalfCourt = false,
    bool isActive = true,
  }) async {
    final res = await _authPost(
      'vendor/playgrounds',
      token,
      {
        'playground_name': name,
        'price_per_hour': pricePerHour,
        'can_half_court': canHalfCourt,
        'is_active': isActive,
      },
    );
    _throwIfBad(res);
  }

  Future<void> patchPlayground(
    String token, {
    required int playgroundId,
    String? name,
    double? pricePerHour,
    bool? canHalfCourt,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['playground_name'] = name;
    if (pricePerHour != null) body['price_per_hour'] = pricePerHour;
    if (canHalfCourt != null) body['can_half_court'] = canHalfCourt;
    if (isActive != null) body['is_active'] = isActive;
    final res = await _authPatch('vendor/playgrounds/$playgroundId', token, body);
    _throwIfBad(res);
  }

  Future<void> addPlaygroundPhoto(String token, {required int playgroundId, required String photoUrl}) async {
    final res = await _authPost(
      'vendor/playgrounds/$playgroundId/photos',
      token,
      {'photo_url': photoUrl.trim()},
    );
    _throwIfBad(res);
  }

  Future<void> deletePhoto(String token, {required int photoId}) async {
    final res = await _authDelete('vendor/photos/$photoId', token);
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      throw VendorAuthApiException(_errBody(body) ?? 'Delete failed', statusCode: res.statusCode);
    }
  }

  Future<List<Map<String, dynamic>>> listAvailability(String token, {required int playgroundId}) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair('vendor/availability');
    try {
      Future<http.Response> one(String p) {
        final u = _uri(p).replace(queryParameters: {'playground_id': '$playgroundId'});
        return own.get(u, headers: _bearer(token)).timeout(const Duration(seconds: 25));
      }

      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) {
        res = await one(b);
      }
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw VendorAuthApiException(_errBody(body) ?? 'Failed to load availability', statusCode: res.statusCode);
      }
      final j = jsonDecode(body);
      if (j is! Map) return [];
      final list = j['slots'];
      if (list is! List) return [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> createAvailability(
    String token, {
    required int playgroundId,
    required String availableDate,
    required String startTime,
    required String endTime,
  }) async {
    final res = await _authPost(
      'vendor/availability',
      token,
      {
        'playground_id': playgroundId,
        'available_date': availableDate,
        'start_time': startTime,
        'end_time': endTime,
      },
    );
    _throwIfBad(res);
  }

  Future<void> deleteAvailability(String token, {required int availabilityId}) async {
    final res = await _authDelete('vendor/availability/$availabilityId', token);
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      throw VendorAuthApiException(_errBody(body) ?? 'Delete failed', statusCode: res.statusCode);
    }
  }

  void _throwIfBad(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      throw VendorAuthApiException(_errBody(body) ?? 'Request failed (${res.statusCode})', statusCode: res.statusCode);
    }
  }

  Future<http.Response> _authGet(String path, String token) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) {
        return own.get(_uri(p), headers: _bearer(token)).timeout(const Duration(seconds: 25));
      }

      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) {
        res = await one(b);
      }
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<http.Response> _authPost(String path, String token, Map<String, dynamic> body) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) {
        return own
            .post(_uri(p), headers: _bearer(token), body: jsonEncode(body))
            .timeout(const Duration(seconds: 25));
      }

      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) {
        res = await one(b);
      }
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<http.Response> _authPatch(String path, String token, Map<String, dynamic> body) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) {
        return own
            .patch(_uri(p), headers: _bearer(token), body: jsonEncode(body))
            .timeout(const Duration(seconds: 25));
      }

      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) {
        res = await one(b);
      }
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<http.Response> _authDelete(String path, String token) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) {
        return own.delete(_uri(p), headers: _bearer(token)).timeout(const Duration(seconds: 25));
      }

      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) {
        res = await one(b);
      }
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }
}
