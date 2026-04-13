import 'package:flutter/material.dart';

import 'card_mode_placeholders.dart';
import 'cards_hub_image_paths.dart';
import 'open_packs_page.dart';
import 'trade_hub_page.dart';
import 'view_collection_page.dart';

/// Dark card-hub aesthetic (purple/black, orange/gold accents).
abstract final class _CardHubTheme {
  static const Color bgDeep = Color(0xFF0A0A1A);
  static const Color bgElevated = Color(0xFF12122A);
  static const Color orange = Color(0xFFFF8C00);
  static const Color gold = Color(0xFFFFD700);
}

/// Entry points into the card game modes. Fixed viewport (no scroll).
class CardsGameHubPage extends StatelessWidget {
  const CardsGameHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _CardHubTheme.bgDeep,
      child: CustomPaint(
        painter: _GridPatternPainter(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _FeaturedPacksHero(
                    onOpenPacks: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const OpenPacksPage()),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 76,
                  width: double.infinity,
                  child: _OneVOneCta(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const OneVOnePage()),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 4,
                  child: _SecondaryGrid(
                    onCollection: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const ViewCollectionPage()),
                    ),
                    onDuplicates: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const ViewCollectionPage(duplicatesOnly: true),
                      ),
                    ),
                    onTrading: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const TradeHubPage()),
                    ),
                    onSbc: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const SbcPage()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedPacksHero extends StatelessWidget {
  const _FeaturedPacksHero({required this.onOpenPacks});

  final VoidCallback onOpenPacks;

  @override
  Widget build(BuildContext context) {
    return _HubTappableImage(
      imageAsset: CardsHubImagePaths.packsHero,
      onTap: onOpenPacks,
      height: null,
      borderRadius: 22,
      strongBorder: true,
    );
  }
}

class _OneVOneCta extends StatelessWidget {
  const _OneVOneCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HubTappableImage(
      imageAsset: CardsHubImagePaths.oneVOne,
      onTap: onTap,
      height: 76,
      borderRadius: 20,
      strongBorder: true,
    );
  }
}

class _SecondaryGrid extends StatelessWidget {
  const _SecondaryGrid({
    required this.onCollection,
    required this.onDuplicates,
    required this.onTrading,
    required this.onSbc,
  });

  final VoidCallback onCollection;
  final VoidCallback onDuplicates;
  final VoidCallback onTrading;
  final VoidCallback onSbc;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HubTappableImage(
                  imageAsset: CardsHubImagePaths.collection,
                  onTap: onCollection,
                  borderRadius: 18,
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: _HubTappableImage(
                  imageAsset: CardsHubImagePaths.duplicates,
                  onTap: onDuplicates,
                  borderRadius: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HubTappableImage(
                  imageAsset: CardsHubImagePaths.trading,
                  onTap: onTrading,
                  borderRadius: 18,
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: _HubTappableImage(
                  imageAsset: CardsHubImagePaths.sbc,
                  onTap: onSbc,
                  borderRadius: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Framed tap target; shows [imageAsset] or an empty interior if the file is missing.
class _HubTappableImage extends StatelessWidget {
  const _HubTappableImage({
    required this.imageAsset,
    required this.onTap,
    this.height,
    this.borderRadius = 20,
    this.strongBorder = false,
  });

  final String imageAsset;
  final VoidCallback onTap;
  final double? height;
  final double borderRadius;
  final bool strongBorder;

  @override
  Widget build(BuildContext context) {
    final borderW = strongBorder ? 1.5 : 1.2;
    final gold = _CardHubTheme.gold.withAlpha(strongBorder ? 200 : 100);
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: _CardHubTheme.bgElevated,
      border: Border.all(width: borderW, color: gold),
      boxShadow: [
        BoxShadow(
          color: _CardHubTheme.orange.withAlpha(strongBorder ? 55 : 28),
          blurRadius: strongBorder ? 24 : 14,
          spreadRadius: strongBorder ? -2 : 0,
          offset: Offset(0, strongBorder ? 10 : 6),
        ),
      ],
    );

    Widget imageFill() => Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
        );

    if (height != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            height: height,
            decoration: decoration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius - 1),
              child: SizedBox(width: double.infinity, height: height, child: imageFill()),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Ink(
              width: w,
              height: h,
              decoration: decoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius - 1),
                child: SizedBox(width: w, height: h, child: imageFill()),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withAlpha(10)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
