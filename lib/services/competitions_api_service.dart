import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/competition.dart';

class CompetitionsApiException implements Exception {
  CompetitionsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Fetches the `competitions` list. Tries `GET /competitions` first, then
/// falls back to `GET /api/competitions`.
class CompetitionsApiService {
  CompetitionsApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _rootUri(String suffix) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final s = suffix.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$normalized/$s');
  }

  Future<List<Competition>> fetchCompetitions() async {
    final ownClient = _client ?? http.Client();
    final paths = ['competitions', 'api/competitions'];
    try {
      for (final p in paths) {
        http.Response res;
        try {
          res = await ownClient
              .get(_rootUri(p), headers: const {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 20));
        } catch (_) {
          continue;
        }
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw CompetitionsApiException(
            'Competitions request failed (${res.statusCode}).',
          );
        }
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final List<dynamic> raw;
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          final inner =
              decoded['competitions'] ??
              decoded['data'] ??
              decoded['rows'] ??
              decoded['results'];
          if (inner is! List) {
            throw CompetitionsApiException(
              'Unexpected competitions JSON shape: ${decoded.keys.join(', ')}',
            );
          }
          raw = inner;
        } else {
          throw CompetitionsApiException(
            'Unexpected competitions JSON: ${decoded.runtimeType}',
          );
        }
        final out = <Competition>[];
        for (final item in raw) {
          if (item is! Map) continue;
          try {
            out.add(Competition.fromJson(Map<String, dynamic>.from(item)));
          } on FormatException {
            continue;
          }
        }
        return out;
      }
      throw CompetitionsApiException('Competitions route not found.');
    } finally {
      if (_client == null) ownClient.close();
    }
  }
}
