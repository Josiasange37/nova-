import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nova/services/agent_service.dart';

class AvatarWidget extends StatefulWidget {
  final ValueNotifier<AvatarState> stateNotifier;

  const AvatarWidget({
    super.key,
    required this.stateNotifier,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _time = 0.0;
  double _mouthOpen = 0.0;
  double _eyeScaleY = 1.0;
  double _nextBlinkTime = 3.0;
  bool _isBlinking = false;
  double _blinkProgress = 0.0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        if (!mounted) return;
        setState(() {
          // Increment animation time (roughly 60 ticks per second)
          _time += 0.016;

          final state = widget.stateNotifier.value;

          // 1. Calculate mouth target open factor
          double targetOpen = 0.0;
          if (state == AvatarState.talking) {
            targetOpen = 0.25 + (sin(_time * 8.5).abs()) * 0.75;
          } else if (state == AvatarState.listening) {
            targetOpen = 0.45;
          } else if (state == AvatarState.thinking) {
            targetOpen = 0.0;
          }

          // Smooth mouth opening interpolation
          _mouthOpen += (targetOpen - _mouthOpen) * 0.18;

          // 2. Random eye blinking logic
          if (_time > _nextBlinkTime && !_isBlinking) {
            _isBlinking = true;
            _blinkProgress = 0.0;
          }

          if (_isBlinking) {
            _blinkProgress += 0.15; // Speed of the blink
            if (_blinkProgress >= 1.0) {
              _isBlinking = false;
              _eyeScaleY = 1.0;
              // Schedule next blink in 3 to 7 seconds
              _nextBlinkTime = _time + 3.0 + _random.nextDouble() * 4.0;
            } else {
              // Sinusoidal blink scaling (goes down to 0.05 and back to 1.0)
              final sineVal = sin(_blinkProgress * pi);
              _eyeScaleY = 1.0 - (sineVal * 0.95);
            }
          }
        });
      })..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AvatarState>(
      valueListenable: widget.stateNotifier,
      builder: (context, state, child) {
        return CustomPaint(
          painter: _AvatarPainter(
            state: state,
            time: _time,
            mouthOpen: _mouthOpen,
            eyeScaleY: _eyeScaleY,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final AvatarState state;
  final double time;
  final double mouthOpen;
  final double eyeScaleY;

  _AvatarPainter({
    required this.state,
    required this.time,
    required this.mouthOpen,
    required this.eyeScaleY,
  });

  void _drawRoundedRect(Canvas canvas, Paint paint, double x, double y, double w, double h, double r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(r),
      ),
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    const double r = 120.0;

    // Sway/breathing translation
    final double bounce = state == AvatarState.talking ? sin(time * 8.5) * 2.5 : 0.0;
    final double breatheY = sin(time * 2.0) * 3.0;

    canvas.save();
    canvas.translate(cx, cy + breatheY + bounce);

    // 1. Glow effect
    final double glowScale = state == AvatarState.talking ? 1.0 + sin(time * 8.5) * 0.04 : 1.0;
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x33A8FFF5), // cyan tint glow
          const Color(0x00A8FFF5),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.6));

    canvas.drawCircle(Offset.zero, r * 1.5 * glowScale, glowPaint);

    // 2. Headset cups and band
    final Paint headsetPaint = Paint()..color = const Color(0xFF4A4DFF);
    _drawRoundedRect(canvas, headsetPaint, -182, -45, 58, 90, 18); // Left cup
    _drawRoundedRect(canvas, headsetPaint, 124, -45, 58, 90, 18);  // Right cup
    _drawRoundedRect(canvas, headsetPaint, -38, 116, 76, 34, 18);  // Connection node / band accent

    // Outer primary connection ring
    final Paint outerRingPaint = Paint()
      ..color = const Color(0xFF4A4DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(Offset.zero, 126, outerRingPaint);

    // 3. Face
    final Paint facePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFBFCFD),
          Color(0xFFEDF1F4),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas.drawCircle(Offset.zero, r, facePaint);

    // Cyan inner accent ring
    final Paint cyanRingPaint = Paint()
      ..color = const Color(0xE6A8FFF5) // rgba(168,255,245,.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset.zero, 118, cyanRingPaint);

    // 4. Eyes
    final Paint eyePaint = Paint()..color = const Color(0xFF5A5EFF);
    
    // Left eye (blinking scaled)
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-35, -12),
        width: 20,
        height: 20 * eyeScaleY,
      ),
      eyePaint,
    );

    // Right eye (blinking scaled)
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(35, -12),
        width: 20,
        height: 20 * eyeScaleY,
      ),
      eyePaint,
    );

    // 5. Mouth Drawing
    final Paint mouthPaint = Paint()
      ..color = const Color(0xFF5A5EFF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (state == AvatarState.talking || state == AvatarState.listening) {
      final double openHeight = 8.0 + mouthOpen * 18.0;
      mouthPaint.strokeWidth = 7;
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0, 30),
          width: (18.0 + mouthOpen * 3.0) * 2, // scale width slightly
          height: openHeight * 2,
        ),
        mouthPaint,
      );
    } else if (state == AvatarState.thinking) {
      // Concentrated straight line
      mouthPaint.strokeWidth = 8;
      canvas.drawLine(
        const Offset(-18, 25),
        const Offset(18, 25),
        mouthPaint,
      );
    } else {
      // Idle smile
      mouthPaint.strokeWidth = 8;
      final Rect mouthRect = Rect.fromCircle(center: const Offset(0, 12), radius: 30);
      canvas.drawArc(mouthRect, 0.2 * pi, 0.6 * pi, false, mouthPaint);
    }

    // 6. Listening Waves
    if (state == AvatarState.listening) {
      final Paint listenPaint = Paint()
        ..color = const Color(0xB3A8FFF5) // rgba(168,255,245,.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      for (int i = 0; i < 3; i++) {
        final double radius = 150.0 + (i * 18.0) + ((time * 40.0) % 18.0);
        canvas.drawCircle(Offset.zero, radius, listenPaint);
      }
    }

    // 7. Thinking Dots
    if (state == AvatarState.thinking) {
      final Paint dotPaint = Paint()..color = const Color(0xFF4A4DFF);
      for (int i = 0; i < 3; i++) {
        final bool active = ((time * 4.0).floor() % 3) == i;
        canvas.drawCircle(
          Offset(-20.0 + i * 20.0, -145.0),
          active ? 7.0 : 5.0,
          dotPaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.time != time ||
        oldDelegate.mouthOpen != mouthOpen ||
        oldDelegate.eyeScaleY != eyeScaleY;
  }
}
