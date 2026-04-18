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
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
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
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(13)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.1).round()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.surfaceContainerLow,
                      colorScheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(20)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                      image: team.logoUrl != null && team.logoUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(team.logoUrl!),
                              fit: BoxFit.contain,
                            )
                          : null,
                    ),
                    child: team.logoUrl == null || team.logoUrl!.isEmpty
                        ? Icon(
                            Icons.shield,
                            size: 28,
                            color: colorScheme.primary.withAlpha(180),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      team.teamName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LBL TEAM',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.secondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
