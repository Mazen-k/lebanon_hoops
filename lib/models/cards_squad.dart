/// One slot on a 1v1 squad (API keys `pg`…`c`; DB columns `pg`…`c`).
class CardsSquadSlotCard {
  const CardsSquadSlotCard({
    required this.cardId,
    required this.position,
    required this.firstName,
    required this.lastName,
    this.overall,
    this.attack,
    this.defend,
    this.teamName,
    this.cardImage,
  });

  final int cardId;
  final String position;
  final String firstName;
  final String lastName;
  final int? overall;
  final int? attack;
  final int? defend;
  final String? teamName;
  final String? cardImage;

  bool get isEmpty => cardId <= 0;

  String get playerLabel {
    if (isEmpty) return '';
    final a = firstName.trim();
    final b = lastName.trim();
    if (a.isEmpty && b.isEmpty) return 'Card #$cardId';
    return '$a $b'.trim();
  }

  factory CardsSquadSlotCard.fromJson(Map<String, dynamic> json) {
    int cardIdFromJson() {
      final raw = json['card_id'] ?? json['cardId'];
      if (raw == null) return -1;
      if (raw is int) return raw < 0 ? -1 : raw;
      final p = int.tryParse(raw.toString());
      if (p == null || p < 0) return -1;
      return p;
    }

    int? opt(String a, [String? b]) {
      final v = json[a] ?? (b != null ? json[b] : null);
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    final cid = cardIdFromJson();

    final img = json['card_image'] ?? json['cardImage'];

    return CardsSquadSlotCard(
      cardId: cid,
      position: (json['position'] ?? (cid <= 0 ? '' : '?')).toString(),
      firstName: (json['first_name'] ?? json['firstName'] ?? '').toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
      overall: opt('overall'),
      attack: opt('attack'),
      defend: opt('defend'),
      teamName: json['team_name']?.toString() ?? json['teamName']?.toString(),
      cardImage: img?.toString(),
    );
  }
}

/// Full squad row + resolved slot cards from `GET /cards/squad`.
class CardsSquadPayload {
  const CardsSquadPayload({
    required this.id,
    required this.squadNumber,
    required this.squadName,
    required this.slots,
  });

  final int id;
  final int squadNumber;
  final String squadName;
  final Map<String, CardsSquadSlotCard> slots;

  static const slotOrder = ['pg', 'sg', 'sf', 'pf', 'c'];

  factory CardsSquadPayload.fromJson(Map<String, dynamic> json) {
    int n(String a, [String? b]) {
      final v = json[a] ?? (b != null ? json[b] : null);
      if (v is int) return v;
      if (v == null) throw FormatException('Missing $a');
      return int.parse(v.toString());
    }

    final rawSlots = json['slots'];
    if (rawSlots is! Map) {
      throw const FormatException('Missing slots map');
    }
    final sm = Map<String, dynamic>.from(rawSlots);
    final slots = <String, CardsSquadSlotCard>{};
    for (final key in slotOrder) {
      final v = sm[key];
      if (v is Map) {
        slots[key] = CardsSquadSlotCard.fromJson(Map<String, dynamic>.from(v));
      }
    }
    if (slots.length != 5) {
      throw const FormatException('Squad must have 5 slots');
    }

    return CardsSquadPayload(
      id: n('id'),
      squadNumber: n('squad_number', 'squadNumber'),
      squadName: (json['squad_name'] ?? json['squadName'] ?? '').toString(),
      slots: slots,
    );
  }

  /// Local-only editor state before `POST /cards/squad` (not persisted; [id] is 0).
  factory CardsSquadPayload.draft(int squadNumber) {
    CardsSquadSlotCard empty(String key) {
      final pos = switch (key) {
        'pg' => 'PG',
        'sg' => 'SG',
        'sf' => 'SF',
        'pf' => 'PF',
        'c' => 'C',
        _ => '?',
      };
      return CardsSquadSlotCard(cardId: -1, position: pos, firstName: '', lastName: '');
    }

    final slots = <String, CardsSquadSlotCard>{};
    for (final k in slotOrder) {
      slots[k] = empty(k);
    }
    return CardsSquadPayload(
      id: 0,
      squadNumber: squadNumber,
      squadName: 'Squad $squadNumber',
      slots: slots,
    );
  }

  bool get isPersisted => id > 0;

  CardsSquadPayload copyWith({
    int? id,
    String? squadName,
    Map<String, CardsSquadSlotCard>? slots,
  }) {
    return CardsSquadPayload(
      id: id ?? this.id,
      squadNumber: squadNumber,
      squadName: squadName ?? this.squadName,
      slots: slots != null ? Map<String, CardsSquadSlotCard>.from(slots) : Map<String, CardsSquadSlotCard>.from(this.slots),
    );
  }
}
