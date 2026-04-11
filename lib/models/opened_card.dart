/// One card returned from POST /packs/open (persisted as `card_instances`).
class OpenedCard {
  final int cardInstanceId;
  final int cardId;
  final String cardType;
  final int playerId;
  final int attack;
  final int defend;
  final String? cardImage;

  const OpenedCard({
    required this.cardInstanceId,
    required this.cardId,
    required this.cardType,
    required this.playerId,
    required this.attack,
    required this.defend,
    this.cardImage,
  });

  factory OpenedCard.fromJson(Map<String, dynamic> json) {
    int n(String snake, [String? camel]) {
      final v = json[snake] ?? (camel != null ? json[camel] : null);
      if (v is int) return v;
      if (v == null) throw FormatException('Missing $snake in card JSON');
      return int.parse(v.toString());
    }

    final img = json['card_image'] ?? json['cardImage'];

    return OpenedCard(
      cardInstanceId: n('card_instance_id', 'cardInstanceId'),
      cardId: n('card_id', 'cardId'),
      cardType: (json['card_type'] ?? json['cardType'] ?? '').toString(),
      playerId: n('player_id', 'playerId'),
      attack: n('attack'),
      defend: n('defend'),
      cardImage: img == null ? null : img.toString(),
    );
  }
}
