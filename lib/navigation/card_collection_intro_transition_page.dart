import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/games/cards/card_game_ui_theme.dart';
import '../screens/games/games_shell.dart';
import '../theme/colors.dart';

/// Matches [GamesShell] cards tab / [CardGameUiTheme] — transition must land here, not on hot orange.
const Color _hubBg = Color(0xFF0A0A1A);
const Color _hubDeep = Color(0xFF050510);
const Color _hubElevated = Color(0xFF12122A);
const Color _hubTwilight = Color(0xFF151528);

/// Full-screen handoff: home chrome → card hub (navy), then [GamesShell].
class CardCollectionIntroTransitionPage extends StatefulWidget {
  const CardCollectionIntroTransitionPage({super.key, this.onSignOut});

  final Future<void> Function()? onSignOut;

  @override
  State<CardCollectionIntroTransitionPage> createState() =>
      _CardCollectionIntroTransitionPageState();
}

class _CardCollectionIntroTransitionPageState extends State<CardCollectionIntroTransitionPage>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _ballController;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeTitleAnim;
  late final Animation<double> _fadeSubtitleAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _vignetteAnim;

  /// Slower, more deliberate handoff (~4.6s).
  static const _sequence = Duration(milliseconds: 4600);

  double _smoothT(double raw) =>
      Curves.easeInOutCubic.transform(raw.clamp(0.0, 1.0));

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(vsync: this, duration: _sequence);

    _ballController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _scaleAnim = Tween<double>(begin: 0.78, end: 1.05).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.62, curve: Curves.easeOutCubic),
      ),
    );

    _fadeTitleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.38, 0.78, curve: Curves.easeOut),
      ),
    );

    _fadeSubtitleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.52, 0.88, curve: Curves.easeOut),
      ),
    );

    _glowAnim = Tween<double>(begin: 0.12, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 1.0, curve: Curves.easeInOut),
      ),
    );

    _vignetteAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
      ),
    );

    _mainController.addListener(_onMainTick);
    _startSequence();
  }

  bool _didWarmHaptic = false;

  void _onMainTick() {
    if (!_didWarmHaptic && _mainController.value >= 0.82) {
      _didWarmHaptic = true;
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _startSequence() async {
    await _mainController.forward();
    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => GamesShell(onSignOut: widget.onSignOut),
        transitionDuration: const Duration(milliseconds: 720),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mainController.removeListener(_onMainTick);
    _mainController.dispose();
    _ballController.dispose();
    super.dispose();
  }

  /// Background gradient + vignette: ends on hub navy (not orange floor).
  Widget _buildStage(double tRaw, double glow, double vignette) {
    final t = _smoothT(tRaw);

    final topLeft = Color.lerp(
      Color.lerp(AppColors.surface, AppColors.secondaryContainer, 0.12)!,
      _hubTwilight,
      t,
    )!;
    final upperMid = Color.lerp(
      AppColors.surfaceContainerHigh,
      _hubElevated,
      t,
    )!;
    final lowerMid = Color.lerp(
      AppColors.surfaceDim,
      _hubBg,
      Curves.easeIn.transform(t),
    )!;
    final bottom = Color.lerp(
      AppColors.secondaryFixedDim,
      _hubDeep,
      t,
    )!;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                topLeft,
                upperMid,
                lowerMid,
                bottom,
              ],
              stops: const [0.0, 0.34, 0.68, 1.0],
            ),
          ),
        ),
        // Subtle warmth near bottom only — atmospheric, not a solid orange floor.
        IgnorePointer(
          child: Opacity(
            opacity: (0.14 *
                    glow *
                    Curves.easeOut.transform(
                      ((tRaw - 0.35) / 0.65).clamp(0.0, 1.0),
                    ))
                .clamp(0.0, 0.10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    CardGameUiTheme.gold.withAlpha((18 + (14 * glow).round()).clamp(8, 40)),
                  ],
                  stops: const [0.0, 0.58, 1.0],
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _IntroVignettePainter(strength: vignette * 0.55),
            child: const SizedBox.expand(),
          ),
        ),
        IgnorePointer(
          child: Opacity(
            opacity: (0.16 * glow).clamp(0.0, 0.22),
            child: CustomPaint(
              painter: _IntroLightStreakPainter(progress: tRaw, phase: glow),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _IntroParticlePainter(
              seed: 11,
              progress: tRaw,
              warmth: glow,
              darkPhase: t,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _ballController]),
      builder: (context, child) {
        final t = _mainController.value;
        final glow = _glowAnim.value;
        final vignette = _vignetteAnim.value;
        final titleA = _fadeTitleAnim.value;
        final subA = _fadeSubtitleAnim.value;
        final ballScale = _scaleAnim.value;

        // Glow under ball: cool at start → soft gold edge, never full orange fill.
        final shadowBlue = AppColors.secondary.withAlpha((40 + 50 * (1 - t)).round());
        final shadowGold = CardGameUiTheme.gold.withAlpha((35 * glow).round());

        return Scaffold(
          backgroundColor: _hubBg,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildStage(t, glow, vignette),
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0011)
                          ..rotateY(_ballController.value * math.pi * 2),
                        child: Transform.scale(
                          scale: ballScale,
                          child: SizedBox(
                            width: 148,
                            height: 148,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowBlue,
                                    blurRadius: 48,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: shadowGold,
                                    blurRadius: 28 * glow,
                                    spreadRadius: 0,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withAlpha((50 + 80 * t).round()),
                                    blurRadius: 24,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: const ClipOval(
                                child: CustomPaint(
                                  painter: _IntroBasketballPainter(),
                                  child: SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Opacity(
                        opacity: titleA,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - titleA)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'CARD COLLECTION',
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(
                                      color: Color.lerp(
                                        AppColors.onSurface,
                                        CardGameUiTheme.onDark,
                                        _smoothT(t),
                                      ),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 3.2,
                                      fontSize: 13,
                                    ) ??
                                    TextStyle(
                                      color: Color.lerp(
                                        AppColors.onSurface,
                                        CardGameUiTheme.onDark,
                                        _smoothT(t),
                                      ),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 3.2,
                                      fontSize: 13,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: 52,
                                height: 2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      CardGameUiTheme.gold.withAlpha((100 + 100 * titleA).round()),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Entering game mode',
                                textAlign: TextAlign.center,
                                style: textTheme.headlineSmall?.copyWith(
                                      color: Color.lerp(
                                        AppColors.onSurface,
                                        CardGameUiTheme.onDark,
                                        _smoothT(t),
                                      ),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      height: 1.15,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withAlpha((28 + 70 * t).round()),
                                          blurRadius: 18,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ) ??
                                    TextStyle(
                                      color: Color.lerp(
                                        AppColors.onSurface,
                                        CardGameUiTheme.onDark,
                                        _smoothT(t),
                                      ),
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12 * subA),
                      Opacity(
                        opacity: subA,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - subA)),
                          child: Text(
                            'Loading cards hub…',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                                  color: Color.lerp(
                                    AppColors.onSurfaceVariant,
                                    CardGameUiTheme.onDark.withAlpha(180),
                                    _smoothT(t),
                                  ),
                                  letterSpacing: 0.3,
                                  fontWeight: FontWeight.w500,
                                ) ??
                                TextStyle(
                                  color: Color.lerp(
                                    AppColors.onSurfaceVariant,
                                    CardGameUiTheme.onDark.withAlpha(180),
                                    _smoothT(t),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IntroVignettePainter extends CustomPainter {
  _IntroVignettePainter({required this.strength});

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength < 0.02) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.05,
        colors: [
          Colors.transparent,
          Colors.black.withAlpha((110 * strength).round()),
        ],
        stops: const [0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _IntroVignettePainter oldDelegate) {
    return oldDelegate.strength != strength;
  }
}

/// Soft horizontal flares — gold / violet, not harsh red-orange.
class _IntroLightStreakPainter extends CustomPainter {
  _IntroLightStreakPainter({required this.progress, required this.phase});

  final double progress;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final centerY = size.height * 0.52;
    final wobble = 0.5 + 0.5 * math.sin(progress * math.pi * 1.2);

    final rect1 = Rect.fromCenter(
      center: Offset(size.width * 0.5, centerY),
      width: size.width * (0.32 + progress * 0.55),
      height: 5,
    );

    paint.shader = LinearGradient(
      colors: [
        Colors.transparent,
        Color.lerp(
          AppColors.secondaryFixedDim,
          CardGameUiTheme.panelBorder,
          progress,
        )!.withAlpha((28 + 55 * phase * wobble).round()),
        Colors.transparent,
      ],
    ).createShader(rect1);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect1, const Radius.circular(24)),
      paint,
    );

    final rect2 = Rect.fromCenter(
      center: Offset(size.width * 0.5, centerY + 36),
      width: size.width * (0.2 + progress * 0.45),
      height: 3,
    );

    paint.shader = LinearGradient(
      colors: [
        Colors.transparent,
        CardGameUiTheme.gold.withAlpha((18 + 40 * phase * progress).round()),
        Colors.transparent,
      ],
    ).createShader(rect2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect2, const Radius.circular(20)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _IntroLightStreakPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.phase != phase;
  }
}

/// Dust motes: cool on light bg, warm specks on dark.
class _IntroParticlePainter extends CustomPainter {
  _IntroParticlePainter({
    required this.seed,
    required this.progress,
    required this.warmth,
    required this.darkPhase,
  });

  final int seed;
  final double progress;
  final double warmth;
  final double darkPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 36; i++) {
      rnd.nextDouble();
      final x = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final drift = progress * 26 * math.sin(i * 0.7 + progress * math.pi);
      var y = baseY + drift;
      y = y % size.height;
      if (y < 0) y += size.height;
      final r = 0.5 + rnd.nextDouble() * 1.2;
      final cool = AppColors.secondaryContainer;
      final warm = CardGameUiTheme.gold;
      final blended = Color.lerp(cool, warm, darkPhase * 0.82)!;
      final alpha = (10 + 22 * warmth * (0.4 + 0.6 * rnd.nextDouble()) * (0.55 + 0.45 * darkPhase))
          .round()
          .clamp(6, 42);
      paint.color = blended.withAlpha(alpha);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntroParticlePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.warmth != warmth ||
        oldDelegate.darkPhase != darkPhase;
  }
}

class _IntroBasketballPainter extends CustomPainter {
  const _IntroBasketballPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2 * 0.92;
    final rect = Rect.fromCircle(center: c, radius: R);

    // 1. Base sphere with spherical gradient
    final ball = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.36, -0.4),
        radius: 1.06,
        colors: const [
          Color(0xFFFFE8C8), // Highlight
          Color(0xFFE79A52), // Mid-tone
          Color(0xFFB85F1E), // Base
          Color(0xFF5C2E12), // Shadow
        ],
        stops: const [0.0, 0.34, 0.66, 1.0],
      ).createShader(rect);
    canvas.drawCircle(c, R, ball);

    // 2. Subtle pebble texture for leather feel
    final rng = math.Random(42);
    final pebble = Paint()
      ..blendMode = BlendMode.multiply
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 60; i++) {
      final u = rng.nextDouble() * 2 * math.pi;
      final rr = R * math.sqrt(rng.nextDouble()) * 0.94;
      final px = c.dx + rr * math.cos(u);
      final py = c.dy + rr * math.sin(u) * 0.98;
      final pr = 0.5 + rng.nextDouble() * 1.0;
      pebble.color = const Color(0xFF3D2414).withAlpha((15 + rng.nextInt(15)).clamp(5, 40));
      canvas.drawCircle(Offset(px, py), pr, pebble);
    }

    // 3. Ambient occlusion shadow
    final ao = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.12, 0.55),
        radius: 0.92,
        colors: [
          Colors.transparent,
          Colors.black.withAlpha(100),
        ],
        stops: const [0.44, 1.0],
      ).createShader(rect);
    canvas.drawCircle(c, R * 0.99, ao);

    // 4. Seams
    final seam = Paint()
      ..color = const Color(0xFF120800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, size.width * 0.035)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Horizontal equator (slightly curved)
    final eq = Path()
      ..moveTo(c.dx - R * 0.98, c.dy + R * 0.05)
      ..quadraticBezierTo(c.dx, c.dy + R * 0.12, c.dx + R * 0.98, c.dy + R * 0.05);
    canvas.drawPath(eq, seam);

    // Vertical meridian (slightly curved)
    final meridian = Path()
      ..moveTo(c.dx + R * 0.05, c.dy - R * 0.98)
      ..quadraticBezierTo(c.dx + R * 0.12, c.dy, c.dx + R * 0.05, c.dy + R * 0.98);
    canvas.drawPath(meridian, seam);

    // Side channels (Pushed further outwards to look like 🏀 emoji)
    // Left channel
    final left = Path()
      ..moveTo(c.dx - R * 0.3, c.dy - R * 0.92)
      ..cubicTo(
        c.dx - R * 0.85,
        c.dy - R * 0.45,
        c.dx - R * 0.85,
        c.dy + R * 0.45,
        c.dx - R * 0.3,
        c.dy + R * 0.92,
      );
    canvas.drawPath(left, seam);

    // Right channel
    final right = Path()
      ..moveTo(c.dx + R * 0.3, c.dy - R * 0.92)
      ..cubicTo(
        c.dx + R * 0.85,
        c.dy - R * 0.45,
        c.dx + R * 0.85,
        c.dy + R * 0.45,
        c.dx + R * 0.3,
        c.dy + R * 0.92,
      );
    canvas.drawPath(right, seam);

    // 5. Specular glint
    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.55),
        radius: 0.34,
        colors: [
          Colors.white.withAlpha(180),
          Colors.white.withAlpha(0),
        ],
      ).createShader(Rect.fromCircle(center: c.translate(-R * 0.26, -R * 0.3), radius: R * 0.2));
    canvas.drawCircle(c.translate(-R * 0.24, -R * 0.28), R * 0.11, glint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
