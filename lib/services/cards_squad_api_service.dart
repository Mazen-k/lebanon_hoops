import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/cards_squad.dart';

class CardsSquadApiException implements Exception {
  CardsSquadApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CardsSquadLoadResult {
  const CardsSquadLoadResult.ok(CardsSquadPayload this.squad)
      : needInstances = false,
        have = 0,
        need = 5;

  const CardsSquadLoadResult.needMoreInstances({required this.have, required this.need})
      : squad = null,
        needInstances = true;

  final CardsSquadPayload? squad;
  final bool needInstances;
  final int have;
  final int need;
}

class CardsSquadApiService {
  CardsSquadApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _baseUri(String path, [Map<String, String>? query]) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$p');
    return query == null ? u : u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  Future<CardsSquadLoadResult> fetchSquad({
    required int userId,
    required int squadNumber,
  }) async {
    if (squadNumber < 1 || squadNumber > 3) {
      throw CardsSquadApiException('squad_number must be 1, 2, or 3');
    }
    final path = BackendConfig.cardsSquadPath;
    final alt = path.startsWith('api/') ? path.substring(4) : 'api/$path';
    final own = _client ?? http.Client();
    try {
      Future<http.Response> getP(String p) => own
          .get(
            _baseUri(p, {
              'user_id': '$userId',
              'squad_number': '$squadNumber',
            }),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 25));

      var res = await getP(path);
      if (res.statusCode == 404) res = await getP(alt);
      final bodyStr = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        var msg = 'Squad load failed (${res.statusCode})';
        try {
          final err = jsonDecode(bodyStr);
          if (err is Map && err['error'] != null) msg = err['error'].toString();
        } catch (_) {
          if (bodyStr.isNotEmpty && bodyStr.length < 220) msg = bodyStr;
        }
        throw CardsSquadApiException(msg);
      }
      final decoded = jsonDecode(bodyStr);
      if (decoded is! Map<String, dynamic>) {
        throw CardsSquadApiException('Invalid squad response');
      }
      if (decoded['need_instances'] == true) {
        final have = int.tryParse('${decoded['have'] ?? 0}') ?? 0;
        final need = int.tryParse('${decoded['need'] ?? 5}') ?? 5;
        return CardsSquadLoadResult.needMoreInstances(have: have, need: need);
      }
      final raw = decoded['squad'];
      if (raw == null) {
        return const CardsSquadLoadResult.needMoreInstances(have: 0, need: 5);
      }
      if (raw is! Map<String, dynamic>) {
        throw CardsSquadApiException('Invalid squad object');
      }
      return CardsSquadLoadResult.ok(CardsSquadPayload.fromJson(raw));
    } finally {
      if (_client == null) {
        own.close();
      }
    }
  }

  Future<CardsSquadPayload> patchSquad({
    required int userId,
    required int squadNumber,
    String? squadName,
    Map<String, int>? slots,
  }) async {
    if (squadNumber < 1 || squadNumber > 3) {
      throw CardsSquadApiException('squad_number must be 1, 2, or 3');
    }
    if (squadName == null && (slots == null || slots.isEmpty)) {
      throw CardsSquadApiException('Nothing to update');
    }
    final path = BackendConfig.cardsSquadPath;
    final alt = path.startsWith('api/') ? path.substring(4) : 'api/$path';
    final slotsBody = (slots != null && slots.isNotEmpty) ? slots : null;
    final body = <String, dynamic>{
      'user_id': userId,
      'squad_number': squadNumber,
      'squad_name': ?squadName,
      'slots': ?slotsBody,
    };
    final own = _client ?? http.Client();
    try {
      Future<http.Response> patchP(String p) => own
          .patch(
            _baseUri(p),
            headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      var res = await patchP(path);
      if (res.statusCode == 404) res = await patchP(alt);
      final bodyStr = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        var msg = 'Squad save failed (${res.statusCode})';
        try {
          final err = jsonDecode(bodyStr);
          if (err is Map && err['error'] != null) msg = err['error'].toString();
        } catch (_) {
          if (bodyStr.isNotEmpty && bodyStr.length < 220) msg = bodyStr;
        }
        throw CardsSquadApiException(msg);
      }
      final decoded = jsonDecode(bodyStr);
      if (decoded is! Map<String, dynamic>) {
        throw CardsSquadApiException('Invalid squad PATCH response');
      }
      final raw = decoded['squad'];
      if (raw is! Map<String, dynamic>) {
        throw CardsSquadApiException('Response missing squad');
      }
      return CardsSquadPayload.fromJson(raw);
    } finally {
      if (_client == null) {
        own.close();
      }
    }
  }
}
