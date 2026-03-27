import 'package:flutter/material.dart';
import '../../../core/app_fonts.dart';
import '../../../core/theme.dart';

// ===================================================================
//  TRANSPORT BAR — Playback controls with neumorphic hardware style
//  Enhanced: glass card buttons, glow states, LCD position counter
// ===================================================================

class SongLabTransportBar extends StatelessWidget {
  final double duration;
  final double position;
  final bool isPlaying;
  final bool loopEnabled;
  final (double, double)? loopRegion;
  final VoidCallback onSkipBackward;
  final VoidCallback onStop;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipForward;
  final VoidCallback onToggleLoop;
  final Animation<double> playPulseAnimation;

  const SongLabTransportBar({
    super.key,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.loopEnabled,
    this.loopRegion,
    required this.onSkipBackward,
    required this.onStop,
    required this.onPlayPause,
    required this.onSkipForward,
    required this.onToggleLoop,
    required this.playPulseAnimation,
  });

  static String formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Format position as MM:SS.ms for the LCD counter.
  static String formatTimeLcd(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60);
    final sInt = s.toInt();
    final ms = ((s - sInt) * 100).toInt();
    return '${m.toString().padLeft(2, '0')}:${sInt.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  static SliderThemeData sliderTheme(Color activeColor, {double trackHeight = 3}) {
    return SliderThemeData(
      activeTrackColor: activeColor,
      inactiveTrackColor: AppColors.bgInput,
      thumbColor: activeColor,
      overlayColor: activeColor.withValues(alpha: 0.1),
      trackHeight: trackHeight,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.bgDark,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Skip backward — neumorphic hardware button
          _TransportButton(
            icon: Icons.replay_5_rounded,
            iconSize: 16,
            size: 32,
            enabled: duration > 0,
            onTap: duration > 0 ? onSkipBackward : null,
          ),
          const SizedBox(width: 4),

          // Stop — neumorphic hardware button
          _TransportButton(
            icon: Icons.stop_rounded,
            iconSize: 18,
            size: 32,
            enabled: duration > 0,
            onTap: duration > 0 ? onStop : null,
          ),
          const SizedBox(width: 6),

          // Play/Pause — large center button with green glow when playing
          AnimatedBuilder(
            animation: playPulseAnimation,
            builder: (_, __) => _TransportButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              iconSize: 26,
              size: 44,
              enabled: duration > 0,
              isPlaying: isPlaying,
              pulseValue: playPulseAnimation.value,
              glowColor: isPlaying ? AppColors.accent2 : null,
              onTap: duration > 0 ? onPlayPause : null,
              borderRadius: 12,
            ),
          ),
          const SizedBox(width: 6),

          // Skip forward — neumorphic hardware button
          _TransportButton(
            icon: Icons.forward_5_rounded,
            iconSize: 16,
            size: 32,
            enabled: duration > 0,
            onTap: duration > 0 ? onSkipForward : null,
          ),
          const SizedBox(width: 8),

          // LCD Position counter display: MM:SS.ms
          Expanded(
            child: Container(
              height: 38,
              decoration: AppTheme.insetPanel(
                radius: 8,
                glowColor: isPlaying ? AppColors.accent.withValues(alpha: 0.15) : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    formatTimeLcd(position),
                    style: AppTheme.lcdStyle(
                      size: 16,
                      weight: FontWeight.w800,
                      color: isPlaying ? AppColors.accent : AppColors.textPrimary,
                      glow: isPlaying,
                    ),
                  ),
                  Text(
                    '/ ${formatTime(duration)}',
                    style: AppFonts.jetBrainsMono(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Loop A-B toggle — hardware style
          GestureDetector(
            onTap: duration > 0 ? onToggleLoop : null,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              width: 36,
              height: 32,
              decoration: AppTheme.glassCard(
                radius: 8,
                bgColor: loopEnabled ? AppColors.accent2.withValues(alpha: 0.15) : AppColors.bgPanel,
                borderColor: loopEnabled
                    ? AppColors.accent2.withValues(alpha: 0.5)
                    : AppColors.border,
                glowColor: loopEnabled ? AppColors.accent2 : null,
              ),
              alignment: Alignment.center,
              child: Text(
                'A-B',
                style: AppFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: loopEnabled ? AppColors.accent2 : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
//  Neumorphic Hardware-style Transport Button
// ───────────────────────────────────────────────────────────────────

class _TransportButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final double size;
  final bool enabled;
  final bool isPlaying;
  final double pulseValue;
  final Color? glowColor;
  final VoidCallback? onTap;
  final double borderRadius;

  const _TransportButton({
    required this.icon,
    required this.iconSize,
    required this.size,
    required this.enabled,
    this.isPlaying = false,
    this.pulseValue = 0.0,
    this.glowColor,
    this.onTap,
    this.borderRadius = 8,
  });

  @override
  State<_TransportButton> createState() => _TransportButtonState();
}

class _TransportButtonState extends State<_TransportButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final hasGlow = widget.glowColor != null && widget.isPlaying;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: hasGlow
              ? widget.glowColor!.withValues(alpha: 0.10 + widget.pulseValue * 0.05)
              : AppColors.bgPanel,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: hasGlow
                ? widget.glowColor!.withValues(alpha: 0.5)
                : const Color(0x08FFFFFF),
            width: hasGlow ? 1.5 : 1,
          ),
          boxShadow: _isPressed
              // Pressed state — inset-like, flatter shadows
              ? [
                  BoxShadow(
                    color: const Color(0xFF181818),
                    blurRadius: 3,
                    offset: const Offset(1, 1),
                  ),
                  BoxShadow(
                    color: const Color(0xFF2A2A2A),
                    blurRadius: 3,
                    offset: const Offset(-1, -1),
                  ),
                ]
              // Raised state — neumorphic raised + optional glow
              : [
                  ...AppColors.neumorphicRaised(
                    scale: 0.4,
                    glowColor: hasGlow ? widget.glowColor : null,
                  ),
                ],
        ),
        child: Icon(
          widget.icon,
          size: widget.iconSize,
          color: hasGlow
              ? widget.glowColor
              : widget.enabled
                  ? AppColors.textSecondary
                  : AppColors.textMuted,
        ),
      ),
    );
  }
}
