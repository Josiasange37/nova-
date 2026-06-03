import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nova/services/agent_service.dart';
import 'package:nova/ui/avatar_widget.dart';
import 'package:nova/ui/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // The avatar state notifier for the AvatarWidget
  final ValueNotifier<AvatarState> _avatarState =
      ValueNotifier(AvatarState.idle);

  // Phase controller: drives the whole splash sequence
  late AnimationController _phaseController;

  // Floating bob animation (continuous gentle float)
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Glow pulse animation
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Particle animation
  late AnimationController _particleController;

  // ── Phase animations (all driven by _phaseController) ──

  // Phase 1: Avatar slides in from right, peeking
  late Animation<double> _peekSlideX;
  late Animation<double> _peekScale;
  late Animation<double> _peekRotation;

  // Phase 2: Avatar fully enters center
  late Animation<double> _enterSlideX;
  late Animation<double> _enterScale;
  late Animation<double> _enterRotation;

  // Phase 3: "Hello!" text fade in & scale
  late Animation<double> _helloOpacity;
  late Animation<double> _helloScale;

  // Phase 4: Float up slightly & settle
  late Animation<double> _floatUpY;

  // Phase 5: Exit – avatar shrinks & fades, background transitions
  late Animation<double> _exitScale;
  late Animation<double> _exitOpacity;

  // Background & Nova text
  late Animation<double> _bgOpacity;
  late Animation<double> _novaTextOpacity;
  late Animation<double> _novaTextScale;
  late Animation<double> _subtitleOpacity;

  // Particle system
  final List<_Particle> _particles = [];
  final Random _random = Random();

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initParticles();

    // ── Float controller (loops forever for gentle bob) ──
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // ── Glow pulse ──
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // ── Particle controller ──
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )
      ..addListener(() {
        if (mounted) setState(() => _updateParticles());
      })
      ..repeat();

    // ── Main phase controller (total ~4.5 seconds) ──
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    // Phase 1 (0% → 18%): Peek from right edge
    _peekSlideX = Tween<double>(begin: 1.5, end: 0.6).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOutBack),
      ),
    );
    _peekScale = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
      ),
    );
    _peekRotation = Tween<double>(begin: -0.15, end: 0.08).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
      ),
    );

    // Phase 2 (18% → 38%): Slide to center, grow to full size
    _enterSlideX = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.18, 0.38, curve: Curves.easeOutCubic),
      ),
    );
    _enterScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.18, 0.38, curve: Curves.elasticOut),
      ),
    );
    _enterRotation = Tween<double>(begin: 0.08, end: 0.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.18, 0.38, curve: Curves.easeOut),
      ),
    );

    // Phase 3 (38% → 55%): Hello text appears
    _helloOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.38, 0.50, curve: Curves.easeIn),
      ),
    );
    _helloScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.38, 0.55, curve: Curves.elasticOut),
      ),
    );

    // Phase 4 (55% → 70%): Gentle float up
    _floatUpY = Tween<double>(begin: 0.0, end: -20.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.55, 0.70, curve: Curves.easeInOut),
      ),
    );

    // Nova text & subtitle
    _novaTextOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.20, 0.40, curve: Curves.easeIn),
      ),
    );
    _novaTextScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.20, 0.45, curve: Curves.elasticOut),
      ),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.45, 0.60, curve: Curves.easeIn),
      ),
    );

    // Phase 5 (78% → 100%): Exit animation
    _exitScale = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.78, 1.0, curve: Curves.easeInBack),
      ),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );
    _bgOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _phaseController,
        curve: const Interval(0.88, 1.0, curve: Curves.easeIn),
      ),
    );

    // Listen for phase changes to update avatar state
    _phaseController.addListener(_onPhaseProgress);
    _phaseController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _navigated = true;
        _navigateToHome();
      }
    });

    // Start the animation sequence
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _phaseController.forward();
    });
  }

  void _initParticles() {
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3.0 + 1.0,
        speedX: (_random.nextDouble() - 0.5) * 0.002,
        speedY: -_random.nextDouble() * 0.003 - 0.001,
        opacity: _random.nextDouble() * 0.5 + 0.1,
        color: _random.nextBool()
            ? const Color(0xFF388BFD)
            : const Color(0xFFA8FFF5),
      ));
    }
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.x += p.speedX;
      p.y += p.speedY;
      if (p.y < -0.05) {
        p.y = 1.05;
        p.x = _random.nextDouble();
      }
      if (p.x < -0.05) p.x = 1.05;
      if (p.x > 1.05) p.x = -0.05;
    }
  }

  void _onPhaseProgress() {
    final progress = _phaseController.value;

    // Update avatar expression based on animation phase
    if (progress < 0.38) {
      // Entering — idle/curious look
      _avatarState.value = AvatarState.idle;
    } else if (progress < 0.55) {
      // Saying hello — talking animation
      _avatarState.value = AvatarState.talking;
    } else if (progress < 0.78) {
      // Floating — back to idle with smile
      _avatarState.value = AvatarState.idle;
    } else {
      // Exiting
      _avatarState.value = AvatarState.idle;
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.05, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _phaseController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    _avatarState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _phaseController,
          _floatController,
          _glowController,
        ]),
        builder: (context, _) {
          final progress = _phaseController.value;

          // Calculate composite transforms
          double slideX;
          double scale;
          double rotation;

          if (progress < 0.18) {
            slideX = _peekSlideX.value;
            scale = _peekScale.value;
            rotation = _peekRotation.value;
          } else if (progress < 0.38) {
            slideX = _enterSlideX.value;
            scale = _enterScale.value;
            rotation = _enterRotation.value;
          } else {
            slideX = 0.0;
            scale = 1.0;
            rotation = 0.0;
          }

          // Apply exit transforms
          if (progress > 0.78) {
            scale *= _exitScale.value;
          }

          // Float offset
          final floatY = _floatUpY.value +
              (progress > 0.38 && progress < 0.78
                  ? _floatAnimation.value
                  : 0.0);

          final contentOpacity =
              progress > 0.85 ? _exitOpacity.value : 1.0;
          final bgOpacity = progress > 0.88 ? _bgOpacity.value : 1.0;

          return Opacity(
            opacity: bgOpacity,
            child: Stack(
              children: [
                // ── Background gradient ──
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.0, -0.3),
                      radius: 1.2,
                      colors: [
                        Color(0xFF141D2B),
                        Color(0xFF0D1117),
                        Color(0xFF080B0F),
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                ),

                // ── Floating particles ──
                ...List.generate(_particles.length, (i) {
                  final p = _particles[i];
                  return Positioned(
                    left: p.x * screenSize.width,
                    top: p.y * screenSize.height,
                    child: Container(
                      width: p.size,
                      height: p.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.color.withOpacity(p.opacity * bgOpacity),
                      ),
                    ),
                  );
                }),

                // ── Center glow ──
                Center(
                  child: Transform.translate(
                    offset: Offset(0, floatY - 40),
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF388BFD)
                                .withOpacity(0.12 * _glowAnimation.value),
                            blurRadius: 120,
                            spreadRadius: 40,
                          ),
                          BoxShadow(
                            color: const Color(0xFFA8FFF5)
                                .withOpacity(0.06 * _glowAnimation.value),
                            blurRadius: 80,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Avatar + Hello text ──
                Opacity(
                  opacity: contentOpacity,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar
                        Transform.translate(
                          offset: Offset(
                            slideX * screenSize.width * 0.5,
                            floatY,
                          ),
                          child: Transform.scale(
                            scale: scale,
                            child: Transform.rotate(
                              angle: rotation,
                              child: SizedBox(
                                width: 240,
                                height: 240,
                                child: AvatarWidget(
                                  stateNotifier: _avatarState,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // "Hello!" greeting text
                        Transform.translate(
                          offset: Offset(0, floatY * 0.5),
                          child: Opacity(
                            opacity: _helloOpacity.value * contentOpacity,
                            child: Transform.scale(
                              scale: _helloScale.value,
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFFA8FFF5),
                                    Color(0xFF388BFD),
                                    Color(0xFF8B5CF6),
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'Hello! 👋',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Nova title text
                        Opacity(
                          opacity:
                              _novaTextOpacity.value * contentOpacity,
                          child: Transform.scale(
                            scale: _novaTextScale.value,
                            child: ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                colors: [
                                  Color(0xFF388BFD),
                                  Color(0xFF8B5CF6),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'NOVA',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 12.0,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subtitle
                        Opacity(
                          opacity:
                              _subtitleOpacity.value * contentOpacity,
                          child: const Text(
                            'Your Intelligent Mobile Agent',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF8B949E),
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Bottom loading indicator ──
                if (progress < 0.85)
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: (progress > 0.40 ? 1.0 : 0.0) *
                          (progress > 0.78
                              ? (1.0 - ((progress - 0.78) / 0.07)
                                      .clamp(0.0, 1.0))
                              : 1.0),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ((progress - 0.40) / 0.38)
                                    .clamp(0.0, 1.0),
                                backgroundColor:
                                    const Color(0xFF21262D),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF388BFD),
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Initializing...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6E7681),
                              letterSpacing: 1.0,
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
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  double opacity;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.color,
  });
}
