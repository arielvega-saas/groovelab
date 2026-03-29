import 'timing_data.dart';

class Take {
  final String id;
  final String sessionId;
  final DateTime timestamp;
  final int bpm;
  final String timeSignature;
  final Duration duration;
  final String? audioFilePath;
  final List<NoteOnset> onsets;
  final TimingMetrics? metrics;
  final bool isBestTake;

  Take({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.bpm,
    required this.timeSignature,
    required this.duration,
    this.audioFilePath,
    this.onsets = const [],
    this.metrics,
    this.isBestTake = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'bpm': bpm,
    'timeSignature': timeSignature,
    'durationMs': duration.inMilliseconds,
    'audioFilePath': audioFilePath,
    'onsets': onsets.map((o) => o.toJson()).toList(),
    'metrics': metrics?.toJson(),
    'isBestTake': isBestTake,
  };

  factory Take.fromJson(Map<String, dynamic> json) => Take(
    id: json['id'] as String,
    sessionId: json['sessionId'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    bpm: json['bpm'] as int,
    timeSignature: json['timeSignature'] as String,
    duration: Duration(milliseconds: json['durationMs'] as int),
    audioFilePath: json['audioFilePath'] as String?,
    onsets: (json['onsets'] as List?)
        ?.map((o) => NoteOnset.fromJson(o as Map<String, dynamic>))
        .toList() ?? [],
    metrics: json['metrics'] != null
        ? TimingMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
        : null,
    isBestTake: json['isBestTake'] as bool? ?? false,
  );
}
