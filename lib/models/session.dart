class PracticeSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int bpmStart;
  final int bpmEnd;
  final String timeSignature;
  final String drumStyle;
  final int takesRecorded;
  final double? averageDeviation;
  final double? consistencyScore;
  final String? driftDirection; // 'rushing', 'dragging', 'steady'

  PracticeSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.bpmStart,
    required this.bpmEnd,
    required this.timeSignature,
    this.drumStyle = '',
    this.takesRecorded = 0,
    this.averageDeviation,
    this.consistencyScore,
    this.driftDirection,
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'bpmStart': bpmStart,
    'bpmEnd': bpmEnd,
    'timeSignature': timeSignature,
    'drumStyle': drumStyle,
    'takesRecorded': takesRecorded,
    'averageDeviation': averageDeviation,
    'consistencyScore': consistencyScore,
    'driftDirection': driftDirection,
  };

  factory PracticeSession.fromJson(Map<String, dynamic> json) => PracticeSession(
    id: json['id'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    bpmStart: json['bpmStart'] as int,
    bpmEnd: json['bpmEnd'] as int,
    timeSignature: json['timeSignature'] as String,
    drumStyle: json['drumStyle'] as String? ?? '',
    takesRecorded: json['takesRecorded'] as int? ?? 0,
    averageDeviation: (json['averageDeviation'] as num?)?.toDouble(),
    consistencyScore: (json['consistencyScore'] as num?)?.toDouble(),
    driftDirection: json['driftDirection'] as String?,
  );
}
