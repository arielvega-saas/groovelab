import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_fonts.dart';
import '../../core/theme.dart';
import '../../models/timing_data.dart';
import '../../models/take.dart';
import '../shared/widgets.dart';

// These providers are imported from app.dart via the parent
// We reference them by their global definitions

/// Mini waveform showing onset amplitudes over time.
class OnsetWaveform extends StatelessWidget {
  final List<NoteOnset> onsets;
  final bool isRecording;

  const OnsetWaveform({
    super.key,
    required this.onsets,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 60),
      painter: _OnsetWaveformPainter(onsets, isRecording),
    );
  }
}

class _OnsetWaveformPainter extends CustomPainter {
  final List<NoteOnset> onsets;
  final bool isRecording;

  _OnsetWaveformPainter(this.onsets, this.isRecording);

  @override
  void paint(Canvas canvas, Size size) {
    if (onsets.isEmpty) return;

    final barWidth = max(2.0, (size.width / max(onsets.length, 1)) - 1);
    final maxBars = (size.width / (barWidth + 1)).floor();
    final displayOnsets = onsets.length > maxBars
        ? onsets.sublist(onsets.length - maxBars)
        : onsets;

    for (var i = 0; i < displayOnsets.length; i++) {
      final onset = displayOnsets[i];
      final x = i * (barWidth + 1);
      final height = onset.amplitude * size.height * 0.9;
      final y = (size.height - height) / 2;

      final color = switch (onset.quality) {
        TimingQuality.green => const Color(0xFF00FF88),
        TimingQuality.yellow => const Color(0xFFFFB020),
        TimingQuality.red => const Color(0xFFFF3B5C),
      };

      // Paint bar with slight alpha fade at the tail
      final frac = i / displayOnsets.length;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.5 + frac * 0.45)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height.clamp(2, size.height)),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }

    // Recording pulse indicator
    if (isRecording) {
      // Glow
      final glow = Paint()
        ..color = AppColors.danger.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(size.width - 8, 8), 7, glow);

      final pulse = Paint()
        ..color = AppColors.danger
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width - 8, 8), 4, pulse);

      // White center dot
      final center = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width - 8, 8), 1.5, center);
    }
  }

  @override
  bool shouldRepaint(covariant _OnsetWaveformPainter old) =>
      old.onsets.length != onsets.length || old.isRecording != isRecording;
}

/// Take list item with score badge and details.
class TakeListItem extends StatelessWidget {
  final Take take;
  final bool isBest;
  final VoidCallback? onTap;

