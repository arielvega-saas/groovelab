import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/timing_data.dart';
import '../../models/take.dart';
import 'timing_analyzer.dart';

/// Current timing analyzer instance
final timingAnalyzerProvider = StateProvider<TimingAnalyzer?>((ref) => null);

/// Live onsets collected during current recording
final liveOnsetsProvider = StateProvider<List<NoteOnset>>((ref) => []);

/// Current take's timing metrics (computed after recording stops)
final currentMetricsProvider = StateProvider<TimingMetrics?>((ref) => null);

/// All takes in current session
final takesProvider = StateProvider<List<Take>>((ref) => []);

/// Best take in current session (highest consistency score)
final bestTakeProvider = Provider<Take?>((ref) {
  final takes = ref.watch(takesProvider);
  if (takes.isEmpty) return null;
  return takes.reduce((a, b) =>
    (a.metrics?.consistencyScore ?? 0) >= (b.metrics?.consistencyScore ?? 0) ? a : b
  );
});

/// Whether the timing analysis overlay should be shown
final showTimingOverlayProvider = StateProvider<bool>((ref) => false);

/// Comparison between current and best take
final takeComparisonProvider = Provider<TimingComparison?>((ref) {
  final current = ref.watch(currentMetricsProvider);
  final best = ref.watch(bestTakeProvider);
  if (current == null || best?.metrics == null) return null;
  return TimingAnalyzer.compare(best!.metrics!, current);
});
