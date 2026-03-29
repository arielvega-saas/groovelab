import 'package:flutter_test/flutter_test.dart';
import 'package:groovelab/models/timing_data.dart';

void main() {
  // ── NoteOnset ──

  group('NoteOnset', () {
    group('quality thresholds', () {
      test('deviation under 10ms is green', () {
        const onset = NoteOnset(
          timestampUs: 500000,
          expectedBeatUs: 500000,
          deviationMs: 0.0,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 0.8,
        );
        expect(onset.quality, TimingQuality.green);
      });

      test('deviation of exactly 9.99ms is green', () {
        const onset = NoteOnset(
          timestampUs: 509990,
          expectedBeatUs: 500000,
          deviationMs: 9.99,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 0.8,
        );
        expect(onset.quality, TimingQuality.green);
      });

      test('deviation of exactly 10ms is yellow', () {
        const onset = NoteOnset(
          timestampUs: 510000,
          expectedBeatUs: 500000,
          deviationMs: 10.0,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 0.8,
        );
        expect(onset.quality, TimingQuality.yellow);
      });

      test('deviation of 29.99ms is yellow', () {
        const onset = NoteOnset(
          timestampUs: 529990,
          expectedBeatUs: 500000,
          deviationMs: 29.99,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 0.8,
        );
        expect(onset.quality, TimingQuality.yellow);
      });

      test('deviation of 30ms is red', () {
        const onset = NoteOnset(
          timestampUs: 530000,
          expectedBeatUs: 500000,
          deviationMs: 30.0,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 0.8,
        );
        expect(onset.quality, TimingQuality.red);
      });

      test('large deviation is red', () {
        const onset = NoteOnset(
          timestampUs: 600000,
          expectedBeatUs: 500000,
          deviationMs: 100.0,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 0.8,
        );
        expect(onset.quality, TimingQuality.red);
      });

      test('negative deviation uses absolute value for quality', () {
        const earlyGreen = NoteOnset(
          timestampUs: 495000,
          expectedBeatUs: 500000,
          deviationMs: -5.0,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 0.8,
        );
        expect(earlyGreen.quality, TimingQuality.green);

        const earlyYellow = NoteOnset(
          timestampUs: 485000,
          expectedBeatUs: 500000,
          deviationMs: -15.0,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 0.8,
        );
        expect(earlyYellow.quality, TimingQuality.yellow);

        const earlyRed = NoteOnset(
          timestampUs: 465000,
          expectedBeatUs: 500000,
          deviationMs: -35.0,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 0.8,
        );
        expect(earlyRed.quality, TimingQuality.red);
      });

      test('zero deviation is green (perfect hit)', () {
        const onset = NoteOnset(
          timestampUs: 500000,
          expectedBeatUs: 500000,
          deviationMs: 0.0,
          beatIndex: 0,
          measureIndex: 0,
          amplitude: 1.0,
        );
        expect(onset.quality, TimingQuality.green);
      });
    });

    group('JSON serialization', () {
      test('toJson produces all required fields', () {
        const onset = NoteOnset(
          timestampUs: 1000000,
          expectedBeatUs: 1000500,
          deviationMs: -0.5,
          beatIndex: 2,
          measureIndex: 3,
          amplitude: 0.75,
        );

        final json = onset.toJson();

        expect(json['timestampUs'], 1000000);
        expect(json['expectedBeatUs'], 1000500);
        expect(json['deviationMs'], -0.5);
        expect(json['beatIndex'], 2);
        expect(json['measureIndex'], 3);
        expect(json['amplitude'], 0.75);
      });

      test('fromJson round-trip preserves all values', () {
        const original = NoteOnset(
          timestampUs: 2500000,
          expectedBeatUs: 2500100,
          deviationMs: 0.1,
          beatIndex: 3,
          measureIndex: 7,
          amplitude: 0.92,
        );

        final restored = NoteOnset.fromJson(original.toJson());

        expect(restored.timestampUs, original.timestampUs);
        expect(restored.expectedBeatUs, original.expectedBeatUs);
        expect(restored.deviationMs, original.deviationMs);
        expect(restored.beatIndex, original.beatIndex);
        expect(restored.measureIndex, original.measureIndex);
        expect(restored.amplitude, original.amplitude);
      });

      test('fromJson handles num types (int stored as double)', () {
        final json = {
          'timestampUs': 1000000,
          'expectedBeatUs': 1000000,
          'deviationMs': 5, // int instead of double
          'beatIndex': 0,
          'measureIndex': 0,
          'amplitude': 1, // int instead of double
        };

        final onset = NoteOnset.fromJson(json);

        expect(onset.deviationMs, 5.0);
        expect(onset.amplitude, 1.0);
      });
    });
  });

  // ── TimingMetrics ──

  group('TimingMetrics', () {
    group('factory empty', () {
      test('produces zeroed metrics with steady drift', () {
        final empty = TimingMetrics.empty();

        expect(empty.averageDeviationMs, 0.0);
        expect(empty.stdDeviationMs, 0.0);
        expect(empty.consistencyScore, 0);
        expect(empty.driftDirection, 'steady');
        expect(empty.driftRateMs, 0.0);
        expect(empty.totalNotes, 0);
        expect(empty.greenNotes, 0);
        expect(empty.yellowNotes, 0);
        expect(empty.redNotes, 0);
        expect(empty.deviationsPerMeasure, isEmpty);
      });
    });

    group('JSON serialization', () {
      test('toJson round-trip preserves all fields', () {
        const original = TimingMetrics(
          averageDeviationMs: 3.14,
          stdDeviationMs: 7.21,
          consistencyScore: 85,
          driftDirection: 'rushing',
          driftRateMs: -1.5,
          totalNotes: 64,
          greenNotes: 48,
          yellowNotes: 12,
          redNotes: 4,
          deviationsPerMeasure: [1.0, 2.5, -0.3, 4.1],
        );

        final json = original.toJson();
        final restored = TimingMetrics.fromJson(json);

        expect(restored.averageDeviationMs, original.averageDeviationMs);
        expect(restored.stdDeviationMs, original.stdDeviationMs);
        expect(restored.consistencyScore, original.consistencyScore);
        expect(restored.driftDirection, original.driftDirection);
        expect(restored.driftRateMs, original.driftRateMs);
        expect(restored.totalNotes, original.totalNotes);
        expect(restored.greenNotes, original.greenNotes);
        expect(restored.yellowNotes, original.yellowNotes);
        expect(restored.redNotes, original.redNotes);
        expect(restored.deviationsPerMeasure, original.deviationsPerMeasure);
      });

      test('fromJson handles integer values for double fields', () {
        final json = {
          'averageDeviationMs': 3,
          'stdDeviationMs': 7,
          'consistencyScore': 85,
          'driftDirection': 'dragging',
          'driftRateMs': 2,
          'totalNotes': 10,
          'greenNotes': 5,
          'yellowNotes': 3,
          'redNotes': 2,
          'deviationsPerMeasure': [1, 2, 3],
        };

        final metrics = TimingMetrics.fromJson(json);

        expect(metrics.averageDeviationMs, 3.0);
        expect(metrics.stdDeviationMs, 7.0);
        expect(metrics.driftRateMs, 2.0);
        expect(metrics.deviationsPerMeasure, [1.0, 2.0, 3.0]);
      });

      test('empty metrics survive JSON round-trip', () {
        final empty = TimingMetrics.empty();
        final restored = TimingMetrics.fromJson(empty.toJson());

        expect(restored.totalNotes, 0);
        expect(restored.driftDirection, 'steady');
        expect(restored.deviationsPerMeasure, isEmpty);
      });
    });

    group('note color counts', () {
      test('note counts add up to totalNotes', () {
        const metrics = TimingMetrics(
          averageDeviationMs: 5.0,
          stdDeviationMs: 10.0,
          consistencyScore: 80,
          driftDirection: 'steady',
          driftRateMs: 0.0,
          totalNotes: 100,
          greenNotes: 60,
          yellowNotes: 30,
          redNotes: 10,
          deviationsPerMeasure: [],
        );

        expect(
          metrics.greenNotes + metrics.yellowNotes + metrics.redNotes,
          metrics.totalNotes,
        );
      });
    });

    group('consistency score bounds', () {
      test('score is within 0-100 range for typical values', () {
        const metrics = TimingMetrics(
          averageDeviationMs: 12.0,
          stdDeviationMs: 25.0,
          consistencyScore: 50,
          driftDirection: 'steady',
          driftRateMs: 0.0,
          totalNotes: 32,
          greenNotes: 10,
          yellowNotes: 12,
          redNotes: 10,
          deviationsPerMeasure: [],
        );

        expect(metrics.consistencyScore, greaterThanOrEqualTo(0));
        expect(metrics.consistencyScore, lessThanOrEqualTo(100));
      });
    });
  });

  // ── TimingQuality enum ──

  group('TimingQuality', () {
    test('has exactly three values', () {
      expect(TimingQuality.values.length, 3);
    });

    test('values are green, yellow, red', () {
      expect(TimingQuality.values, contains(TimingQuality.green));
      expect(TimingQuality.values, contains(TimingQuality.yellow));
      expect(TimingQuality.values, contains(TimingQuality.red));
    });
  });
}
