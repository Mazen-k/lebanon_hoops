import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/tradeable_instance.dart';

class TradeApiException implements Exception {
  TradeApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TradeApiService {
  TradeApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _rootUri(String suffix, [Map<String, String>? query]) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final s = suffix.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$s');
    return query == null ? u : u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  List<String> _pair(String prefix) {
    if (prefix.startsWith('api/')) return [prefix, prefix.substring(4)];
    return [prefix, 'api/$prefix'];
  }

  Future<String> createRoom({required int userId}) async {
    final paths = _pair('trade/rooms');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .post(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({'user_id': userId}),
            )
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw TradeApiException('Create room failed (${res.statusCode})');
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is! Map || d['code'] == null) throw TradeApiException('Invalid create response');
        return d['code'].toString().toUpperCase();
      }
      throw TradeApiException('Trade API route not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> joinRoom({required String code, required int userId}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('trade/rooms/$c/join');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .post(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({'user_id': userId}),
            )
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 404) continue;
        if (res.statusCode == 409) {
          throw TradeApiException('Room is full');
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw TradeApiException('Join failed (${res.statusCode})');
        }
        return;
      }
      throw TradeApiException('Room not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<Map<String, dynamic>> getRoomState({required String code, required int userId}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('trade/rooms/$c');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .get(_rootUri(p, {'user_id': '$userId'}), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw TradeApiException('Room state (${res.statusCode})');
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is! Map<String, dynamic>) throw TradeApiException('Invalid state');
        return d;
      }
      throw TradeApiException('Room not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> putTradeCoins({required String code, required int userId, required int coins}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('trade/rooms/$c/coins');
    final body = jsonEncode({'user_id': userId, 'coins': coins});
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .put(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var msg = 'Coins update failed (${res.statusCode})';
          try {
            final m = jsonDecode(utf8.decode(res.bodyBytes));
            if (m is Map && m['error'] != null) msg = m['error'].toString();
          } catch (_) {}
          throw TradeApiException(msg);
        }
        return;
      }
      throw TradeApiException('Coins route not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> postSlotReaction({
    required String code,
    required int userId,
    required int slotIndex,
    required String reaction,
  }) async {
    if (slotIndex < 0 || slotIndex > 2) throw TradeApiException('Invalid slot');
    final c = code.trim().toUpperCase();
    final paths = _pair('trade/rooms/$c/slot-reaction');
    final body = jsonEncode({
      'user_id': userId,
      'slot_index': slotIndex,
      'reaction': reaction,
    });
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .post(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var msg = 'Reaction failed (${res.statusCode})';
          try {
            final m = jsonDecode(utf8.decode(res.bodyBytes));
            if (m is Map && m['error'] != null) msg = m['error'].toString();
          } catch (_) {}
          throw TradeApiException(msg);
        }
        return;
      }
      throw TradeApiException('Reaction route not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> putOffer({required String code, required int userId, required List<int?> slots}) async {
    if (slots.length != 3) throw TradeApiException('Need exactly 3 slots');
    final c = code.trim().toUpperCase();
    final paths = _pair('trade/rooms/$c/offer');
    final body = jsonEncode({
      'user_id': userId,
      'slots': slots.map((e) => e).toList(),
    });
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .put(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var msg = 'Offer update failed (${res.statusCode})';
          try {
            final m = jsonDecode(utf8.decode(res.bodyBytes));
            if (m is Map && m['error'] != null) msg = m['error'].toString();
          } catch (_) {}
          throw TradeApiException(msg);
        }
        return;
      }
      throw TradeApiException('Offer route not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> leaveRoom({required String code, required int userId}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('trade/rooms/$c/leave');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .post(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({'user_id': userId}),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var msg = 'Leave failed (${res.statusCode})';
          try {
            final m = jsonDecode(utf8.decode(res.bodyBytes));
            if (m is Map && m['error'] != null) msg = m['error'].toString();
          } catch (_) {}
          throw TradeApiException(msg);
        }
        return;
      }
    } finally {
      if (_client == null) own.close();
    }
  }

  /// Returns `waiting_peer_ready`, `both_ready`, or throws.
  Future<String> confirmReady({required String code, required int userId}) async {
    return _postTradeStep(code, userId, 'confirm-ready');
  }

  /// Returns `waiting_peer_finalize`, `completed`, or throws.
  Future<String> confirmFinalize({required String code, required int userId}) async {
    return _postTradeStep(code, userId, 'confirm-finalize', timeout: const Duration(seconds: 30));
  }

  Future<String> _postTradeStep(
    String code,
    int userId,
    String segment, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('trade/rooms/$c/$segment');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .post(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({'user_id': userId}),
            )
            .timeout(timeout);
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var msg = 'Trade step failed (${res.statusCode})';
          try {
            final m = jsonDecode(utf8.decode(res.bodyBytes));
            if (m is Map && m['error'] != null) msg = m['error'].toString();
          } catch (_) {}
          throw TradeApiException(msg);
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is Map && d['status'] != null) return d['status'].toString();
        return 'ok';
      }
      throw TradeApiException('Trade route not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<List<TradeableInstance>> tradeableInstances({required int userId}) async {
    final paths = _pair('trade/instances');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .get(_rootUri(p, {'user_id': '$userId'}), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw TradeApiException('Tradeable list (${res.statusCode})');
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is! Map) throw TradeApiException('Invalid instances JSON');
        final list = d['instances'];
        if (list is! List) return [];
        return list
            .map((e) => TradeableInstance.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      throw TradeApiException('Instances route not found');
    } finally {
      if (_client == null) own.close();
    }
  }
}
