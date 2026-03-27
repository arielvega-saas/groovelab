// ═══════════════════════════════════════════════════════════════════
//  PAD MODELS - Professional Pad Performance System
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ── Musical Keys ──

const List<String> musicalKeys = [
  'C', 'C#', 'D', 'D#', 'E', 'F',
  'F#', 'G', 'G#', 'A', 'A#', 'B',
];

/// Semitone offset from C for each key
int semitonesFromC(String key) => musicalKeys.indexOf(key);

/// Calculate semitone difference between two keys (shortest path)
int semitoneDistance(String from, String to) {
  final fromIdx = musicalKeys.indexOf(from);
  final toIdx = musicalKeys.indexOf(to);
  if (fromIdx < 0 || toIdx < 0) return 0;
  int diff = toIdx - fromIdx;
  if (diff > 6) diff -= 12;
  if (diff < -6) diff += 12;
  return diff;
}

// ── Transition Modes ──

enum TransitionMode {
  instant,
  smooth,
  worship,
  cinematic,
  manualFade;

  String get label {
    switch (this) {
      case instant: return 'Instant';
      case smooth: return 'Smooth';
      case worship: return 'Worship';
      case cinematic: return 'Cinematic';
      case manualFade: return 'Manual';
    }
  }

  double get defaultDuration {
    switch (this) {
      case instant: return 0.05;
      case smooth: return 1.2;
      case worship: return 2.5;
      case cinematic: return 4.0;
      case manualFade: return 0.0;
    }
  }

  IconData get icon {
    switch (this) {
      case instant: return Icons.flash_on;
      case smooth: return Icons.waves;
      case worship: return Icons.church;
      case cinematic: return Icons.movie;
      case manualFade: return Icons.tune;
    }
  }
}

// ── Pad Key State ──

enum PadKeyState {
  inactive,
  selected,
  playing,
  target,
  transitioning;
}

// ── Sound Categories ──

enum SoundCategory {
  favorites,
  factory,
  worship,
  ambient,
  cinematic,
  warm,
  dark,
  bright,
  organ,
  drone,
  shimmer,
  userImported;

  String get label {
    switch (this) {
      case favorites: return 'Favorites';
      case factory: return 'Factory';
      case worship: return 'Worship';
      case ambient: return 'Ambient';
      case cinematic: return 'Cinematic';
      case warm: return 'Warm';
      case dark: return 'Dark';
      case bright: return 'Bright';
      case organ: return 'Organ';
      case drone: return 'Drone';
      case shimmer: return 'Shimmer';
      case userImported: return 'Imported';
    }
  }

  IconData get icon {
    switch (this) {
      case favorites: return Icons.favorite;
      case factory: return Icons.piano;
      case worship: return Icons.church;
      case ambient: return Icons.air;
      case cinematic: return Icons.movie;
      case warm: return Icons.wb_sunny;
      case dark: return Icons.dark_mode;
      case bright: return Icons.light_mode;
      case organ: return Icons.music_note;
      case drone: return Icons.graphic_eq;
      case shimmer: return Icons.auto_awesome;
      case userImported: return Icons.file_upload;
    }
  }
}

// ── Sound Mood ──

enum SoundMood {
  warm,
  bright,
  deep,
  intimate,
  epic,
  cinematic,
  neutral;

  String get label {
    switch (this) {
      case warm: return 'Warm';
      case bright: return 'Bright';
      case deep: return 'Deep';
      case intimate: return 'Intimate';
      case epic: return 'Epic';
      case cinematic: return 'Cinematic';
      case neutral: return 'Neutral';
    }
  }

  Color get color {
    switch (this) {
      case warm: return const Color(0xFFFF8C42);
      case bright: return const Color(0xFFFFD700);
      case deep: return const Color(0xFF1E3A5F);
      case intimate: return const Color(0xFF9B59B6);
      case epic: return const Color(0xFFE74C3C);
      case cinematic: return const Color(0xFF2C3E50);
      case neutral: return const Color(0xFF95A5A6);
    }
  }
}

// ── Harmonic Type ──

enum HarmonicType {
  rootOnly,
  rootFifth,
  rootOctave,
  majorTexture,
  minorTexture,
  neutralAmbient;

