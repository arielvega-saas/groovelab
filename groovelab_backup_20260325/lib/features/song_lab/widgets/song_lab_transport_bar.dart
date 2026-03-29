import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

// ===================================================================
//  TRANSPORT BAR — Playback controls (~50px)
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
      height: 50,
      decoration: const BoxDecoration(
        color: AppColors.bgDark,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Skip backward
          GestureDetector(
            onTap: duration > 0 ? onSkipBackward : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.bgPanel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.replay_5_rounded,
                size: 16,
                color: duration > 0 ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Stop
          GestureDetector(
            onTap: duration > 0 ? onStop : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.bgPanel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.stop_rounded,
                size: 18,
                color: duration > 0 ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Play/Pause (large center button)
          AnimatedBuilder(
            animation: playPulseAnimation,
            builder: (_, __) => GestureDetector(
              onTap: duration > 0 ? onPlayPause : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? AppColors.accent.withValues(alpha: 0.15 + playPulseAnimation.value * 0.05)
                      : AppColors.bgPanel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPlaying
                        ? AppColors.accent.withValues(alpha: 0.5)
                        : AppColors.border,
                    width: isPlaying ? 1.5 : 1,
                  ),
                  boxShadow: isPlaying
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ]
                      : AppColors.neumorphicRaised(scale: 0.4),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 26,
                  color: isPlaying ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Skip forward
          GestureDetector(
            onTap: duration > 0 ? onSkipForward : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.bgPanel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.forward_5_rounded,
                size: 16,
                color: duration > 0 ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Position / Duration text
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  formatTime(position),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isPlaying ? AppColors.accent : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '/ ${formatTime(duration)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Loop A-B toggle
          GestureDetector(
            onTap: duration > 0 ? onToggleLoop : null,
            child: Container(
              width: 36,
              height: 32,
              decoration: BoxDecoration(
                color: loopEnabled ? AppColors.accent2.withValues(alpha: 0.15) : AppColors.bgPanel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: loopEnabled
                      ? AppColors.accent2.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
                boxShadow: loopEnabled
                    ? [BoxShadow(color: AppColors.accent2.withValues(alpha: 0.2), blurRadius: 6)]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                'A-B',
                style: GoogleFonts.jetBrainsMono(
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
