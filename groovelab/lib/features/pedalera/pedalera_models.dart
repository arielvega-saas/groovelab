import 'package:flutter/material.dart';

/// Types of effects available in the signal chain.
enum EffectType {
  noiseGate,
  compressor,
  drive,
  eq,
  amp,
  cabinet,
  chorus,
  delay,
  reverb,
  volume,
}

/// State of an individual effect pedal.
@immutable
class PedalState {
  final EffectType type;
  final String name;
  final bool enabled;
  final Map<String, double> params;
  final IconData icon;
  final Color color;

  const PedalState({
    required this.type,
    required this.name,
    this.enabled = true,
    this.params = const {},
    required this.icon,
    required this.color,
  });

  PedalState copyWith({
    EffectType? type,
    String? name,
    bool? enabled,
    Map<String, double>? params,
    IconData? icon,
    Color? color,
  }) {
    return PedalState(
      type: type ?? this.type,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      params: params ?? this.params,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'name': name,
    'enabled': enabled,
    'params': params,
  };

  static PedalState fromJson(Map<String, dynamic> json) {
    final type = EffectType.values.firstWhere(
      (e) => e.name == json['type'], orElse: () => EffectType.drive);
    return PedalState(
      type: type,
      name: json['name'] ?? type.name,
      enabled: json['enabled'] ?? true,
      params: Map<String, double>.from(json['params'] ?? {}),
      icon: _iconForType(type),
      color: _colorForType(type),
    );
  }
}

/// A scene within a preset that defines pedal states and parameter overrides.
///
/// Scenes allow switching between different configurations of the same preset
/// during a performance (e.g., verse vs chorus vs solo).
@immutable
class PresetScene {
  final String name;
  final String icon;
  final Color color;

  /// Maps pedal index -> enabled/disabled state for this scene.
  final Map<int, bool> pedalStates;

  /// Maps pedal index -> parameter name -> override value for this scene.
  final Map<int, Map<String, double>> pedalParamOverrides;

  const PresetScene({
    required this.name,
    this.icon = '🎵',
    this.color = const Color(0xFF636E72),
    this.pedalStates = const {},
    this.pedalParamOverrides = const {},
  });

