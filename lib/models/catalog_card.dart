import 'collection_card.dart';

/// One row from GET /cards/catalog (full game + ownership + wishlist flag).
class CatalogCard {
  const CatalogCard({
    required this.cardId,
    required this.cardType,
    required this.playerId,
    required this.attack,
    required this.defend,
    required this.position,
    required this.nationality,
    required this.firstName,
    required this.lastName,
    required this.overall,
    required this.ownedCount,
    required this.onWishlist,
    this.cardImage,
    this.teamId,
    this.teamName,
  });

  final int cardId;
  final String cardType;
  final int playerId;
  final int attack;
  final int defend;
  final String? cardImage;
  final String position;
  final String nationality;
  final String firstName;
  final String lastName;
  final int? teamId;
  final String? teamName;
  final int overall;
  final int ownedCount;
  final bool onWishlist;

  bool get owned => ownedCount > 0;

  String get playerLabel {
    final a = firstName.trim();
    final b = lastName.trim();
    if (a.isEmpty && b.isEmpty) return 'Player #$playerId';
    return '$a $b'.trim();
  }

  static bool _parseBool(dynamic v) {
    if (v == true) return true;
    if (v == false) return false;
    if (v == null) return false;
    final s = v.toString().toLowerCase();
    return s == 't' || s == 'true' || s == '1';
  }

  factory CatalogCard.fromJson(Map<String, dynamic> json) {
    int n(String snake, [String? camel]) {
      final v = json[snake] ?? (camel != null ? json[camel] : null);
      if (v is int) return v;
      if (v == null) throw FormatException('Missing $snake in catalog JSON');
      return int.parse(v.toString());
    }

    int? optInt(String snake, [String? camel]) {
      final v = json[snake] ?? (camel != null ? json[camel] : null);
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    final img = json['card_image'] ?? json['cardImage'];

    return CatalogCard(
      cardId: n('card_id', 'cardId'),
      cardType: (json['card_type'] ?? json['cardType'] ?? '').toString(),
      playerId: n('player_id', 'playerId'),
      attack: n('attack'),
      defend: n('defend'),
      cardImage: img == null ? null : img.toString(),
      position: (json['position'] ?? '?').toString(),
      nationality: (json['nationality'] ?? '').toString(),
      firstName: (json['first_name'] ?? json['firstName'] ?? '').toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
      teamId: optInt('team_id', 'teamId'),
      teamName: json['team_name']?.toString() ?? json['teamName']?.toString(),
      overall: n('overall'),
      ownedCount: n('owned_count', 'ownedCount'),
      onWishlist: _parseBool(json['on_wishlist'] ?? json['onWishlist']),
    );
  }

  String nationalityBucket() => CollectionCard.nationalityBucket(nationality);
}
