import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../song_lab_models.dart';

// ===================================================================
//  WAVEFORM PAINTER — CustomPainter for audio waveform visualization
//  Enhanced: gradient bars, glow playhead, loop overlay, grid lines
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

    // ── Subtle horizontal grid lines ──
    _drawGridLines(canvas, w, h, centerY);

    // ── Draw A-B loop region overlay ──
    if (loopRegion != null && duration > 0) {
      final aX = (loopRegion!.startTime / duration) * w;
      final bX = (loopRegion!.endTime / duration) * w;

      // Loop region translucent overlay
      canvas.drawRect(
        Rect.fromLTRB(aX, 0, bX, h),
        Paint()..color = loopColorA.withValues(alpha: 0.12),
      );

      // Subtle top/bottom edge highlights for the loop region
      canvas.drawRect(
        Rect.fromLTRB(aX, 0, bX, 1.5),
        Paint()..color = loopColorA.withValues(alpha: 0.35),
      );
      canvas.drawRect(
        Rect.fromLTRB(aX, h - 1.5, bX, h),
        Paint()..color = loopColorB.withValues(alpha: 0.35),
      );

      // A marker line with glow
      canvas.drawLine(
        Offset(aX, 0),
        Offset(aX, h),
        Paint()
          ..color = loopColorA.withValues(alpha: 0.25)
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawLine(
        Offset(aX, 0),
        Offset(aX, h),
        Paint()
          ..color = loopColorA
          ..strokeWidth = 2,
      );

      // B marker line with glow
      canvas.drawLine(
        Offset(bX, 0),
        Offset(bX, h),
        Paint()
          ..color = loopColorB.withValues(alpha: 0.25)
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
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

    // ── Draw waveform bars with vertical gradient ──
    if (waveform.isNotEmpty) {
      _drawGradientBars(canvas, w, h, centerY, waveform, 0.8);
    } else {
      // Placeholder waveform (generated)
      const barCount = 200;
      final rng = math.Random(42);
      final placeholderWaveform = List.generate(barCount, (i) => 0.2 + rng.nextDouble() * 0.6);
      _drawGradientBars(canvas, w, h, centerY, placeholderWaveform, 0.6);
    }

    // Center line
    canvas.drawLine(
      Offset(0, centerY),
      Offset(w, centerY),
      Paint()
        ..color = accentColor.withValues(alpha: 0.15)
        ..strokeWidth = 0.5,
    );

    // ── Playback position line with glow effect ──
    if (position > 0) {
      final posX = position * w;

      // Outer glow (4px color blur behind)
      canvas.drawLine(
        Offset(posX, 0),
        Offset(posX, h),
        Paint()
          ..color = accentColor.withValues(alpha: 0.25)
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Inner glow
      canvas.drawLine(
        Offset(posX, 0),
        Offset(posX, h),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Crisp white playhead line (1px)
      canvas.drawLine(
        Offset(posX, 0),
        Offset(posX, h),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..strokeWidth = 1.0,
      );

      // Top triangle indicator
      final trianglePath = Path()
        ..moveTo(posX - 4, 0)
        ..lineTo(posX + 4, 0)
        ..lineTo(posX, 6)
        ..close();
      canvas.drawPath(trianglePath, Paint()..color = accentColor);

      // Bottom triangle indicator (mirror)
      final bottomTriPath = Path()
        ..moveTo(posX - 4, h)
        ..lineTo(posX + 4, h)
        ..lineTo(posX, h - 6)
        ..close();
      canvas.drawPath(bottomTriPath, Paint()..color = accentColor.withValues(alpha: 0.6));
    }
  }

  /// Draws subtle horizontal grid lines for visual reference.
  void _drawGridLines(Canvas canvas, double w, double h, double centerY) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    // Draw grid lines at 25%, 50% (center), and 75% height
    final gridPositions = [
      centerY - h * 0.25,
      centerY - h * 0.125,
      centerY,
      centerY + h * 0.125,
      centerY + h * 0.25,
    ];

    for (final y in gridPositions) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  /// Draws waveform bars with a vertical gradient (dark at bottom, accent at top).
  void _drawGradientBars(
    Canvas canvas,
    double w,
    double h,
    double centerY,
    List<double> data,
    double maxHeightFactor,
  ) {
    final barCount = data.length;
    final barWidth = w / barCount;
    final maxBarHeight = h * maxHeightFactor;
    final playX = position * w;

    // Build darker variant of accent for gradient bottom
    final darkAccent = Color.lerp(
      const Color(0xFF0A0A0A),
      accentColor,
      0.3,
    )!;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth;
      final amplitude = data[i].clamp(0.0, 1.0);
      final barH = amplitude * maxBarHeight;
      final isPast = x < playX;
      final alpha = isPast ? 0.85 : 0.25;

      // Upper bar — gradient from center (dark) to top (accent)
      final upperRect = Rect.fromLTWH(x + 1, centerY - barH / 2, barWidth - 2, barH / 2);
      if (barH > 0) {
        final upperShader = ui.Gradient.linear(
          Offset(x, centerY),
          Offset(x, centerY - barH / 2),
          [
            darkAccent.withValues(alpha: alpha * 0.6),
            accentColor.withValues(alpha: alpha),
          ],
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(upperRect, const Radius.circular(1)),
          Paint()..shader = upperShader,
        );
      }

      // Lower bar (mirror) — gradient from center (dark) to bottom (accent)
      final lowerRect = Rect.fromLTWH(x + 1, centerY, barWidth - 2, barH / 2);
      if (barH > 0) {
        final lowerShader = ui.Gradient.linear(
          Offset(x, centerY),
          Offset(x, centerY + barH / 2),
          [
            darkAccent.withValues(alpha: alpha * 0.6),
            accentColor.withValues(alpha: alpha),
          ],
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(lowerRect, const Radius.circular(1)),
          Paint()..shader = lowerShader,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SongLabWaveformPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.waveform != waveform ||
        oldDelegate.loopRegion != loopRegion ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.duration != duration;
  }
}