  String get label {
    switch (this) {
      case rootOnly: return 'Root';
      case rootFifth: return 'Root + 5th';
      case rootOctave: return 'Root + Octave';
      case majorTexture: return 'Major';
      case minorTexture: return 'Minor';
      case neutralAmbient: return 'Neutral';
    }
  }
}

// ── Pad Sound ──

class PadSound {
  final int index;
  final String name;
  final SoundCategory category;
  final String originalKey;
  final double duration;
  final bool isFactory;
  final bool isFavorite;
  final SoundMood mood;
  final List<String> tags;

  const PadSound({
    required this.index,
    required this.name,
    this.category = SoundCategory.userImported,
    this.originalKey = 'C',
    this.duration = 0.0,
    this.isFactory = false,
    this.isFavorite = false,
    this.mood = SoundMood.neutral,
    this.tags = const [],
  });

  PadSound copyWith({
    String? name,
    SoundCategory? category,
    String? originalKey,
    double? duration,
    bool? isFactory,
    bool? isFavorite,
    SoundMood? mood,
    List<String>? tags,
  }) {
    return PadSound(
      index: index,
      name: name ?? this.name,
      category: category ?? this.category,
      originalKey: originalKey ?? this.originalKey,
      duration: duration ?? this.duration,
      isFactory: isFactory ?? this.isFactory,
      isFavorite: isFavorite ?? this.isFavorite,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
    );
  }
}

// ── Pad Song (Preset) ──

class PadSong {
  final String id;
  final String title;
  final String key;
  final int? soundIndex;
  final String? soundName;
  final double bpm;
  final bool clickEnabled;
  final double volume;
  final double pan;
  final double fadeInTime;
  final double fadeOutTime;
  final String notes;
  final int colorValue;
  final SoundMood mood;
  final HarmonicType harmonicType;
  final bool isFavorite;
  final TransitionMode transitionMode;

  const PadSong({
    required this.id,
    required this.title,
    this.key = 'C',
    this.soundIndex,
    this.soundName,
    this.bpm = 120,
    this.clickEnabled = false,
    this.volume = 1.0,
    this.pan = 0.0,
    this.fadeInTime = 0.5,
    this.fadeOutTime = 1.0,
    this.notes = '',
    this.colorValue = 0xFF00D4FF,
    this.mood = SoundMood.neutral,
    this.harmonicType = HarmonicType.rootOnly,
    this.isFavorite = false,
    this.transitionMode = TransitionMode.smooth,
  });

  Color get color => Color(colorValue);

  PadSong copyWith({
    String? title,
    String? key,
    int? soundIndex,
    String? soundName,
    double? bpm,
    bool? clickEnabled,
    double? volume,
    double? pan,
    double? fadeInTime,
    double? fadeOutTime,
    String? notes,
    int? colorValue,
    SoundMood? mood,
    HarmonicType? harmonicType,
    bool? isFavorite,
    TransitionMode? transitionMode,
  }) {
    return PadSong(
      id: id,
      title: title ?? this.title,
      key: key ?? this.key,
      soundIndex: soundIndex ?? this.soundIndex,
      soundName: soundName ?? this.soundName,
      bpm: bpm ?? this.bpm,
      clickEnabled: clickEnabled ?? this.clickEnabled,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      fadeInTime: fadeInTime ?? this.fadeInTime,
      fadeOutTime: fadeOutTime ?? this.fadeOutTime,
      notes: notes ?? this.notes,
      colorValue: colorValue ?? this.colorValue,
      mood: mood ?? this.mood,
      harmonicType: harmonicType ?? this.harmonicType,
      isFavorite: isFavorite ?? this.isFavorite,
      transitionMode: transitionMode ?? this.transitionMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'key': key,
    'soundIndex': soundIndex,
    'soundName': soundName,
    'bpm': bpm,
    'clickEnabled': clickEnabled,
    'volume': volume,
    'pan': pan,
    'fadeInTime': fadeInTime,
    'fadeOutTime': fadeOutTime,
    'notes': notes,
    'colorValue': colorValue,
    'mood': mood.index,
    'harmonicType': harmonicType.index,
    'isFavorite': isFavorite,
    'transitionMode': transitionMode.index,
  };

  factory PadSong.fromJson(Map<String, dynamic> json) => PadSong(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    key: json['key'] ?? 'C',
    soundIndex: json['soundIndex'],
    soundName: json['soundName'],
    bpm: (json['bpm'] ?? 120).toDouble(),
    clickEnabled: json['clickEnabled'] ?? false,
    volume: (json['volume'] ?? 1.0).toDouble(),
    pan: (json['pan'] ?? 0.0).toDouble(),
    fadeInTime: (json['fadeInTime'] ?? 0.5).toDouble(),
    fadeOutTime: (json['fadeOutTime'] ?? 1.0).toDouble(),
    notes: json['notes'] ?? '',
    colorValue: json['colorValue'] ?? 0xFF00D4FF,
    mood: SoundMood.values[json['mood'] ?? 6],
    harmonicType: HarmonicType.values[json['harmonicType'] ?? 0],
    isFavorite: json['isFavorite'] ?? false,
    transitionMode: TransitionMode.values[json['transitionMode'] ?? 1],
  );
}

// ── Pad Setlist ──

class PadSetlist {
  final String id;
  final String name;
  final List<PadSong> songs;
  final bool autoTransition;
  final TransitionMode transitionMode;
  final int colorValue;

