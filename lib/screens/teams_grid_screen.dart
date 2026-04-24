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
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    if (_error != null) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
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
        ),
      );
    }

    if (_teams == null) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return ColoredBox(
      color: colorScheme.surface,
      child: _teams!.isEmpty
          ? Padding(
              padding: EdgeInsets.only(top: topInset),
              child: Center(
                child: Text(
                  'No teams found',
                  style: TextStyle(color: colorScheme.secondary),
                ),
              ),
            )
          : GridView.builder(
              padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 120),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (team.logoUrl == null || team.logoUrl!.isEmpty)
              Icon(
                Icons.shield,
                size: 56,
                color: colorScheme.primary.withAlpha(80),
              )
            else
              SizedBox(
                height: 56,
                width: 56,
                child: Image.network(
                  team.logoUrl!,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.shield,
                    size: 56,
                    color: colorScheme.primary.withAlpha(80),
                  ),
                ),
              ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    team.teamName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF151b2a),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
