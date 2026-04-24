/// One row from the `competitions` table.
///
/// Example: `(42001, 'Division 1', 'M', 2025, 2026)`.
class Competition {
  final int competitionId;
  final String competitionName;
  final String gender; // 'M' or 'F'
  final int startYear;
  final int endYear;

  const Competition({
    required this.competitionId,
    required this.competitionName,
    required this.gender,
    required this.startYear,
    required this.endYear,
  });

  /// Friendly season label: `"2025/2026"`.
  String get seasonLabel => '$startYear/$endYear';

  /// Compact season label: `"25/26"`.
  String get seasonShortLabel {
    final s = startYear % 100;
    final e = endYear % 100;
    return '${s.toString().padLeft(2, '0')}/${e.toString().padLeft(2, '0')}';
  }

  /// `"M"` → `"Men's"`, `"F"` → `"Women's"`.
  String get genderLabel => gender.toUpperCase() == 'F' ? "Women's" : "Men's";

  /// Short label shown in chips: `"MEN"` / `"WOMEN"`.
  String get genderShortLabel => gender.toUpperCase() == 'F' ? 'WOMEN' : 'MEN';

  factory Competition.fromJson(Map<String, dynamic> json) {
    final id = json['competition_id'] ?? json['competitionId'] ?? json['id'];
    final name =
        json['competition_name'] ??
        json['competitionName'] ??
        json['name'] ??
        'Competition';
    final gender = json['gender'] ?? 'M';
    final startYear = json['start_year'] ?? json['startYear'];
    final endYear = json['end_year'] ?? json['endYear'];

    if (id == null || startYear == null || endYear == null) {
      throw FormatException(
        'Expected competition_id, start_year, end_year in competition JSON: $json',
      );
    }

    int asInt(dynamic v) {
      if (v is int) return v;
      return int.parse(v.toString());
    }

    return Competition(
      competitionId: asInt(id),
      competitionName: name.toString(),
      gender: gender.toString().toUpperCase(),
      startYear: asInt(startYear),
      endYear: asInt(endYear),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Competition && other.competitionId == competitionId);

  @override
  int get hashCode => competitionId.hashCode;
}