  const PadSetlist({
    required this.id,
    required this.name,
    this.songs = const [],
    this.autoTransition = false,
    this.transitionMode = TransitionMode.smooth,
    this.colorValue = 0xFF00D4FF,
  });

  Color get color => Color(colorValue);

  PadSetlist copyWith({
    String? name,
    List<PadSong>? songs,
    bool? autoTransition,
    TransitionMode? transitionMode,
    int? colorValue,
  }) {
    return PadSetlist(
      id: id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
      autoTransition: autoTransition ?? this.autoTransition,
      transitionMode: transitionMode ?? this.transitionMode,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songs': songs.map((s) => s.toJson()).toList(),
    'autoTransition': autoTransition,
    'transitionMode': transitionMode.index,
    'colorValue': colorValue,
  };

  factory PadSetlist.fromJson(Map<String, dynamic> json) => PadSetlist(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    songs: (json['songs'] as List?)?.map((s) => PadSong.fromJson(s)).toList() ?? [],
    autoTransition: json['autoTransition'] ?? false,
    transitionMode: TransitionMode.values[json['transitionMode'] ?? 1],
    colorValue: json['colorValue'] ?? 0xFF00D4FF,
  );
}

// ── Mixer Channel ──

class PadMixerChannel {
  final String name;
  final double volume;
  final double pan;
  final bool muted;
  final bool solo;
  final IconData icon;

  const PadMixerChannel({
    required this.name,
    this.volume = 1.0,
    this.pan = 0.0,
    this.muted = false,
    this.solo = false,
    this.icon = Icons.music_note,
  });

  PadMixerChannel copyWith({
    String? name,
    double? volume,
    double? pan,
    bool? muted,
    bool? solo,
  }) {
    return PadMixerChannel(
      name: name ?? this.name,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      muted: muted ?? this.muted,
      solo: solo ?? this.solo,
      icon: icon,
    );
  }
}

// ── Pad Sub-View ──

enum PadSubView {
  live,
  setlist,
  sounds,
  mixer,
  stage;

  String get label {
    switch (this) {
      case live: return 'Live';
      case setlist: return 'Setlist';
      case sounds: return 'Sounds';
      case mixer: return 'Mixer';
      case stage: return 'Stage';
    }
  }

