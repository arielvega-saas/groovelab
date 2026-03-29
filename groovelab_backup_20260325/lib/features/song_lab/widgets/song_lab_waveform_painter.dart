import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../song_lab_models.dart';

// ===================================================================
//  WAVEFORM PAINTER — CustomPainter for audio waveform visualization
// ===================================================================

class SongLabWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double position;
  final LoopRegion? loopRegion;
  final double duration;
  final Color accentColor;
  final Color loopColorA;
  final Color loopColorB;

  SongLabWaveformPainter({
    required this.waveform,
    required this.position,
    this.loopRegion,
    required this.duration,
    required this.accentColor,
    required this.loopColorA,
    required this.loopColorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerY = h / 2;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = AppColors.bgInset,
    );

    // Draw A-B loop region
    if (loopRegion != null && duration > 0) {
      final aX = (loopRegion!.startTime / duration) * w;
      final bX = (loopRegion!.endTime / duration) * w;

      // Loop region fill
      canvas.drawRect(
        Rect.fromLTRB(aX, 0, bX, h),
        Paint()..color = loopColorA.withValues(alpha: 0.08),
      );

      // A marker line
      canvas.drawLine(
        Offset(aX, 0),
        Offset(aX, h),
        Paint()
          ..color = loopColorA
          ..strokeWidth = 2,
      );

      // B marker line
      canvas.drawLine(
        Offset(bX, 0),
        Offset(bX, h),
        Paint()
          ..color = loopColorB
          ..strokeWidth = 2,
      );

      // A label
      final aPainter = TextPainter(
        text: TextSpan(
          text: 'A',
          style: TextStyle(
            color: loopColorA,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      aPainter.paint(canvas, Offset(aX + 3, 2));

      // B label
      final bPainter = TextPainter(
        text: TextSpan(
          text: 'B',
          style: TextStyle(
            color: loopColorB,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      bPainter.paint(canvas, Offset(bX - 12, 2));
    }

    // Draw waveform bars
    if (waveform.isNotEmpty) {
      final barCount = waveform.length;
      final barWidth = w / barCount;
      final maxBarHeight = h * 0.8;
      final playX = position * w;

      for (int i = 0; i < barCount; i++) {
        final x = i * barWidth;
        final amplitude = waveform[i].clamp(0.0, 1.0);
        final barH = amplitude * maxBarHeight;
        final isPast = x < playX;

        final paint = Paint()
          ..color = isPast
              ? accentColor.withValues(alpha: 0.85)
              : accentColor.withValues(alpha: 0.25);

        // Upper bar
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 1, centerY - barH / 2, barWidth - 2, barH / 2),
            const Radius.circular(1),
          ),
          paint,
        );

        // Lower bar (mirror)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 1, centerY, barWidth - 2, barH / 2),
            const Radius.circular(1),
          ),
          paint,
        );
      }
    } else {
      // Placeholder waveform (generated)
      final barCount = 200;
      final barWidth = w / barCount;
      final maxBarHeight = h * 0.6;
      final playX = position * w;
      final rng = math.Random(42);

      for (int i = 0; i < barCount; i++) {
        final x = i * barWidth;
        final amplitude = 0.2 + rng.nextDouble() * 0.6;
        final barH = amplitude * maxBarHeight;
        final isPast = x < playX;

        final paint = Paint()
          ..color = isPast
              ? accentColor.withValues(alpha: 0.7)
              : accentColor.withValues(alpha: 0.2);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 0.5, centerY - barH / 2, barWidth - 1, barH / 2),
            const Radius.circular(1),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 0.5, centerY, barWidth - 1, barH / 2),
            const Radius.circular(1),
          ),
          paint,
        );
      }
    }

    // Center line
    canvas.drawLine(
      Offset(0, centerY),
      Offset(w, centerY),
      Paint()
        ..color = accentColor.withValues(alpha: 0.15)
        ..strokeWidth = 0.5,
    );

    // Playback position line
    if (position > 0) {
      final posX = position * w;

      // Glow
      canvas.drawLine(
        Offset(posX, 0),
        Offset(posX, h),
        Paint()
          ..color = accentColor.withValues(alpha: 0.3)
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Main line
      canvas.drawLine(
        Offset(posX, 0),
        Offset(posX, h),
        Paint()
          ..color = accentColor
          ..strokeWidth = 2,
      );

      // Top triangle indicator
      final trianglePath = Path()
        ..moveTo(posX - 4, 0)
        ..lineTo(posX + 4, 0)
        ..lineTo(posX, 6)
        ..close();
      canvas.drawPath(trianglePath, Paint()..color = accentColor);
    }
  }

  @override
  bool shouldRepaint(covariant SongLabWaveformPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.waveform != waveform ||
        oldDelegate.loopRegion != loopRegion ||
        oldDelegate.accentColor != accentColor;
  }
}
