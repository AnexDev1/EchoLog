import 'package:flutter/material.dart';
import 'dart:ui'
    as ui; // For potential future use with shaders or advanced drawing
import 'dart:math' as math; // For placeholder data generation if needed

class MiniWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color waveColor; // Base color for the unplayed part
  final double strokeWidth;
  final double progressPercent; // Playback progress from 0.0 to 1.0
  final Color progressColor; // Color for the played part of the waveform
  final Color thumbColor; // Color for the progress indicator thumb

  MiniWaveformPainter({
    required this.waveformData,
    required this.waveColor,
    this.strokeWidth = 1.5,
    this.progressPercent = 0.0, // Default to 0 if not playing or no progress
    Color? progressColor,
    Color? thumbColor,
  }) : progressColor =
           progressColor ??
           waveColor.withOpacity(1.0), // Make progress part more solid/distinct
       thumbColor = thumbColor ?? (progressColor ?? waveColor.withOpacity(1.0));

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap
          .round // Makes the ends of the lines rounded
      ..style = PaintingStyle.stroke;

    final middleY = size.height / 2;
    final double barWidth =
        size.width / waveformData.length; // Width of each bar in the waveform

    Path unplayedPath = Path();
    Path playedPath = Path();

    for (int i = 0; i < waveformData.length; i++) {
      final x = barWidth * i + barWidth / 2; // Center x-coordinate for the bar

      // Normalize and scale bar height, ensuring a minimum visible height
      // waveformData[i] is expected to be between 0.0 and 1.0
      final barHeight = (waveformData[i].clamp(0.05, 1.0) * size.height * 0.9)
          .abs();
      final yStart = middleY - barHeight / 2;
      final yEnd = middleY + barHeight / 2;

      // Determine if this bar is part of the played portion
      final currentXProgressPoint =
          size.width * progressPercent.clamp(0.0, 1.0);

      if (x <= currentXProgressPoint) {
        playedPath.moveTo(x, yStart);
        playedPath.lineTo(x, yEnd);
      } else {
        unplayedPath.moveTo(x, yStart);
        unplayedPath.lineTo(x, yEnd);
      }
    }

    // Draw the unplayed part of the wave
    paint.color = waveColor.withOpacity(0.65); // Typically less prominent
    canvas.drawPath(unplayedPath, paint);

    // Draw the played part of the wave
    paint.color =
        progressColor; // Typically more prominent or the main mood color
    canvas.drawPath(playedPath, paint);

    // Draw a small thumb indicator if progress is between 0 and 1 (exclusive)
    if (progressPercent > 0.0 && progressPercent < 1.0) {
      final thumbX = size.width * progressPercent.clamp(0.0, 1.0);
      final thumbPaint = Paint()
        ..color = thumbColor
        ..style = PaintingStyle.fill; // Fill the circle for the thumb
      // Draw a circle as the thumb. Adjust radius as needed.
      canvas.drawCircle(Offset(thumbX, middleY), strokeWidth * 1.8, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MiniWaveformPainter oldDelegate) {
    // Repaint if any of these properties change
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.waveColor != waveColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progressPercent != progressPercent ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.thumbColor != thumbColor;
  }
}
