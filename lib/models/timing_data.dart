/// Represents a single detected note onset and its timing relative to the beat grid.
class NoteOnset {
  /// Timestamp in microseconds from session start
  final int timestampUs;

  /// The expected beat timestamp in microseconds
  final int expectedBeatUs;

  /// Deviation in milliseconds (negative = early, positive = late)
  final double deviationMs;

  /// Beat index within the measure (0-based)
  final int beatIndex;

  /// Measure number (0-based)
  final int measureIndex;

  /// Amplitude of the onset (0.0 - 1.0)
  final double amplitude;

  const NoteOnset({
    required this.timestampUs,
    required this.expectedBeatUs,
    required this.deviationMs,
    required this.beatIndex,
    required this.measureIndex,
    required this.amplitude,
  });

  /// green (<10ms), yellow (10-30ms), red (>30ms)
  TimingQuality get quality {
    final abs = deviationMs.abs();
    if (abs < 10) return TimingQuality.green;
    if (abs < 30) return TimingQuality.yellow;
    return TimingQuality.red;
  }

  Map<String, dynamic> toJson() => {
    'timestampUs': timestampUs,
    'expectedBeatUs': expectedBeatUs,
    'deviationMs': deviationMs,
    'beatIndex': beatIndex,
    'measureIndex': measureIndex,
    'amplitude': amplitude,
  };

  factory NoteOnset.fromJson(Map<String, dynamic> json) => NoteOnset(
    timestampUs: json['timestampUs'] as int,
    expectedBeatUs: json['expectedBeatUs'] as int,
    deviationMs: (json['deviationMs'] as num).toDouble(),
    beatIndex: json['beatIndex'] as int,
    measureIndex: json['measureIndex'] as int,
    amplitude: (json['amplitude'] as num).toDouble(),
  );
}

enum TimingQuality { green, yellow, red }

/// Aggregated timing metrics for a take or session.
class TimingMetrics {
  final double averageDeviationMs;
  final double stdDeviationMs;
  final int consistencyScore; // 0-100
  final String driftDirection; // 'rushing', 'dragging', 'steady'
  final double driftRateMs; // ms drift per measure
  final int totalNotes;
  final int greenNotes;
  final int yellowNotes;
  final int redNotes;
  final List<double> deviationsPerMeasure;

  const TimingMetrics({
    required this.averageDeviationMs,
    required this.stdDeviationMs,
    required this.consistencyScore,
    required this.driftDirection,
    required this.driftRateMs,
    required this.totalNotes,
    required this.greenNotes,
    required this.yellowNotes,
    required this.redNotes,
    required this.deviationsPerMeasure,
  });

  factory TimingMetrics.empty() => const TimingMetrics(
    averageDeviationMs: 0,
    stdDeviationMs: 0,
    consistencyScore: 0,
    driftDirection: 'steady',
    driftRateMs: 0,
    totalNotes: 0,
    greenNotes: 0,
    yellowNotes: 0,
    redNotes: 0,
    deviationsPerMeasure: [],
  );

  Map<String, dynamic> toJson() => {
    'averageDeviationMs': averageDeviationMs,
    'stdDeviationMs': stdDeviationMs,
    'consistencyScore': consistencyScore,
    'driftDirection': driftDirection,
    'driftRateMs': driftRateMs,
    'totalNotes': totalNotes,
    'greenNotes': greenNotes,
    'yellowNotes': yellowNotes,
    'redNotes': redNotes,
    'deviationsPerMeasure': deviationsPerMeasure,
  };

  factory TimingMetrics.fromJson(Map<String, dynamic> json) => TimingMetrics(
    averageDeviationMs: (json['averageDeviationMs'] as num).toDouble(),
    stdDeviationMs: (json['stdDeviationMs'] as num).toDouble(),
    consistencyScore: json['consistencyScore'] as int,
    driftDirection: json['driftDirection'] as String,
    driftRateMs: (json['driftRateMs'] as num).toDouble(),
    totalNotes: json['totalNotes'] as int,
    greenNotes: json['greenNotes'] as int,
    yellowNotes: json['yellowNotes'] as int,
    redNotes: json['redNotes'] as int,
    deviationsPerMeasure: (json['deviationsPerMeasure'] as List)
        .map((e) => (e as num).toDouble())
        .toList(),
  );
}
