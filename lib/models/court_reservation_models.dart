import 'dart:convert';

int _jsonInt(Object? v) {
  if (v == null) throw FormatException('missing int');
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.parse(v.toString());
}

class CourtSummary {
  const CourtSummary({
    required this.courtId,
    required this.courtName,
    required this.location,
    this.phoneNumber,
    this.logoUrl,
  });

  final int courtId;
  final String courtName;
  final String location;
  final String? phoneNumber;
  final String? logoUrl;

  factory CourtSummary.fromJson(Map<String, dynamic> json) {
    return CourtSummary(
      courtId: _jsonInt(json['court_id'] ?? json['courtId']),
      courtName: (json['court_name'] ?? json['courtName'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      phoneNumber: json['phone_number']?.toString() ?? json['phoneNumber']?.toString(),
      logoUrl: json['logo_url']?.toString() ?? json['logoUrl']?.toString(),
    );
  }
}

class PlaygroundSummary {
  const PlaygroundSummary({
    required this.playgroundId,
    required this.courtId,
    required this.playgroundName,
    required this.pricePerHour,
    required this.isActive,
    required this.canHalfCourt,
    required this.photoUrls,
  });

  final int playgroundId;
  final int courtId;
  final String playgroundName;
  final double pricePerHour;
  final bool isActive;
  final bool canHalfCourt;
  final List<String> photoUrls;

  factory PlaygroundSummary.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photo_urls'] ?? json['photoUrls'];
    List<String> urls = [];
    if (rawPhotos is List) {
      urls = rawPhotos.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    } else if (rawPhotos is String && rawPhotos.trim().startsWith('[')) {
      try {
        final decoded = jsonDecode(rawPhotos);
        if (decoded is List) {
          urls = decoded.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    return PlaygroundSummary(
      playgroundId: _jsonInt(json['playground_id'] ?? json['playgroundId']),
      courtId: _jsonInt(json['court_id'] ?? json['courtId']),
      playgroundName: (json['playground_name'] ?? json['playgroundName'] ?? '').toString(),
      pricePerHour: (json['price_per_hour'] ?? json['pricePerHour'] ?? 0) is num
          ? ((json['price_per_hour'] ?? json['pricePerHour']) as num).toDouble()
          : double.tryParse('${json['price_per_hour'] ?? json['pricePerHour'] ?? 0}') ?? 0,
      isActive: json['is_active'] == true || json['isActive'] == true || json['is_active'] == 1,
      canHalfCourt: json['can_half_court'] == true || json['canHalfCourt'] == true || json['can_half_court'] == 1,
      photoUrls: urls,
    );
  }
}

class AvailabilitySlotDto {
  const AvailabilitySlotDto({
    required this.availabilityId,
    required this.availableDate,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    required this.isBooked,
  });

  final int availabilityId;
  final String availableDate;
  final String startTime;
  final String endTime;
  final bool isAvailable;
  final bool isBooked;

  bool get canReserve => isAvailable && !isBooked;

  factory AvailabilitySlotDto.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlotDto(
      availabilityId: _jsonInt(json['availability_id'] ?? json['availabilityId']),
      availableDate: (json['available_date'] ?? json['availableDate'] ?? '').toString(),
      startTime: (json['start_time'] ?? json['startTime'] ?? '').toString(),
      endTime: (json['end_time'] ?? json['endTime'] ?? '').toString(),
      isAvailable: json['is_available'] == true || json['isAvailable'] == true || json['is_available'] == 1,
      isBooked: json['is_booked'] == true || json['isBooked'] == true || json['is_booked'] == 1,
    );
  }
}
