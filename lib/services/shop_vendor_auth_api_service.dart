import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/shop_vendor_session.dart';

class ShopVendorApiException implements Exception {
  ShopVendorApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ShopVendorAuthApiService {
  ShopVendorAuthApiService({http.Client? client}) : _client = client;

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

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<ShopVendorSession> shopVendorLogin({
    required String username,
    required String password,
  }) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair('auth/shop-vendor-login');
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
        throw ShopVendorApiException(
          _errBody(body) ?? 'Shop vendor login failed (${res.statusCode})',
          statusCode: res.statusCode,
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw ShopVendorApiException('Invalid response');
      return ShopVendorSession.fromJson(decoded);
    } finally {
      if (_client == null) own.close();
    }
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listItems(String token) async {
    final res = await _authGet('shop-vendor/items', token);
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ShopVendorApiException(_errBody(body) ?? 'Failed to load items', statusCode: res.statusCode);
    }
    final j = jsonDecode(body);
    if (j is! Map) return [];
    final list = j['items'];
    if (list is! List) return [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createItem(
    String token, {
    required String name,
    required String category,
    required double price,
    required int quantityAvailable,
    String? subtitle,
    double? originalPrice,
    String? imageUrl,
    String? badge,
    bool isFeatured = false,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'category': category,
      'price': price,
      'quantity_available': quantityAvailable,
      'is_featured': isFeatured,
    };
    if (subtitle != null) body['subtitle'] = subtitle;
    if (originalPrice != null) body['original_price'] = originalPrice;
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (badge != null) body['badge'] = badge;
    if (description != null) body['description'] = description;
    final res = await _authPost('shop-vendor/items', token, body);
    _throwIfBad(res);
  }

  Future<void> patchItem(
    String token, {
    required int itemId,
    String? name,
    String? subtitle,
    String? category,
    double? price,
    double? originalPrice,
    int? quantityAvailable,
    String? imageUrl,
    String? badge,
    bool? isFeatured,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (subtitle != null) body['subtitle'] = subtitle;
    if (category != null) body['category'] = category;
    if (price != null) body['price'] = price;
    if (originalPrice != null) body['original_price'] = originalPrice;
    if (quantityAvailable != null) body['quantity_available'] = quantityAvailable;
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (badge != null) body['badge'] = badge;
    if (isFeatured != null) body['is_featured'] = isFeatured;
    if (description != null) body['description'] = description;
    final res = await _authPatch('shop-vendor/items/$itemId', token, body);
    _throwIfBad(res);
  }

  Future<void> deleteItem(String token, {required int itemId}) async {
    final res = await _authDelete('shop-vendor/items/$itemId', token);
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      throw ShopVendorApiException(_errBody(body) ?? 'Delete failed', statusCode: res.statusCode);
    }
  }

  // ── Photos ────────────────────────────────────────────────────────────────

  Future<void> addItemPhoto(String token, {required int itemId, required String photoUrl}) async {
    final res = await _authPost('shop-vendor/items/$itemId/photos', token, {'photo_url': photoUrl.trim()});
    _throwIfBad(res);
  }

  Future<void> deletePhoto(String token, {required int photoId}) async {
    final res = await _authDelete('shop-vendor/photos/$photoId', token);
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      throw ShopVendorApiException(_errBody(body) ?? 'Delete failed', statusCode: res.statusCode);
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  void _throwIfBad(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      throw ShopVendorApiException(
        _errBody(body) ?? 'Request failed (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
  }

  Future<http.Response> _authGet(String path, String token) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) =>
          own.get(_uri(p), headers: _bearer(token)).timeout(const Duration(seconds: 25));
      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) res = await one(b);
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<http.Response> _authPost(String path, String token, Map<String, dynamic> body) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) =>
          own.post(_uri(p), headers: _bearer(token), body: jsonEncode(body)).timeout(const Duration(seconds: 25));
      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) res = await one(b);
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<http.Response> _authPatch(String path, String token, Map<String, dynamic> body) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) =>
          own.patch(_uri(p), headers: _bearer(token), body: jsonEncode(body)).timeout(const Duration(seconds: 25));
      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) res = await one(b);
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }

  Future<http.Response> _authDelete(String path, String token) async {
    final own = _client ?? http.Client();
    final (a, b) = _pair(path);
    try {
      Future<http.Response> one(String p) =>
          own.delete(_uri(p), headers: _bearer(token)).timeout(const Duration(seconds: 25));
      http.Response res = await one(a);
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (res.statusCode == 404 || (res.statusCode >= 400 && _looksLikeHtml(preview))) res = await one(b);
      return res;
    } finally {
      if (_client == null) own.close();
    }
  }
}
