import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedWaveformPlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final Size size;
  final int barCount;

  const AnimatedWaveformPlayButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.activeColor =
        Colors.blueAccent, // Example: Theme.of(context).colorScheme.primary
    this.inactiveColor = Colors.grey,
    this.size = const Size(
      28,
      28,
    ), // Make it slightly smaller than typical IconButton
    this.barCount = 4,
  });

  @override
  State<AnimatedWaveformPlayButton> createState() =>
      _AnimatedWaveformPlayButtonState();
}

class _AnimatedWaveformPlayButtonState extends State<AnimatedWaveformPlayButton>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.barCount,
      (index) => AnimationController(
        duration: Duration(milliseconds: 300 + (index * 100)), // Vary duration
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.2,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    if (widget.isPlaying) {
      for (var controller in _controllers) {
        controller.repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedWaveformPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        for (var controller in _controllers) {
          controller.repeat(reverse: true);
        }
      } else {
        for (var controller in _controllers) {
          controller.stop();
          // Animate back to a resting state (e.g., all bars at a low, consistent height)
          controller.animateTo(
            0.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isPlaying ? widget.activeColor : widget.inactiveColor;
    final double totalBarWidth =
        widget.size.width * 0.8; // Use 80% of width for bars
    final double individualBarWidth =
        totalBarWidth / (widget.barCount * 2 - 1); // bar width with spacing
    final double spacing = individualBarWidth * 0.5; // Spacing between bars

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size.width,
        height: widget.size.height,
        child: CustomPaint(
          painter: _WaveformButtonPainter(
            animations: _animations,
            color: color,
            barWidth: individualBarWidth,
            spacing: spacing,
            isPlaying: widget.isPlaying,
          ),
        ),
      ),
    );
  }
}

class _WaveformButtonPainter extends CustomPainter {
  final List<Animation<double>> animations;
  final Color color;
  final double barWidth;
  final double spacing;
  final bool isPlaying;

  _WaveformButtonPainter({
    required this.animations,
    required this.color,
    required this.barWidth,
    required this.spacing,
    required this.isPlaying,
  }) : super(
         repaint: Listenable.merge(animations),
       ); // Repaint when any animation ticks

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double totalWidthOfBarsAndSpaces =
        (animations.length * barWidth) + ((animations.length - 1) * spacing);
    double startX = (size.width - totalWidthOfBarsAndSpaces) / 2;

    for (int i = 0; i < animations.length; i++) {
      final animationValue = animations[i].value;
      // When not playing, draw a consistent low bar or a play icon shape
      final barHeight = isPlaying
          ? animationValue *
                size.height *
                0.9 // Use 90% of height for max
          : size.height *
                (0.2 + (i % 2 == 0 ? 0.1 : 0.15)); // Static pattern for paused

      final x = startX + i * (barWidth + spacing);
      final y = (size.height - barHeight) / 2; // Center vertically

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }

    // If not playing, consider drawing a play triangle icon overlay or instead of bars
    if (!isPlaying) {
      final playPath = Path();
      double playIconSize = size.height * 0.5;
      double playIconStartX = (size.width - playIconSize * 0.8) / 2;
      double playIconStartY = (size.height - playIconSize) / 2;

      playPath.moveTo(playIconStartX, playIconStartY);
      playPath.lineTo(playIconStartX, playIconStartY + playIconSize);
      playPath.lineTo(
        playIconStartX + playIconSize * 0.866,
        playIconStartY + playIconSize / 2,
      ); // Equilateral triangle point
      playPath.close();

      final playPaint = Paint()
        ..color = color
            .withOpacity(0.8) // Slightly transparent overlay
        ..style = PaintingStyle.fill;
      // canvas.drawPath(playPath, playPaint); // Option 1: Overlay play icon
      // Option 2: If you want ONLY the play icon when paused, clear the bars above and draw this.
      // For now, the bars have a static pattern when paused.
    }
  }

  @override
  bool shouldRepaint(_WaveformButtonPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isPlaying != isPlaying;
  }
}
