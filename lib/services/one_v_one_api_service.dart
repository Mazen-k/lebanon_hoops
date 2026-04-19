import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class OneVOneApiException implements Exception {
  OneVOneApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class OneVOneApiService {
  OneVOneApiService({http.Client? client}) : _client = client;

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
    final paths = _pair('cards/one-v-one/rooms');
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
          throw OneVOneApiException('Create room failed (${res.statusCode})');
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is! Map || d['code'] == null) throw OneVOneApiException('Invalid create response');
        return d['code'].toString().toUpperCase();
      }
      throw OneVOneApiException('1v1 API route not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> joinRoom({required String code, required int userId}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('cards/one-v-one/rooms/$c/join');
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
        if (res.statusCode == 409) throw OneVOneApiException('Room is full');
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw OneVOneApiException('Join failed (${res.statusCode})');
        }
        return;
      }
      throw OneVOneApiException('Room not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<Map<String, dynamic>> getRoomState({required String code, required int userId}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('cards/one-v-one/rooms/$c');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .get(_rootUri(p, {'user_id': '$userId'}), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw OneVOneApiException('Room state (${res.statusCode})');
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is! Map<String, dynamic>) throw OneVOneApiException('Invalid state');
        return d;
      }
      throw OneVOneApiException('Room not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> leaveRoom({required String code, required int userId}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('cards/one-v-one/rooms/$c/leave');
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
          throw OneVOneApiException('Leave failed (${res.statusCode})');
        }
        return;
      }
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> postSquadPick({required String code, required int userId, required int squadNumber}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('cards/one-v-one/rooms/$c/squad-pick');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .post(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({'user_id': userId, 'squad_number': squadNumber}),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var msg = 'Squad pick failed (${res.statusCode})';
          try {
            final m = jsonDecode(utf8.decode(res.bodyBytes));
            if (m is Map && m['error'] != null) msg = m['error'].toString();
          } catch (_) {}
          throw OneVOneApiException(msg);
        }
        return;
      }
      throw OneVOneApiException('Squad pick route not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> postLead({required String code, required int userId, required String slot, required String mode}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('cards/one-v-one/rooms/$c/lead');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .post(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({'user_id': userId, 'slot': slot, 'mode': mode}),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var msg = 'Play action failed (${res.statusCode})';
          try {
            final m = jsonDecode(utf8.decode(res.bodyBytes));
            if (m is Map && m['error'] != null) msg = m['error'].toString();
          } catch (_) {}
          throw OneVOneApiException(msg);
        }
        return;
      }
      throw OneVOneApiException('Lead route not found');
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<void> postRespond({required String code, required int userId, required String slot}) async {
    final c = code.trim().toUpperCase();
    final paths = _pair('cards/one-v-one/rooms/$c/respond');
    final own = _client ?? http.Client();
    try {
      for (final p in paths) {
        final res = await own
            .post(
              _rootUri(p),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({'user_id': userId, 'slot': slot}),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var msg = 'Respond failed (${res.statusCode})';
          try {
            final m = jsonDecode(utf8.decode(res.bodyBytes));
            if (m is Map && m['error'] != null) msg = m['error'].toString();
          } catch (_) {}
          throw OneVOneApiException(msg);
        }
        return;
      }
      throw OneVOneApiException('Respond route not found');
    } finally {
      if (_client == null) own.close();
    }
  }
}
