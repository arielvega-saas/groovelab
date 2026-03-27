import 'package:flutter/material.dart';
import '../../../core/app_fonts.dart';
import '../../../core/theme.dart';

// ===================================================================
//  HEADER BAR — Top bar with track name and action buttons (~40px)
// ===================================================================

class SongLabHeader extends StatelessWidget {
  final String? trackName;
  final bool isPlaying;
  final double duration;
  final String lang;
  final VoidCallback onSave;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;
  final VoidCallback onDiscard;

  const SongLabHeader({
    super.key,
    this.trackName,
    required this.isPlaying,
    required this.duration,
    required this.lang,
    required this.onSave,
    required this.onLibrary,
    required this.onSettings,
    required this.onDiscard,
  });

  static Widget _headerIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.bgPanel,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 15, color: AppColors.textMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AppColors.bgDark,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlaying ? AppColors.accent2 : AppColors.textMuted,
              boxShadow: isPlaying
                  ? [BoxShadow(color: AppColors.accent2.withValues(alpha: 0.5), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SONG LAB',
            style: AppFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          // Track name
          if (trackName != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgInset,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  trackName!,
                  style: AppFonts.outfit(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 6),
          // Save button
          _headerIconButton(Icons.save_rounded, onSave),
          const SizedBox(width: 4),
          // Library button
          _headerIconButton(Icons.folder_open_rounded, onLibrary),
          const SizedBox(width: 4),
          // Settings button
          _headerIconButton(Icons.settings_rounded, onSettings),
                  const SizedBox(width: 4),
                  // Discard project
                  if (trackName != null)
                    GestureDetector(
                      onTap: onDiscard,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                      ),
                    ),
        ],
      ),
    );
  }
}
