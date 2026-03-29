import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

// ===================================================================
//  SEGMENTED CONTROL — View switcher (~34px)
// ===================================================================

class SongLabSegmentedControl extends StatelessWidget {
  final int viewIndex;
  final ValueChanged<int> onViewChanged;
  final String lang;
  final bool hasStemsAvailable;

  const SongLabSegmentedControl({
    super.key,
    required this.viewIndex,
    required this.onViewChanged,
    required this.lang,
    this.hasStemsAvailable = false,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['Player', 'Stems', 'Chords', 'Export'];
    final icons = [
      Icons.play_circle_outline_rounded,
      Icons.call_split_rounded,
      Icons.piano_rounded,
      Icons.ios_share_rounded,
    ];

    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgInset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = viewIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onViewChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isActive
                      ? Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1)
                      : null,
                  boxShadow: isActive
                      ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.1), blurRadius: 6)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[i],
                      size: 12,
                      color: isActive ? AppColors.accent : AppColors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      labels[i],
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
