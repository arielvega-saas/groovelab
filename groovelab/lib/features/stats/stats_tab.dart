import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';
import '../../models/session.dart';

class StatsTab extends ConsumerWidget {
  final VoidCallback onSaveData;

  const StatsTab({super.key, required this.onSaveData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _buildStatsTab(ref);
  }

  Widget _buildStatsTab(WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final totalTime = ref.watch(totalPracticeTimeProvider);
    final sessionCount = ref.watch(sessionCountProvider);
    final bpm = ref.watch(bpmProvider);
    final tempoName = getTempoName(bpm);
    final mins = (totalTime / 60).floor();
    final secs = (totalTime % 60).floor();
    final history = ref.watch(sessionsHistoryProvider);
    final weeklyGoal = ref.watch(weeklyGoalMinutesProvider);

    // Compute practice streak (consecutive days with sessions)
    final streak = _computeStreak(history);
    // Compute this week's practice time
    final weeklyMinutes = _computeWeeklyMinutes(history, totalTime);
    // Sessions with scores for the chart
    final scoredSessions = history.where((s) => s.consistencyScore != null).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    // Best score
    final bestScore = scoredSessions.isNotEmpty
        ? scoredSessions.map((s) => s.consistencyScore!).reduce(max).round()
        : 0;
    final avgScore = scoredSessions.isNotEmpty
        ? (scoredSessions.map((s) => s.consistencyScore!).reduce((a, b) => a + b) / scoredSessions.length).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Section header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28, height: 1,
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(tr(lang, 'practiceStatistics').toUpperCase(), style: AppFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2.5,
                )),
              ),
              Container(
                width: 28, height: 1,
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Top stats row
          Row(
            children: [
              Expanded(child: _statCard('$mins:${secs.toString().padLeft(2, "0")}', tr(lang, 'totalTime'))),
              const SizedBox(width: 8),
              Expanded(child: _statCard('$sessionCount', tr(lang, 'sessions'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statCard('$streak ${tr(lang, "days")}', tr(lang, 'practiceStreak'))),
              const SizedBox(width: 8),
              Expanded(child: _statCard(tempoName, tr(lang, 'tempo'))),
            ],
          ),
          const SizedBox(height: 8),
          // Scores row
          if (scoredSessions.isNotEmpty) ...[
            Row(
              children: [
                Expanded(child: _statCard('$avgScore', tr(lang, 'avgScore'))),
                const SizedBox(width: 8),
                Expanded(child: _statCard('$bestScore', tr(lang, 'bestScore'))),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Weekly Goal progress
          _panel(tr(lang, 'weeklyGoal'), Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${tr(lang, "thisWeek")}: ${weeklyMinutes.round()} ${tr(lang, "minutes")}',
                    style: AppTheme.monoStyle(size: 13, color: AppColors.accent)),
                  Text('$weeklyGoal ${tr(lang, "minPerWeek")}',
                    style: AppTheme.monoStyle(size: 11, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: weeklyGoal > 0 ? (weeklyMinutes / weeklyGoal).clamp(0.0, 1.0) : 0,
                  minHeight: 8,
                  backgroundColor: AppColors.bgInput,
                  valueColor: AlwaysStoppedAnimation(
                    weeklyMinutes >= weeklyGoal ? AppColors.accent2 : AppColors.accent),
                ),
              ),
              const SizedBox(height: 8),
              _sliderRow(tr(lang, 'weeklyGoal'), weeklyGoal, 10, 300, '$weeklyGoal ${tr(lang, "minutes")}',
                  (v) { ref.read(weeklyGoalMinutesProvider.notifier).state = v; onSaveData(); }),
            ],
          )),
          // Weekly bar chart (Mon-Sun)
          _buildWeeklyBarChart(lang, history, totalTime),
          // Score history chart
          if (scoredSessions.length >= 2)
            _panel(tr(lang, 'scoreHistory'), SizedBox(
              height: 120,
              child: CustomPaint(
                size: const Size(double.infinity, 120),
                painter: _ScoreChartPainter(
                  scores: scoredSessions.map((s) => s.consistencyScore!.toDouble()).toList(),
                  color: AppColors.accent2,
                  bgColor: AppColors.bgInput,
                ),
              ),
            )),
          // Recent sessions
          _panel(tr(lang, 'recentSessions'), history.isEmpty
            ? Text(tr(lang, 'noSessionsYet'),
                style: AppFonts.outfit(fontSize: 13, color: AppColors.textMuted, height: 1.5))
            : Column(
                children: history.reversed.take(10).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final dur = s.duration;
                  final durStr = '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, "0")}';
                  final scoreStr = s.consistencyScore != null ? '${s.consistencyScore!.round()}%' : '--';
                  final scoreColor = s.consistencyScore != null
                      ? (s.consistencyScore! >= 80 ? AppColors.accent2 : s.consistencyScore! >= 50 ? AppColors.warning : AppColors.danger)
                      : AppColors.textMuted;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.accent.withValues(alpha: 0.04) : AppColors.bgInput.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: i == 0 ? Border.all(color: AppColors.accent.withValues(alpha: 0.15)) : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: scoreColor.withValues(alpha: 0.12),
                          ),
                          child: Text(scoreStr,
                            style: AppTheme.monoStyle(size: 12, weight: FontWeight.w700, color: scoreColor)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${s.bpmStart} BPM · ${s.timeSignature}',
                          style: AppTheme.monoStyle(size: 11, color: AppColors.textSecondary))),
                        Text(durStr, style: AppTheme.monoStyle(size: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ),
        ],
      ),
    );
  }

