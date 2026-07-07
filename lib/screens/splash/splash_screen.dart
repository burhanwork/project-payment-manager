import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final Future<dynamic> initFuture;
  final void Function(dynamic result) onComplete;

  const AnimatedSplashScreen({
    super.key,
    required this.initFuture,
    required this.onComplete,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  // Logo entrance
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // Glow pulse
  late AnimationController _glowController;
  late Animation<double> _glowScale;
  late Animation<double> _glowOpacity;

  // Particle ring
  late AnimationController _ringController;

  // Text
  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  // Exit fade
  late AnimationController _exitController;
  late Animation<double> _exitOpacity;

  // Background shimmer
  late AnimationController _shimmerController;

  dynamic _initResult;
  bool _initDone = false;
  bool _animReady = false;

  @override
  void initState() {
    super.initState();

    // 1. Logo: scale + fade (0 → 800ms)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // 2. Glow pulse (continuous loop, starts after logo)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowOpacity = Tween<double>(begin: 0.3, end: 0.65).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // 3. Rotating particle ring
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    // 4. Text: fade + slide up (starts at 600ms)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // 5. Exit fade
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    // 6. Background shimmer
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _startSequence();

    // Run init in parallel
    widget.initFuture.then((result) {
      _initResult = result;
      _initDone = true;
      _tryComplete();
    });
  }

  Future<void> _startSequence() async {
    // Small delay so native splash fades naturally
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // Logo entrance
    await _logoController.forward();
    if (!mounted) return;

    // Text slides up
    _textController.forward();

    // Minimum display time
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    _animReady = true;
    _tryComplete();
  }

  void _tryComplete() {
    if (!_initDone || !_animReady) return;
    if (!mounted) return;
    _exitController.forward().then((_) {
      if (mounted) widget.onComplete(_initResult);
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    _ringController.dispose();
    _textController.dispose();
    _exitController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitController,
      builder: (context, child) {
        return Opacity(
          opacity: _exitOpacity.value,
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1540),
        body: AnimatedBuilder(
          animation: Listenable.merge([
            _shimmerController,
            _logoController,
            _glowController,
            _ringController,
            _textController,
          ]),
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Animated background gradient ──────────────────────────
                _buildBackground(),

                // ── Particle ring ─────────────────────────────────────────
                Center(child: _buildParticleRing()),

                // ── Glow bloom behind logo ────────────────────────────────
                Center(child: _buildGlowBloom()),

                // ── Logo ──────────────────────────────────────────────────
                Center(child: _buildLogo()),

                // ── App name + tagline ────────────────────────────────────
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: _buildText(),
                ),

                // ── Bottom loader dots ────────────────────────────────────
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: _buildDots(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final shimmer = _shimmerController.value;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.3 + shimmer * 0.15),
          radius: 1.2 + shimmer * 0.3,
          colors: const [
            Color(0xFF1A2B6B),
            Color(0xFF0D1B4B),
            Color(0xFF060D2B),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildGlowBloom() {
    return Transform.scale(
      scale: _glowScale.value,
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4C6EF5).withOpacity(_glowOpacity.value),
              blurRadius: 90,
              spreadRadius: 30,
            ),
            BoxShadow(
              color: const Color(0xFF7B9FFF).withOpacity(_glowOpacity.value * 0.4),
              blurRadius: 140,
              spreadRadius: 60,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticleRing() {
    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(
        painter: _ParticleRingPainter(
          progress: _ringController.value,
          opacity: _logoOpacity.value,
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Transform.scale(
      scale: _logoScale.value,
      child: Opacity(
        opacity: _logoOpacity.value,
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B5BDB).withOpacity(0.6),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Image.asset(
              'assets/images/splash_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildText() {
    return FadeTransition(
      opacity: _textOpacity,
      child: SlideTransition(
        position: _textSlide,
        child: Column(
          children: [
            const Text(
              'Project Payment Manager',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Payment Manager',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDots() {
    return FadeTransition(
      opacity: _textOpacity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final phase = (_shimmerController.value + i / 3) % 1.0;
          final scale = 0.6 + 0.4 * math.sin(phase * math.pi);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.4 + 0.4 * scale),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ParticleRingPainter extends CustomPainter {
  final double progress;
  final double opacity;

  _ParticleRingPainter({required this.progress, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity < 0.05) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const particleCount = 12;

    for (int i = 0; i < particleCount; i++) {
      final angle = (2 * math.pi * i / particleCount) + (progress * 2 * math.pi);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      // Vary size and opacity per particle
      final phase = (progress + i / particleCount) % 1.0;
      final particleOpacity = (0.15 + 0.35 * math.sin(phase * math.pi)) * opacity;
      final particleRadius = 2.5 + 1.5 * math.sin(phase * math.pi);

      final paint = Paint()
        ..color = const Color(0xFF7B9FFF).withOpacity(particleOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), particleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticleRingPainter old) =>
      old.progress != progress || old.opacity != opacity;
}
