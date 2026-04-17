int _vendorJsonInt(Object? v) {
  if (v == null) throw FormatException('missing court_id');
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.parse(v.toString());
}

class VendorSession {
  const VendorSession({
    required this.token,
    required this.courtId,
    required this.courtName,
    required this.location,
    required this.username,
  });

  final String token;
  final int courtId;
  final String courtName;
  final String location;
  final String username;

  factory VendorSession.fromJson(Map<String, dynamic> json) {
    return VendorSession(
      token: (json['token'] ?? '').toString(),
      courtId: _vendorJsonInt(json['court_id'] ?? json['courtId']),
      courtName: (json['court_name'] ?? json['courtName'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
    );
  }
}
