import 'package:flutter/material.dart';

import '../../../models/cards_squad.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_game_ui_theme.dart';

/// Read-only or interactive half court (same layout as [SquadEditorPage]).
class SquadHalfcourtBoard extends StatelessWidget {
  const SquadHalfcourtBoard({
    super.key,
    required this.squad,
    this.readOnly = true,
    this.showCombatStats = false,
    this.disabledSlots = const {},
    this.onSlotTap,
  });

  final CardsSquadPayload squad;
  final bool readOnly;
  final bool showCombatStats;
  /// Slot keys already played this round — shown greyed and not tappable.
  final Set<String> disabledSlots;
  final void Function(String slotKey)? onSlotTap;

  static String slotLabel(String key) {
    return switch (key) {
      'pg' => 'PG',
      'sg' => 'SG',
      'sf' => 'SF',
      'pf' => 'PF',
      'c' => 'C',
      _ => key.toUpperCase(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.68,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _HalfCourtPainter())),
              _slotAt(w, h, 'pg', 0.5, 0.18),
              _slotAt(w, h, 'sg', 0.82, 0.42),
              _slotAt(w, h, 'sf', 0.18, 0.42),
              _slotAt(w, h, 'pf', 0.32, 0.78),
              _slotAt(w, h, 'c', 0.68, 0.78),
            ],
          );
        },
      ),
    );
  }

  Widget _slotAt(double w, double h, String key, double fx, double fy) {
    final card = squad.slots[key]!;
    final used = disabledSlots.contains(key);
    return Positioned(
      left: w * fx - _CourtSlotChip.slotStackWidth / 2,
      top: h * fy - _CourtSlotChip.slotStackHeight / 2,
      width: _CourtSlotChip.slotStackWidth,
      height: _CourtSlotChip.slotStackHeight + (showCombatStats && !card.isEmpty && !used ? 18 : 0),
      child: _CourtSlotChip(
        label: slotLabel(key),
        card: card,
        isEmpty: card.isEmpty,
        showCombatStats: showCombatStats && !used,
        slotUsed: used,
        onTap: readOnly || onSlotTap == null || used ? null : () => onSlotTap!(key),
      ),
    );
  }
}

class _CourtSlotChip extends StatelessWidget {
  const _CourtSlotChip({
    required this.label,
    required this.card,
    required this.isEmpty,
    required this.showCombatStats,
    this.slotUsed = false,
    required this.onTap,
  });

  static const double slotStackWidth = 108;
  static const double slotStackHeight = 168;

  static const double _cardW = 96;
  static const double _cardH = 130;

  final String label;
  final CardsSquadSlotCard card;
  final bool isEmpty;
  final bool showCombatStats;
  final bool slotUsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _cardW,
                  height: _cardH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CardGameUiTheme.gold.withAlpha(isEmpty ? 75 : (slotUsed ? 50 : 110)),
                      width: isEmpty ? 1.8 : 1.4,
                    ),
                    color: isEmpty ? CardGameUiTheme.elevated.withAlpha(220) : null,
                    boxShadow: [
                      BoxShadow(
                        color: CardGameUiTheme.orangeGlow.withAlpha(isEmpty ? 22 : (slotUsed ? 10 : 40)),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isEmpty
                      ? Center(
                          child: Icon(
                            Icons.add_rounded,
                            size: 44,
                            color: CardGameUiTheme.gold.withAlpha(onTap == null ? 90 : 220),
                          ),
                        )
                      : Opacity(
                          opacity: slotUsed ? 0.35 : 1,
                          child: BundledPlayCardImage(
                            cardId: card.cardId,
                            fit: BoxFit.cover,
                            width: _cardW,
                            height: _cardH,
                            fallbackImageUrl: card.cardImage,
                            errorPlaceholder: ColoredBox(
                              color: CardGameUiTheme.panel,
                              child: Center(
                                child: Text(
                                  card.playerLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: CardGameUiTheme.onDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                if (slotUsed && !isEmpty)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black.withAlpha(150),
                      ),
                      child: const Center(
                        child: Text(
                          'USED',
                          style: TextStyle(
                            color: CardGameUiTheme.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (showCombatStats && !isEmpty && (card.attack != null || card.defend != null)) ...[
              const SizedBox(height: 2),
              Text(
                'ATK ${card.attack ?? '—'}  DEF ${card.defend ?? '—'}',
                style: TextStyle(
                  color: CardGameUiTheme.onDark.withAlpha(200),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(200),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CardGameUiTheme.gold.withAlpha(90)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: CardGameUiTheme.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HalfCourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Floor Background (Warm Wood)
    final floor = Paint()..color = const Color(0xFF2D1D14);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(16));
    canvas.drawRRect(r, floor);

    canvas.save();
    canvas.clipRRect(r);

    // Subtle wood grain lines
    final grain = Paint()
      ..color = Colors.white.withAlpha(8)
      ..strokeWidth = 1;
    for (double x = 0; x < w; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grain);
    }

    final line = Paint()
      ..color = Colors.white.withAlpha(110)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final midX = w / 2;
    // The court is viewed from the top, basket is at the bottom
    final baselineY = h - 12;
    final basketY = baselineY - 24;

    // 2. Outer Boundary
    canvas.drawRect(Rect.fromLTWH(4, 4, w - 8, h - 8), line..strokeWidth = 1.2);

    // 3. The Key (Rectangular)
    final keyW = w * 0.38;
    final keyH = h * 0.34;
    final keyRect = Rect.fromLTWH(midX - keyW / 2, baselineY - keyH, keyW, keyH);
    
    final keyFill = Paint()..color = const Color(0xFF3E2B1E).withAlpha(180);
    canvas.drawRect(keyRect, keyFill);
    canvas.drawRect(keyRect, line..strokeWidth = 1.8);

    // 4. Free Throw Circle
    canvas.drawArc(
      Rect.fromCenter(center: Offset(midX, baselineY - keyH), width: keyW, height: keyW),
      3.1415,
      3.1415,
      false,
      line,
    );

    // 5. 3-Point Line
    // Straight sides from baseline
    final sideDist = 18.0;
    final sideY = baselineY - h * 0.18;
    canvas.drawLine(Offset(sideDist, baselineY), Offset(sideDist, sideY), line);
    canvas.drawLine(Offset(w - sideDist, baselineY), Offset(w - sideDist, sideY), line);
    
    // Top Arc
    canvas.drawArc(
      Rect.fromCenter(center: Offset(midX, basketY), width: w * 0.92, height: h * 0.65),
      3.1415 + 0.3,
      2.55,
      false,
      line,
    );

    // 6. Restricted Area (No-charge semi-circle)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(midX, basketY), radius: 22),
      3.1415,
      3.1415,
      false,
      line..color = Colors.white.withAlpha(60),
    );

    // 7. Backboard and Hoop
    final boardW = 44.0;
    canvas.drawLine(
      Offset(midX - boardW / 2, basketY + 4), 
      Offset(midX + boardW / 2, basketY + 4), 
      line..color = Colors.white.withAlpha(200)..strokeWidth = 2.5
    );
    
    final hoopPaint = Paint()
      ..color = const Color(0xFFFF8C00).withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(midX, basketY + 2), 7, hoopPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
