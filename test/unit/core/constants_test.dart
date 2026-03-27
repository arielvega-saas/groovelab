import 'package:flutter_test/flutter_test.dart';
import 'package:groovelab/core/constants.dart';

void main() {
  // ── Drum Patterns ──

  group('drumPatterns', () {
    test('every drum style has a corresponding pattern', () {
      for (final style in drumStyles) {
        expect(drumPatterns.containsKey(style), isTrue,
            reason: 'Missing pattern for drum style: $style');
      }
    });

    test('every pattern has kick, snare, hihat, ride tracks', () {
      for (final entry in drumPatterns.entries) {
        final pattern = entry.value;
        expect(pattern.containsKey('kick'), isTrue,
            reason: '${entry.key} missing kick track');
        expect(pattern.containsKey('snare'), isTrue,
            reason: '${entry.key} missing snare track');
        expect(pattern.containsKey('hihat'), isTrue,
            reason: '${entry.key} missing hihat track');
        expect(pattern.containsKey('ride'), isTrue,
            reason: '${entry.key} missing ride track');
      }
    });

    test('all pattern tracks have 16 steps (standard 4/4 grid)', () {
      for (final entry in drumPatterns.entries) {
        for (final trackEntry in entry.value.entries) {
          expect(trackEntry.value.length, 16,
              reason:
                  '${entry.key}/${trackEntry.key} has ${trackEntry.value.length} steps, expected 16');
        }
      }
    });

    test('pattern values are only 0 or 1', () {
      for (final entry in drumPatterns.entries) {
        for (final trackEntry in entry.value.entries) {
          for (int i = 0; i < trackEntry.value.length; i++) {
            final val = trackEntry.value[i];
            expect(val == 0 || val == 1, isTrue,
                reason:
                    '${entry.key}/${trackEntry.key}[$i] = $val, expected 0 or 1');
          }
        }
      }
    });

    test('no pattern has all tracks silent', () {
      for (final entry in drumPatterns.entries) {
        final totalHits = entry.value.values
            .expand((steps) => steps)
            .reduce((a, b) => a + b);
        expect(totalHits, greaterThan(0),
            reason: '${entry.key} pattern is completely silent');
      }
    });

    test('every pattern has at least one kick hit', () {
      for (final entry in drumPatterns.entries) {
        final kickHits = entry.value['kick']!.reduce((a, b) => a + b);
        expect(kickHits, greaterThan(0),
            reason: '${entry.key} has no kick hits');
      }
    });
  });

  // ── Drum pattern utility functions ──

  group('drumStepsPerBeat', () {
    test('quarter note denominator gives 4 steps per beat', () {
      expect(drumStepsPerBeat(4), 4);
    });

    test('eighth note denominator gives 2 steps per beat', () {
      expect(drumStepsPerBeat(8), 2);
    });
  });

  group('drumTotalSteps', () {
    test('4/4 time gives 16 steps', () {
      expect(drumTotalSteps(4, 4), 16);
    });

    test('3/4 time gives 12 steps', () {
      expect(drumTotalSteps(3, 4), 12);
    });

    test('6/8 time gives 12 steps', () {
      expect(drumTotalSteps(6, 8), 12);
    });

    test('7/8 time gives 14 steps', () {
      expect(drumTotalSteps(7, 8), 14);
    });

    test('5/4 time gives 20 steps', () {
      expect(drumTotalSteps(5, 4), 20);
    });

    test('12/8 time gives 24 steps', () {
      expect(drumTotalSteps(12, 8), 24);
    });
  });

  group('adaptDrumPattern', () {
    test('returns same pattern when totalSteps matches', () {
      final source = drumPatterns['Rock']!;
      final adapted = adaptDrumPattern(source, 16);

      for (final track in source.keys) {
        expect(adapted[track], source[track]);
      }
    });

    test('pads with zeros when expanding to more steps', () {
      final source = drumPatterns['Rock']!;
      final adapted = adaptDrumPattern(source, 20);

      for (final track in adapted.keys) {
        expect(adapted[track]!.length, 20);
        // Original 16 steps preserved
        for (int i = 0; i < 16; i++) {
          expect(adapted[track]![i], source[track]![i]);
        }
        // Extra steps are zero
        for (int i = 16; i < 20; i++) {
          expect(adapted[track]![i], 0);
        }
      }
    });

    test('truncates when reducing to fewer steps', () {
      final source = drumPatterns['Rock']!;
      final adapted = adaptDrumPattern(source, 12);

      for (final track in adapted.keys) {
        expect(adapted[track]!.length, 12);
        for (int i = 0; i < 12; i++) {
          expect(adapted[track]![i], source[track]![i]);
        }
      }
    });
  });

  // ── Time Signatures ──

  group('timeSignatures', () {
    test('contains common time signatures', () {
      final labels = timeSignatures.map((ts) => ts.label).toList();

      expect(labels, contains('4/4'));
      expect(labels, contains('3/4'));
      expect(labels, contains('6/8'));
    });

    test('label matches num/den format', () {
      for (final ts in timeSignatures) {
        expect(ts.label, '${ts.num}/${ts.den}');
      }
    });

    test('numerator is positive', () {
      for (final ts in timeSignatures) {
        expect(ts.num, greaterThan(0),
            reason: '${ts.label} has non-positive numerator');
      }
    });

    test('denominator is a power of 2 (standard notation)', () {
      const validDenominators = {1, 2, 4, 8, 16, 32};
      for (final ts in timeSignatures) {
        expect(validDenominators.contains(ts.den), isTrue,
            reason:
                '${ts.label} denominator ${ts.den} is not a standard power of 2');
      }
    });

    test('no duplicate time signatures', () {
      final labels = timeSignatures.map((ts) => ts.label).toList();
      expect(labels.toSet().length, labels.length,
          reason: 'Duplicate time signatures found');
    });
  });

  // ── Tempo Markings ──

  group('tempoMarkings', () {
    test('are sorted by min value ascending', () {
      for (int i = 1; i < tempoMarkings.length; i++) {
        expect(tempoMarkings[i].min, greaterThanOrEqualTo(tempoMarkings[i - 1].min),
            reason:
                '${tempoMarkings[i].name} min (${tempoMarkings[i].min}) is not >= ${tempoMarkings[i - 1].name} min (${tempoMarkings[i - 1].min})');
      }
    });

    test('ranges are contiguous (no gaps)', () {
      for (int i = 1; i < tempoMarkings.length; i++) {
        expect(tempoMarkings[i].min, tempoMarkings[i - 1].max,
            reason:
                'Gap between ${tempoMarkings[i - 1].name} (max=${tempoMarkings[i - 1].max}) and ${tempoMarkings[i].name} (min=${tempoMarkings[i].min})');
      }
    });

    test('min is less than max for each marking', () {
      for (final m in tempoMarkings) {
        expect(m.min, lessThan(m.max),
            reason: '${m.name} has min >= max');
      }
    });

    test('cover the standard BPM range from 20 to 500', () {
      expect(tempoMarkings.first.min, lessThanOrEqualTo(20));
      expect(tempoMarkings.last.max, greaterThanOrEqualTo(300));
    });

    test('each marking has a non-empty name', () {
      for (final m in tempoMarkings) {
        expect(m.name.isNotEmpty, isTrue);
      }
    });
  });

  // ── getTempoName ──

  group('getTempoName', () {
    test('returns Grave for very slow tempos', () {
      expect(getTempoName(20), 'Grave');
      expect(getTempoName(39), 'Grave');
    });

    test('returns Moderato for 108-119 BPM', () {
      expect(getTempoName(108), 'Moderato');
      expect(getTempoName(119), 'Moderato');
    });

    test('returns Allegro for 120 BPM', () {
      expect(getTempoName(120), 'Allegro');
    });

    test('returns Presto for fast tempos', () {
      expect(getTempoName(180), 'Presto');
    });

    test('returns Prestissimo for tempos >= 200', () {
      expect(getTempoName(200), 'Prestissimo');
      expect(getTempoName(300), 'Prestissimo');
    });

    test('returns Prestissimo for tempos above all ranges', () {
      expect(getTempoName(999), 'Prestissimo');
    });

    test('boundary values resolve correctly', () {
      // Each marking uses >= min and < max
      expect(getTempoName(40), 'Largo'); // exactly at boundary
      expect(getTempoName(60), 'Larghetto');
      expect(getTempoName(66), 'Adagio');
      expect(getTempoName(76), 'Andante');
      expect(getTempoName(156), 'Vivace');
      expect(getTempoName(176), 'Presto');
    });
  });

  // ── Drum Styles & Click Sounds ──

  group('drumStyles', () {
    test('is non-empty', () {
      expect(drumStyles, isNotEmpty);
    });

    test('contains no duplicates', () {
      expect(drumStyles.toSet().length, drumStyles.length);
    });

    test('contains common genres', () {
      expect(drumStyles, contains('Rock'));
      expect(drumStyles, contains('Jazz'));
      expect(drumStyles, contains('Funk'));
      expect(drumStyles, contains('Blues'));
    });
  });

  group('clickSoundNames', () {
    test('is non-empty', () {
      expect(clickSoundNames, isNotEmpty);
    });

    test('contains no duplicates', () {
      expect(clickSoundNames.toSet().length, clickSoundNames.length);
    });

    test('contains the default Wood sound', () {
      expect(clickSoundNames, contains('Wood'));
    });
  });
}
