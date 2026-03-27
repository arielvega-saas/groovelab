import 'dart:math';
import '../../models/timing_data.dart';
import '../../core/audio/native_audio_bridge.dart';

/// Core timing analysis engine.
/// Compares detected note onsets against the metronome's beat grid
/// and produces detailed timing metrics.
class TimingAnalyzer {
  final int bpm;
  final int beatsPerBar;
  final int subdivision;

  /// Beat grid timestamps in microseconds from session start
  final List<int> _beatGridUs = [];

  /// Collected onsets during this analysis session
  final List<NoteOnset> _onsets = [];

  /// Session start timestamp in microseconds
  int _sessionStartUs = 0;

  /// Beat interval in microseconds
  int get beatIntervalUs => (60 * 1000000 / bpm).round();

  /// Sub-beat interval in microseconds
  int get subBeatIntervalUs => (beatIntervalUs / subdivision).round();

  TimingAnalyzer({
    required this.bpm,
    required this.beatsPerBar,
    this.subdivision = 1,
  });

  /// Start a new analysis session. Call this when recording begins.
  void startSession(int startTimestampUs) {
    _sessionStartUs = startTimestampUs;
    _beatGridUs.clear();
    _onsets.clear();

    // Pre-generate beat grid for 10 minutes (enough for any practice session)
    const maxDurationUs = 10 * 60 * 1000000; // 10 minutes
    int t = 0;
    while (t < maxDurationUs) {
      _beatGridUs.add(t);
      t += subBeatIntervalUs;
    }
  }

  /// Process a detected onset event and map it to the nearest beat.
  NoteOnset? processOnset(OnsetEvent event) {
    if (_beatGridUs.isEmpty) return null;

    // Convert to session-relative timestamp
    final relativeUs = event.timestampUs - _sessionStartUs;
    if (relativeUs < 0) return null;

    // Find the nearest beat in the grid using binary search
    final nearestIdx = _findNearestBeat(relativeUs);
    if (nearestIdx < 0) return null;

    final expectedBeatUs = _beatGridUs[nearestIdx];
    final deviationUs = relativeUs - expectedBeatUs;
    final deviationMs = deviationUs / 1000.0;

    // Skip if deviation is more than half a beat interval (likely noise)
    if (deviationMs.abs() > beatIntervalUs / 2000.0) return null;

    // Calculate beat and measure indices
    final beatsFromStart = nearestIdx;
    final mainBeatIdx = (beatsFromStart ~/ subdivision) % beatsPerBar;
    final measureIdx = beatsFromStart ~/ (beatsPerBar * subdivision);

    final onset = NoteOnset(
      timestampUs: relativeUs,
      expectedBeatUs: expectedBeatUs,
      deviationMs: deviationMs,
      beatIndex: mainBeatIdx,
      measureIndex: measureIdx,
      amplitude: event.amplitude,
    );

    _onsets.add(onset);
    return onset;
  }

  /// Binary search for nearest beat grid position.
  int _findNearestBeat(int timestampUs) {
    if (_beatGridUs.isEmpty) return -1;

    int lo = 0;
    int hi = _beatGridUs.length - 1;

    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_beatGridUs[mid] < timestampUs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    // Check if lo or lo-1 is closer
    if (lo > 0) {
      final distLo = (timestampUs - _beatGridUs[lo]).abs();
      final distPrev = (timestampUs - _beatGridUs[lo - 1]).abs();
      if (distPrev < distLo) return lo - 1;
    }

    return lo;
  }

  /// Get all collected onsets.
  List<NoteOnset> get onsets => List.unmodifiable(_onsets);

