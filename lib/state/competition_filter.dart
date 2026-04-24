import 'package:flutter/foundation.dart';

import '../models/competition.dart';
import '../services/competitions_api_service.dart';

/// Global, app-wide selection of which competition (gender + season) the user
/// is browsing. Screens that depend on this (Home, Games, Teams) listen to it
/// via [ChangeNotifier] and reload when it changes.
///
/// Defaults: gender `M`, season `2025/2026` (Men's Division 1).
class AppCompetitionFilter extends ChangeNotifier {
  AppCompetitionFilter._();

  static final AppCompetitionFilter instance = AppCompetitionFilter._();

  /// Compile-time fallback when the server has no `/competitions` route yet.
  static const Competition _fallbackDefault = Competition(
    competitionId: 42001,
    competitionName: 'Division 1',
    gender: 'M',
    startYear: 2025,
    endYear: 2026,
  );

  final CompetitionsApiService _api = CompetitionsApiService();

  List<Competition> _competitions = const [_fallbackDefault];
  Competition _selected = _fallbackDefault;
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  List<Competition> get competitions => List.unmodifiable(_competitions);
  Competition get selected => _selected;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;

  /// All genders that have at least one competition (usually `{'M','F'}`).
  Set<String> get availableGenders =>
      _competitions.map((c) => c.gender).toSet();

  /// Competitions available for the currently selected gender, newest first.
  List<Competition> competitionsForGender(String gender) {
    final g = gender.toUpperCase();
    final list = _competitions.where((c) => c.gender == g).toList()
      ..sort((a, b) {
        final byStart = b.startYear.compareTo(a.startYear);
        if (byStart != 0) return byStart;
        return b.endYear.compareTo(a.endYear);
      });
    return list;
  }

  /// Load the full competitions list once. Safe to call repeatedly.
  Future<void> ensureLoaded({bool force = false}) async {
    if (_loading) return;
    if (_loadedOnce && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _api.fetchCompetitions();
      if (list.isEmpty) {
        _competitions = const [_fallbackDefault];
      } else {
        _competitions = list;
        // Prefer the currently selected id if still present, else default to
        // the latest Men's season (or the newest overall competition).
        final currentStillThere = list.where(
          (c) => c.competitionId == _selected.competitionId,
        );
        if (currentStillThere.isNotEmpty) {
          _selected = currentStillThere.first;
        } else {
          _selected = _pickDefault(list);
        }
      }
      _loadedOnce = true;
    } catch (e) {
      _error = e.toString();
      // Keep the fallback so the rest of the app still works.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Switch gender while keeping a sensible season selection if possible.
  void selectGender(String gender) {
    final g = gender.toUpperCase();
    if (g == _selected.gender) return;
    final inGender = competitionsForGender(g);
    if (inGender.isEmpty) return;
    // Try to keep the same season years; otherwise take the newest.
    final sameSeason = inGender.firstWhere(
      (c) =>
          c.startYear == _selected.startYear && c.endYear == _selected.endYear,
      orElse: () => inGender.first,
    );
    _selected = sameSeason;
    notifyListeners();
  }

  /// Pick a specific competition directly (e.g. a tapped season pill).
  void selectCompetition(Competition competition) {
    if (competition.competitionId == _selected.competitionId) return;
    _selected = competition;
    notifyListeners();
  }

  Competition _pickDefault(List<Competition> list) {
    final mens = list.where((c) => c.gender == 'M').toList()
      ..sort((a, b) {
        final byStart = b.startYear.compareTo(a.startYear);
        if (byStart != 0) return byStart;
        return b.endYear.compareTo(a.endYear);
      });
    if (mens.isNotEmpty) {
      // Prefer the exact default (Men's 2025/2026) when present.
      final preferred = mens.firstWhere(
        (c) =>
            c.startYear == _fallbackDefault.startYear &&
            c.endYear == _fallbackDefault.endYear,
        orElse: () => mens.first,
      );
      return preferred;
    }
    return list.first;
  }
}
