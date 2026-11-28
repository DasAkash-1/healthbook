import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Launch screen shown before the intro screen: a plain white page with the
// caduceus emblem and the "Healthbook" title fading in, and five dots that
// pulse one after another along the bottom.
//
// It moves on to [nextScreen] only when both of these are true:
//   1. [minimumDisplayTime] has passed, so the animation always gets to play.
//   2. [loadTask] (if given) has finished, or [maximumWaitTime] has run out,
//      so a slow or failing task can never leave the user stuck on this screen.
class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final Duration minimumDisplayTime;
  final Duration maximumWaitTime;

  // Work to finish while the splash is showing, such as loading images.
  // It gets the splash's BuildContext (needed for precacheImage).
  final Future<void> Function(BuildContext context)? loadTask;

  const SplashScreen({
    super.key,
    required this.nextScreen,
    this.minimumDisplayTime = const Duration(milliseconds: 2500),
    this.maximumWaitTime = const Duration(seconds: 6),
    this.loadTask,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // One controller runs the whole entrance: logo first, then the title, then the dots.
  late final AnimationController _entranceController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _dotsFade;

  @override
  void initState() {
    super.initState();

    // Allow drawing behind status/navigation bars for a full-bleed splash canvas.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _titleFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );

    _dotsFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    _entranceController.forward();

    // Start the loading check after the first frame, because loading images
    // needs a fully built BuildContext.
    WidgetsBinding.instance.addPostFrameCallback((_) => _waitForAppToLoad());
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // Waits for the minimum display time AND the loading task, then moves on.
  Future<void> _waitForAppToLoad() async {
    if (!mounted) return;

    final minimumTime = Future<void>.delayed(widget.minimumDisplayTime);
    final loading = _runLoadTask().timeout(
      widget.maximumWaitTime,
      onTimeout: () {},
    );

    await Future.wait([minimumTime, loading]);
    if (!mounted) return;
    _goToNextScreen();
  }

  Future<void> _runLoadTask() async {
    final task = widget.loadTask;
    if (task == null) return;
    try {
      await task(context);
    } catch (_) {
      // A failed preload must never stop the app from starting.
    }
  }

  void _goToNextScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Centered emblem and brand title.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Caduceus emblem: fades in while growing slightly.
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/caduceus.png',
                      height: 160,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Brand title, fading in a moment after the emblem.
                FadeTransition(
                  opacity: _titleFade,
                  child: const Text(
                    'Healthbook',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                      color: Color(0xFF102A66),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Five loading dots along the bottom edge.
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _dotsFade,
              child: const _PulsingDots(),
            ),
          ),
        ],
      ),
    );
  }
}

// Row of dots that pulse in turn, so a wave travels from left to right.
class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  static const int _dotCount = 5;
  static const double _dotSize = 10;
  static const double _dotGap = 12;
  static const Color _dotColor = Color(0xFF6688C9);

  // Tweak the look here. Set _minScale and _maxScale both to 1.0 for a
  // fade-only version where the dots do not grow or shrink.
  static const double _minScale = 0.6;
  static const double _maxScale = 1.15;
  static const double _minOpacity = 0.35;

  static const Duration _cycleLength = Duration(milliseconds: 1400);
  static const double _stagger = 0.1; // delay between neighbours, as a share of a cycle
  static const double _activePart = 0.6; // share of a cycle each dot spends pulsing

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycleLength)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    // Each dot is a little behind the one on its left.
    final t = (_controller.value - index * _stagger) % 1.0;
    final wave = t < _activePart ? math.sin(math.pi * t / _activePart) : 0.0;

    final scale = _minScale + (_maxScale - _minScale) * wave;
    final opacity = _minOpacity + (1 - _minOpacity) * wave;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _dotColor.withValues(alpha: opacity),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _dotCount; i++) ...[
              if (i > 0) const SizedBox(width: _dotGap),
              _buildDot(i),
            ],
          ],
        );
      },
    );
  }
}
