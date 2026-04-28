import 'dart:convert';

import 'package:flutter/material.dart';

/// Parses `player_boxscores.stats` / team totals JSON into display strings.
Map<String, String> parseBoxscoreStatTotals(dynamic raw) {
  if (raw == null) return {};
  if (raw is Map) {
    return {
      for (final e in raw.entries)
        e.key.toString(): e.value == null ? '—' : e.value.toString(),
    };
  }
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return {};
    try {
      final d = jsonDecode(s);
      return parseBoxscoreStatTotals(d);
    } catch (_) {
      return {};
    }
  }
  return {};
}

String boxscoreStatValue(Map<String, String> stats, String key) {
  for (final entry in stats.entries) {
    if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
  }
  return '—';
}

String boxscorePercentLabel(String raw) {
  if (raw == '—') return raw;
  return raw.endsWith('%') ? raw : '$raw%';
}

/// Minutes as shown on game box score (FLB uses `Mins`; other feeds use MIN / Min).
String boxscoreMinutesDisplay(Map<String, String> stats) {
  for (final k in ['Mins', 'MIN', 'Min', 'Minutes', 'minutes', 'MP']) {
    final v = boxscoreStatValue(stats, k);
    if (v != '—' && v.trim().isNotEmpty) return v;
  }
  return '—';
}

String boxscoreEffFromStats(Map<String, String> stats) {
  final pts = int.tryParse(boxscoreStatValue(stats, 'Pts')) ?? 0;
  final off = int.tryParse(boxscoreStatValue(stats, 'OFF')) ?? 0;
  final def = int.tryParse(boxscoreStatValue(stats, 'DEF')) ?? 0;
  final ast = int.tryParse(boxscoreStatValue(stats, 'AST')) ?? 0;
  final stl = int.tryParse(boxscoreStatValue(stats, 'STL')) ?? 0;
  final blk = int.tryParse(boxscoreStatValue(stats, 'BLK')) ?? 0;
  final fgm = int.tryParse(boxscoreStatValue(stats, 'FGM')) ?? 0;
  final fga = int.tryParse(boxscoreStatValue(stats, 'FGA')) ?? 0;
  final ftm = int.tryParse(boxscoreStatValue(stats, 'FTM')) ?? 0;
  final fta = int.tryParse(boxscoreStatValue(stats, 'FTA')) ?? 0;
  final turnovers = int.tryParse(boxscoreStatValue(stats, 'TO')) ?? 0;
  final misses = (fga - fgm) + (fta - ftm);
  return '${pts + off + def + ast + stl + blk - turnovers - misses}';
}

/// Same grid as an expanded player row on [GameBoxscoreScreen].
class BoxscoreExpandedStatPanel extends StatelessWidget {
  const BoxscoreExpandedStatPanel({
    super.key,
    required this.scheme,
    required this.stats,
  });

  final ColorScheme scheme;
  final Map<String, String> stats;

