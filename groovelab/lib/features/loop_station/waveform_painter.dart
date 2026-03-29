import 'package:flutter/material.dart';

/// Custom painter that draws a mini waveform visualization for a loop layer.
class WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;
  final double progress;
  final bool showProgress;

  WaveformPainter({
    required this.waveform,
    required this.color,
    this.progress = 0,
    this.showProgress = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final barWidth = size.width / waveform.length;
    final midY = size.height / 2;
    final maxHeight = size.height * 0.9;
    final progressX = size.width * progress;

    final paintBefore = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final paintAfter = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < waveform.length; i++) {
      final x = i * barWidth;
      final amp = waveform[i].clamp(0.0, 1.0);
      final h = (amp * maxHeight / 2).clamp(1.0, maxHeight / 2);

      final paint = (showProgress && x <= progressX) ? paintBefore : paintAfter;

      // Draw symmetric bar
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, midY),
          width: (barWidth * 0.7).clamp(1, 4),
          height: h * 2,
        ),
        const Radius.circular(1),
      );
      canvas.drawRRect(rect, paint);
    }

    // Draw progress line
    if (showProgress && progress > 0) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.showProgress != showProgress ||
        oldDelegate.color != color ||
        oldDelegate.waveform != waveform;
  }
}
