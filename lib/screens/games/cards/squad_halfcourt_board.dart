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
    this.onSlotTap,
  });

  final CardsSquadPayload squad;
  final bool readOnly;
  final bool showCombatStats;
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
              _slotAt(w, h, 'pg', 0.5, 0.065),
              _slotAt(w, h, 'sg', 0.82, 0.24),
              _slotAt(w, h, 'sf', 0.18, 0.24),
              _slotAt(w, h, 'pf', 0.2, 0.52),
              _slotAt(w, h, 'c', 0.5, 0.69),
            ],
          );
        },
      ),
    );
  }

  Widget _slotAt(double w, double h, String key, double fx, double fy) {
    final card = squad.slots[key]!;
    return Positioned(
      left: w * fx - _CourtSlotChip.slotStackWidth / 2,
      top: h * fy - _CourtSlotChip.slotStackHeight / 2,
      width: _CourtSlotChip.slotStackWidth,
      height: _CourtSlotChip.slotStackHeight + (showCombatStats && !card.isEmpty ? 18 : 0),
      child: _CourtSlotChip(
        label: slotLabel(key),
        card: card,
        isEmpty: card.isEmpty,
        showCombatStats: showCombatStats,
        onTap: readOnly || onSlotTap == null ? null : () => onSlotTap!(key),
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
    required this.onTap,
  });

  static const double slotStackWidth = 108;
  static const double slotStackHeight = 158;

  static const double _cardW = 96;
  static const double _cardH = 118;

  final String label;
  final CardsSquadSlotCard card;
  final bool isEmpty;
  final bool showCombatStats;
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
            Container(
              width: _cardW,
              height: _cardH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: CardGameUiTheme.gold.withAlpha(isEmpty ? 75 : 110),
                  width: isEmpty ? 1.8 : 1.4,
                ),
                color: isEmpty ? CardGameUiTheme.elevated.withAlpha(220) : null,
                boxShadow: [
                  BoxShadow(
                    color: CardGameUiTheme.orangeGlow.withAlpha(isEmpty ? 22 : 40),
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
                  : BundledPlayCardImage(
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
    final floor = Paint()..color = const Color(0xFF2A1D14);
    final line = Paint()
      ..color = Colors.white.withAlpha(95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(14));
    canvas.drawRRect(r, floor);

    canvas.save();
    canvas.clipRRect(r);

    final midX = w / 2;
    final hoopY = h - 14;
    canvas.drawLine(Offset(0, hoopY), Offset(w, hoopY), line..strokeWidth = 1.2);

    final keyPaint = Paint()..color = const Color(0xFF3D2818).withAlpha(220);
    final keyPath = Path()
      ..moveTo(midX - w * 0.19, hoopY)
      ..lineTo(midX + w * 0.19, hoopY)
      ..lineTo(midX + w * 0.14, hoopY - h * 0.32)
      ..lineTo(midX - w * 0.14, hoopY - h * 0.32)
      ..close();
    canvas.drawPath(keyPath, keyPaint);
    canvas.drawPath(keyPath, line..strokeWidth = 1.8);

    final paintArc = Paint()
      ..color = Colors.white.withAlpha(85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(midX, hoopY), width: w * 0.78, height: h * 0.42),
      3.35,
      0.55,
      false,
      paintArc,
    );

    canvas.drawCircle(Offset(midX, hoopY - h * 0.12), w * 0.055, line..strokeWidth = 1.5);

    final board = Paint()..color = const Color(0xFF8B7355);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(midX, hoopY + 4), width: 42, height: 6),
        const Radius.circular(2),
      ),
      board,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
