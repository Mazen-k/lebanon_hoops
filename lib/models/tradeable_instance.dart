/// One card_instances row the user can offer (duplicate stack).
class TradeableInstance {
  const TradeableInstance({
    required this.cardInstanceId,
    required this.cardId,
    required this.cardType,
    required this.attack,
    required this.defend,
    required this.overall,
    this.cardImage,
    this.firstName,
    this.lastName,
  });

  final int cardInstanceId;
  final int cardId;
  final String cardType;
  final int attack;
  final int defend;
  final int overall;
  final String? cardImage;
  final String? firstName;
  final String? lastName;

  String get label {
    final a = (firstName ?? '').trim();
    final b = (lastName ?? '').trim();
    if (a.isEmpty && b.isEmpty) return 'Card #$cardId';
    return '$a $b'.trim();
  }

  factory TradeableInstance.fromJson(Map<String, dynamic> json) {
    int n(String snake, [String? camel]) {
      final v = json[snake] ?? (camel != null ? json[camel] : null);
      if (v is int) return v;
      if (v == null) throw FormatException('Missing $snake');
      return int.parse(v.toString());
    }

    final img = json['card_image'] ?? json['cardImage'];
    return TradeableInstance(
      cardInstanceId: n('card_instance_id', 'cardInstanceId'),
      cardId: n('card_id', 'cardId'),
      cardType: (json['card_type'] ?? json['cardType'] ?? '').toString(),
      attack: n('attack'),
      defend: n('defend'),
      overall: n('overall'),
      cardImage: img == null ? null : img.toString(),
      firstName: json['first_name']?.toString() ?? json['firstName']?.toString(),
      lastName: json['last_name']?.toString() ?? json['lastName']?.toString(),
    );
  }
}
