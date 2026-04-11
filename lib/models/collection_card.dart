/// One distinct [play_cards] row in the user's collection (from GET /collection).
class CollectionCard {
  const CollectionCard({
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
    this.cardImage,
    this.teamId,
    this.teamName,
    this.instanceCount,
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

  /// Present on duplicate stacks: how many copies the user owns (≥ 2).
  final int? instanceCount;

  String get playerLabel {
    final a = firstName.trim();
    final b = lastName.trim();
    if (a.isEmpty && b.isEmpty) return 'Player #$playerId';
    return '$a $b'.trim();
  }

  /// Maps DB codes to filter buckets (Lebanon / USA / Other).
  static String nationalityBucket(String raw) {
    final u = raw.trim().toUpperCase();
    if (u.isEmpty) return 'Other';
    if (const {'LB', 'LEB', 'LEBANON', 'LBN'}.contains(u)) return 'Lebanon';
    if (const {'US', 'USA', 'UNITED STATES'}.contains(u)) return 'USA';
    return 'Other';
  }

  factory CollectionCard.fromJson(Map<String, dynamic> json) {
    int n(String snake, [String? camel]) {
      final v = json[snake] ?? (camel != null ? json[camel] : null);
      if (v is int) return v;
      if (v == null) throw FormatException('Missing $snake in collection card JSON');
      return int.parse(v.toString());
    }

    int? optInt(String snake, [String? camel]) {
      final v = json[snake] ?? (camel != null ? json[camel] : null);
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    final img = json['card_image'] ?? json['cardImage'];

    return CollectionCard(
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
      instanceCount: optInt('instance_count', 'instanceCount'),
    );
  }
}
