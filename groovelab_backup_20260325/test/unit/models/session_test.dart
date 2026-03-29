import 'package:flutter_test/flutter_test.dart';
import 'package:groovelab/models/session.dart';

void main() {
  group('PracticeSession', () {
    // ── Creation ──

    group('creation', () {
      test('stores all required fields', () {
        final session = PracticeSession(
          id: 'session-1',
          startTime: DateTime(2025, 6, 15, 10, 0),
          endTime: DateTime(2025, 6, 15, 10, 30),
          bpmStart: 100,
          bpmEnd: 120,
          timeSignature: '4/4',
        );

        expect(session.id, 'session-1');
        expect(session.bpmStart, 100);
        expect(session.bpmEnd, 120);
        expect(session.timeSignature, '4/4');
      });

      test('optional fields default correctly', () {
        final session = PracticeSession(
          id: 'session-2',
          startTime: DateTime(2025, 1, 1),
          endTime: DateTime(2025, 1, 1, 0, 5),
          bpmStart: 120,
          bpmEnd: 120,
          timeSignature: '4/4',
        );

        expect(session.drumStyle, '');
        expect(session.takesRecorded, 0);
        expect(session.averageDeviation, isNull);
        expect(session.consistencyScore, isNull);
        expect(session.driftDirection, isNull);
      });

      test('stores optional timing analysis fields', () {
        final session = PracticeSession(
          id: 'session-3',
          startTime: DateTime(2025, 1, 1),
          endTime: DateTime(2025, 1, 1, 0, 10),
          bpmStart: 90,
          bpmEnd: 95,
          timeSignature: '3/4',
          drumStyle: 'Jazz',
          takesRecorded: 5,
          averageDeviation: 7.3,
          consistencyScore: 88.5,
          driftDirection: 'rushing',
        );

        expect(session.drumStyle, 'Jazz');
        expect(session.takesRecorded, 5);
        expect(session.averageDeviation, 7.3);
        expect(session.consistencyScore, 88.5);
        expect(session.driftDirection, 'rushing');
      });
    });

    // ── Duration ──

    group('duration computation', () {
      test('calculates exact minute durations', () {
        final session = PracticeSession(
          id: 'dur-1',
          startTime: DateTime(2025, 1, 1, 14, 0, 0),
          endTime: DateTime(2025, 1, 1, 14, 15, 0),
          bpmStart: 120,
          bpmEnd: 120,
          timeSignature: '4/4',
        );

        expect(session.duration, const Duration(minutes: 15));
      });

      test('handles sub-second precision', () {
        final start = DateTime(2025, 1, 1, 10, 0, 0, 0);
        final end = DateTime(2025, 1, 1, 10, 0, 0, 500);

        final session = PracticeSession(
          id: 'dur-2',
          startTime: start,
          endTime: end,
          bpmStart: 120,
          bpmEnd: 120,
          timeSignature: '4/4',
        );

        expect(session.duration.inMilliseconds, 500);
      });

      test('zero duration when start equals end', () {
        final t = DateTime(2025, 6, 1, 12, 0);
        final session = PracticeSession(
          id: 'dur-3',
          startTime: t,
          endTime: t,
          bpmStart: 120,
          bpmEnd: 120,
          timeSignature: '4/4',
        );

        expect(session.duration, Duration.zero);
      });

      test('handles long sessions (hours)', () {
        final session = PracticeSession(
          id: 'dur-4',
          startTime: DateTime(2025, 1, 1, 8, 0),
          endTime: DateTime(2025, 1, 1, 10, 30),
          bpmStart: 60,
          bpmEnd: 180,
          timeSignature: '4/4',
        );

        expect(session.duration, const Duration(hours: 2, minutes: 30));
      });
    });

    // ── JSON round-trip ──

    group('JSON serialization', () {
      test('toJson includes all fields', () {
        final session = PracticeSession(
          id: 'json-1',
          startTime: DateTime.utc(2025, 3, 15, 9, 30),
          endTime: DateTime.utc(2025, 3, 15, 10, 0),
          bpmStart: 80,
          bpmEnd: 100,
          timeSignature: '6/8',
          drumStyle: 'Blues',
          takesRecorded: 3,
          averageDeviation: 12.4,
          consistencyScore: 72.0,
          driftDirection: 'dragging',
        );

        final json = session.toJson();

        expect(json['id'], 'json-1');
        expect(json['bpmStart'], 80);
        expect(json['bpmEnd'], 100);
        expect(json['timeSignature'], '6/8');
        expect(json['drumStyle'], 'Blues');
        expect(json['takesRecorded'], 3);
        expect(json['averageDeviation'], 12.4);
        expect(json['consistencyScore'], 72.0);
        expect(json['driftDirection'], 'dragging');
      });

      test('full round-trip preserves all data', () {
        final original = PracticeSession(
          id: 'rt-1',
          startTime: DateTime.utc(2025, 7, 4, 18, 0, 0),
          endTime: DateTime.utc(2025, 7, 4, 18, 45, 30),
          bpmStart: 72,
          bpmEnd: 144,
          timeSignature: '7/8',
          drumStyle: 'Afrobeat',
          takesRecorded: 12,
          averageDeviation: 5.67,
          consistencyScore: 91.2,
          driftDirection: 'steady',
        );

        final restored = PracticeSession.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.startTime, original.startTime);
        expect(restored.endTime, original.endTime);
        expect(restored.bpmStart, original.bpmStart);
        expect(restored.bpmEnd, original.bpmEnd);
        expect(restored.timeSignature, original.timeSignature);
        expect(restored.drumStyle, original.drumStyle);
        expect(restored.takesRecorded, original.takesRecorded);
        expect(restored.averageDeviation, original.averageDeviation);
        expect(restored.consistencyScore, original.consistencyScore);
        expect(restored.driftDirection, original.driftDirection);
        expect(restored.duration, original.duration);
      });

      test('round-trip with null optional fields', () {
        final original = PracticeSession(
          id: 'rt-null',
          startTime: DateTime.utc(2025, 1, 1),
          endTime: DateTime.utc(2025, 1, 1, 0, 5),
          bpmStart: 120,
          bpmEnd: 120,
          timeSignature: '4/4',
        );

        final restored = PracticeSession.fromJson(original.toJson());

        expect(restored.averageDeviation, isNull);
        expect(restored.consistencyScore, isNull);
        expect(restored.driftDirection, isNull);
        expect(restored.drumStyle, '');
        expect(restored.takesRecorded, 0);
      });

      test('fromJson handles missing optional keys gracefully', () {
        final json = {
          'id': 'compat-1',
          'startTime': '2025-01-01T00:00:00.000',
          'endTime': '2025-01-01T00:10:00.000',
          'bpmStart': 120,
          'bpmEnd': 120,
          'timeSignature': '4/4',
          // drumStyle, takesRecorded, averageDeviation, etc. omitted
        };

        final session = PracticeSession.fromJson(json);

        expect(session.drumStyle, '');
        expect(session.takesRecorded, 0);
        expect(session.averageDeviation, isNull);
        expect(session.consistencyScore, isNull);
        expect(session.driftDirection, isNull);
      });

      test('fromJson handles num type for double fields', () {
        final json = {
          'id': 'num-1',
          'startTime': '2025-01-01T00:00:00.000',
          'endTime': '2025-01-01T00:10:00.000',
          'bpmStart': 120,
          'bpmEnd': 120,
          'timeSignature': '4/4',
          'averageDeviation': 5, // int instead of double
          'consistencyScore': 80, // int instead of double
        };

        final session = PracticeSession.fromJson(json);

        expect(session.averageDeviation, 5.0);
        expect(session.consistencyScore, 80.0);
      });
    });

    // ── BPM edge cases ──

    group('BPM boundary values', () {
      test('very slow tempo (Grave range)', () {
        final session = PracticeSession(
          id: 'bpm-slow',
          startTime: DateTime(2025, 1, 1),
          endTime: DateTime(2025, 1, 1, 0, 30),
          bpmStart: 20,
          bpmEnd: 20,
          timeSignature: '4/4',
        );

        expect(session.bpmStart, 20);
        final restored = PracticeSession.fromJson(session.toJson());
        expect(restored.bpmStart, 20);
      });

      test('very fast tempo (Prestissimo range)', () {
        final session = PracticeSession(
          id: 'bpm-fast',
          startTime: DateTime(2025, 1, 1),
          endTime: DateTime(2025, 1, 1, 0, 5),
          bpmStart: 300,
          bpmEnd: 300,
          timeSignature: '4/4',
        );

        expect(session.bpmStart, 300);
        final restored = PracticeSession.fromJson(session.toJson());
        expect(restored.bpmStart, 300);
      });
    });

    // ── Drift direction values ──

    group('drift direction', () {
      test('supports rushing value', () {
        final session = PracticeSession(
          id: 'drift-1',
          startTime: DateTime(2025, 1, 1),
          endTime: DateTime(2025, 1, 1, 0, 5),
          bpmStart: 120,
          bpmEnd: 120,
          timeSignature: '4/4',
          driftDirection: 'rushing',
        );

        final restored = PracticeSession.fromJson(session.toJson());
        expect(restored.driftDirection, 'rushing');
      });

      test('supports dragging value', () {
        final session = PracticeSession(
          id: 'drift-2',
          startTime: DateTime(2025, 1, 1),
          endTime: DateTime(2025, 1, 1, 0, 5),
          bpmStart: 120,
          bpmEnd: 120,
          timeSignature: '4/4',
          driftDirection: 'dragging',
        );

        final restored = PracticeSession.fromJson(session.toJson());
        expect(restored.driftDirection, 'dragging');
      });

      test('supports steady value', () {
        final session = PracticeSession(
          id: 'drift-3',
          startTime: DateTime(2025, 1, 1),
          endTime: DateTime(2025, 1, 1, 0, 5),
          bpmStart: 120,
          bpmEnd: 120,
          timeSignature: '4/4',
          driftDirection: 'steady',
        );

        final restored = PracticeSession.fromJson(session.toJson());
        expect(restored.driftDirection, 'steady');
      });
    });
  });
}
