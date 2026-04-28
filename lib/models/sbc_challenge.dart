class SbcRewardCard {
  const SbcRewardCard({
    required this.cardId,
    required this.playerId,
    required this.firstName,
    required this.lastName,
    required this.position,
    required this.teamName,
    required this.overall,
    this.cardImage,
  });

  final int cardId;
  final int? playerId;
  final String firstName;
  final String lastName;
  final String position;
  final String? teamName;
  final int? overall;
  final String? cardImage;

  String get playerLabel {
    final a = firstName.trim();
    final b = lastName.trim();
    if (a.isEmpty && b.isEmpty) return 'Card #$cardId';
    return '$a $b'.trim();
  }

  factory SbcRewardCard.fromJson(Map<String, dynamic> json) {
    int n(String key, [String? alt]) {
      final v = json[key] ?? (alt != null ? json[alt] : null);
      if (v is int) return v;
      if (v == null) throw FormatException('Missing $key');
      return int.parse(v.toString());
    }

    int? optInt(String key, [String? alt]) {
      final v = json[key] ?? (alt != null ? json[alt] : null);
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return SbcRewardCard(
      cardId: n('card_id', 'cardId'),
      playerId: optInt('player_id', 'playerId'),
      firstName: (json['first_name'] ?? json['firstName'] ?? '').toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
      position: (json['position'] ?? '?').toString(),
      teamName: json['team_name']?.toString() ?? json['teamName']?.toString(),
      overall: optInt('overall'),
      cardImage: json['card_image']?.toString() ?? json['cardImage']?.toString(),
    );
  }
}

class SbcRequirement {
  const SbcRequirement({
    required this.requirementId,
    required this.sbcId,
    required this.requirementType,
    required this.requiredValue,
    required this.requiredText,
    required this.minCount,
  });

  final int requirementId;
  final int sbcId;
  final String requirementType;
  final int? requiredValue;
  final String? requiredText;
  final int minCount;

  factory SbcRequirement.fromJson(Map<String, dynamic> json) {
    int n(String key, [String? alt]) {
      final v = json[key] ?? (alt != null ? json[alt] : null);
      if (v is int) return v;
      if (v == null) throw FormatException('Missing $key');
      return int.parse(v.toString());
    }

    int? optInt(String key, [String? alt]) {
      final v = json[key] ?? (alt != null ? json[alt] : null);
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return SbcRequirement(
      requirementId: n('requirement_id', 'requirementId'),
      sbcId: n('sbc_id', 'sbcId'),
      requirementType: (json['requirement_type'] ?? json['requirementType'] ?? '').toString(),
      requiredValue: optInt('required_value', 'requiredValue'),
      requiredText: json['required_text']?.toString() ?? json['requiredText']?.toString(),
      minCount: optInt('min_count', 'minCount') ?? 1,
    );
  }
}

class SbcChallenge {
  const SbcChallenge({
    required this.sbcId,
    required this.sbcName,
    required this.description,
    required this.rewardCardId,
    required this.isActive,
    required this.rewardCard,
    required this.requirements,
  });

  final int sbcId;
  final String sbcName;
  final String? description;
  final int rewardCardId;
  final bool isActive;
  final SbcRewardCard rewardCard;
  final List<SbcRequirement> requirements;

  factory SbcChallenge.fromJson(Map<String, dynamic> json) {
    int n(String key, [String? alt]) {
      final v = json[key] ?? (alt != null ? json[alt] : null);
      if (v is int) return v;
      if (v == null) throw FormatException('Missing $key');
      return int.parse(v.toString());
    }

    final rewardRaw = json['reward_card'] ?? json['rewardCard'];
    final reqRaw = json['requirements'];
    if (rewardRaw is! Map<String, dynamic>) {
      throw const FormatException('Missing reward_card object');
    }
    if (reqRaw is! List) {
      throw const FormatException('Missing requirements array');
    }
    return SbcChallenge(
      sbcId: n('sbc_id', 'sbcId'),
      sbcName: (json['sbc_name'] ?? json['sbcName'] ?? '').toString(),
      description: json['description']?.toString(),
      rewardCardId: n('reward_card_id', 'rewardCardId'),
      isActive: json['is_active'] == true || json['isActive'] == true,
      rewardCard: SbcRewardCard.fromJson(rewardRaw),
      requirements: reqRaw
          .whereType<Map>()
          .map((e) => SbcRequirement.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class SbcSubmitResult {
  const SbcSubmitResult({
    required this.rewardCardId,
    required this.rewardInstanceId,
  });

  final int rewardCardId;
  final int? rewardInstanceId;

  factory SbcSubmitResult.fromJson(Map<String, dynamic> json) {
    int n(String key, [String? alt]) {
      final v = json[key] ?? (alt != null ? json[alt] : null);
      if (v is int) return v;
      if (v == null) throw FormatException('Missing $key');
      return int.parse(v.toString());
    }

    final rawInstance = json['reward_instance_id'] ?? json['rewardInstanceId'];
    int? rewardInstanceId;
    if (rawInstance is int) rewardInstanceId = rawInstance;
    if (rawInstance is String) rewardInstanceId = int.tryParse(rawInstance);

    return SbcSubmitResult(
      rewardCardId: n('reward_card_id', 'rewardCardId'),
      rewardInstanceId: rewardInstanceId,
    );
  }
}
