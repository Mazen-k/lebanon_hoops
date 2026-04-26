import 'package:flutter/material.dart';
import '../data/team_repository.dart';
import '../models/team.dart';
import '../state/competition_filter.dart';
import 'team_profile_screen.dart';

class TeamsGridScreen extends StatefulWidget {
  const TeamsGridScreen({super.key});

  @override
  State<TeamsGridScreen> createState() => _TeamsGridScreenState();
}

class _TeamsGridScreenState extends State<TeamsGridScreen> {
  final _teamsRepo = const TeamRepository();
  final AppCompetitionFilter _filter = AppCompetitionFilter.instance;
  List<Team>? _teams;
  String? _error;
  int _loadSeq = 0;
  int? _loadedForCompetitionId;

  @override
  void initState() {
    super.initState();
    _filter.addListener(_onFilterChanged);
    _loadTeams();
  }

  @override
  void dispose() {
    _filter.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    if (!mounted) return;
    if (_loadedForCompetitionId == _filter.selected.competitionId) return;
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final seq = ++_loadSeq;
    final cid = _filter.selected.competitionId;
    if (mounted) {
      setState(() {
        _teams = null;
        _error = null;
      });
    }
    try {
      final teams = await _teamsRepo.fetchTeams(competitionId: cid);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _teams = teams;
        _loadedForCompetitionId = cid;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = e.toString();
        _loadedForCompetitionId = cid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: colorScheme.secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTeams,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_teams == null) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    return ColoredBox(
      color: colorScheme.surface,
      child: _teams!.isEmpty
          ? Center(
              child: Text(
                'No teams found',
                style: TextStyle(color: colorScheme.secondary),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 120),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _teams!.length,
              itemBuilder: (context, index) {
                final team = _teams![index];
                return _TeamCard(team: team);
              },
            ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isDark = colorScheme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamProfileScreen(teamId: team.teamId),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? colorScheme.outlineVariant.withValues(alpha: 0.5)
                : Colors.grey.withAlpha(40),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (team.logoUrl == null || team.logoUrl!.isEmpty)
              Icon(
                Icons.shield,
                size: 64,
                color: colorScheme.primary.withValues(alpha: 0.3),
              )
            else
              SizedBox(
                height: 64,
                width: 64,
                child: Image.network(
                  team.logoUrl!,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.shield,
                    size: 64,
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              team.teamName.toUpperCase(),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.2,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
