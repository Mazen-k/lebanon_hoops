import 'package:flutter/material.dart';

import 'card_game_ui_theme.dart';
import 'squad_editor_page.dart';

/// Head-to-head card battles hub (matchmaking and squads — mostly placeholders).
class OneVOnePage extends StatelessWidget {
  const OneVOnePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CardGameUiTheme.bg,
      appBar: AppBar(
        title: const Text('1v1'),
        backgroundColor: CardGameUiTheme.bg,
        foregroundColor: CardGameUiTheme.onDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(
                  child: _OneVOneTopTileDisabled(
                    icon: Icons.shuffle_rounded,
                    title: 'Random game',
                    subtitle: 'Quick match vs a random opponent',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _OneVOneTopTileDisabled(
                    icon: Icons.group_rounded,
                    title: 'Play against a friend',
                    subtitle: 'Invite someone you know',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'Your squads',
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(220),
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Build up to three lineups for different matchups.',
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(140),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            _SquadEditRow(
              squadIndex: 1,
              onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SquadEditorPage(squadNumber: 1)),
                  ),
            ),
            const SizedBox(height: 10),
            _SquadEditRow(
              squadIndex: 2,
              onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SquadEditorPage(squadNumber: 2)),
                  ),
            ),
            const SizedBox(height: 10),
            _SquadEditRow(
              squadIndex: 3,
              onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SquadEditorPage(squadNumber: 3)),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same visual language as trade hub top tiles, non-interactive.
class _OneVOneTopTileDisabled extends StatelessWidget {
  const _OneVOneTopTileDisabled({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.72,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: CardGameUiTheme.panel.withAlpha(240),
          border: Border.all(
            color: CardGameUiTheme.gold.withAlpha(55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: CardGameUiTheme.orangeGlow.withAlpha(22),
              blurRadius: 12,
              offset: const Offset(0, 5),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: CardGameUiTheme.gold.withAlpha(200)),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CardGameUiTheme.onDark,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(130),
                fontSize: 11.5,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(
                color: CardGameUiTheme.orangeGlow.withAlpha(200),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquadEditRow extends StatelessWidget {
  const _SquadEditRow({
    required this.squadIndex,
    required this.onTap,
  });

  final int squadIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: CardGameUiTheme.panel.withAlpha(240),
            border: Border.all(
              color: CardGameUiTheme.gold.withAlpha(85),
              width: 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: CardGameUiTheme.orangeGlow.withAlpha(30),
                blurRadius: 12,
                offset: const Offset(0, 5),
                spreadRadius: -3,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: CardGameUiTheme.elevated,
                  border: Border.all(color: CardGameUiTheme.gold.withAlpha(70)),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: CardGameUiTheme.gold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Edit squad $squadIndex',
                  style: const TextStyle(
                    color: CardGameUiTheme.onDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: CardGameUiTheme.onDark.withAlpha(160),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
