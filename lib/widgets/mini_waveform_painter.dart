import 'dart:math' as math;

import 'package:flutter/material.dart';

class MiniWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color waveColor;
  final double strokeWidth; // Will now represent the width of each bar
  final double progressPercent;
  final Color progressColor;
  final Color thumbColor;
  final bool isAnimating;
  final double barSpacing; // Space between bars
  final double barBorderRadius; // Radius for rounded bars

  MiniWaveformPainter({
    required this.waveformData,
    required this.waveColor,
    this.strokeWidth = 3.0, // Default bar width
    this.progressPercent = 0.0,
    Color? progressColor,
    Color? thumbColor,
    required this.isAnimating,
    this.barSpacing = 2.5, // Default spacing
    this.barBorderRadius = 1.5, // Default corner radius
  }) : progressColor = progressColor ?? waveColor.withOpacity(1.0),
       thumbColor = thumbColor ?? (progressColor ?? waveColor.withOpacity(1.0));

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle
          .fill // Fill for bars
      ..isAntiAlias = true;

    final middleY = size.height / 2;
    // Calculate the total width available for bars (considering spacing)
    final double totalBarWidth =
        size.width - (barSpacing * (waveformData.length - 1));
    final double individualBarWidth = math.max(
      1.0,
      totalBarWidth / waveformData.length,
    );

    double timeBasedAnimationFactor = 0.0;
    if (isAnimating) {
      final double phase =
          (DateTime.now().millisecondsSinceEpoch % 1500) / 1500.0;
      timeBasedAnimationFactor = math.sin(phase * 2 * math.pi) * 0.075;
    }

    for (int i = 0; i < waveformData.length; i++) {
      final x = (individualBarWidth + barSpacing) * i;

      double barAmplitude = waveformData[i].clamp(0.05, 1.0);
      // Ensure minimum height for very small amplitudes to keep bars visible
      double minVisualHeight = size.height * 0.05;
      double barHeight = (barAmplitude * size.height * 0.9)
          .clamp(minVisualHeight, size.height * 0.9)
          .abs();

      if (isAnimating) {
        barHeight *= (1 + timeBasedAnimationFactor * barAmplitude);
        barHeight = barHeight.clamp(minVisualHeight, size.height * 0.98);
      }

      final yStart = middleY - barHeight / 2;
      final rect = RRect.fromLTRBR(
        x,
        yStart,
        x + individualBarWidth,
        yStart + barHeight,
        Radius.circular(barBorderRadius),
      );

      final currentXProgressPoint =
          size.width * progressPercent.clamp(0.0, 1.0);
      // A bar is considered "played" if its center is before or at the progress point
      final barCenterX = x + individualBarWidth / 2;

      if (barCenterX <= currentXProgressPoint) {
        paint.color = progressColor;
      } else {
        // If part of the bar is played, draw that part with progressColor
        if (x < currentXProgressPoint) {
          // Draw the played portion
          final RRect playedPortionRect = RRect.fromLTRBR(
            x,
            yStart,
            math.min(x + individualBarWidth, currentXProgressPoint),
            yStart + barHeight,
            Radius.circular(barBorderRadius),
          );
          paint.color = progressColor;
          canvas.drawRRect(playedPortionRect, paint);

          // Draw the unplayed portion if it exists
          if (x + individualBarWidth > currentXProgressPoint) {
            final RRect unplayedPortionRect = RRect.fromLTRBR(
              currentXProgressPoint,
              yStart,
              x + individualBarWidth,
              yStart + barHeight,
              Radius.circular(barBorderRadius),
            );
            paint.color = waveColor.withOpacity(
              0.55,
            ); // Slightly more transparent unplayed part
            canvas.drawRRect(unplayedPortionRect, paint);
          }
          continue; // Skip the main draw for this bar as it's handled
        } else {
          paint.color = waveColor.withOpacity(0.55);
        }
      }
      canvas.drawRRect(rect, paint);
    }

    // Draw a more distinct thumb indicator
    if (progressPercent > 0.0 && progressPercent <= 1.0) {
      final thumbX = size.width * progressPercent.clamp(0.0, 1.0);
      final thumbPaint = Paint()
        ..color = thumbColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      final thumbShadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0)
        ..isAntiAlias = true;

      // Draw a subtle shadow for depth
      canvas.drawCircle(
        Offset(thumbX, middleY),
        strokeWidth * 1.5 + 1,
        thumbShadowPaint,
      );
      // Draw the main thumb
      canvas.drawCircle(Offset(thumbX, middleY), strokeWidth * 1.5, thumbPaint);
      // Optional: add a small border to the thumb
      final thumbBorderPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..isAntiAlias = true;
      canvas.drawCircle(
        Offset(thumbX, middleY),
        strokeWidth * 1.5,
        thumbBorderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MiniWaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.waveColor != waveColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progressPercent != progressPercent ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.thumbColor != thumbColor ||
        oldDelegate.isAnimating != isAnimating ||
        oldDelegate.barSpacing != barSpacing ||
        oldDelegate.barBorderRadius != barBorderRadius;
  }
}
