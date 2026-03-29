import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

// ===================================================================
//  EMPTY STATE — No track loaded
// ===================================================================

class SongLabEmptyState extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onImport;
  final String lang;

  const SongLabEmptyState({
    super.key,
    required this.isLoading,
    required this.onImport,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bgPanel,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.neumorphicRaised(scale: 0.6),
            ),
            child: Icon(
              Icons.library_music_rounded,
              size: 28,
              color: AppColors.accent.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No track loaded',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Import an audio file to get started',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          if (isLoading)
            Column(
              children: [
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      backgroundColor: AppColors.bgInset,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading audio...',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            )
          else
            HardwareButton(
              onTap: onImport,
              glowColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_upload_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Import Audio',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
