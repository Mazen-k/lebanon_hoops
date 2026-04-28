int _jsonInt(Object? v, String field) {
  if (v == null) throw FormatException('missing $field');
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.parse(v.toString());
}

class ShopVendorSession {
  const ShopVendorSession({
    required this.token,
    required this.shopVendorId,
    required this.shopName,
    required this.username,
  });

  final String token;
  final int shopVendorId;
  final String shopName;
  final String username;

  factory ShopVendorSession.fromJson(Map<String, dynamic> json) {
    return ShopVendorSession(
      token: (json['token'] ?? '').toString(),
      shopVendorId: _jsonInt(json['shop_vendor_id'] ?? json['shopVendorId'], 'shop_vendor_id'),
      shopName: (json['shop_name'] ?? json['shopName'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
    );
  }
}