  IconData get icon {
    switch (this) {
      case live: return Icons.grid_view_rounded;
      case setlist: return Icons.queue_music;
      case sounds: return Icons.library_music;
      case mixer: return Icons.tune;
      case stage: return Icons.stadium;
    }
  }
}

// ── Song Color Presets ──

const List<int> songColorPresets = [
  0xFF00D4FF, // cyan
  0xFF00FF88, // green
  0xFFFF6B35, // orange
  0xFFFF3B5C, // red
  0xFFFFB020, // amber
  0xFF9B59B6, // purple
  0xFF3498DB, // blue
  0xFF1ABC9C, // teal
  0xFFE91E63, // pink
  0xFF8BC34A, // lime
];

// ── Factory C Major Pads — built-in default library ──

/// Factory pads in C Major scale. These are the preloaded default pads
/// available on first launch. They are read-only and cannot be deleted.
const List<PadSong> kFactoryCMajorPads = [
  PadSong(
    id: 'factory_c4',
    title: 'Do — C4',
    key: 'C',
    bpm: 120,
    volume: 1.0,
    pan: 0.0,
    colorValue: 0xFF00E5FF, // neon cyan
    mood: SoundMood.neutral,
    harmonicType: HarmonicType.rootOnly,
    transitionMode: TransitionMode.smooth,
    notes: 'C Major — Root',
    fadeInTime: 0.3,
    fadeOutTime: 1.5,
  ),
  PadSong(
    id: 'factory_d4',
    title: 'Re — D4',
    key: 'D',
    bpm: 120,
    volume: 1.0,
    pan: 0.0,
    colorValue: 0xFF00FF11, // neon green
    mood: SoundMood.bright,
    harmonicType: HarmonicType.rootOnly,
    transitionMode: TransitionMode.smooth,
    notes: 'C Major — 2nd',
    fadeInTime: 0.3,
    fadeOutTime: 1.5,
  ),
  PadSong(
    id: 'factory_e4',
    title: 'Mi — E4',
    key: 'E',
    bpm: 120,
    volume: 1.0,
    pan: 0.0,
    colorValue: 0xFFFF9500, // orange
    mood: SoundMood.warm,
    harmonicType: HarmonicType.rootOnly,
    transitionMode: TransitionMode.smooth,
    notes: 'C Major — 3rd',
    fadeInTime: 0.3,
    fadeOutTime: 1.5,
  ),
  PadSong(
    id: 'factory_f4',
    title: 'Fa — F4',
    key: 'F',
    bpm: 120,
    volume: 1.0,
    pan: 0.0,
    colorValue: 0xFFFF6B35, // red-orange
    mood: SoundMood.warm,
    harmonicType: HarmonicType.rootOnly,
    transitionMode: TransitionMode.smooth,
    notes: 'C Major — 4th',
    fadeInTime: 0.3,
    fadeOutTime: 1.5,
  ),
  PadSong(
    id: 'factory_g4',
    title: 'Sol — G4',
    key: 'G',
    bpm: 120,
    volume: 1.0,
    pan: 0.0,
    colorValue: 0xFF4FC3F7, // sky blue
    mood: SoundMood.bright,
    harmonicType: HarmonicType.rootOnly,
    transitionMode: TransitionMode.smooth,
    notes: 'C Major — 5th',
    fadeInTime: 0.3,
    fadeOutTime: 1.5,
  ),
  PadSong(
    id: 'factory_a4',
    title: 'La — A4',
    key: 'A',
    bpm: 120,
    volume: 1.0,
    pan: 0.0,
    colorValue: 0xFFE040FB, // purple
    mood: SoundMood.intimate,
    harmonicType: HarmonicType.rootOnly,
    transitionMode: TransitionMode.smooth,
    notes: 'C Major — 6th',
    fadeInTime: 0.3,
    fadeOutTime: 1.5,
  ),
  PadSong(
    id: 'factory_b4',
    title: 'Si — B4',
    key: 'B',
    bpm: 120,
    volume: 1.0,
    pan: 0.0,
    colorValue: 0xFFFFB020, // amber
    mood: SoundMood.warm,
    harmonicType: HarmonicType.rootOnly,
    transitionMode: TransitionMode.smooth,
    notes: 'C Major — 7th',
    fadeInTime: 0.3,
    fadeOutTime: 1.5,
  ),
  PadSong(
    id: 'factory_c5',
    title: 'Do — C5',
    key: 'C',
    bpm: 120,
    volume: 1.0,
    pan: 0.0,
    colorValue: 0xFF00E5FF, // neon cyan (octave)
    mood: SoundMood.bright,
    harmonicType: HarmonicType.rootOctave,
    transitionMode: TransitionMode.smooth,
    notes: 'C Major — Octave',
    fadeInTime: 0.3,
    fadeOutTime: 1.5,
  ),
];

/// IDs of all factory pads (used to prevent deletion).
final Set<String> kFactoryPadIds = kFactoryCMajorPads.map((p) => p.id).toSet();

// ── Factory Ambient Pad Assets — bundled audio library ──

/// Metadata for a factory ambient pad that is loaded from the web/pads/ folder.
class FactoryPadAsset {
  final String id;
  final String name;
  final String urlPath;  // relative URL, e.g. "pads/cello_c.mp3"
  final String key;
  final SoundCategory category;
  final SoundMood mood;
  final int colorValue;

