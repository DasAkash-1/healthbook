import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final Duration minimumDisplayTime;

  const SplashScreen({
    super.key,
    required this.nextScreen,
    this.minimumDisplayTime = const Duration(milliseconds: 3000),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController.forward();

    _timer = Timer(widget.minimumDisplayTime, () {
      if (!mounted) return;

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
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEFF),
      body: Stack(
        children: [
          // Background grid
          const Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),

          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Heart + ECG logo
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return SizedBox(
                          width: 200,
                          height: 200,
                          child: CustomPaint(
                            painter: _HeartLogoPainter(
                              pulseValue: _pulseAnimation.value,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // App name
                    const Text(
                      'Healthbook',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: Color(0xFF102A66),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Small loading indicator
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LoadingDot(),
                  SizedBox(width: 12),
                  _LoadingDot(),
                  SizedBox(width: 12),
                  _LoadingDot(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingDot extends StatelessWidget {
  const _LoadingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF6688C9),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x226080B8)
      ..strokeWidth = 0.6;

    const double spacing = 20;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeartLogoPainter extends CustomPainter {
  final double pulseValue;

  const _HeartLogoPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double baseRadius = 78;

    // Outer circular ring with pulse
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFAFC8F5).withValues(alpha: 0.8),
          const Color(0xFF416EB5),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: baseRadius * pulseValue),
      );

    canvas.drawCircle(center, baseRadius * pulseValue, circlePaint);

    // Heart paint
    final heartPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF102A66);

    // Centered Heart shape
    final heartPath = Path();
    final heartTop = center.dy - 28;
    
    heartPath.moveTo(center.dx, heartTop + 20);
    // Left curve
    heartPath.cubicTo(
      center.dx - 24, heartTop, 
      center.dx - 40, heartTop + 16, 
      center.dx - 40, heartTop + 36
    );
    // Bottom point
    heartPath.cubicTo(
      center.dx - 40, heartTop + 64, 
      center.dx, heartTop + 84, 
      center.dx, heartTop + 84
    );
    // Right curve
    heartPath.cubicTo(
      center.dx, heartTop + 84, 
      center.dx + 40, heartTop + 64, 
      center.dx + 40, heartTop + 36
    );
    // Back to top
    heartPath.cubicTo(
      center.dx + 40, heartTop + 16, 
      center.dx + 24, heartTop, 
      center.dx, heartTop + 20
    );

    canvas.drawPath(heartPath, heartPaint);

    // ECG line - centered vertically at center.dy
    final ecgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF102A66);

    final ecgPath = Path();
    final ecgY = center.dy + 8; // Slightly below absolute center to sit in heart
    
    ecgPath.moveTo(center.dx - 55, ecgY);
    ecgPath.lineTo(center.dx - 25, ecgY);
    ecgPath.lineTo(center.dx - 18, ecgY + 22); // down
    ecgPath.lineTo(center.dx - 8, ecgY - 12);  // up
    ecgPath.lineTo(center.dx + 2, ecgY + 5);   // small bounce
    ecgPath.lineTo(center.dx + 35, ecgY);
    ecgPath.lineTo(center.dx + 50, ecgY);

    canvas.drawPath(ecgPath, ecgPaint);

    // ECG dots
    final dotPaint = Paint()..color = const Color(0xFF102A66);
    canvas.drawCircle(Offset(center.dx + 58, ecgY), 3.5, dotPaint);
    canvas.drawCircle(Offset(center.dx + 68, ecgY), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _HeartLogoPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue;
  }
}
