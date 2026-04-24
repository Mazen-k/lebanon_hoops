import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/team.dart';

class CardsFilterOptionsException implements Exception {
  CardsFilterOptionsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Card catalog / wishlist / trade filter metadata from the API.
class CardCatalogFilterOptions {
  const CardCatalogFilterOptions({
    required this.teams,
    required this.nationalities,
  });

  final List<Team> teams;
  final List<String> nationalities;
}

class CardsFilterOptionsService {
  CardsFilterOptionsService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$normalized/$p');
  }

  List<String> _pairPaths() => const [
    'cards/filter-options',
    'api/cards/filter-options',
  ];

  Future<CardCatalogFilterOptions> fetchFilterOptions() async {
    final own = _client ?? http.Client();
    try {
      for (final path in _pairPaths()) {
        final res = await own
            .get(_uri(path), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 25));
        if (res.statusCode == 404) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw CardsFilterOptionsException(
            'Filter options failed (${res.statusCode})',
          );
        }
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is! Map<String, dynamic>) {
          throw CardsFilterOptionsException('Invalid filter options JSON');
        }
        final teamsRaw = decoded['teams'];
        final natRaw = decoded['nationalities'];
        final teams = <Team>[];
        if (teamsRaw is List) {
          for (final e in teamsRaw) {
            if (e is! Map) continue;
            try {
              teams.add(Team.fromJson(Map<String, dynamic>.from(e)));
            } catch (_) {
              continue;
            }
          }
        }
        final nationalities = <String>[];
        if (natRaw is List) {
          for (final e in natRaw) {
            if (e == null) continue;
            final s = e.toString().trim();
            if (s.isNotEmpty) nationalities.add(s);
          }
        }
        return CardCatalogFilterOptions(
          teams: teams,
          nationalities: nationalities,
        );
      }
      throw CardsFilterOptionsException('Filter options route not found');
    } finally {
      if (_client == null) own.close();
    }
  }
}