  int _computeStreak(List<PracticeSession> history) {
    if (history.isEmpty) return 0;
    final days = <DateTime>{};
    for (final s in history) {
      days.add(DateTime(s.startTime.year, s.startTime.month, s.startTime.day));
    }
    final sorted = days.toList()..sort((a, b) => b.compareTo(a));
    int streak = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i - 1].difference(sorted[i]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    // Check if most recent day is today or yesterday
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(sorted.first).inDays;
    if (diff > 1) return 0; // streak broken
    return streak;
  }

  double _computeWeeklyMinutes(List<PracticeSession> history, double totalTimeSecs) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final mondayMidnight = DateTime(weekStart.year, weekStart.month, weekStart.day);
    double weekSecs = 0;
    for (final s in history) {
      if (s.startTime.isAfter(mondayMidnight)) {
        weekSecs += s.duration.inSeconds;
      }
    }
    return weekSecs / 60;
  }

  /// Weekly bar chart: practice minutes per day (Mon-Sun).
  Widget _buildWeeklyBarChart(String lang, List<PracticeSession> history, double totalTimeSecs) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final mondayMidnight = DateTime(weekStart.year, weekStart.month, weekStart.day);

    // Compute minutes per day (0=Mon, 6=Sun)
    final dailyMins = List<double>.filled(7, 0);
    for (final s in history) {
      if (s.startTime.isAfter(mondayMidnight)) {
        final dayIdx = s.startTime.weekday - 1; // 0=Mon
        dailyMins[dayIdx] += s.duration.inSeconds / 60.0;
      }
    }

    final maxMins = dailyMins.reduce(max).clamp(1.0, 9999.0);
    final dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final todayIdx = now.weekday - 1;

    return _panel(tr(lang, 'thisWeek'), SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final mins = dailyMins[i];
          final barHeight = (mins / maxMins * 70).clamp(2.0, 70.0);
          final isToday = i == todayIdx;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (mins > 0)
                    Text('${mins.round()}', style: AppTheme.monoStyle(
                      size: 8, color: isToday ? AppColors.accent : AppColors.textMuted)),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: mins > 0 ? barHeight : 2,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      gradient: mins > 0 ? LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: isToday
                          ? [AppColors.accent, AppColors.accent2]
                          : [AppColors.accent2.withValues(alpha: 0.35), AppColors.accent2.withValues(alpha: 0.6)],
                      ) : null,
                      color: mins > 0 ? null : AppColors.bgInput,
                      boxShadow: (mins > 0 && isToday) ? [
                        BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: -2),
                      ] : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(dayLabels[i], style: AppFonts.outfit(
                    fontSize: 10, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? AppColors.accent : AppColors.textMuted,
                  )),
                ],
              ),
            ),
          );
        }),
      ),
    ));
  }

  // ─── Shared helper widgets ───────────────────────────────────────

  Widget _panel(String title, Widget content) {
    return AppTheme.premiumPanel(title: title.toUpperCase(), content: content);
  }

  Widget _sliderRow(String label, int value, int min, int max, String display, Function(int) onChanged) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: AppFonts.outfit(
          fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted,
        ))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.bgInput,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 3,
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        Container(
          width: 58,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(display, style: AppTheme.monoStyle(
            size: 11, weight: FontWeight.w600, color: AppColors.accent,
          ), textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bgCard,
            AppColors.bgCard.withBlue(AppColors.bgCard.blue + 8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.accent, AppColors.accent2],
            ).createShader(bounds),
            child: Text(value, style: AppTheme.monoStyle(size: 24, weight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(height: 5),
          Text(label, style: AppFonts.outfit(
            fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted, letterSpacing: 0.3,
          )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SCORE HISTORY CHART PAINTER
// ═══════════════════════════════════════════════════════════════════

class _ScoreChartPainter extends CustomPainter {
  final List<double> scores;
  final Color color;
  final Color bgColor;

  _ScoreChartPainter({
    required this.scores,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;

    const padding = 8.0;
    final chartW = size.width - padding * 2;
    final chartH = size.height - padding * 2;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = padding + chartH * (1 - i / 4);
      canvas.drawLine(Offset(padding, y), Offset(padding + chartW, y), gridPaint);
    }

    // Draw score line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    const maxScore = 100.0;

    for (int i = 0; i < scores.length; i++) {
      final x = padding + (i / (scores.length - 1)) * chartW;
      final y = padding + chartH * (1 - scores[i] / maxScore);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, padding + chartH);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    fillPath.lineTo(padding + chartW, padding + chartH);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw dots at each point
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < scores.length; i++) {
      final x = padding + (i / (scores.length - 1)) * chartW;
      final y = padding + chartH * (1 - scores[i] / maxScore);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }

    // Labels
    final textStyle = TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9);
    final tp0 = TextPainter(text: TextSpan(text: '0', style: textStyle), textDirection: TextDirection.ltr)..layout();
    tp0.paint(canvas, Offset(0, padding + chartH - tp0.height / 2));
    final tp100 = TextPainter(text: TextSpan(text: '100', style: textStyle), textDirection: TextDirection.ltr)..layout();
    tp100.paint(canvas, Offset(0, padding - tp100.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter old) =>
      old.scores.length != scores.length || old.color != color;
}
