import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/opened_card.dart';
import '../../../util/card_image_url.dart';
import '../../../theme/colors.dart';

const double _kRevealCardW = 150;
const double _kRevealCardH = 200;

/// Full-screen animated reveal after a pack is opened (cards already saved on server).
class PackRevealScreen extends StatefulWidget {
  const PackRevealScreen({super.key, required this.cards});

  final List<OpenedCard> cards;

  @override
  State<PackRevealScreen> createState() => _PackRevealScreenState();
}

class _PackRevealScreenState extends State<PackRevealScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hapticMid = false;
  bool _hapticFlip = false;

  static const _duration = Duration(milliseconds: 4800);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _controller.addListener(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  void _onTick() {
    final t = _controller.value;
    if (!_hapticMid && t >= 0.2) {
      _hapticMid = true;
      HapticFeedback.mediumImpact();
    }
    if (!_hapticFlip && t >= 0.62) {
      _hapticFlip = true;
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onSurface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildAmbientGlow(t),
                _buildFlash(t),
                ..._buildCardsLayer(context, t),
                _buildPackLayer(t),
                _buildTopBar(context, t),
                _buildDoneButton(context, t),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAmbientGlow(double t) {
    final pulse = 0.35 + 0.15 * (1 + math.sin(t * math.pi * 2)) * (1 - t).clamp(0.0, 1.0);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              AppColors.primary.withAlpha((255 * pulse).round()),
              AppColors.onSurface,
            ],
            stops: const [0.0, 0.85],
          ),
        ),
      ),
    );
  }

  /// White crack-open flash as the pack breaks.
  Widget _buildFlash(double t) {
    final start = 0.16;
    final end = 0.32;
    double flash = 0;
    if (t >= start && t <= end) {
      final u = ((t - start) / (end - start)).clamp(0.0, 1.0);
      flash = (u < 0.5 ? u * 2 : 2 - u * 2);
    }
    return IgnorePointer(
      child: Container(
        color: Colors.white.withAlpha((255 * 0.85 * flash).round()),
      ),
    );
  }

  Widget _buildPackLayer(double t) {
    final burstEnd = 0.28;
    if (t >= burstEnd) return const SizedBox.shrink();

    final u = (t / burstEnd).clamp(0.0, 1.0);
    final shake = 0.035 * math.sin(t * 40);
    final scale = 1.0 + 0.08 * math.sin(t * 12) + 0.35 * Curves.easeIn.transform(u);
    final rot = shake + u * 0.18;
    final opacity = 1.0 - Curves.easeIn.transform(u);

    return Center(
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: 200,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: AppColors.signatureGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(200),
                    blurRadius: 32 + 48 * u,
                    spreadRadius: 4 * u,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_rounded, size: 72, color: AppColors.onPrimary.withAlpha(230)),
                  const SizedBox(height: 12),
                  Text(
                    'STANDARD',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PACK',
                    style: TextStyle(
                      color: AppColors.onPrimary.withAlpha(220),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCardsLayer(BuildContext context, double t) {
    final cards = widget.cards;
    if (cards.isEmpty) return [];

    final spreadStart = 0.26;
    final spreadEnd = 0.52;
    final spreadT = ((t - spreadStart) / (spreadEnd - spreadStart)).clamp(0.0, 1.0);
    final spread = Curves.easeOutCubic.transform(spreadT);

    final flipBase = 0.52;
    final flipSlot = 0.11;

    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.46);
    final targets = _slotTargets(cards.length, w, h);

    final list = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      final target = targets[i];
      final pos = Offset.lerp(center, target, spread)!;

      final flipStart = flipBase + i * flipSlot;
      final flipDur = 0.14;
      double flipP = ((t - flipStart) / flipDur).clamp(0.0, 1.0);
      flipP = Curves.easeOutBack.transform(flipP);

      final scaleInStart = 0.24 + i * 0.04;
      final scaleIn = ((t - scaleInStart) / 0.18).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(scaleIn);

      list.add(
        Positioned(
          left: pos.dx - _kRevealCardW / 2,
          top: pos.dy - _kRevealCardH / 2,
          child: Transform.scale(
            scale: 0.15 + 0.85 * scale,
            child: _FlipCard(
              flipProgress: flipP,
              card: cards[i],
            ),
          ),
        ),
      );
    }
    return list;
  }

  List<Offset> _slotTargets(int n, double w, double h) {
    final midX = w / 2;
    final midY = h * 0.46;
    const gap = 12.0;
    switch (n) {
      case 1:
        return [Offset(midX, midY)];
      case 2:
        return [
          Offset(midX - _kRevealCardW / 2 - gap / 2, midY),
          Offset(midX + _kRevealCardW / 2 + gap / 2, midY),
        ];
      case 3:
        return [
          Offset(midX, midY - _kRevealCardH / 2 - gap / 2),
          Offset(midX - _kRevealCardW / 2 - gap / 2, midY + _kRevealCardH / 2 + gap / 2),
          Offset(midX + _kRevealCardW / 2 + gap / 2, midY + _kRevealCardH / 2 + gap / 2),
        ];
      default:
        return [
          Offset(midX - _kRevealCardW / 2 - gap / 2, midY - _kRevealCardH / 2 - gap / 2),
          Offset(midX + _kRevealCardW / 2 + gap / 2, midY - _kRevealCardH / 2 - gap / 2),
          Offset(midX - _kRevealCardW / 2 - gap / 2, midY + _kRevealCardH / 2 + gap / 2),
          Offset(midX + _kRevealCardW / 2 + gap / 2, midY + _kRevealCardH / 2 + gap / 2),
        ];
    }
  }

  Widget _buildTopBar(BuildContext context, double t) {
    final show = t > 0.05;
    return Positioned(
      top: 8,
      left: 8,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
        ),
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context, double t) {
    final show = t > 0.88;
    return Positioned(
      left: 24,
      right: 24,
      bottom: 24,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        child: IgnorePointer(
          ignoring: !show,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add to collection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.flipProgress, required this.card});

  final double flipProgress;
  final OpenedCard card;

  @override
  Widget build(BuildContext context) {
    final angle = (1.0 - flipProgress) * math.pi;

    return SizedBox(
      width: _kRevealCardW,
      height: _kRevealCardH,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(angle),
        child: angle < math.pi / 2
            ? _CardFront(card: card)
            : Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(math.pi),
                child: const _CardBack(),
              ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kRevealCardW,
      height: _kRevealCardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppColors.secondary,
            AppColors.inverseSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withAlpha(200), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(100),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_basketball, size: 44, color: AppColors.onPrimary.withAlpha(220)),
          const SizedBox(height: 8),
          Text(
            'LBL',
            style: TextStyle(
              color: AppColors.onPrimary.withAlpha(240),
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card});

  final OpenedCard card;

  String? _imageUrl() => displayableCardImageUrl(card.cardImage);

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl();

    return Container(
      width: _kRevealCardW,
      height: _kRevealCardH,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: AppColors.surfaceContainerHigh,
                child: Icon(Icons.person, size: 48, color: AppColors.secondary),
              ),
            )
          : ColoredBox(
              color: AppColors.surfaceContainerHigh,
              child: Icon(Icons.person, size: 48, color: AppColors.secondary),
            ),
    );
  }
}
