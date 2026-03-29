import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../models/timing_data.dart';

/// Displays aggregate timing metrics for a take or session.
class SessionMetricsCard extends StatelessWidget {
  final TimingMetrics metrics;
  final TimingMetrics? previousMetrics; // for comparison

  const SessionMetricsCard({
    super.key,
    required this.metrics,
    this.previousMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final scoreCol = _consistencyColor(metrics.consistencyScore);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(
        glowColor: scoreCol,
        borderColor: scoreCol.withValues(alpha: 0.18),
      ),
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
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [scoreCol, scoreCol.withValues(alpha: 0.5)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: scoreCol.withValues(alpha: 0.4), blurRadius: 5)],
                ),
              ),
              Text('SESSION METRICS', style: GoogleFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 1.8,
              )),
            ],
          ),
          const SizedBox(height: 14),

          // ── Top row: Score + Deviation + Drift ──
          Row(
            children: [
              Expanded(child: _metricCircle(
                value: metrics.consistencyScore,
                label: 'Consistency',
                color: scoreCol,
              )),
              Expanded(child: _metricColumn(
                value: '${metrics.averageDeviationMs.abs().toStringAsFixed(1)}ms',
                label: 'Avg Deviation',
                subtitle: metrics.averageDeviationMs < 0 ? 'EARLY' : 'LATE',
                subtitleColor: metrics.averageDeviationMs < 0
                    ? AppColors.accent
                    : AppColors.warning,
              )),
              Expanded(child: _metricColumn(
                value: _driftIcon(metrics.driftDirection),
                label: 'Drift',
                subtitle: metrics.driftDirection.toUpperCase(),
                subtitleColor: metrics.driftDirection == 'steady'
                    ? AppColors.accent2
                    : AppColors.warning,
              )),
            ],
          ),

          const SizedBox(height: 16),

          // ── Quality distribution bar ──
          _qualityBar(),

          const SizedBox(height: 12),

          // ── Note counts ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bgDeepest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _noteCount(metrics.greenNotes, 'Tight', const Color(0xFF00FF88)),
                _vertDivider(),
                _noteCount(metrics.yellowNotes, 'Close', const Color(0xFFFFB020)),
                _vertDivider(),
                _noteCount(metrics.redNotes, 'Off', const Color(0xFFFF3B5C)),
                _vertDivider(),
                _noteCount(metrics.totalNotes, 'Total', AppColors.textSecondary),
              ],
            ),
          ),

          // ── Comparison with previous take ──
          if (previousMetrics != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, AppColors.border, Colors.transparent],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _comparisonRow(previousMetrics!),
          ],
        ],
      ),
    );
  }

  Widget _metricCircle({required int value, required String label, required Color color}) {
    return Column(
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background track
              SizedBox(
                width: 68, height: 68,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 5,
                  backgroundColor: AppColors.bgInput,
                  valueColor: const AlwaysStoppedAnimation(Colors.transparent),
                ),
              ),
              // Progress arc
              SizedBox(
                width: 68, height: 68,
                child: CircularProgressIndicator(
                  value: value / 100.0,
                  strokeWidth: 5,
                  backgroundColor: AppColors.bgInput,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Score text with gradient
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                ).createShader(bounds),
                child: Text(
                  '$value',
                  style: AppTheme.monoStyle(
                    size: 22, weight: FontWeight.w800, color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.outfit(
          fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500,
        )),
      ],
    );
  }

  Widget _metricColumn({required String value, required String label, String? subtitle, Color? subtitleColor}) {
    return Column(
      children: [
        Text(value, style: AppTheme.monoStyle(size: 18, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: (subtitleColor ?? AppColors.textMuted).withValues(alpha: 0.12),
              border: Border.all(
                color: (subtitleColor ?? AppColors.textMuted).withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Text(subtitle, style: GoogleFonts.outfit(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: subtitleColor ?? AppColors.textMuted, letterSpacing: 0.8,
            )),
          ),
        ],
      ],
    );
  }

  Widget _qualityBar() {
    if (metrics.totalNotes == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NOTE QUALITY', style: GoogleFonts.outfit(
          fontSize: 9, fontWeight: FontWeight.w600,
          color: AppColors.textMuted, letterSpacing: 1.5,
        )),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (metrics.greenNotes > 0)
                  Expanded(
                    flex: metrics.greenNotes,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00CC6A), Color(0xFF00FF88)],
                        ),
                      ),
                    ),
                  ),
                if (metrics.yellowNotes > 0)
                  Expanded(
                    flex: metrics.yellowNotes,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFDD9010), Color(0xFFFFB020)],
                        ),
                      ),
                    ),
                  ),
                if (metrics.redNotes > 0)
                  Expanded(
                    flex: metrics.redNotes,
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
    );
  }

  Widget _noteCount(int count, String label, Color color) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
          ).createShader(bounds),
          child: Text('$count', style: AppTheme.monoStyle(
            size: 18, weight: FontWeight.w800, color: Colors.white,
          )),
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.outfit(
          fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w500,
        )),
      ],
    );
  }

  Widget _vertDivider() {
    return Container(
      width: 1, height: 28,
      color: AppColors.border.withValues(alpha: 0.6),
    );
  }

  Widget _comparisonRow(TimingMetrics prev) {
    final consImproved = metrics.consistencyScore > prev.consistencyScore;
    final diff = metrics.consistencyScore - prev.consistencyScore;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: (consImproved ? AppColors.accent2 : AppColors.danger).withValues(alpha: 0.06),
        border: Border.all(
          color: (consImproved ? AppColors.accent2 : AppColors.danger).withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            consImproved ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: consImproved ? AppColors.accent2 : AppColors.danger,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            consImproved ? 'Improving!' : 'Keep practicing',
            style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: consImproved ? AppColors.accent2 : AppColors.textMuted,
            ),
          ),
          if (consImproved) ...[
            const SizedBox(width: 8),
            Text(
              '+$diff pts',
              style: AppTheme.monoStyle(size: 11, color: AppColors.accent2),
            ),
          ],
        ],
      ),
    );
  }

  Color _consistencyColor(int score) {
    if (score >= 80) return const Color(0xFF00FF88);
    if (score >= 50) return const Color(0xFFFFB020);
    return const Color(0xFFFF3B5C);
  }

  String _driftIcon(String direction) {
    switch (direction) {
      case 'rushing': return '>>';
      case 'dragging': return '<<';
      default: return '==';
    }
  }
}
