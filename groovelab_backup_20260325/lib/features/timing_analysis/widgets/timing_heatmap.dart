import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../models/timing_data.dart';

/// Visual heatmap showing timing quality per note per measure.
/// Green = <10ms off, Yellow = 10-30ms, Red = >30ms
class TimingHeatmap extends StatelessWidget {
  final List<NoteOnset> onsets;
  final int beatsPerBar;
  final int subdivision;

  const TimingHeatmap({
    super.key,
    required this.onsets,
    required this.beatsPerBar,
    this.subdivision = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (onsets.isEmpty) {
      return Container(
        height: 100,
        decoration: AppTheme.glassCard(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_on_rounded, size: 22, color: AppColors.textMuted),
              const SizedBox(height: 6),
              Text('No timing data yet', style: GoogleFonts.outfit(
                color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ),
      );
    }

    // Group onsets by measure
    final measureMap = <int, List<NoteOnset>>{};
    for (final onset in onsets) {
      measureMap.putIfAbsent(onset.measureIndex, () => []);
      measureMap[onset.measureIndex]!.add(onset);
    }

    final maxMeasure = measureMap.keys.reduce((a, b) => a > b ? a : b);
    final notesPerMeasure = beatsPerBar * subdivision;

    return Container(
      decoration: AppTheme.glassCard(),
      padding: const EdgeInsets.all(14),
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
              Text('TIMING GRID', style: GoogleFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 1.8,
              )),
              const Spacer(),
              _legendDot(const Color(0xFF00FF88), '<10ms'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFFFFB020), '10-30ms'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFFFF3B5C), '>30ms'),
            ],
          ),
          const SizedBox(height: 10),
          // ── Grid ──
          SizedBox(
            height: ((maxMeasure + 1) * 30.0).clamp(30.0, 320.0),
            child: ListView.builder(
              itemCount: maxMeasure + 1,
              itemBuilder: (context, measureIdx) {
                final measureOnsets = measureMap[measureIdx] ?? [];
                return _buildMeasureRow(measureIdx, measureOnsets, notesPerMeasure);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasureRow(int measureIdx, List<NoteOnset> measureOnsets, int notesPerMeasure) {
    final slots = List<NoteOnset?>.filled(notesPerMeasure, null);
    for (final onset in measureOnsets) {
      final slotIdx = onset.beatIndex * subdivision;
      if (slotIdx < notesPerMeasure) {
        slots[slotIdx] = onset;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${measureIdx + 1}',
              style: AppTheme.monoStyle(size: 9, color: AppColors.textMuted),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 6),
          ...List.generate(notesPerMeasure, (i) {
            final onset = slots[i];
            final isBeatBoundary = i % subdivision == 0;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Tooltip(
                  message: onset != null
                      ? '${onset.deviationMs.toStringAsFixed(1)}ms'
                      : 'No note',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 22,
                    decoration: BoxDecoration(
                      color: _getCellColor(onset),
                      borderRadius: BorderRadius.circular(3),
                      border: isBeatBoundary
                          ? Border.all(color: AppColors.borderLight.withValues(alpha: 0.7), width: 0.6)
                          : null,
                      boxShadow: onset != null ? [
                        BoxShadow(
                          color: _getCellColor(onset).withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ] : null,
                    ),
                    child: onset != null
                        ? Center(
                            child: Text(
                              onset.deviationMs >= 0
                                  ? '+${onset.deviationMs.toStringAsFixed(0)}'
                                  : onset.deviationMs.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 7,
                                color: Colors.black87,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getCellColor(NoteOnset? onset) {
    if (onset == null) return AppColors.bgCard;
    switch (onset.quality) {
      case TimingQuality.green:
        return const Color(0xFF00FF88).withValues(alpha: 0.72);
      case TimingQuality.yellow:
        return const Color(0xFFFFB020).withValues(alpha: 0.72);
      case TimingQuality.red:
        return const Color(0xFFFF3B5C).withValues(alpha: 0.72);
    }
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.outfit(
          color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w500,
        )),
      ],
    );
  }
}