  /// Calculate aggregate timing metrics from all collected onsets.
  TimingMetrics calculateMetrics() {
    if (_onsets.isEmpty) return TimingMetrics.empty();

    final deviations = _onsets.map((o) => o.deviationMs).toList();

    // Average deviation
    final avgDev = deviations.reduce((a, b) => a + b) / deviations.length;

    // Standard deviation (Bessel's correction: N-1 for sample variance)
    final variance = deviations
        .map((d) => (d - avgDev) * (d - avgDev))
        .reduce((a, b) => a + b) / max(1, deviations.length - 1);
    final stdDev = sqrt(variance);

    // Consistency score: 100 = perfect, 0 = terrible
    // Based on standard deviation: <5ms = 100, >50ms = 0
    final consistency = (100 * (1 - (stdDev / 50).clamp(0.0, 1.0))).round();

    // Drift detection: linear regression of deviations over time
    final driftResult = _calculateDrift();

    // Color counts
    int green = 0, yellow = 0, red = 0;
    for (final o in _onsets) {
      switch (o.quality) {
        case TimingQuality.green: green++; break;
        case TimingQuality.yellow: yellow++; break;
        case TimingQuality.red: red++; break;
      }
    }

    // Per-measure average deviation
    final measureMap = <int, List<double>>{};
    for (final o in _onsets) {
      measureMap.putIfAbsent(o.measureIndex, () => []);
      measureMap[o.measureIndex]!.add(o.deviationMs);
    }
    final maxMeasure = measureMap.keys.isEmpty ? 0 : measureMap.keys.reduce(max);
    final deviationsPerMeasure = List<double>.generate(maxMeasure + 1, (i) {
      final devs = measureMap[i];
      if (devs == null || devs.isEmpty) return 0.0;
      return devs.reduce((a, b) => a + b) / devs.length;
    });

    return TimingMetrics(
      averageDeviationMs: avgDev,
      stdDeviationMs: stdDev,
      consistencyScore: consistency,
      driftDirection: driftResult.direction,
      driftRateMs: driftResult.ratePerMeasure,
      totalNotes: _onsets.length,
      greenNotes: green,
      yellowNotes: yellow,
      redNotes: red,
      deviationsPerMeasure: deviationsPerMeasure,
    );
  }

  /// Linear regression on deviations to detect rushing/dragging.
  _DriftResult _calculateDrift() {
    if (_onsets.length < 4) {
      return _DriftResult('steady', 0);
    }

    // Use onset index as x, deviation as y
    final n = _onsets.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = _onsets[i].deviationMs;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final denominator = n * sumX2 - sumX * sumX;
    if (denominator.abs() < 1e-10) return _DriftResult('steady', 0);
    final slope = (n * sumXY - sumX * sumY) / denominator;

    // Convert slope to ms drift per measure
    final notesPerMeasure = beatsPerBar * subdivision;
    final driftPerMeasure = slope * notesPerMeasure;

    String direction;
    if (driftPerMeasure < -1.0) {
      direction = 'rushing'; // Getting consistently early = speeding up
    } else if (driftPerMeasure > 1.0) {
      direction = 'dragging'; // Getting consistently late = slowing down
    } else {
      direction = 'steady';
    }

    return _DriftResult(direction, driftPerMeasure);
  }

  /// Compare two sets of metrics for improvement tracking.
  static TimingComparison compare(TimingMetrics before, TimingMetrics after) {
    return TimingComparison(
      deviationImprovement: before.averageDeviationMs.abs() - after.averageDeviationMs.abs(),
      consistencyImprovement: after.consistencyScore - before.consistencyScore,
      driftImprovement: before.driftRateMs.abs() - after.driftRateMs.abs(),
    );
  }
}

class _DriftResult {
  final String direction;
  final double ratePerMeasure;
  _DriftResult(this.direction, this.ratePerMeasure);
}

/// Comparison between two takes/sessions.
class TimingComparison {
  /// Positive = improved (less deviation)
  final double deviationImprovement;

  /// Positive = improved (higher score)
  final int consistencyImprovement;

  /// Positive = improved (less drift)
  final double driftImprovement;

  const TimingComparison({
    required this.deviationImprovement,
    required this.consistencyImprovement,
    required this.driftImprovement,
  });

  bool get isImproved =>
      deviationImprovement > 0 && consistencyImprovement >= 0;
}
