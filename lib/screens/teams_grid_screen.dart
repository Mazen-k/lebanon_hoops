import 'package:flutter/material.dart';
import '../data/team_repository.dart';
import '../models/team.dart';
import 'team_profile_screen.dart';

class TeamsGridScreen extends StatefulWidget {
  const TeamsGridScreen({super.key});

  @override
  State<TeamsGridScreen> createState() => _TeamsGridScreenState();
}

class _TeamsGridScreenState extends State<TeamsGridScreen> {
  final _teamsRepo = const TeamRepository();
  List<Team>? _teams;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await _teamsRepo.fetchTeams();
      if (mounted) setState(() { _teams = teams; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); });
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
              Icon(Icons.wifi_off_rounded, size: 48, color: colorScheme.secondary),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: colorScheme.secondary), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () {
                setState(() { _error = null; });
                _loadTeams();
              }, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_teams == null) {
      return Center(child: CircularProgressIndicator(color: colorScheme.primary));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface, 
      body: SafeArea(
        child: _teams!.isEmpty
            ? Center(
                child: Text(
                  'No teams found',
                  style: TextStyle(color: colorScheme.secondary),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 96, 16, 120), 
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
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TeamProfileScreen(teamId: team.teamId),
        ));
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
