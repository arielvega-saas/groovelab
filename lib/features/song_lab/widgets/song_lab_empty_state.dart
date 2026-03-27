import 'package:flutter/material.dart';
import '../../../core/app_fonts.dart';
import '../../../core/theme.dart';

// ===================================================================
//  EMPTY STATE — No track loaded
//  Enhanced: animated pulsing icon, gradient glow import button
// ===================================================================

class SongLabEmptyState extends StatefulWidget {
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
  State<SongLabEmptyState> createState() => _SongLabEmptyStateState();
}

class _SongLabEmptyStateState extends State<SongLabEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppAnimations.breathe,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated pulsing music icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, child) => Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.bgPanel,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.15 + _pulseAnimation.value * 0.15),
                  ),
                  boxShadow: [
                    ...AppColors.neumorphicRaised(scale: 0.6),
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.08 + _pulseAnimation.value * 0.10),
                      blurRadius: 16 + _pulseAnimation.value * 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 30,
                  color: AppColors.accent.withValues(alpha: 0.5 + _pulseAnimation.value * 0.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No track loaded',
            style: AppFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Import an audio file to get started',
            style: AppFonts.outfit(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          if (widget.isLoading)
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
                  style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            )
          else
            // Prominent import button with gradient and glow
            _buildImportButton(),
        ],
      ),
    );
  }

  Widget _buildImportButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => GestureDetector(
        onTap: widget.onImport,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent.withValues(alpha: 0.20),
                ModuleColors.songLab.withValues(alpha: 0.15),
                AppColors.accent.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.35 + _pulseAnimation.value * 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.12 + _pulseAnimation.value * 0.08),
                blurRadius: 14 + _pulseAnimation.value * 6,
                spreadRadius: -2,
              ),
              ...AppColors.neumorphicRaised(scale: 0.5),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.file_upload_rounded,
                size: 20,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Text(
                'Import Audio',
                style: AppFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
