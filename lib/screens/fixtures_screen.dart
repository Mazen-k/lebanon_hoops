import 'package:flutter/material.dart';

import '../layout/app_shell_bottom_inset.dart';
import '../models/game_fixture_view.dart';
import '../services/games_api_service.dart';
import '../state/competition_filter.dart';
import 'game_boxscore_screen.dart';
import '../widgets/league_fixture_card.dart';

/// League schedule from `games`, split by `games.week` with a premium week
/// navigator header.  Supports tap-arrows, swipe (PageView), and date-range
/// labels derived from the fixtures themselves.
///
/// The competition id is taken from [AppCompetitionFilter]; when the user
/// changes gender/season on the Home page, this screen reloads automatically.
class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key, this.competitionId});

  static const int defaultCompetitionId = 42001;

  /// If provided, overrides the global [AppCompetitionFilter].
  final int? competitionId;

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen>
    with SingleTickerProviderStateMixin {
  final _api = GamesApiService();
  final AppCompetitionFilter _filter = AppCompetitionFilter.instance;
  PageController? _pageController;
  List<int> _weeks = const [];
  final Map<int, List<GameFixtureView>> _fixturesByWeek = {};
  final Set<int> _weekLoadInFlight = {};
  bool _loadingBootstrap = true;
  String? _errorBootstrap;
  bool _legacySingleList = false;
  List<GameFixtureView> _legacyFixtures = const [];
  int _pageIndex = 0;
  int _bootstrapSeq = 0;
  int? _activeCompetitionId;

  // Animation controller for the week label cross-fade.
  late final AnimationController _labelAnim;
  late final Animation<double> _labelFade;

  int get _competitionId =>
      widget.competitionId ?? _filter.selected.competitionId;

  static int _compareGameWeeks(int a, int b) {
    final aRegular = a >= 0;
    final bRegular = b >= 0;
    if (aRegular && bRegular) return a.compareTo(b);
    if (aRegular) return -1;
    if (bRegular) return 1;
    return a.abs().compareTo(b.abs());
  }

  static List<int> _orderedGameWeeks(Iterable<int> weeks) =>
      weeks.toList()..sort(_compareGameWeeks);

  @override
  void initState() {
    super.initState();
    _labelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _labelFade = CurvedAnimation(parent: _labelAnim, curve: Curves.easeInOut);
    if (widget.competitionId == null) {
      _filter.addListener(_onFilterChanged);
    }
    _bootstrap();
  }

  @override
  void dispose() {
    if (widget.competitionId == null) {
      _filter.removeListener(_onFilterChanged);
    }
    _pageController?.dispose();
    _labelAnim.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    if (!mounted) return;
    if (_activeCompetitionId == _filter.selected.competitionId) return;
    _bootstrap();
  }

  // ─── bootstrap ────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    final seq = ++_bootstrapSeq;
    final cid = _competitionId;
    setState(() {
      _loadingBootstrap = true;
      _errorBootstrap = null;
      _fixturesByWeek.clear();
      _weekLoadInFlight.clear();
      _legacyFixtures = const [];
      _weeks = const [];
      _legacySingleList = false;
      _pageIndex = 0;
      _pageController?.dispose();
      _pageController = null;
      _activeCompetitionId = cid;
    });
    try {
      List<int> weeks = [];
      try {
        weeks = _orderedGameWeeks(
          await _api.fetchGameWeeks(competitionId: cid),
        );
      } on GamesApiException {
        weeks = [];
      }
      if (!mounted || seq != _bootstrapSeq) return;

      if (weeks.isEmpty) {
        final rows = await _api.fetchGames(competitionId: cid);
        if (!mounted || seq != _bootstrapSeq) return;
        final list = rows
            .map(GameFixtureView.fromGamesApiRow)
            .where((f) => f.matchId > 0)
            .toList();

        final derivedWeeks = _orderedGameWeeks(
          list.map((f) => f.week).whereType<int>().toSet(),
        );

        if (derivedWeeks.isNotEmpty) {
          final grouped = <int, List<GameFixtureView>>{};
          for (final f in list) {
            if (f.week != null) (grouped[f.week!] ??= []).add(f);
          }
          for (final g in grouped.values) {
            g.sort((a, b) => a.matchId.compareTo(b.matchId));
          }

          final initialPage = derivedWeeks.length - 1;
          _pageController?.dispose();
          _pageController = PageController(initialPage: initialPage);

          setState(() {
            _legacySingleList = false;
            _weeks = derivedWeeks;
            _pageIndex = initialPage;
            _fixturesByWeek
              ..clear()
              ..addAll(grouped);
            _weekLoadInFlight.clear();
            _loadingBootstrap = false;
          });
          return;
        }

        // True fallback: no week column at all.
        setState(() {
          _legacySingleList = true;
          _weeks = const [];
          _legacyFixtures = list;
          _loadingBootstrap = false;
        });
        return;
      }

      final initialPage = weeks.length - 1;
      _pageController?.dispose();
      _pageController = PageController(initialPage: initialPage);

      setState(() {
        _legacySingleList = false;
        _weeks = weeks;
        _pageIndex = initialPage;
        _fixturesByWeek.clear();
        _weekLoadInFlight.clear();
        _loadingBootstrap = false;
      });

      await _loadWeek(weeks[initialPage], force: true);
    } on GamesApiException catch (e) {
      if (mounted && seq == _bootstrapSeq) {
        setState(() {
          _errorBootstrap = e.message;
          _loadingBootstrap = false;
        });
      }
    } catch (e) {
      if (mounted && seq == _bootstrapSeq) {
        setState(() {
          _errorBootstrap = '$e';
          _loadingBootstrap = false;
        });
      }
    }
  }

  // ─── week loading ─────────────────────────────────────────────────────────

  Future<void> _loadWeek(int week, {bool force = false}) async {
    if (!force && _fixturesByWeek.containsKey(week)) return;
    if (_weekLoadInFlight.contains(week)) return;
    final cid = _competitionId;
    setState(() => _weekLoadInFlight.add(week));
    try {
      final rows = await _api.fetchGames(competitionId: cid, week: week);
      if (!mounted || cid != _activeCompetitionId) return;
      final list =
          rows
              .map(GameFixtureView.fromGamesApiRow)
              .where((f) => f.matchId > 0)
              .toList()
            ..sort((a, b) => a.matchId.compareTo(b.matchId));
      setState(() {
        _fixturesByWeek[week] = list;
        _weekLoadInFlight.remove(week);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weekLoadInFlight.remove(week);
        _fixturesByWeek[week] = [];
      });
    }
  }

  Future<void> _refreshVisible() async {
    if (_legacySingleList) {
      final cid = _competitionId;
      setState(() => _loadingBootstrap = true);
      try {
        final rows = await _api.fetchGames(competitionId: cid);
        if (!mounted || cid != _activeCompetitionId) return;
        final list = rows
            .map(GameFixtureView.fromGamesApiRow)
            .where((f) => f.matchId > 0)
            .toList();
        setState(() {
          _legacyFixtures = list;
          _loadingBootstrap = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loadingBootstrap = false);
      }
      return;
    }
    if (_weeks.isEmpty) return;
    await _loadWeek(_weeks[_pageIndex], force: true);
  }

  // ─── navigation ───────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    _animateLabelChange(() => setState(() => _pageIndex = index));
    if (_weeks.isEmpty) return;
    final w = _weeks[index];
    _loadWeek(w);
    if (index + 1 < _weeks.length) _loadWeek(_weeks[index + 1]);
    if (index > 0) _loadWeek(_weeks[index - 1]);
  }

  void _goToWeekIndex(int index) {
    if (_weeks.isEmpty || index == _pageIndex) return;
    final target = index.clamp(0, _weeks.length - 1);
    _loadWeek(_weeks[target]);
    _pageController?.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpWeekWindow(int delta) {
    if (_weeks.isEmpty) return;
    _goToWeekIndex((_pageIndex + delta).clamp(0, _weeks.length - 1));
  }

  /// Briefly fades the label out and back in when the week changes.
  void _animateLabelChange(VoidCallback change) {
    _labelAnim.reverse().then((_) {
      change();
      if (mounted) _labelAnim.forward();
    });
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loadingBootstrap) {
      return ColoredBox(
        color: cs.surface,
        child: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }
    if (_errorBootstrap != null) {
      return ColoredBox(
        color: cs.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorBootstrap!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    // Legacy single-list mode (no week column in the data).
    if (_legacySingleList) {
      return ColoredBox(
        color: cs.surface,
        child: RefreshIndicator(
          color: cs.primary,
          onRefresh: _refreshVisible,
          child: _buildFixtureList(context, cs, _legacyFixtures),
        ),
      );
    }

    final pc = _pageController;
    if (pc == null || _weeks.isEmpty) {
      return ColoredBox(
        color: cs.surface,
        child: Center(
          child: Text(
            'No week data for this competition.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return ColoredBox(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekNavigatorHeader(
            weeks: _weeks,
            focusedIndex: _pageIndex,
            labelFade: _labelFade,
            colorScheme: cs,
            onWeekSelected: _goToWeekIndex,
            onWindowSwipe: _jumpWeekWindow,
          ),
          Expanded(
            child: PageView.builder(
              controller: pc,
              itemCount: _weeks.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final week = _weeks[index];
                final fixtures = _fixturesByWeek[week];
                final inFlight =
                    _weekLoadInFlight.contains(week) && fixtures == null;

                if (inFlight || fixtures == null) {
                  return Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  );
                }

                return RefreshIndicator(
                  color: cs.primary,
                  onRefresh: () => _loadWeek(week, force: true),
                  child: _buildFixtureList(context, cs, fixtures),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixtureList(
    BuildContext context,
    ColorScheme cs,
    List<GameFixtureView> fixtures,
  ) {
    final bottomPad = appShellBottomBarOverlap(context);
    if (fixtures.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
        children: [
          const SizedBox(height: 80),
          Text(
            'No games this week.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: fixtures.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final f = fixtures[i];
        return LeagueFixtureCard(
          fixture: f,
          onCardTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => GameBoxscoreScreen(matchId: f.matchId),
            ),
          ),
        );
      },
    );
  }
}

// ─── Week Navigator Header ─────────────────────────────────────────────────

class _WeekNavigatorHeader extends StatelessWidget {
  const _WeekNavigatorHeader({
    required this.weeks,
    required this.focusedIndex,
    required this.labelFade,
    required this.colorScheme,
    required this.onWeekSelected,
    required this.onWindowSwipe,
  });

  final List<int> weeks;
  final int focusedIndex;
  final Animation<double> labelFade;
  final ColorScheme colorScheme;
  final ValueChanged<int> onWeekSelected;
  final ValueChanged<int> onWindowSwipe;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final visibleCount = width >= 430
            ? 7
            : width >= 340
            ? 5
            : 3;
        final half = visibleCount ~/ 2;
        final start = (focusedIndex - half).clamp(
          0,
          (weeks.length - visibleCount).clamp(0, weeks.length),
        );
        final end = (start + visibleCount).clamp(0, weeks.length);
        final visibleWeeks = weeks.sublist(start, end);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 120) return;
            final direction = velocity < 0 ? 1 : -1;
            onWindowSwipe(direction * visibleCount);
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: FadeTransition(
              opacity: labelFade,
              child: Row(
                children: [
                  for (var i = 0; i < visibleWeeks.length; i++) ...[
                    Expanded(
                      child: _WeekLabelChip(
                        week: visibleWeeks[i],
                        isFocused: start + i == focusedIndex,
                        colorScheme: cs,
                        onTap: () => onWeekSelected(start + i),
                      ),
                    ),
                    if (i != visibleWeeks.length - 1) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekLabelChip extends StatelessWidget {
  const _WeekLabelChip({
    required this.week,
    required this.isFocused,
    required this.colorScheme,
    required this.onTap,
  });

  final int week;
  final bool isFocused;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final label = _WeekDisplayLabel.fromWeek(week);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isFocused ? 6 : 4,
            vertical: isFocused ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isFocused
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.top,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: isFocused ? 9 : 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: isFocused
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label.bottom,
                maxLines: label.isSpecial ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: label.isSpecial
                      ? (isFocused ? 12 : 9.5)
                      : (isFocused ? 24 : 16),
                  fontWeight: isFocused ? FontWeight.w900 : FontWeight.w700,
                  fontStyle: isFocused ? FontStyle.italic : FontStyle.normal,
                  letterSpacing: label.isSpecial
                      ? (isFocused ? -0.15 : 0)
                      : (isFocused ? -0.7 : -0.2),
                  height: label.isSpecial ? 1.05 : null,
                  color: isFocused ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: isFocused ? 28 : 16,
                height: 3,
                decoration: BoxDecoration(
                  color: isFocused
                      ? cs.primary
                      : cs.outlineVariant.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDisplayLabel {
  const _WeekDisplayLabel({
    required this.top,
    required this.bottom,
    required this.isSpecial,
  });

  final String top;
  final String bottom;
  final bool isSpecial;

  factory _WeekDisplayLabel.fromWeek(int week) {
    return switch (week) {
      -1 => const _WeekDisplayLabel(
        top: 'STAGE',
        bottom: 'RELEGATION\nROUND 1',
        isSpecial: true,
      ),
      -2 => const _WeekDisplayLabel(
        top: 'STAGE',
        bottom: 'RELEGATION\nROUND 2',
        isSpecial: true,
      ),
      -3 => const _WeekDisplayLabel(
        top: 'STAGE',
        bottom: 'FINAL 4\nPLAYOFF',
        isSpecial: true,
      ),
      -4 => const _WeekDisplayLabel(
        top: 'STAGE',
        bottom: 'FINAL 4',
        isSpecial: true,
      ),
      -5 => const _WeekDisplayLabel(
        top: 'STAGE',
        bottom: '3RD\nPLACE',
        isSpecial: true,
      ),
      -6 => const _WeekDisplayLabel(
        top: 'STAGE',
        bottom: 'FINALS',
        isSpecial: true,
      ),
      _ => _WeekDisplayLabel(top: 'WEEK', bottom: '$week', isSpecial: false),
    };
  }
}
