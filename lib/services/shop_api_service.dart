import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/shop_item.dart';

class ShopApiService {
  ShopApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = BackendConfig.apiBaseUrl.trim();
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.replaceAll(RegExp(r'^/+'), '');
    final u = Uri.parse('$normalized/$p');
    if (query == null || query.isEmpty) return u;
    return u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  Future<List<ShopItem>> fetchItems({String? category}) async {
    final query = <String, String>{
      if (category != null && category != 'All Items') 'category': category,
    };
    final own = _client ?? http.Client();
    try {
      final res = await own
          .get(_uri(BackendConfig.shopItemsPath, query),
              headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Shop items request failed (${res.statusCode})');
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! List) throw Exception('Invalid shop items JSON');
      return decoded
          .map((e) => ShopItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } finally {
      if (_client == null) own.close();
    }
  }
}