  PresetScene copyWith({
    String? name,
    String? icon,
    Color? color,
    Map<int, bool>? pedalStates,
    Map<int, Map<String, double>>? pedalParamOverrides,
  }) {
    return PresetScene(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      pedalStates: pedalStates ?? this.pedalStates,
      pedalParamOverrides: pedalParamOverrides ?? this.pedalParamOverrides,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'icon': icon,
    'color': color.a.toInt() << 24 | color.r.toInt() << 16 | color.g.toInt() << 8 | color.b.toInt(),
    'pedalStates': pedalStates.map((k, v) => MapEntry(k.toString(), v)),
    'pedalParamOverrides': pedalParamOverrides.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
  };

  static PresetScene fromJson(Map<String, dynamic> json) {
    return PresetScene(
      name: json['name'] ?? 'Scene',
      icon: json['icon'] ?? '🎵',
      color: Color(json['color'] ?? 0xFF636E72),
      pedalStates: (json['pedalStates'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(int.parse(k), v as bool),
      ) ?? {},
      pedalParamOverrides: (json['pedalParamOverrides'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(
          int.parse(k),
          Map<String, double>.from(v as Map),
        ),
      ) ?? {},
    );
  }
}

/// A complete pedalboard preset.
@immutable
class PedalPreset {
  final String id;
  final String name;
  final String category;
  final List<PedalState> chain;
  final bool isFactory;
  final List<PresetScene> scenes;

  const PedalPreset({
    required this.id,
    required this.name,
    this.category = 'Custom',
    this.chain = const [],
    this.isFactory = false,
    this.scenes = const [],
  });

  PedalPreset copyWith({
    String? id,
    String? name,
    String? category,
    List<PedalState>? chain,
    bool? isFactory,
    List<PresetScene>? scenes,
  }) {
    return PedalPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      chain: chain ?? this.chain,
      isFactory: isFactory ?? this.isFactory,
      scenes: scenes ?? this.scenes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'chain': chain.map((p) => p.toJson()).toList(),
    'scenes': scenes.map((s) => s.toJson()).toList(),
  };

  static PedalPreset fromJson(Map<String, dynamic> json) {
    return PedalPreset(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Untitled',
      category: json['category'] ?? 'Custom',
      chain: (json['chain'] as List?)
          ?.map((p) => PedalState.fromJson(p))
          .toList() ?? [],
      isFactory: json['isFactory'] ?? false,
      scenes: (json['scenes'] as List?)
          ?.map((s) => PresetScene.fromJson(s))
          .toList() ?? [],
    );
  }
}

// ── Amplifier Model ──

/// Represents an amplifier model inspired by real-world amp heads.
@immutable
class AmpModel {
  final String id;
  final String name;
  final String category;
  final Map<String, double> defaultParams;

  const AmpModel({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultParams,
  });
}

/// Factory list of amplifier models.
const List<AmpModel> ampModels = [
  AmpModel(
    id: 'amp_crystal_twin',
    name: 'Crystal Twin',
    category: 'Clean',
    defaultParams: {'gain': 30, 'bass': 55, 'mid': 45, 'treble': 60, 'volume': 65, 'presence': 50},
  ),
  AmpModel(
    id: 'amp_black_panel',
    name: 'Black Panel',
    category: 'Clean',
    defaultParams: {'gain': 35, 'bass': 50, 'mid': 50, 'treble': 55, 'volume': 70, 'presence': 45},
  ),
  AmpModel(
    id: 'amp_brit_crunch',
    name: 'Brit Crunch',
    category: 'Crunch',
    defaultParams: {'gain': 55, 'bass': 50, 'mid': 65, 'treble': 55, 'volume': 68, 'presence': 55},
  ),
  AmpModel(
    id: 'amp_plexi_50',
    name: 'Plexi 50',
    category: 'Crunch',
    defaultParams: {'gain': 60, 'bass': 45, 'mid': 70, 'treble': 60, 'volume': 65, 'presence': 60},
  ),
  AmpModel(
    id: 'amp_dual_rect',
    name: 'Dual Rect',
    category: 'High Gain',
    defaultParams: {'gain': 80, 'bass': 55, 'mid': 60, 'treble': 65, 'volume': 70, 'presence': 55},
  ),
  AmpModel(
    id: 'amp_mark_v',
    name: 'Mark V',
    category: 'High Gain',
    defaultParams: {'gain': 75, 'bass': 50, 'mid': 55, 'treble': 70, 'volume': 68, 'presence': 60},
  ),
  AmpModel(
    id: 'amp_uber_modern',
    name: 'Uber Modern',
    category: 'Modern',
    defaultParams: {'gain': 85, 'bass': 60, 'mid': 50, 'treble': 70, 'volume': 72, 'presence': 65},
  ),
  AmpModel(
    id: 'amp_diamond_plate',
    name: 'Diamond Plate',
    category: 'Modern',
    defaultParams: {'gain': 90, 'bass': 55, 'mid': 55, 'treble': 75, 'volume': 70, 'presence': 60},
  ),
  AmpModel(
    id: 'amp_ac_chime',
    name: 'AC Chime',
    category: 'Boutique',
    defaultParams: {'gain': 40, 'bass': 45, 'mid': 55, 'treble': 65, 'volume': 70, 'presence': 50},
  ),
  AmpModel(
    id: 'amp_tweed_deluxe',
    name: 'Tweed Deluxe',
    category: 'Boutique',
    defaultParams: {'gain': 50, 'bass': 55, 'mid': 60, 'treble': 50, 'volume': 65, 'presence': 45},
  ),
];

// ── Cabinet Model ──

/// Represents a speaker cabinet model.
@immutable
class CabinetModel {
  final String id;
  final String name;
  final String description;
  final String speakerConfig;

  const CabinetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.speakerConfig,
  });
}

/// Factory list of cabinet models.
const List<CabinetModel> cabinetModels = [
  CabinetModel(
    id: 'cab_1x8_practice',
    name: '1x8 Practice',
    description: 'Small practice combo speaker',
    speakerConfig: '1x8',
  ),
  CabinetModel(
    id: 'cab_1x10_jazz',
    name: '1x10 Jazz',
    description: 'Compact jazz combo, warm tone',
    speakerConfig: '1x10',
  ),
  CabinetModel(
    id: 'cab_1x12_combo',
    name: '1x12 Combo',
    description: 'Classic combo cabinet, versatile and balanced',
    speakerConfig: '1x12',
  ),
  CabinetModel(
    id: 'cab_2x12_open',
    name: '2x12 Open Back',
    description: 'Open-back 2x12, airy and chimey tone',
    speakerConfig: '2x12',
  ),
  CabinetModel(
    id: 'cab_2x12_closed',
    name: '2x12 Closed Back',
    description: 'Closed-back 2x12, tighter low end',
    speakerConfig: '2x12',
  ),
  CabinetModel(
    id: 'cab_4x10_bass',
    name: '4x10 Bass',
    description: 'Classic bass cabinet, punchy mids',
    speakerConfig: '4x10',
  ),
  CabinetModel(
    id: 'cab_4x12_closed',
    name: '4x12 Closed',
    description: 'Classic closed-back 4x12, tight and punchy',
    speakerConfig: '4x12',
  ),
  CabinetModel(
    id: 'cab_4x12_open',
    name: '4x12 Open',
    description: 'Open-back 4x12, wide and spacious',
    speakerConfig: '4x12',
  ),
];

// ── Microphone Model ──

/// Represents a microphone model for cabinet miking.
@immutable
class MicModel {
  final String id;
  final String name;
  final String type;
  final String description;