  const FactoryPadAsset({
    required this.id,
    required this.name,
    required this.urlPath,
    this.key = 'C',
    this.category = SoundCategory.ambient,
    this.mood = SoundMood.neutral,
    this.colorValue = 0xFF00D4FF,
  });
}

/// The 11 ambient pad packs loaded from web/pads/ — all in key of C.
/// Modify the key here later to transpose automatically.
const List<FactoryPadAsset> kFactoryAmbientPads = [
  FactoryPadAsset(
    id: 'amb_cello_c',
    name: 'Cello Pads',
    urlPath: 'pads/cello_c.mp3',
    key: 'C',
    category: SoundCategory.cinematic,
    mood: SoundMood.deep,
    colorValue: 0xFF4FC3F7,
  ),
  FactoryPadAsset(
    id: 'amb_mellow_c',
    name: 'Mellow Pads',
    urlPath: 'pads/mellow_c.mp3',
    key: 'C',
    category: SoundCategory.warm,
    mood: SoundMood.warm,
    colorValue: 0xFFFF8C42,
  ),
  FactoryPadAsset(
    id: 'amb_organ_c',
    name: 'Organ Pads',
    urlPath: 'pads/organ_c.mp3',
    key: 'C',
    category: SoundCategory.organ,
    mood: SoundMood.intimate,
    colorValue: 0xFF9B59B6,
  ),
  FactoryPadAsset(
    id: 'amb_shimmer_rhodes_c',
    name: 'Shimmer Rhodes',
    urlPath: 'pads/shimmer_rhodes_c.mp3',
    key: 'C',
    category: SoundCategory.shimmer,
    mood: SoundMood.bright,
    colorValue: 0xFFFFD700,
  ),
  FactoryPadAsset(
    id: 'amb_shimmery_c',
    name: 'Shimmery Pads',
    urlPath: 'pads/shimmery_c.mp3',
    key: 'C',
    category: SoundCategory.shimmer,
    mood: SoundMood.bright,
    colorValue: 0xFF00E5FF,
  ),
  FactoryPadAsset(
    id: 'amb_shiny_c',
    name: 'Shiny Pads',
    urlPath: 'pads/shiny_c.mp3',
    key: 'C',
    category: SoundCategory.bright,
    mood: SoundMood.bright,
    colorValue: 0xFF00FF88,
  ),
  FactoryPadAsset(
    id: 'amb_verb_c',
    name: 'Verb Pads',
    urlPath: 'pads/verb_c.mp3',
    key: 'C',
    category: SoundCategory.ambient,
    mood: SoundMood.deep,
    colorValue: 0xFF3498DB,
  ),
  FactoryPadAsset(
    id: 'amb_bridge_c',
    name: 'Bridge (C min)',
    urlPath: 'pads/bridge_c.mp3',
    key: 'C',
    category: SoundCategory.worship,
    mood: SoundMood.intimate,
    colorValue: 0xFFE91E63,
  ),
  FactoryPadAsset(
    id: 'amb_motion1_c',
    name: 'Motion Pads I',
    urlPath: 'pads/motion1_c.mp3',
    key: 'C',
    category: SoundCategory.cinematic,
    mood: SoundMood.cinematic,
    colorValue: 0xFF1ABC9C,
  ),
  FactoryPadAsset(
    id: 'amb_motion2_c',
    name: 'Motion Pads II',
    urlPath: 'pads/motion2_c.mp3',
    key: 'C',
    category: SoundCategory.cinematic,
    mood: SoundMood.cinematic,
    colorValue: 0xFF8BC34A,
  ),
  FactoryPadAsset(
    id: 'amb_motion3_c',
    name: 'Motion Pads III',
    urlPath: 'pads/motion3_c.mp3',
    key: 'C',
    category: SoundCategory.cinematic,
    mood: SoundMood.epic,
    colorValue: 0xFFFF6B35,
  ),
];
