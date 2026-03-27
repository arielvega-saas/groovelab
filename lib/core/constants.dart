class TempoMarking {
  final int min;
  final int max;
  final String name;
  const TempoMarking(this.min, this.max, this.name);
}

const tempoMarkings = [
  TempoMarking(20, 40, 'Grave'),
  TempoMarking(40, 60, 'Largo'),
  TempoMarking(60, 66, 'Larghetto'),
  TempoMarking(66, 76, 'Adagio'),
  TempoMarking(76, 108, 'Andante'),
  TempoMarking(108, 120, 'Moderato'),
  TempoMarking(120, 156, 'Allegro'),
  TempoMarking(156, 176, 'Vivace'),
  TempoMarking(176, 200, 'Presto'),
  TempoMarking(200, 500, 'Prestissimo'),
];

String getTempoName(int bpm) {
  for (final m in tempoMarkings) {
    if (bpm >= m.min && bpm < m.max) return m.name;
  }
  return 'Prestissimo';
}

class TimeSig {
  final int num;
  final int den;
  final String label;
  const TimeSig(this.num, this.den, this.label);
}

const timeSignatures = [
  TimeSig(2, 4, '2/4'),
  TimeSig(3, 4, '3/4'),
  TimeSig(4, 4, '4/4'),
  TimeSig(5, 4, '5/4'),
  TimeSig(6, 8, '6/8'),
  TimeSig(7, 8, '7/8'),
  TimeSig(9, 8, '9/8'),
  TimeSig(12, 8, '12/8'),
];

const drumStyles = ['Rock', 'Pop', 'Funk', 'Blues', 'Jazz', 'Shuffle', 'Latin', 'Bossa Nova', 'Reggae', 'Metal', 'Afrobeat', 'Swing', 'Hip Hop'];

const clickSoundNames = ['Wood', 'WoodBlock', 'SineBurst', 'Digital', 'Clave', 'Clave HQ', 'Hi-Hat', 'Cowbell', 'Beep', 'Rimshot', 'Shaker', 'Tambourine', 'Stick', 'Tick-Tock', '808 Cowbell'];

typedef DrumPattern = Map<String, List<int>>;

/// Steps per beat based on beat unit: /4 = 4 steps (16th note grid), /8 = 2 steps
int drumStepsPerBeat(int beatUnit) => beatUnit == 8 ? 2 : 4;

/// Total sequencer steps for a time signature
int drumTotalSteps(int beats, int beatUnit) => beats * drumStepsPerBeat(beatUnit);

/// Adapt a 16-step drum pattern to a different step count
DrumPattern adaptDrumPattern(DrumPattern source, int totalSteps) {
  return source.map((track, steps) {
    if (steps.length == totalSteps) return MapEntry(track, steps);
    final adapted = List<int>.generate(totalSteps, (i) =>
      i < steps.length ? steps[i] : 0);
    return MapEntry(track, adapted);
  });
}

final Map<String, DrumPattern> drumPatterns = {
  'Rock': {
    'kick':  [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0],
    'snare': [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    'hihat': [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Pop': {
    'kick':  [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0],
    'snare': [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    'hihat': [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Funk': {
    'kick':  [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0],
    'snare': [0,0,0,0, 1,0,0,1, 0,0,1,0, 1,0,0,0],
    'hihat': [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Blues': {
    'kick':  [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0],
    'snare': [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    'hihat': [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Jazz': {
    'kick':  [1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0],
    'snare': [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
    'hihat': [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0],
    'ride':  [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1],
  },
  'Shuffle': {
    'kick':  [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0],
    'snare': [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    'hihat': [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Latin': {
    'kick':  [1,0,0,0, 0,0,1,0, 0,0,1,0, 0,0,0,0],
    'snare': [0,0,0,1, 0,0,0,0, 0,0,0,1, 0,1,0,0],
    'hihat': [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Bossa Nova': {
    'kick':  [1,0,0,0, 0,0,1,0, 0,1,0,0, 0,0,1,0],
    'snare': [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
    'hihat': [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Reggae': {
    'kick':  [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0],
    'snare': [0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0],
    'hihat': [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Metal': {
    'kick':  [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],
    'snare': [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    'hihat': [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Afrobeat': {
    'kick':  [1,0,0,1, 0,0,1,0, 0,0,1,0, 0,1,0,0],
    'snare': [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    'hihat': [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
  'Swing': {
    'kick':  [1,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0],
    'snare': [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
    'hihat': [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0],
    'ride':  [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1],
  },
  'Hip Hop': {
    'kick':  [1,0,0,0, 0,0,0,1, 0,0,1,0, 0,0,0,0],
    'snare': [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0],
    'hihat': [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1],
    'ride':  [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0],
  },
};