  const MicModel({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
  });
}

/// Factory list of microphone models.
const List<MicModel> micModels = [
  MicModel(
    id: 'mic_dynamic_57',
    name: 'Dynamic 57',
    type: 'Dynamic',
    description: 'Industry standard dynamic mic, mid-focused and punchy',
  ),
  MicModel(
    id: 'mic_dynamic_421',
    name: 'Dynamic 421',
    type: 'Dynamic',
    description: 'Versatile dynamic mic, full range with presence',
  ),
  MicModel(
    id: 'mic_condenser_414',
    name: 'Condenser 414',
    type: 'Condenser',
    description: 'Large diaphragm condenser, detailed and transparent',
  ),
  MicModel(
    id: 'mic_condenser_87',
    name: 'Condenser 87',
    type: 'Condenser',
    description: 'Classic studio condenser, silky top end',
  ),
  MicModel(
    id: 'mic_ribbon_121',
    name: 'Ribbon 121',
    type: 'Ribbon',
    description: 'Modern ribbon mic, smooth highs and natural tone',
  ),
  MicModel(
    id: 'mic_ribbon_160',
    name: 'Ribbon 160',
    type: 'Ribbon',
    description: 'Vintage ribbon character, warm and dark',
  ),
  MicModel(
    id: 'mic_dynamic_906',
    name: 'Dynamic 906',
    type: 'Dynamic',
    description: 'Flat-profile dynamic, bright and articulate',
  ),
];

// ── Default parameters per effect type ──

Map<String, double> defaultParams(EffectType type) {
  return switch (type) {
    EffectType.noiseGate => {
      'threshold': -40,  // -80 to 0 dB
      'attack': 0.5,     // 0.1-10 ms
      'hold': 100,       // 10-500 ms
      'release': 50,     // 10-500 ms
    },
    EffectType.compressor => {
      'threshold': -24,  // -60 to 0 dB
      'ratio': 4,        // 1-20
      'attack': 10,      // 0.1-200 ms
      'release': 100,    // 10-1000 ms
      'makeupGain': 0,   // -20 to +20 dB
    },
    EffectType.drive => {
      'gain': 50,        // 0-100
      'tone': 50,        // 0-100 (legacy alias)
      'toneControl': 50, // 0=dark, 50=neutral, 100=bright
      'level': 70,       // 0-100
      'driveType': 0,    // 0=Clean Boost, 1=Tube OD, 2=Heavy Dist, 3=Fuzz
    },
    EffectType.eq => {'low': 0, 'lowMid': 0, 'mid': 0, 'hiMid': 0, 'high': 0},
    EffectType.amp => {'gain': 50, 'bass': 50, 'mid': 50, 'treble': 50, 'volume': 70},
    EffectType.cabinet => {
      'mix': 100,        // 0-100
      'cabinetType': 0,  // 0=1x12 Combo, 1=2x12 Open, 2=4x12 Closed, 3=1x10 Jazz
    },
    EffectType.chorus => {
      'rate': 40,        // 0-100 (maps to 0-2.5 Hz)
      'depth': 50,       // 0-100 (maps to 0-10 ms)
      'mix': 40,         // 0-100
    },
    EffectType.delay => {'time': 400, 'feedback': 35, 'mix': 30},
    EffectType.reverb => {
      'decay': 50,       // 0-100
      'mix': 30,         // 0-100
      'preDelay': 0,     // 0-200 ms
      'reverbType': 0,   // 0=Room, 1=Hall, 2=Plate, 3=Spring, 4=Cathedral, 5=Chamber
    },
    EffectType.volume => {
      'level': 100,      // 0-100
      'curve': 0,        // 0=linear, 1=logarithmic, 2=exponential
    },
  };
}

IconData _iconForType(EffectType type) {
  return switch (type) {
    EffectType.noiseGate => Icons.noise_aware,
    EffectType.compressor => Icons.compress,
    EffectType.drive => Icons.electric_bolt,
    EffectType.eq => Icons.equalizer,
    EffectType.amp => Icons.amp_stories,
    EffectType.cabinet => Icons.speaker,
    EffectType.chorus => Icons.waves,
    EffectType.delay => Icons.timer,
    EffectType.reverb => Icons.spatial_audio,
    EffectType.volume => Icons.volume_up,
  };
}

Color _colorForType(EffectType type) {
  return switch (type) {
    EffectType.noiseGate => const Color(0xFF636E72),
    EffectType.compressor => const Color(0xFF6C5CE7),
    EffectType.drive => const Color(0xFFFF9F43),
    EffectType.eq => const Color(0xFF00B894),
    EffectType.amp => const Color(0xFFE84393),
    EffectType.cabinet => const Color(0xFF74B9FF),
    EffectType.chorus => const Color(0xFF00E5C8),
    EffectType.delay => const Color(0xFFFD79A8),
    EffectType.reverb => const Color(0xFF55EFC4),
    EffectType.volume => const Color(0xFFDFE6E9),
  };
}

PedalState createDefaultPedal(EffectType type) {
  return PedalState(
    type: type,
    name: type.name[0].toUpperCase() + type.name.substring(1),
    enabled: true,
    params: defaultParams(type),
    icon: _iconForType(type),
    color: _colorForType(type),
  );
}

// ── Factory Presets ──

List<PedalPreset> factoryPresets = [
  // ── Clean Studio ──
  PedalPreset(
    id: 'clean_studio',
    name: 'Clean Studio',
    category: 'Clean',
    isFactory: true,
    chain: [
      // 0: compressor
      createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -20, 'ratio': 3, 'attack': 5, 'release': 200}),
      // 1: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 2, 'lowMid': 0, 'mid': 1, 'hiMid': 2, 'high': 3}),
      // 2: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 30, 'mix': 20}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {2: {'decay': 45, 'mix': 30, 'reverbType': 5}},
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {2: {'decay': 25, 'mix': 15}},
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {
          0: {'threshold': -16, 'ratio': 4},
          1: {'high': 5, 'hiMid': 3},
          2: {'decay': 40, 'mix': 25},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {
          0: {'makeupGain': 4},
          1: {'mid': 3, 'hiMid': 4},
          2: {'decay': 50, 'mix': 30, 'reverbType': 1},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {2: {'decay': 75, 'mix': 50, 'reverbType': 4}},
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {2: {'decay': 80, 'mix': 45, 'reverbType': 1}},
      ),
    ],
  ),

