import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../app_fonts.dart';

// ═══════════════════════════════════════════════════════════════
//  PREMIUM CONTROLS — Reusable pro-audio UI widgets
//
//  PremiumKnob      Rotary encoder with neumorphic arc & pointer
//  LEDIndicator     Glowing LED dot with optional pulse
//  VUMeter          Segmented level meter (green/amber/red)
//  GlowingIconButton  Icon button with halo glow
//  PremiumToggle    Hardware-style rocker toggle switch
// ═══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
//  1. PremiumKnob
// ─────────────────────────────────────────────────────────────

class PremiumKnob extends StatefulWidget {
  const PremiumKnob({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 60,
    this.color = AppColors.accent,
    this.label,
    this.valueText,
    this.minAngle = -140,
    this.maxAngle = 140,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double size;
  final Color color;
  final String? label;
  final String? valueText;
  final double minAngle;
  final double maxAngle;

  @override
  State<PremiumKnob> createState() => _PremiumKnobState();
}

class _PremiumKnobState extends State<PremiumKnob> {
  double _dragStartValue = 0;

  void _onPanStart(DragStartDetails details) {
    _dragStartValue = widget.value;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Vertical drag: up = increase, down = decrease
    // Horizontal drag: right = increase, left = decrease
    final delta = (-details.delta.dy + details.delta.dx) / (widget.size * 2);
    final newValue = (_dragStartValue + delta).clamp(0.0, 1.0);
    _dragStartValue = newValue;
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _PremiumKnobPainter(
                value: widget.value,
                color: widget.color,
                minAngle: widget.minAngle,
                maxAngle: widget.maxAngle,
              ),
            ),
          ),
        ),
        if (widget.valueText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.valueText!,
            style: AppFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: widget.color,
            ),
          ),
        ],
        if (widget.label != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.label!,
            style: AppFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _PremiumKnobPainter extends CustomPainter {
  _PremiumKnobPainter({
    required this.value,
    required this.color,
    required this.minAngle,
    required this.maxAngle,
  });

  final double value;
  final Color color;
  final double minAngle;
  final double maxAngle;

  static const double _deg2rad = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final outerRingRadius = radius * 0.92;
    final knobRadius = radius * 0.65;
    final tickRadius = radius * 0.82;
    final pointerStart = knobRadius * 0.3;
    final pointerEnd = knobRadius * 0.85;

    // Convert angle range — 0 deg = top (12 o'clock)
    // Canvas rotation: 0 is 3 o'clock, so offset by -90
    final startRad = (minAngle - 90) * _deg2rad;
    final endRad = (maxAngle - 90) * _deg2rad;
    final sweepTotal = endRad - startRad;
    final currentRad = startRad + sweepTotal * value;

    // ── Outer ring shadow (neumorphic) ──
    final darkShadow = Paint()
      ..color = const Color(0xFF181818)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center + const Offset(2, 2), outerRingRadius, darkShadow);

    final lightShadow = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center + const Offset(-2, -2), outerRingRadius, lightShadow);

    // ── Outer ring background ──
    final outerRingPaint = Paint()
      ..color = AppColors.bgInset
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12;
    canvas.drawCircle(center, outerRingRadius, outerRingPaint);

    // ── Tick marks ──
    final tickPaint = Paint()
      ..color = AppColors.textMuted
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    const tickStep = 30.0;
    for (double deg = minAngle; deg <= maxAngle; deg += tickStep) {
      final rad = (deg - 90) * _deg2rad;
      final inner = center + Offset(math.cos(rad) * (tickRadius - 3), math.sin(rad) * (tickRadius - 3));
      final outer = center + Offset(math.cos(rad) * (tickRadius + 3), math.sin(rad) * (tickRadius + 3));
      canvas.drawLine(inner, outer, tickPaint);
    }

    // ── Active arc with glow ──
    final arcRect = Rect.fromCircle(center: center, radius: outerRingRadius);
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.14
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawArc(arcRect, startRad, sweepTotal * value, false, glowPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, startRad, sweepTotal * value, false, arcPaint);

    // ── Center knob ──
    final knobGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: [
        AppColors.bgPanel.withValues(alpha: 1),
        AppColors.bgElevated,
        AppColors.bgPanel,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final knobPaint = Paint()
      ..shader = knobGradient.createShader(
        Rect.fromCircle(center: center, radius: knobRadius),
      );
    canvas.drawCircle(center, knobRadius, knobPaint);

    // Knob edge highlight
    final edgePaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawCircle(center, knobRadius, edgePaint);

    // ── Pointer indicator ──
    final pointerPaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final pStart = center + Offset(
      math.cos(currentRad) * pointerStart,
      math.sin(currentRad) * pointerStart,
    );
    final pEnd = center + Offset(
      math.cos(currentRad) * pointerEnd,
      math.sin(currentRad) * pointerEnd,
    );
    canvas.drawLine(pStart, pEnd, pointerPaint);
  }

  @override
  bool shouldRepaint(_PremiumKnobPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.minAngle != minAngle ||
      oldDelegate.maxAngle != maxAngle;
}

// ─────────────────────────────────────────────────────────────
//  2. LEDIndicator
// ─────────────────────────────────────────────────────────────

class LEDIndicator extends StatelessWidget {
  const LEDIndicator({
    super.key,
    this.color = AppColors.accent,
    this.size = 8,
    this.active = true,
    this.pulse = false,
    this.pulseController,
  });

