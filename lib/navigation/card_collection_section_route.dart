import 'dart:math' as math;
import 'dart:ui' show FontFeature, MaskFilter, BlurStyle, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/games/games_shell.dart';
import '../screens/games/cards/card_game_ui_theme.dart';
import '../theme/colors.dart';

const Color _cardGameHubBg = Color(0xFF0A0A1A);
const Color _cardGameDeep = Color(0xFF030308);
const Color _cardGameMid = Color(0xFF0C1028);
const Color _neonCyan = Color(0xFF00D4FF);

/// Curves in Flutter assert `t` is in \[0, 1\]; normalize any driven value first.
double _saturateT(double t) => t.clamp(0.0, 1.0);

/// Full “new app boot” sequence — not a light transition: haptics, loading chrome,
/// big motion, then hand-off to [GamesShell].
PageRoute<void> buildCardCollectionSectionRoute({
  Future<void> Function()? onSignOut,
}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 5600),
    reverseTransitionDuration: const Duration(milliseconds: 420),
    opaque: true,
    pageBuilder: (context, animation, secondaryAnimation) {
      return _CardGameBootSequence(onSignOut: onSignOut);
    },
    // Important: do NOT fade the whole page over 5s — the boot animation lives inside
    // the child; a route-level FadeTransition stayed near opacity 0 for most of that
    // time so nothing looked like it was happening.
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}

class _CardGameBootSequence extends StatefulWidget {
  const _CardGameBootSequence({this.onSignOut});

  final Future<void> Function()? onSignOut;

  @override
  State<_CardGameBootSequence> createState() => _CardGameBootSequenceState();
}