  const TakeListItem({
    super.key,
    required this.take,
    this.isBest = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mins = take.duration.inMinutes.toString().padLeft(2, '0');
    final secs = (take.duration.inSeconds % 60).toString().padLeft(2, '0');
    final scoreCol = take.metrics != null
        ? scoreColor(take.metrics!.consistencyScore)
        : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isBest
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.06),
                    AppColors.bgCard,
                  ],
                )
              : null,
          color: isBest ? null : AppColors.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBest
                ? AppColors.accent.withValues(alpha: 0.35)
                : AppColors.border,
            width: isBest ? 1.2 : 0.8,
          ),
          boxShadow: isBest ? [
            BoxShadow(color: AppColors.accent.withValues(alpha: 0.07), blurRadius: 14),
          ] : [
            const BoxShadow(color: Color(0x20000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // ── Take info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${take.bpm} BPM  ${take.timeSignature}  $mins:$secs',
                        style: AppTheme.monoStyle(size: 12),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.accent2],
                            ),
                          ),
                          child: Text('BEST', style: AppFonts.outfit(
                            fontSize: 8, fontWeight: FontWeight.w800,
                            color: AppColors.bgDeepest, letterSpacing: 1,
                          )),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${take.onsets.length} notes',
                        style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                      ),
                      if (take.metrics != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(width: 1, height: 10, color: AppColors.border),
                        ),
                        Text(
                          '${take.metrics!.averageDeviationMs.abs().toStringAsFixed(1)}ms '
                          '${take.metrics!.averageDeviationMs < 0 ? "early" : "late"}',
                          style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(width: 1, height: 10, color: AppColors.border),
                        ),
                        Text(
                          take.metrics!.driftDirection,
                          style: AppFonts.outfit(
                            fontSize: 11,
                            color: take.metrics!.driftDirection == 'steady'
                                ? AppColors.accent2
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Mini quality bar
                  if (take.metrics != null && take.metrics!.totalNotes > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 5,
                        child: Row(
                          children: [
                            if (take.metrics!.greenNotes > 0)
                              Expanded(
                                flex: take.metrics!.greenNotes,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF00CC6A), Color(0xFF00FF88)],
                                    ),
                                  ),
                                ),
                              ),
                            if (take.metrics!.yellowNotes > 0)
                              Expanded(
                                flex: take.metrics!.yellowNotes,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFDD9010), Color(0xFFFFB020)],
                                    ),
                                  ),
                                ),
                              ),
                            if (take.metrics!.redNotes > 0)
                              Expanded(
                                flex: take.metrics!.redNotes,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFCC1A3A), Color(0xFFFF3B5C)],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Score badge ──
            if (take.metrics != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scoreCol.withValues(alpha: 0.14),
                      scoreCol.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: scoreCol.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(color: scoreCol.withValues(alpha: 0.12), blurRadius: 10),
                  ],
                ),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [scoreCol, scoreCol.withValues(alpha: 0.75)],
                      ).createShader(bounds),
                      child: Text(
                        '${take.metrics!.consistencyScore}',
                        style: AppTheme.monoStyle(
                          size: 22, weight: FontWeight.w800, color: Colors.white,
                        ),
                      ),
                    ),
                    Text('score', style: AppFonts.outfit(
                      fontSize: 8, color: AppColors.textMuted, fontWeight: FontWeight.w500,
                    )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Deviation distribution chart showing timing spread.
class DeviationChart extends StatelessWidget {
  final List<NoteOnset> onsets;

  const DeviationChart({super.key, required this.onsets});

  @override
  Widget build(BuildContext context) {
    if (onsets.isEmpty) return const SizedBox.shrink();

    // Build histogram: -50ms to +50ms in 5ms buckets
    final buckets = List<int>.filled(21, 0); // -50 to +50 in 5ms steps
    for (final onset in onsets) {
      final idx = ((onset.deviationMs + 50) / 5).round().clamp(0, 20);
      buckets[idx]++;
    }
    final maxCount = buckets.reduce(max).clamp(1, 999999);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 3, height: 12,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.accent, AppColors.accent2],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 5)],
                ),
              ),
              Text('DEVIATION SPREAD', style: AppFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 1.8,
              )),
            ],
          ),
          const SizedBox(height: 12),

          // ── Histogram bars ──
          SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(21, (i) {
                final height = (buckets[i] / maxCount) * 56;
                final ms = (i * 5) - 50;
                final bool isCenter = ms.abs() < 5;
                final Color barColor;
                if (ms.abs() < 10) {
                  barColor = const Color(0xFF00FF88);
                } else if (ms.abs() < 30) {
                  barColor = const Color(0xFFFFB020);
                } else {
                  barColor = const Color(0xFFFF3B5C);
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Ghost bar (background)
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.bgInput.withValues(alpha: 0.5),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                          ),
                        ),
                        // Active bar
                        if (height > 0)
                          AnimatedContainer(
                            duration: Duration(milliseconds: 300 + i * 15),
                            curve: Curves.easeOut,
                            height: height.clamp(1, 56),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  barColor.withValues(alpha: 0.6),
                                  barColor.withValues(alpha: isCenter ? 1.0 : 0.85),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                              boxShadow: isCenter ? [
                                BoxShadow(color: barColor.withValues(alpha: 0.4), blurRadius: 6),
                              ] : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── Center line marker ──
          SizedBox(
            height: 14,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 1, height: 8,
                    color: AppColors.accent.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // ── X axis labels ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('-50ms', style: AppTheme.monoStyle(size: 8, color: AppColors.textMuted)),
              Text('0', style: AppTheme.monoStyle(size: 9, color: AppColors.accent, weight: FontWeight.w700)),
              Text('+50ms', style: AppTheme.monoStyle(size: 8, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
