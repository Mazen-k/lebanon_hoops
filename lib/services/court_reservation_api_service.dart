import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/court_reservation_models.dart';

class CourtReservationApiException implements Exception {
  CourtReservationApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CourtReservationApiService {
  CourtReservationApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$p');
    return query == null ? u : u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  (String, String) _pair(String path) {
    if (path.startsWith('api/')) return (path, path.substring(4));
    return (path, 'api/$path');
  }

  static bool _looksLikeHtml(String body) {
    final t = body.trimLeft().toLowerCase();
    return t.startsWith('<!doctype') || t.startsWith('<html');
  }

  Future<http.Response> _get(String path, [Map<String, String>? query]) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) {
        return own
            .get(_uri(p, query), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 25));
      }

      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      final bad = _looksLikeHtml(preview) || preview.toLowerCase().contains('cannot get');
      if (res.statusCode == 404 || (res.statusCode >= 400 && bad)) {
        res = await one(b);
      }
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) {
        return own
            .post(
              _uri(p),
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 25));
      }

      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      final bad = _looksLikeHtml(preview) || preview.toLowerCase().contains('cannot post');
      if (res.statusCode == 404 || (res.statusCode >= 400 && bad)) {
        res = await one(b);
      }
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<List<CourtSummary>> fetchCourts({String? search}) async {
    final q = <String, String>{};
    final s = search?.trim();
    if (s != null && s.isNotEmpty) q['search'] = s;

    final res = await _get('public/courts', q.isEmpty ? null : q);
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode == 503) {
      throw CourtReservationApiException(_extractError(body) ?? 'Court module not installed on server.', statusCode: 503);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CourtReservationApiException(_extractError(body) ?? 'Failed to load courts (${res.statusCode})', statusCode: res.statusCode);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw CourtReservationApiException('Invalid courts response');
    }
    final list = decoded['courts'];
    if (list is! List<dynamic>) return [];
    return list.map((e) => CourtSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<({CourtSummary court, List<PlaygroundSummary> playgrounds})> fetchCourtPlaygrounds(int courtId) async {
    final res = await _get('public/courts/$courtId/playgrounds');
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode == 404) {
      throw CourtReservationApiException('Court not found', statusCode: 404);
    }
    if (res.statusCode == 503) {
      throw CourtReservationApiException(_extractError(body) ?? 'Court module not installed.', statusCode: 503);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CourtReservationApiException(_extractError(body) ?? 'Failed to load playgrounds', statusCode: res.statusCode);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw CourtReservationApiException('Invalid playgrounds response');
    }
    final courtMap = decoded['court'];
    final list = decoded['playgrounds'];
    if (courtMap is! Map<String, dynamic>) {
      throw CourtReservationApiException('Missing court in response');
    }
    final court = CourtSummary.fromJson(courtMap);
    final playgrounds = list is List<dynamic>
        ? list.map((e) => PlaygroundSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <PlaygroundSummary>[];
    return (court: court, playgrounds: playgrounds);
  }

  Future<List<AvailabilitySlotDto>> fetchAvailability({
    required int playgroundId,
    required DateTime date,
  }) async {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final res = await _get(
      'public/playgrounds/$playgroundId/availability',
      {'date': '$y-$m-$d'},
    );
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode == 503) {
      throw CourtReservationApiException(_extractError(body) ?? 'Court module not installed.', statusCode: 503);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CourtReservationApiException(_extractError(body) ?? 'Failed to load slots', statusCode: res.statusCode);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw CourtReservationApiException('Invalid availability response');
    }
    final list = decoded['slots'];
    if (list is! List<dynamic>) return [];
    return list.map((e) => AvailabilitySlotDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> createReservation({
    required int userId,
    required int availabilityId,
  }) async {
    final res = await _post('public/reservations', {
      'user_id': userId,
      'availability_id': availabilityId,
    });
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode == 409) {
      throw CourtReservationApiException(_extractError(body) ?? 'Slot no longer available', statusCode: 409);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CourtReservationApiException(_extractError(body) ?? 'Booking failed (${res.statusCode})', statusCode: res.statusCode);
    }
  }

  static String? _extractError(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] != null) return j['error'].toString();
    } catch (_) {}
    return null;
  }
}