class _CardGameBootSequenceState extends State<_CardGameBootSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _introComplete = false;
  int _hapticStage = -1;

  static const _bootDuration = Duration(milliseconds: 5200);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _bootDuration);
    _c.addListener(_onTickHaptics);
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _introComplete = true);
      }
    });
    _c.forward();
  }

  void _onTickHaptics() {
    final t = _c.value;
    void bump(int stage, VoidCallback fn) {
      if (_hapticStage < stage && t >= _milestones[stage]) {
        _hapticStage = stage;
        fn();
      }
    }

    bump(0, () => HapticFeedback.mediumImpact());
    bump(1, () => HapticFeedback.heavyImpact());
    bump(2, () => HapticFeedback.mediumImpact());
    bump(3, () => HapticFeedback.lightImpact());
  }

  /// Normalized thresholds for haptics (t in 0..1).
  static const List<double> _milestones = [0.06, 0.34, 0.62, 0.86];

  @override
  void dispose() {
    _c.removeListener(_onTickHaptics);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GamesShell(onSignOut: widget.onSignOut),
        if (!_introComplete)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _saturateT(_c.value);
                  double dissolve = 1.0;
                  if (t > 0.84) {
                    dissolve =
                        1.0 - Curves.easeInOut.transform(_saturateT((t - 0.84) / 0.16));
                  }

                  // Subtle “impact shake” while the ball slams the visual center.
                  final shakeT = CurvedAnimation(
                    parent: AlwaysStoppedAnimation(t),
                    curve: const Interval(0.30, 0.52, curve: Curves.easeOut),
                  ).value;
                  final shake =
                      shakeT > 0 && shakeT < 1 ? 8 * math.sin(t * math.pi * 14) * (1 - shakeT) : 0.0;

                  return Opacity(
                    opacity: dissolve.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(shake, shake * 0.6),
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          CustomPaint(
                            painter: _BootBackdropPainter(progress: t),
                            child: const SizedBox.expand(),
                          ),
                          _OpeningFlashLayer(progress: t),
                          _LoadingModuleLayer(progress: t),
                          _BasketballFlyLayer(progress: t),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _OpeningFlashLayer extends StatelessWidget {
  const _OpeningFlashLayer({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = _saturateT(progress);
    final flash = CurvedAnimation(
      parent: AlwaysStoppedAnimation(p),
      curve: const Interval(0.0, 0.14, curve: Curves.easeOut),
    ).value;
    if (flash < 0.01) return const SizedBox.shrink();
    final u = _saturateT(p / 0.14);
    final opacity = (1 - Curves.easeIn.transform(u)) * 0.42 * flash.clamp(0.0, 1.0);
    return ColoredBox(color: Colors.white.withAlpha((opacity * 255).round()));
  }
}

/// Big “loading a new module” title + progress — reads like an app splash.
class _LoadingModuleLayer extends StatelessWidget {
  const _LoadingModuleLayer({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = _saturateT(progress);
    final enter = CurvedAnimation(
      parent: AlwaysStoppedAnimation(p),
      curve: const Interval(0.12, 0.28, curve: Curves.easeOutCubic),
    ).value;
    final hold = CurvedAnimation(
      parent: AlwaysStoppedAnimation(p),
      curve: const Interval(0.28, 0.78, curve: Curves.linear),
    ).value;
    final exit = CurvedAnimation(
      parent: AlwaysStoppedAnimation(p),
      curve: const Interval(0.72, 0.88, curve: Curves.easeIn),
    ).value;

    final opacity = (enter * (1 - exit)).clamp(0.0, 1.0);
    if (opacity < 0.02) return const SizedBox.shrink();

    final slidePx = 20.0 * (1.0 - Curves.easeOutCubic.transform(enter.clamp(0, 1)));
    final barProgress =
        Interval(0.16, 0.76, curve: Curves.easeInOut).transform(p);
    final tChrome = CurvedAnimation(
      parent: AlwaysStoppedAnimation(p),
      curve: const Interval(0.08, 0.82, curve: Curves.easeInOutCubic),
    ).value;

    final titleOn =
        Color.lerp(AppColors.onSurface, CardGameUiTheme.onDark, tChrome)!;
    final subtitleOn = Color.lerp(
      AppColors.onSurfaceVariant,
      CardGameUiTheme.onDark.withAlpha((0.55 * 255).round()),
      tChrome,
    )!;
    final hintOn = Color.lerp(
      AppColors.secondary,
      CardGameUiTheme.onDark.withAlpha((0.38 * 255).round()),
      tChrome,
    )!;
    final goldMix = Color.lerp(AppColors.primary, CardGameUiTheme.gold, tChrome)!;
    final trackBg = Color.lerp(
      AppColors.surfaceContainerHighest,
      Colors.black.withAlpha(120),
      tChrome,
    )!;

    return Opacity(
      opacity: opacity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW =
              math.min(constraints.maxWidth - 56, 340).clamp(160.0, 400.0).toDouble();
          final maxH = math.max(120.0, constraints.maxHeight - 40);

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
                  child: Transform.translate(
                    offset: Offset(0, slidePx),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CARD',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 6,
                            height: 0.95,
                            shadows: [
                              Shadow(
                                color: Colors.black.withAlpha((80 + 120 * tChrome).round()),
                                blurRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                              Shadow(
                                color: goldMix.withAlpha((120 + 120 * tChrome).round()),
                                blurRadius: 28 + 6 * tChrome,
                              ),
                              Shadow(
                                color: Color.lerp(AppColors.secondary, _neonCyan, tChrome)!
                                    .withAlpha((100 + 140 * tChrome).round()),
                                blurRadius: 10 + 6 * tChrome,
                                offset: Offset(2 + tChrome, 0),
                              ),
                            ],
                            color: titleOn,
                          ),
                        ),
                        Text(
                          'COLLECTION',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 5,
                            height: 0.95,
                            shadows: [
                              Shadow(
                                color: Color.lerp(
                                  AppColors.primaryContainer,
                                  CardGameUiTheme.orangeGlow,
                                  tChrome,
                                )!.withAlpha((140 + 60 * tChrome).round()),
                                blurRadius: 18 + 6 * tChrome,
                              ),
                              Shadow(
                                color: goldMix.withAlpha((100 + 80 * tChrome).round()),
                                blurRadius: 8,
                              ),
                            ],
                            color: titleOn,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'LOADING MODULE',
                          style: TextStyle(
                            color: subtitleOn,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Preparing your deck & economy…',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: hintOn,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: maxW,
                            height: 8,
                            child: LinearProgressIndicator(
                              value: barProgress.clamp(0.0, 1.0),
                              backgroundColor: trackBg,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color.lerp(
                                  AppColors.primary,
                                  Color.lerp(
                                        CardGameUiTheme.orangeGlow,
                                        CardGameUiTheme.gold,
                                        hold,
                                      )!,
                                  tChrome,
                                )!,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(barProgress * 100).clamp(0, 100).round()}%',
                          style: TextStyle(
                            color: goldMix.withAlpha((180 + 40 * tChrome).round()),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BootBackdropPainter extends CustomPainter {
  _BootBackdropPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final pr = _saturateT(progress);
    final tBg = CurvedAnimation(
      parent: AlwaysStoppedAnimation(pr),
      curve: const Interval(0.0, 0.94, curve: Curves.easeInOutCubic),
    ).value;

    // Start from true “home” chrome (light surface + soft blue), ease into card hub navy.
    final homeTop = Color.lerp(AppColors.surface, AppColors.secondaryContainer, 0.28)!;
    final homeMid = Color.lerp(AppColors.surfaceContainerLow, AppColors.surfaceContainerHigh, 0.5)!;
    final homeBot = Color.lerp(AppColors.surfaceContainerHigh, AppColors.secondaryFixedDim, 0.22)!;

    final topLeft = Color.lerp(homeTop, _cardGameHubBg, tBg)!;
    final mid = Color.lerp(homeMid, _cardGameMid, tBg)!;
    final bottomRight = Color.lerp(homeBot, _cardGameDeep, tBg)!;

    final rect = Offset.zero & size;
    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          topLeft,
          mid,
          bottomRight,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, gradient);

    // Very subtle brand wash while crossing the midpoint — reads as intentional, not noisy.
    final brandWash = CurvedAnimation(
      parent: AlwaysStoppedAnimation(pr),
      curve: const Interval(0.22, 0.62, curve: Curves.easeInOut),
    ).value;
    if (brandWash > 0.02) {
      final wash = Paint()
        ..shader = LinearGradient(
          begin: Alignment(0.2 - 0.4 * tBg, -0.2),
          end: Alignment(0.6 + 0.2 * tBg, 1.0),
          colors: [
            AppColors.primary.withAlpha((18 * brandWash).round()),
            Colors.transparent,
            CardGameUiTheme.gold.withAlpha((14 * brandWash).round()),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, wash);
    }

    final vig = CurvedAnimation(
      parent: AlwaysStoppedAnimation(pr),
      curve: const Interval(0.18, 1.0, curve: Curves.easeOut),
    ).value;
    if (vig > 0.02) {
      final vignette = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.05,
        colors: [
          Colors.transparent,
          Color.lerp(Colors.black54, Colors.black, tBg)!
              .withAlpha((140 * vig).round()),
        ],
          stops: const [0.42, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, vignette);
    }

    // Sweeping highlight (cheap “scan” feel).
    final scan = Interval(0.08, 0.9, curve: Curves.linear).transform(pr);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(lerpDouble(-1.2, 1.2, scan)!, -0.9),
        end: Alignment(lerpDouble(-0.8, 1.4, scan)!, 1.1),
        colors: [
          Colors.transparent,
          Color.lerp(AppColors.primary.withAlpha(24), CardGameUiTheme.gold.withAlpha(28), tBg)!,
          Colors.transparent,
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(rect);
    canvas.drawRect(rect, scanPaint);
  }

  @override
  bool shouldRepaint(covariant _BootBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _BasketballFlyLayer extends StatelessWidget {
  const _BasketballFlyLayer({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = _saturateT(progress);
    final fly = CurvedAnimation(
      parent: AlwaysStoppedAnimation(p),
      curve: const Interval(0.05, 0.48, curve: Curves.easeOutCubic),
    ).value;

    final ax = lerpDouble(-1.55, 0.0, fly)!;
    final ay = lerpDouble(-1.75, -0.02, fly)! + 0.32 * math.sin(fly * math.pi);

    final pulse = CurvedAnimation(
      parent: AlwaysStoppedAnimation(p),
      curve: const Interval(0.36, 0.58, curve: Curves.elasticOut),
    ).value;

    final exit = CurvedAnimation(
      parent: AlwaysStoppedAnimation(p),
      curve: const Interval(0.54, 0.90, curve: Curves.easeInCubic),
    ).value;

    final baseScale = 0.42 + 0.58 * pulse;
    final exitScale = lerpDouble(1.0, 2.85, exit)!;
    final scale = baseScale * exitScale;

    final opacity = (1.0 - exit * 0.98).clamp(0.0, 1.0);
    if (opacity < 0.02) return const SizedBox.shrink();

    // Slow roll so panel seams stay readable (fast spin made lines look “random”).
    final spin = p * math.pi * 0.65 + 0.1 * math.sin(p * math.pi * 3);

    return Opacity(
      opacity: opacity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment(ax, ay),
            child: Transform.rotate(
              angle: spin,
              child: Transform.scale(
                scale: scale,
                child: const _BigBasketballMark(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigBasketballMark extends StatelessWidget {
  const _BigBasketballMark();

  @override
  Widget build(BuildContext context) {
    const size = 260.0;
    return SizedBox(
      width: size,
      height: size * 1.08,
      child: CustomPaint(
        size: Size(size, size * 1.08),
        painter: const _RealisticBasketballPainter(),
      ),
    );
  }
}

/// Leather sphere, pebble texture, Wilson-style channels + equator (no icon overlay).
class _RealisticBasketballPainter extends CustomPainter {
  const _RealisticBasketballPainter();

  static const Color _leatherHi = Color(0xFFFFE0B2);
  static const Color _leatherMid = Color(0xFFE89A4A);
  static const Color _leatherBase = Color(0xFFB85C1A);
  static const Color _leatherDeep = Color(0xFF6B3410);
  static const Color _seam = Color(0xFF120800);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final cy = size.height / 2 - w * 0.02;
    final c = Offset(cx, cy);
    final R = w * 0.44;
    final ballRect = Rect.fromCircle(center: c, radius: R);
    final clip = Path()..addOval(ballRect);

    // Ground shadow (outside clip)
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(52)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + R * 0.74), width: R * 2.15, height: R * 0.44),
      shadowPaint,
    );

    canvas.save();
    canvas.clipPath(clip);

    // Base leather (warmer / less “neon orange” than before)
    final leather = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.40, -0.46),
        radius: 1.08,
        colors: const [
          _leatherHi,
          _leatherMid,
          _leatherBase,
          _leatherDeep,
        ],
        stops: const [0.0, 0.34, 0.66, 1.0],
      ).createShader(ballRect);
    canvas.drawCircle(c, R, leather);

    // Cool fill on lower-right (ambient bounce)
    final fill2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.55, 0.55),
        radius: 0.85,
        colors: [
          const Color(0xFF8B4514).withAlpha(0),
          const Color(0xFF5D2E0C).withAlpha(100),
        ],
        stops: const [0.35, 1.0],
      ).createShader(ballRect);
    canvas.drawCircle(c, R * 0.99, fill2);

    // Pebble grain (multiply so it reads like dimpled leather)
    final rng = math.Random(42);
    final pebble = Paint()
      ..blendMode = BlendMode.multiply
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 160; i++) {
      final u = rng.nextDouble() * 2 * math.pi;
      final rr = R * math.sqrt(rng.nextDouble()) * 0.92;
      final px = c.dx + rr * math.cos(u);
      final py = c.dy + rr * math.sin(u) * 0.97;
      final pr = 0.65 + rng.nextDouble() * 1.15;
      pebble.color = const Color(0xFF3D2414).withAlpha((22 + rng.nextInt(18)).clamp(10, 50));
      canvas.drawCircle(Offset(px, py), pr, pebble);
    }

    // Ambient occlusion at bottom
    final ao = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.08, 0.58),
        radius: 0.92,
        colors: [
          Colors.transparent,
          Colors.black.withAlpha(120),
        ],
        stops: const [0.42, 1.0],
      ).createShader(ballRect);
    canvas.drawCircle(c, R * 0.995, ao);

    final seam = Paint()
      ..color = _seam
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.4, w * 0.024)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Equator (slightly curved arc)
    final equator = Path()
      ..moveTo(c.dx - R * 0.98, c.dy + R * 0.05)
      ..quadraticBezierTo(c.dx, c.dy + R * 0.12, c.dx + R * 0.98, c.dy + R * 0.05);
    canvas.drawPath(equator, seam);

    // Vertical meridian (slightly curved arc)
    final meridian = Path()
      ..moveTo(c.dx + R * 0.05, c.dy - R * 0.98)
      ..quadraticBezierTo(c.dx + R * 0.12, c.dy, c.dx + R * 0.05, c.dy + R * 0.98);
    canvas.drawPath(meridian, seam);

    // Two channel seams (Emoji style: pushed outwards)
    final leftChannel = Path()
      ..moveTo(c.dx - R * 0.32, c.dy - R * 0.9)
      ..cubicTo(
        c.dx - R * 0.88,
        c.dy - R * 0.42,
        c.dx - R * 0.88,
        c.dy + R * 0.42,
        c.dx - R * 0.32,
        c.dy + R * 0.9,
      );
    canvas.drawPath(leftChannel, seam);

    final rightChannel = Path()
      ..moveTo(c.dx + R * 0.32, c.dy - R * 0.9)
      ..cubicTo(
        c.dx + R * 0.88,
        c.dy - R * 0.42,
        c.dx + R * 0.88,
        c.dy + R * 0.42,
        c.dx + R * 0.32,
        c.dy + R * 0.9,
      );
    canvas.drawPath(rightChannel, seam);

    // Specular glint (on top of seams so it reads glossy)
    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.52, -0.58),
        radius: 0.32,
        colors: [
          Colors.white.withAlpha(210),
          Colors.white.withAlpha(0),
        ],
      ).createShader(Rect.fromCircle(center: c.translate(-R * 0.36, -R * 0.4), radius: R * 0.24));
    canvas.drawCircle(c.translate(-R * 0.34, -R * 0.38), R * 0.14, glint);

    canvas.restore();

    // Crisp outer seam / valve ring
    canvas.drawCircle(
      c,
      R,
      Paint()
        ..color = const Color(0xFF2A1810).withAlpha(90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