  final Color color;
  final double size;
  final bool active;
  final bool pulse;
  final AnimationController? pulseController;

  @override
  Widget build(BuildContext context) {
    Widget led = _buildLED();

    if (pulse && active && pulseController != null) {
      final animation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: pulseController!, curve: Curves.easeInOut),
      );
      led = AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Opacity(opacity: animation.value, child: child);
        },
        child: _buildLED(),
      );
    }

    return led;
  }

  Widget _buildLED() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : AppColors.bgInset,
        border: active
            ? null
            : Border.all(color: AppColors.border, width: 0.5),
        boxShadow: active
            ? [AppColors.ledGlow(color)]
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  3. VUMeter
// ─────────────────────────────────────────────────────────────

class VUMeter extends StatelessWidget {
  const VUMeter({
    super.key,
    required this.level,
    this.segments = 12,
    this.width = 8,
    this.height = 60,
    this.horizontal = false,
    this.lowColor,
    this.midColor,
    this.highColor,
  });

  final double level;
  final int segments;
  final double width;
  final double height;
  final bool horizontal;
  final Color? lowColor;
  final Color? midColor;
  final Color? highColor;

  Color _segmentColor(int index) {
    final ratio = index / segments;
    if (ratio < 0.6) return lowColor ?? const Color(0xFF00FF11);
    if (ratio < 0.8) return midColor ?? const Color(0xFFFFBF00);
    return highColor ?? const Color(0xFFFF3B30);
  }

  @override
  Widget build(BuildContext context) {
    final litCount = (level.clamp(0.0, 1.0) * segments).ceil();

    final mainAxisSize = horizontal ? width : height;
    final crossAxisSize = horizontal ? height : width;
    final gap = 2.0;
    final segmentSize = (mainAxisSize - gap * (segments - 1)) / segments;

    return SizedBox(
      width: horizontal ? height : width,
      height: horizontal ? width : height,
      child: horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(segments, (i) => _buildSegment(i, litCount, segmentSize, crossAxisSize, gap)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(segments, (i) {
                // Vertical: top = highest, bottom = lowest
                final reversedIndex = segments - 1 - i;
                return _buildSegment(reversedIndex, litCount, segmentSize, crossAxisSize, gap, isVerticalItem: true, itemIndex: i);
              }),
            ),
    );
  }

  Widget _buildSegment(int segmentIndex, int litCount, double segmentSize, double crossAxisSize, double gap, {bool isVerticalItem = false, int itemIndex = 0}) {
    final isLit = segmentIndex < litCount;
    final segColor = _segmentColor(segmentIndex);

    final segment = Container(
      width: horizontal ? segmentSize : crossAxisSize,
      height: horizontal ? crossAxisSize : segmentSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1.5),
        color: isLit ? segColor : AppColors.bgInset,
        border: isLit ? null : Border.all(color: AppColors.border, width: 0.5),
        boxShadow: isLit
            ? [
                BoxShadow(
                  color: segColor.withValues(alpha: 0.35),
                  blurRadius: 3,
                ),
              ]
            : null,
      ),
    );

    if (horizontal) {
      return Padding(
        padding: EdgeInsets.only(right: segmentIndex < segments - 1 ? gap : 0),
        child: segment,
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(bottom: itemIndex < segments - 1 ? gap : 0),
        child: segment,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  4. GlowingIconButton
// ─────────────────────────────────────────────────────────────

class GlowingIconButton extends StatelessWidget {
  const GlowingIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.accent,
    this.size = 40,
    this.iconSize = 20,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final double iconSize;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: active ? 0.18 : 0.08),
              Colors.transparent,
            ],
          ),
          boxShadow: active
              ? [
                  AppColors.ledGlow(color),
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : AppColors.neumorphicRaised(scale: size / 60),
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: active ? color : color.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  5. PremiumToggle
// ─────────────────────────────────────────────────────────────

class PremiumToggle extends StatelessWidget {
  const PremiumToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.accent,
    this.labelOn,
    this.labelOff,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final String? labelOn;
  final String? labelOff;

  @override
  Widget build(BuildContext context) {
    const trackWidth = 48.0;
    const trackHeight = 24.0;
    const thumbSize = 20.0;
    const thumbPadding = 2.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (labelOff != null) ...[
            Text(
              labelOff!,
              style: AppFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: value ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
          ],
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: trackWidth,
            height: trackHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(trackHeight / 2),
              color: value ? activeColor.withValues(alpha: 0.25) : AppColors.bgInset,
              border: Border.all(
                color: value ? activeColor.withValues(alpha: 0.4) : AppColors.border,
                width: 1,
              ),
              boxShadow: AppColors.neumorphicInset(
                glowColor: value ? activeColor : null,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(thumbPadding),
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.bgPanel,
                    border: Border.all(
                      color: value ? activeColor.withValues(alpha: 0.5) : AppColors.borderLight,
                      width: 0.5,
                    ),
                    boxShadow: [
                      ...AppColors.neumorphicRaised(scale: 0.35),
                      if (value) AppColors.ledGlow(activeColor, intensity: 0.6),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (labelOn != null) ...[
            const SizedBox(width: 6),
            Text(
              labelOn!,
              style: AppFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: value ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