  @override
  Widget build(BuildContext context) {
    final pts = boxscoreStatValue(stats, 'Pts');
    final off = boxscoreStatValue(stats, 'OFF');
    final def = boxscoreStatValue(stats, 'DEF');
    final reb = boxscoreStatValue(stats, 'REB');
    final ast = boxscoreStatValue(stats, 'AST');
    final stl = boxscoreStatValue(stats, 'STL');
    final blk = boxscoreStatValue(stats, 'BLK');
    final turnovers = boxscoreStatValue(stats, 'TO');
    final pf = boxscoreStatValue(stats, 'PF');
    final twoMadeAttempt =
        boxscoreStatValue(stats, '2PM') == '—' && boxscoreStatValue(stats, '2PA') == '—'
            ? '—'
            : '${boxscoreStatValue(stats, '2PM')}/${boxscoreStatValue(stats, '2PA')}';
    final twoPct = boxscorePercentLabel(boxscoreStatValue(stats, '2P%'));
    final threeMadeAttempt =
        boxscoreStatValue(stats, '3PM') == '—' && boxscoreStatValue(stats, '3PA') == '—'
            ? '—'
            : '${boxscoreStatValue(stats, '3PM')}/${boxscoreStatValue(stats, '3PA')}';
    final threePct = boxscorePercentLabel(boxscoreStatValue(stats, '3P%'));
    final ftMadeAttempt =
        boxscoreStatValue(stats, 'FTM') == '—' && boxscoreStatValue(stats, 'FTA') == '—'
            ? '—'
            : '${boxscoreStatValue(stats, 'FTM')}/${boxscoreStatValue(stats, 'FTA')}';
    final ftPct = boxscorePercentLabel(boxscoreStatValue(stats, 'FT%'));
    final eff = boxscoreEffFromStats(stats);

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: SizedBox()),
            Expanded(
              flex: 3,
              child: _PanelGroupLabel(label: 'REB', scheme: scheme),
            ),
            const Expanded(flex: 5, child: SizedBox()),
          ],
        ),
        Table(
          border: TableBorder.symmetric(
            inside: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          columnWidths: const {
            0: FlexColumnWidth(),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
            3: FlexColumnWidth(),
            4: FlexColumnWidth(),
            5: FlexColumnWidth(),
            6: FlexColumnWidth(),
            7: FlexColumnWidth(),
            8: FlexColumnWidth(),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
              children: [
                _PanelHeaderCell(label: 'PTS', scheme: scheme),
                _PanelHeaderCell(label: 'OFF', scheme: scheme),
                _PanelHeaderCell(label: 'DEF', scheme: scheme),
                _PanelHeaderCell(label: 'T', scheme: scheme),
                _PanelHeaderCell(label: 'AST', scheme: scheme),
                _PanelHeaderCell(label: 'STL', scheme: scheme),
                _PanelHeaderCell(label: 'BLK', scheme: scheme),
                _PanelHeaderCell(label: 'TO', scheme: scheme),
                _PanelHeaderCell(label: 'PF', scheme: scheme),
              ],
            ),
            TableRow(
              children: [
                _PanelValueCell(value: pts, scheme: scheme),
                _PanelValueCell(value: off, scheme: scheme),
                _PanelValueCell(value: def, scheme: scheme),
                _PanelValueCell(value: reb, scheme: scheme),
                _PanelValueCell(value: ast, scheme: scheme),
                _PanelValueCell(value: stl, scheme: scheme),
                _PanelValueCell(value: blk, scheme: scheme),
                _PanelValueCell(value: turnovers, scheme: scheme),
                _PanelValueCell(value: pf, scheme: scheme),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _PanelGroupLabel(label: '2PTS', scheme: scheme),
            ),
            Expanded(
              flex: 2,
              child: _PanelGroupLabel(label: '3PTS', scheme: scheme),
            ),
            Expanded(
              flex: 2,
              child: _PanelGroupLabel(label: 'FT', scheme: scheme),
            ),
            Expanded(
              child: _PanelGroupLabel(label: '', scheme: scheme),
            ),
          ],
        ),
        Table(
          border: TableBorder.symmetric(
            inside: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          columnWidths: const {
            0: FlexColumnWidth(),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
            3: FlexColumnWidth(),
            4: FlexColumnWidth(),
            5: FlexColumnWidth(),
            6: FlexColumnWidth(),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
              children: [
                _PanelHeaderCell(label: 'M/A', scheme: scheme),
                _PanelHeaderCell(label: '%', scheme: scheme),
                _PanelHeaderCell(label: 'M/A', scheme: scheme),
                _PanelHeaderCell(label: '%', scheme: scheme),
                _PanelHeaderCell(label: 'M/A', scheme: scheme),
                _PanelHeaderCell(label: '%', scheme: scheme),
                _PanelHeaderCell(label: 'EFF', scheme: scheme),
              ],
            ),
            TableRow(
              children: [
                _PanelValueCell(value: twoMadeAttempt, scheme: scheme),
                _PanelValueCell(value: twoPct, scheme: scheme),
                _PanelValueCell(value: threeMadeAttempt, scheme: scheme),
                _PanelValueCell(value: threePct, scheme: scheme),
                _PanelValueCell(value: ftMadeAttempt, scheme: scheme),
                _PanelValueCell(value: ftPct, scheme: scheme),
                _PanelValueCell(value: eff, scheme: scheme),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _PanelGroupLabel extends StatelessWidget {
  const _PanelGroupLabel({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      alignment: Alignment.center,
      color: scheme.surfaceContainerHighest,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class _PanelHeaderCell extends StatelessWidget {
  const _PanelHeaderCell({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.3,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PanelValueCell extends StatelessWidget {
  const _PanelValueCell({required this.value, required this.scheme});

  final String value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: scheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
