class TrophySeason {
  const TrophySeason({required this.seasonStartYear, required this.seasonEndYear});

  final int seasonStartYear;
  final int seasonEndYear;

  factory TrophySeason.fromJson(Map<String, dynamic> json) {
    return TrophySeason(
      seasonStartYear: (json['season_start_year'] ?? json['seasonStartYear']) as int,
      seasonEndYear: (json['season_end_year'] ?? json['seasonEndYear']) as int,
    );
  }

  /// e.g. 2023–24 when end = start + 1, else start year only.
  String get label {
    if (seasonEndYear == seasonStartYear) return '$seasonStartYear';
    if (seasonEndYear == seasonStartYear + 1) {
      final y2 = seasonEndYear % 100;
      return '$seasonStartYear–${y2.toString().padLeft(2, '0')}';
    }
    return '$seasonStartYear–$seasonEndYear';
  }
}

class TeamTrophySummary {
  const TeamTrophySummary({
    required this.trophyId,
    required this.trophyName,
    this.description,
    this.imageUrl,
    required this.winCount,
    required this.seasons,
  });

  final int trophyId;
  final String trophyName;
  final String? description;
  final String? imageUrl;
  final int winCount;
  final List<TrophySeason> seasons;

  factory TeamTrophySummary.fromJson(Map<String, dynamic> json) {
    final seasonsRaw = json['seasons'] as List<dynamic>? ?? [];
    return TeamTrophySummary(
      trophyId: (json['trophy_id'] ?? json['trophyId']) as int,
      trophyName: (json['trophy_name'] ?? json['trophyName'] ?? '').toString(),
      description: json['trophy_description']?.toString() ?? json['trophyDescription']?.toString(),
      imageUrl: json['trophy_image_url']?.toString() ?? json['trophyImageUrl']?.toString(),
      winCount: (json['win_count'] ?? json['winCount'] ?? seasonsRaw.length) as int,
      seasons: seasonsRaw
          .map((e) => TrophySeason.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
