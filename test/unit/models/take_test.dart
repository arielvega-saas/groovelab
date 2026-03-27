import 'package:flutter_test/flutter_test.dart';
import 'package:groovelab/models/take.dart';
import 'package:groovelab/models/timing_data.dart';

void main() {
  group('Take', () {
    // ── Creation ──

    group('creation', () {
      test('stores all required fields', () {
        final take = Take(
          id: 'take-1',
          sessionId: 'session-1',
          timestamp: DateTime(2025, 6, 15, 10, 5),
          bpm: 120,
          timeSignature: '4/4',
          duration: const Duration(seconds: 30),
        );

        expect(take.id, 'take-1');
        expect(take.sessionId, 'session-1');
        expect(take.bpm, 120);
        expect(take.timeSignature, '4/4');
        expect(take.duration.inSeconds, 30);
      });

      test('optional fields default correctly', () {
        final take = Take(
          id: 'take-2',
          sessionId: 'session-1',
          timestamp: DateTime(2025, 1, 1),
          bpm: 100,
          timeSignature: '3/4',
          duration: const Duration(seconds: 15),
        );

        expect(take.audioFilePath, isNull);
        expect(take.onsets, isEmpty);
        expect(take.metrics, isNull);
        expect(take.isBestTake, false);
      });

      test('stores onsets list', () {
        final onsets = [
          const NoteOnset(
            timestampUs: 500000,
            expectedBeatUs: 500000,
            deviationMs: 0.0,
            beatIndex: 0,
            measureIndex: 0,
            amplitude: 0.8,
          ),
          const NoteOnset(
            timestampUs: 1000000,
            expectedBeatUs: 1000000,
            deviationMs: 0.5,
            beatIndex: 1,
            measureIndex: 0,
            amplitude: 0.7,
          ),
        ];

        final take = Take(
          id: 'take-3',
          sessionId: 'session-1',
          timestamp: DateTime(2025, 1, 1),
          bpm: 120,
          timeSignature: '4/4',
          duration: const Duration(seconds: 8),
          onsets: onsets,
        );

        expect(take.onsets.length, 2);
        expect(take.onsets[0].deviationMs, 0.0);
        expect(take.onsets[1].deviationMs, 0.5);
      });

      test('stores metrics', () {
        const metrics = TimingMetrics(
          averageDeviationMs: 5.0,
          stdDeviationMs: 3.0,
          consistencyScore: 94,
          driftDirection: 'steady',
          driftRateMs: 0.1,
          totalNotes: 32,
          greenNotes: 28,
          yellowNotes: 3,
          redNotes: 1,
          deviationsPerMeasure: [4.0, 5.5, 3.2, 7.1],
        );

        final take = Take(
          id: 'take-4',
          sessionId: 'session-1',
          timestamp: DateTime(2025, 1, 1),
          bpm: 120,
          timeSignature: '4/4',
          duration: const Duration(seconds: 16),
          metrics: metrics,
          isBestTake: true,
        );

        expect(take.metrics, isNotNull);
        expect(take.metrics!.consistencyScore, 94);
        expect(take.isBestTake, true);
      });
    });

    // ── JSON round-trip ──

    group('JSON serialization', () {
      test('toJson includes all fields', () {
        final take = Take(
          id: 'json-1',
          sessionId: 'session-42',
          timestamp: DateTime.utc(2025, 3, 15, 9, 30),
          bpm: 140,
          timeSignature: '6/8',
          duration: const Duration(milliseconds: 8500),
          audioFilePath: '/recordings/take_1.wav',
          isBestTake: true,
        );

        final json = take.toJson();

        expect(json['id'], 'json-1');
        expect(json['sessionId'], 'session-42');
        expect(json['bpm'], 140);
        expect(json['timeSignature'], '6/8');
        expect(json['durationMs'], 8500);
        expect(json['audioFilePath'], '/recordings/take_1.wav');
        expect(json['isBestTake'], true);
      });

      test('duration serializes as milliseconds', () {
        final take = Take(
          id: 'dur-1',
          sessionId: 'session-1',
          timestamp: DateTime.utc(2025, 1, 1),
          bpm: 120,
          timeSignature: '4/4',
          duration: const Duration(seconds: 45, milliseconds: 250),
        );

        final json = take.toJson();
        expect(json['durationMs'], 45250);
      });

      test('full round-trip with no onsets or metrics', () {
        final original = Take(
          id: 'rt-minimal',
          sessionId: 'session-1',
          timestamp: DateTime.utc(2025, 5, 20, 14, 30),
          bpm: 90,
          timeSignature: '3/4',
          duration: const Duration(seconds: 20),
        );

        final restored = Take.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.sessionId, original.sessionId);
        expect(restored.timestamp, original.timestamp);
        expect(restored.bpm, original.bpm);
        expect(restored.timeSignature, original.timeSignature);
        expect(restored.duration, original.duration);
        expect(restored.audioFilePath, isNull);
        expect(restored.onsets, isEmpty);
        expect(restored.metrics, isNull);
        expect(restored.isBestTake, false);
      });

      test('full round-trip with onsets and metrics', () {
        const onsets = [
          NoteOnset(
            timestampUs: 500000,
            expectedBeatUs: 500000,
            deviationMs: 0.0,
            beatIndex: 0,
            measureIndex: 0,
            amplitude: 0.85,
          ),
          NoteOnset(
            timestampUs: 1000200,
            expectedBeatUs: 1000000,
            deviationMs: 0.2,
            beatIndex: 1,
            measureIndex: 0,
            amplitude: 0.72,
          ),
          NoteOnset(
            timestampUs: 1499500,
            expectedBeatUs: 1500000,
            deviationMs: -0.5,
            beatIndex: 2,
            measureIndex: 0,
            amplitude: 0.91,
          ),
        ];

        const metrics = TimingMetrics(
          averageDeviationMs: -0.1,
          stdDeviationMs: 0.35,
          consistencyScore: 99,
          driftDirection: 'steady',
          driftRateMs: 0.02,
          totalNotes: 3,
          greenNotes: 3,
          yellowNotes: 0,
          redNotes: 0,
          deviationsPerMeasure: [-0.1],
        );

        final original = Take(
          id: 'rt-full',
          sessionId: 'session-7',
          timestamp: DateTime.utc(2025, 8, 1, 20, 0),
          bpm: 110,
          timeSignature: '4/4',
          duration: const Duration(seconds: 8),
          audioFilePath: '/path/to/audio.m4a',
          onsets: onsets,
          metrics: metrics,
          isBestTake: true,
        );

        final restored = Take.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.sessionId, original.sessionId);
        expect(restored.audioFilePath, original.audioFilePath);
        expect(restored.isBestTake, true);
        expect(restored.onsets.length, 3);
        expect(restored.onsets[0].deviationMs, 0.0);
        expect(restored.onsets[1].deviationMs, 0.2);
        expect(restored.onsets[2].deviationMs, -0.5);
        expect(restored.metrics, isNotNull);
        expect(restored.metrics!.consistencyScore, 99);
        expect(restored.metrics!.totalNotes, 3);
        expect(restored.metrics!.greenNotes, 3);
        expect(restored.metrics!.deviationsPerMeasure, [-0.1]);
      });

      test('fromJson handles null onsets list', () {
        final json = {
          'id': 'null-onsets',
          'sessionId': 'session-1',
          'timestamp': '2025-01-01T00:00:00.000',
          'bpm': 120,
          'timeSignature': '4/4',
          'durationMs': 5000,
          'audioFilePath': null,
          'onsets': null,
          'metrics': null,
          'isBestTake': false,
        };

        final take = Take.fromJson(json);

        expect(take.onsets, isEmpty);
        expect(take.metrics, isNull);
      });

      test('fromJson handles missing isBestTake (backward compat)', () {
        final json = {
          'id': 'compat-1',
          'sessionId': 'session-1',
          'timestamp': '2025-01-01T00:00:00.000',
          'bpm': 120,
          'timeSignature': '4/4',
          'durationMs': 5000,
        };

        final take = Take.fromJson(json);
        expect(take.isBestTake, false);
      });
    });

    // ── Edge cases for music app ──

    group('music-specific edge cases', () {
      test('very short take (single beat at 60 BPM)', () {
        final take = Take(
          id: 'short-1',
          sessionId: 'session-1',
          timestamp: DateTime(2025, 1, 1),
          bpm: 60,
          timeSignature: '4/4',
          duration: const Duration(seconds: 1),
          onsets: const [
            NoteOnset(
              timestampUs: 0,
              expectedBeatUs: 0,
              deviationMs: 0.0,
              beatIndex: 0,
              measureIndex: 0,
              amplitude: 0.9,
            ),
          ],
        );

        final restored = Take.fromJson(take.toJson());
        expect(restored.onsets.length, 1);
        expect(restored.duration.inSeconds, 1);
      });

      test('fast tempo take (300 BPM)', () {
        // At 300 BPM, beats are 200ms apart
        final take = Take(
          id: 'fast-1',
          sessionId: 'session-1',
          timestamp: DateTime(2025, 1, 1),
          bpm: 300,
          timeSignature: '4/4',
          duration: const Duration(seconds: 4),
        );

        final restored = Take.fromJson(take.toJson());
        expect(restored.bpm, 300);
      });

      test('odd time signature take', () {
        final take = Take(
          id: 'odd-1',
          sessionId: 'session-1',
          timestamp: DateTime(2025, 1, 1),
          bpm: 150,
          timeSignature: '7/8',
          duration: const Duration(seconds: 10),
        );

        final restored = Take.fromJson(take.toJson());
        expect(restored.timeSignature, '7/8');
      });

      test('take with zero duration (edge case)', () {
        final take = Take(
          id: 'zero-dur',
          sessionId: 'session-1',
          timestamp: DateTime(2025, 1, 1),
          bpm: 120,
          timeSignature: '4/4',
          duration: Duration.zero,
        );

        final json = take.toJson();
        expect(json['durationMs'], 0);

        final restored = Take.fromJson(json);
        expect(restored.duration, Duration.zero);
      });
    });
  });
}
