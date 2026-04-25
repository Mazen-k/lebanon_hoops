import 'package:flutter/material.dart';

import '../models/player_leaders.dart';
import '../services/games_api_service.dart';

/// Grid of stat leader cards (top 3 each) + tap opens top-20 sheet.
class PlayerStatLeadersPanel extends StatelessWidget {
  const PlayerStatLeadersPanel({
    super.key,
    required this.scheme,
    required this.api,
    required this.competitionId,
    required this.summary,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.subtitle,
  });

  final ColorScheme scheme;
  final GamesApiService api;
  final int competitionId;
  final PlayerLeadersSummary? summary;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    final s = summary;
    if (s == null || s.stats.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Text(
            'No player box scores yet for this competition.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.66,
            ),
            itemCount: s.stats.length,
            itemBuilder: (context, index) {
              final g = s.stats[index];
              return _StatLeaderCard(
                scheme: scheme,
                group: g,
                onTap: () => _openTop20Sheet(
                  context,
                  scheme: scheme,
                  api: api,
                  competitionId: competitionId,
                  group: g,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _openTop20Sheet(
  BuildContext context, {
  required ColorScheme scheme,
  required GamesApiService api,
  required int competitionId,
  required PlayerStatLeaderGroup group,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surface,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (ctx, scroll) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.title,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Text(
                'Top 20 — per game (min. 1 GP)',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<PlayerLeadersDetail>(
                  future: api.fetchPlayerLeadersDetail(
                    competitionId: competitionId,
                    stat: group.key,
                    limit: 20,
                  ),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '${snap.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      );
                    }
                    final d = snap.data;
                    if (d == null || d.rows.isEmpty) {
                      return const Center(child: Text('No rows.'));
                    }
                    return ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: d.rows.length,
                      itemBuilder: (context, i) {
                        final r = d.rows[i];
                        return _DetailRow(scheme: scheme, row: r);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.scheme, required this.row});

  final ColorScheme scheme;
  final PlayerLeaderRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${row.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _SmallAvatar(url: row.headshotUrl, radius: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  '${row.teamName} · ${row.positionLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            row.valueLabel,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLeaderCard extends StatelessWidget {
  const _StatLeaderCard({
    required this.scheme,
    required this.group,
    required this.onTap,
  });

  final ColorScheme scheme;
  final PlayerStatLeaderGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Text(
                  group.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                    letterSpacing: 0.3,
                    height: 1.15,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: group.top3.isEmpty
                      ? Center(
                          child: Text(
                            '—',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _BigLeaderBlock(
                                scheme: scheme,
                                row: group.top3.first,
                              ),
                            ),
                            if (group.top3.length > 1) ...[
                              const Divider(height: 1),
                              _CompactLeaderRow(
                                scheme: scheme,
                                row: group.top3[1],
                              ),
                            ],
                            if (group.top3.length > 2) ...[
                              const Divider(height: 1),
                              _CompactLeaderRow(
                                scheme: scheme,
                                row: group.top3[2],
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigLeaderBlock extends StatelessWidget {
  const _BigLeaderBlock({required this.scheme, required this.row});

  final ColorScheme scheme;
  final PlayerLeaderRow row;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 26,
      height: 1.05,
      color: scheme.onSurface,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _AvatarWithTeamBadge(
          headshotUrl: row.headshotUrl,
          teamLogoUrl: row.teamLogo,
          size: 64,
          badgeSize: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                row.playerName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.1,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                row.positionLabel,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(row.valueLabel, style: valueStyle),
            Text(
              'Per game',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactLeaderRow extends StatelessWidget {
  const _CompactLeaderRow({required this.scheme, required this.row});

  final ColorScheme scheme;
  final PlayerLeaderRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _SmallAvatar(url: row.headshotUrl, radius: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  row.positionLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            row.valueLabel,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarWithTeamBadge extends StatelessWidget {
  const _AvatarWithTeamBadge({
    required this.headshotUrl,
    required this.teamLogoUrl,
    required this.size,
    required this.badgeSize,
  });

  final String? headshotUrl;
  final String? teamLogoUrl;
  final double size;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _circleImage(headshotUrl, size / 2),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: teamLogoUrl != null && teamLogoUrl!.isNotEmpty
                  ? Image.network(
                      teamLogoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.shield, size: 12),
                    )
                  : const Icon(Icons.shield, size: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleImage(String? url, double radius) {
    final d = radius * 2;
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE0E0E0),
        child: Icon(
          Icons.person,
          size: radius * 1.1,
          color: Colors.grey.shade600,
        ),
      );
    }
    return ClipOval(
      child: Image.network(
        url,
        width: d,
        height: d,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: d,
          height: d,
          color: const Color(0xFFE0E0E0),
          alignment: Alignment.center,
          child: Icon(
            Icons.person,
            size: radius * 1.1,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.url, required this.radius});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE8E8E8),
        child: Icon(Icons.person, size: radius, color: Colors.grey.shade600),
      );
    }
    return ClipOval(
      child: Image.network(
        url!,
        width: d,
        height: d,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFE8E8E8),
          child: Icon(Icons.person, size: radius, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