  // ── Warm Jazz ──
  PedalPreset(
    id: 'warm_jazz',
    name: 'Warm Jazz',
    category: 'Jazz',
    isFactory: true,
    chain: [
      // 0: compressor
      createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -18, 'ratio': 2.5, 'attack': 10, 'release': 300}),
      // 1: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 3, 'lowMid': 2, 'mid': -1, 'hiMid': -2, 'high': -3}),
      // 2: chorus
      createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 20, 'depth': 30, 'mix': 20}),
      // 3: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 45, 'mix': 25}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          2: {'rate': 12, 'depth': 20, 'mix': 15},
          3: {'decay': 55, 'mix': 35, 'reverbType': 5},
        },
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: false, 3: true},
        pedalParamOverrides: {3: {'decay': 35, 'mix': 20}},
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          0: {'makeupGain': 3},
          2: {'rate': 25, 'depth': 35, 'mix': 25},
          3: {'decay': 50, 'mix': 30},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: false, 3: true},
        pedalParamOverrides: {
          0: {'makeupGain': 5},
          1: {'mid': 1, 'hiMid': 0},
          3: {'decay': 55, 'mix': 30, 'reverbType': 1},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          2: {'rate': 10, 'depth': 50, 'mix': 40},
          3: {'decay': 80, 'mix': 55, 'reverbType': 4},
        },
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          2: {'rate': 8, 'depth': 15, 'mix': 10},
          3: {'decay': 70, 'mix': 40},
        },
      ),
    ],
  ),

  // ── Blues Crunch ──
  PedalPreset(
    id: 'blues_crunch',
    name: 'Blues Crunch',
    category: 'Blues',
    isFactory: true,
    chain: [
      // 0: compressor
      createDefaultPedal(EffectType.compressor),
      // 1: drive
      createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 40, 'tone': 55, 'level': 65}),
      // 2: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 2, 'lowMid': 3, 'mid': 1, 'hiMid': 0, 'high': -1}),
      // 3: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 35, 'mix': 20}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: false, 2: true, 3: true},
        pedalParamOverrides: {3: {'decay': 45, 'mix': 30, 'reverbType': 3}},
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {1: {'gain': 30, 'level': 60}},
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          1: {'gain': 55, 'level': 72},
          3: {'decay': 40, 'mix': 25},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          1: {'gain': 65, 'level': 80, 'driveType': 1},
          3: {'decay': 50, 'mix': 30, 'reverbType': 3},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: false, 2: true, 3: true},
        pedalParamOverrides: {3: {'decay': 70, 'mix': 50, 'reverbType': 1}},
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          1: {'gain': 25, 'level': 55},
          3: {'decay': 55, 'mix': 35},
        },
      ),
    ],
  ),

  // ── Classic Rock ──
  PedalPreset(
    id: 'classic_rock',
    name: 'Classic Rock',
    category: 'Rock',
    isFactory: true,
    chain: [
      // 0: noiseGate
      createDefaultPedal(EffectType.noiseGate).copyWith(params: {'threshold': -45, 'attack': 0.5, 'hold': 100, 'release': 40}),
      // 1: compressor
      createDefaultPedal(EffectType.compressor),
      // 2: drive
      createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 65, 'tone': 60, 'toneControl': 60, 'level': 70, 'driveType': 1}),
      // 3: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 3, 'lowMid': 2, 'mid': 4, 'hiMid': 1, 'high': 2}),
      // 4: delay
      createDefaultPedal(EffectType.delay).copyWith(params: {'time': 350, 'feedback': 25, 'mix': 20}),
      // 5: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 40, 'mix': 25, 'preDelay': 0, 'reverbType': 0}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: true, 2: false, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          4: {'time': 400, 'feedback': 30, 'mix': 25},
          5: {'decay': 50, 'mix': 30},
        },
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: false, 5: true},
        pedalParamOverrides: {
          2: {'gain': 50, 'level': 65},
          5: {'decay': 30, 'mix': 20},
        },
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          2: {'gain': 70, 'level': 75},
          4: {'time': 350, 'feedback': 20, 'mix': 15},
          5: {'decay': 40, 'mix': 25},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          2: {'gain': 80, 'level': 82},
          4: {'time': 380, 'feedback': 35, 'mix': 30},
          5: {'decay': 50, 'mix': 30, 'reverbType': 1},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: true, 2: false, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          4: {'time': 500, 'feedback': 45, 'mix': 40},
          5: {'decay': 70, 'mix': 45, 'reverbType': 1},
        },
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          2: {'gain': 45, 'level': 55},
          4: {'time': 400, 'feedback': 30, 'mix': 25},
          5: {'decay': 60, 'mix': 35},
        },
      ),
    ],
  ),

  // ── Hard Rock ──
  PedalPreset(
    id: 'hard_rock',
    name: 'Hard Rock',
    category: 'Rock',
    isFactory: true,
    chain: [
      // 0: noiseGate
      createDefaultPedal(EffectType.noiseGate).copyWith(params: {'threshold': -40, 'attack': 0.5, 'hold': 80, 'release': 30}),
      // 1: compressor
      createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -22, 'ratio': 5, 'attack': 2, 'release': 150, 'makeupGain': 0}),
      // 2: drive
      createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 80, 'tone': 65, 'toneControl': 65, 'level': 72, 'driveType': 2}),
      // 3: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 4, 'lowMid': 1, 'mid': 5, 'hiMid': 3, 'high': 2}),
      // 4: delay
      createDefaultPedal(EffectType.delay).copyWith(params: {'time': 300, 'feedback': 20, 'mix': 15}),
      // 5: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 30, 'mix': 15}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          2: {'gain': 55, 'level': 60},
          4: {'time': 350, 'feedback': 25, 'mix': 20},
          5: {'decay': 45, 'mix': 25},
        },
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: false, 5: true},
        pedalParamOverrides: {
          2: {'gain': 65, 'level': 68},
          5: {'decay': 25, 'mix': 12},
        },
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: false, 5: true},
        pedalParamOverrides: {
          2: {'gain': 85, 'level': 78},
          5: {'decay': 30, 'mix': 15},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          2: {'gain': 90, 'level': 85, 'driveType': 2},
          4: {'time': 320, 'feedback': 30, 'mix': 25},
          5: {'decay': 40, 'mix': 20},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: true, 2: false, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          4: {'time': 450, 'feedback': 40, 'mix': 35},
          5: {'decay': 65, 'mix': 45, 'reverbType': 1},
        },
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          2: {'gain': 50, 'level': 55},
          5: {'decay': 50, 'mix': 30},
        },
      ),
    ],
  ),

  // ── Metal ──
  PedalPreset(
    id: 'metal',
    name: 'Metal',
    category: 'Metal',
    isFactory: true,
    chain: [
      // 0: noiseGate
      createDefaultPedal(EffectType.noiseGate).copyWith(params: {'threshold': -35, 'attack': 0.3, 'hold': 60, 'release': 20}),
      // 1: compressor
      createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -20, 'ratio': 6, 'attack': 1, 'release': 100, 'makeupGain': 2}),
      // 2: drive
      createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 95, 'tone': 70, 'toneControl': 70, 'level': 75, 'driveType': 2}),
      // 3: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 5, 'lowMid': -2, 'mid': 6, 'hiMid': 4, 'high': 3}),
      // 4: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 20, 'mix': 10}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'threshold': -40},
          2: {'gain': 70, 'level': 65},
          4: {'decay': 35, 'mix': 20},
        },
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'threshold': -38},
          2: {'gain': 85, 'level': 72},
          4: {'decay': 15, 'mix': 8},
        },
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'threshold': -32},
          2: {'gain': 95, 'level': 80},
          3: {'low': 6, 'mid': 7},
          4: {'decay': 20, 'mix': 10},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'threshold': -30},
          1: {'makeupGain': 5},
          2: {'gain': 100, 'level': 88},
          3: {'mid': 8, 'hiMid': 5},
          4: {'decay': 30, 'mix': 15},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'threshold': -45},
          2: {'gain': 60, 'level': 55},
          4: {'decay': 70, 'mix': 45, 'reverbType': 4},
        },
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'threshold': -42},
          2: {'gain': 75, 'level': 60},
          4: {'decay': 45, 'mix': 25},
        },
      ),
    ],
  ),

  // ── Acoustic Sim ──
  PedalPreset(
    id: 'acoustic_sim',
    name: 'Acoustic Sim',
    category: 'Clean',
    isFactory: true,
    chain: [
      // 0: compressor
      createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -15, 'ratio': 3, 'attack': 8, 'release': 250}),
      // 1: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': -2, 'lowMid': -1, 'mid': 3, 'hiMid': 4, 'high': 5}),
      // 2: chorus
      createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 15, 'depth': 20, 'mix': 15}),
      // 3: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 50, 'mix': 30}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: true, 2: false, 3: true},
        pedalParamOverrides: {3: {'decay': 60, 'mix': 40, 'reverbType': 5}},
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: false, 3: true},
        pedalParamOverrides: {3: {'decay': 40, 'mix': 20}},
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          0: {'makeupGain': 3},
          2: {'rate': 20, 'depth': 25, 'mix': 20},
          3: {'decay': 55, 'mix': 30},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: false, 3: true},
        pedalParamOverrides: {
          0: {'makeupGain': 5},
          1: {'mid': 5, 'hiMid': 5},
          3: {'decay': 50, 'mix': 25},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          2: {'rate': 10, 'depth': 40, 'mix': 35},
          3: {'decay': 80, 'mix': 55, 'reverbType': 4},
        },
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          2: {'rate': 8, 'depth': 15, 'mix': 10},
          3: {'decay': 65, 'mix': 40},
        },
      ),
    ],
  ),

  // ── Funk Clean ──
  PedalPreset(
    id: 'funk_clean',
    name: 'Funk Clean',
    category: 'Funk',
    isFactory: true,
    chain: [
      // 0: compressor
      createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -18, 'ratio': 5, 'attack': 2, 'release': 150}),
      // 1: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 1, 'lowMid': -1, 'mid': 2, 'hiMid': 4, 'high': 3}),
      // 2: chorus
      createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 50, 'depth': 40, 'mix': 25}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {
          0: {'ratio': 3},
          2: {'rate': 30, 'depth': 25, 'mix': 15},
        },
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: false},
        pedalParamOverrides: {0: {'ratio': 5, 'attack': 1}},
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {
          0: {'ratio': 6, 'attack': 1, 'makeupGain': 3},
          1: {'hiMid': 5, 'high': 4},
          2: {'rate': 55, 'depth': 45, 'mix': 30},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: false},
        pedalParamOverrides: {
          0: {'makeupGain': 5},
          1: {'mid': 4, 'hiMid': 5},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {2: {'rate': 20, 'depth': 55, 'mix': 40}},
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true},
        pedalParamOverrides: {
          0: {'ratio': 3},
          2: {'rate': 25, 'depth': 20, 'mix': 12},
        },
      ),
    ],
  ),

  // ── Ambient ──
  PedalPreset(
    id: 'ambient',
    name: 'Ambient',
    category: 'Ambient',
    isFactory: true,
    chain: [
      // 0: compressor
      createDefaultPedal(EffectType.compressor),
      // 1: chorus
      createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 25, 'depth': 60, 'mix': 50}),
      // 2: delay
      createDefaultPedal(EffectType.delay).copyWith(params: {'time': 500, 'feedback': 55, 'mix': 45}),
      // 3: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 80, 'mix': 55}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          1: {'rate': 15, 'depth': 40, 'mix': 35},
          2: {'time': 600, 'feedback': 50, 'mix': 40},
          3: {'decay': 85, 'mix': 60, 'reverbType': 4},
        },
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          1: {'rate': 20, 'depth': 45, 'mix': 40},
          2: {'time': 450, 'feedback': 45, 'mix': 35},
          3: {'decay': 70, 'mix': 45},
        },
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          1: {'rate': 30, 'depth': 65, 'mix': 55},
          2: {'time': 500, 'feedback': 55, 'mix': 50},
          3: {'decay': 85, 'mix': 60},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: false, 2: true, 3: true},
        pedalParamOverrides: {
          0: {'makeupGain': 4},
          2: {'time': 380, 'feedback': 40, 'mix': 35},
          3: {'decay': 75, 'mix': 50, 'reverbType': 1},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          1: {'rate': 10, 'depth': 80, 'mix': 65},
          2: {'time': 700, 'feedback': 65, 'mix': 55},
          3: {'decay': 95, 'mix': 70, 'reverbType': 4},
        },
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true, 3: true},
        pedalParamOverrides: {
          1: {'rate': 8, 'depth': 50, 'mix': 40},
          2: {'time': 650, 'feedback': 60, 'mix': 50},
          3: {'decay': 90, 'mix': 65, 'reverbType': 1},
        },
      ),
    ],
  ),

  // ── Lo-Fi ──
  PedalPreset(
    id: 'lofi',
    name: 'Lo-Fi',
    category: 'Creative',
    isFactory: true,
    chain: [
      // 0: drive
      createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 20, 'tone': 30, 'level': 60}),
      // 1: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 2, 'lowMid': 1, 'mid': -2, 'hiMid': -4, 'high': -6}),
      // 2: chorus
      createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 35, 'depth': 45, 'mix': 35}),
      // 3: delay
      createDefaultPedal(EffectType.delay).copyWith(params: {'time': 250, 'feedback': 40, 'mix': 30}),
      // 4: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 60, 'mix': 40}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: false, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          2: {'rate': 20, 'depth': 30, 'mix': 20},
          3: {'time': 300, 'feedback': 35, 'mix': 25},
          4: {'decay': 70, 'mix': 50, 'reverbType': 5},
        },
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'gain': 15, 'level': 55},
          2: {'rate': 30, 'depth': 40, 'mix': 30},
        },
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'gain': 30, 'level': 68},
          2: {'rate': 40, 'depth': 50, 'mix': 40},
          4: {'decay': 65, 'mix': 45},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: false, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'gain': 35, 'level': 72},
          3: {'time': 280, 'feedback': 45, 'mix': 35},
          4: {'decay': 55, 'mix': 35},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: false, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          2: {'rate': 15, 'depth': 60, 'mix': 50},
          3: {'time': 400, 'feedback': 55, 'mix': 45},
          4: {'decay': 85, 'mix': 60, 'reverbType': 4},
        },
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'gain': 10, 'level': 45},
          2: {'rate': 18, 'depth': 35, 'mix': 25},
          4: {'decay': 75, 'mix': 50},
        },
      ),
    ],
  ),

  // ── Country ──
  PedalPreset(
    id: 'country',
    name: 'Country',
    category: 'Country',
    isFactory: true,
    chain: [
      // 0: compressor
      createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -16, 'ratio': 3.5, 'attack': 5, 'release': 200}),
      // 1: drive
      createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 25, 'tone': 65, 'level': 70}),
      // 2: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 1, 'lowMid': 0, 'mid': 2, 'hiMid': 3, 'high': 4}),
      // 3: delay
      createDefaultPedal(EffectType.delay).copyWith(params: {'time': 280, 'feedback': 30, 'mix': 25}),
      // 4: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 35, 'mix': 20}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: false, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          3: {'time': 320, 'feedback': 25, 'mix': 20},
          4: {'decay': 45, 'mix': 30, 'reverbType': 3},
        },
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: false, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          3: {'time': 280, 'feedback': 30, 'mix': 22},
          4: {'decay': 30, 'mix': 18},
        },
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          1: {'gain': 30, 'level': 75},
          3: {'time': 280, 'feedback': 25, 'mix': 20},
          4: {'decay': 35, 'mix': 22},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          0: {'makeupGain': 4},
          1: {'gain': 40, 'level': 80},
          3: {'time': 300, 'feedback': 35, 'mix': 30},
          4: {'decay': 40, 'mix': 25, 'reverbType': 3},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: false, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          3: {'time': 400, 'feedback': 45, 'mix': 40},
          4: {'decay': 65, 'mix': 45, 'reverbType': 1},
        },
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: false, 2: true, 3: true, 4: true},
        pedalParamOverrides: {
          3: {'time': 350, 'feedback': 30, 'mix': 25},
          4: {'decay': 50, 'mix': 35},
        },
      ),
    ],
  ),

  // ── Worship ──
  PedalPreset(
    id: 'worship',
    name: 'Worship',
    category: 'Worship',
    isFactory: true,
    chain: [
      // 0: compressor
      createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -18, 'ratio': 3, 'attack': 8, 'release': 300}),
      // 1: drive
      createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 30, 'tone': 50, 'level': 65}),
      // 2: eq
      createDefaultPedal(EffectType.eq).copyWith(params: {'low': 1, 'lowMid': 2, 'mid': 0, 'hiMid': 2, 'high': 3}),
      // 3: chorus
      createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 20, 'depth': 35, 'mix': 30}),
      // 4: delay
      createDefaultPedal(EffectType.delay).copyWith(params: {'time': 450, 'feedback': 40, 'mix': 35}),
      // 5: reverb
      createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 65, 'mix': 45}),
    ],
    scenes: [
      PresetScene(
        name: 'Intro',
        icon: '🌅',
        color: Color(0xFF74B9FF),
        pedalStates: {0: true, 1: false, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          3: {'rate': 12, 'depth': 25, 'mix': 20},
          4: {'time': 500, 'feedback': 45, 'mix': 40},
          5: {'decay': 80, 'mix': 55, 'reverbType': 4},
        },
      ),
      PresetScene(
        name: 'Verso',
        icon: '🎸',
        color: Color(0xFF00B894),
        pedalStates: {0: true, 1: false, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          3: {'rate': 18, 'depth': 30, 'mix': 25},
          4: {'time': 450, 'feedback': 35, 'mix': 30},
          5: {'decay': 60, 'mix': 40},
        },
      ),
      PresetScene(
        name: 'Coro',
        icon: '🔥',
        color: Color(0xFFFF9F43),
        pedalStates: {0: true, 1: true, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          1: {'gain': 40, 'level': 72},
          3: {'rate': 22, 'depth': 40, 'mix': 35},
          4: {'time': 450, 'feedback': 40, 'mix': 35},
          5: {'decay': 70, 'mix': 50},
        },
      ),
      PresetScene(
        name: 'Solo',
        icon: '⚡',
        color: Color(0xFFE84393),
        pedalStates: {0: true, 1: true, 2: true, 3: false, 4: true, 5: true},
        pedalParamOverrides: {
          1: {'gain': 50, 'level': 80},
          4: {'time': 420, 'feedback': 45, 'mix': 40},
          5: {'decay': 70, 'mix': 45, 'reverbType': 1},
        },
      ),
      PresetScene(
        name: 'Ambient',
        icon: '🌊',
        color: Color(0xFF6C5CE7),
        pedalStates: {0: true, 1: false, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          3: {'rate': 10, 'depth': 55, 'mix': 45},
          4: {'time': 600, 'feedback': 55, 'mix': 50},
          5: {'decay': 90, 'mix': 65, 'reverbType': 4},
        },
      ),
      PresetScene(
        name: 'Outro',
        icon: '🌙',
        color: Color(0xFF636E72),
        pedalStates: {0: true, 1: false, 2: true, 3: true, 4: true, 5: true},
        pedalParamOverrides: {
          3: {'rate': 8, 'depth': 20, 'mix': 15},
          4: {'time': 550, 'feedback': 50, 'mix': 45},
          5: {'decay': 85, 'mix': 60, 'reverbType': 1},
        },
      ),
    ],
  ),
];
