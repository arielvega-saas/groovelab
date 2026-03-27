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

/// A complete pedalboard preset.
@immutable
class PedalPreset {
  final String id;
  final String name;
  final String category;
  final List<PedalState> chain;
  final bool isFactory;

  const PedalPreset({
    required this.id,
    required this.name,
    this.category = 'Custom',
    this.chain = const [],
    this.isFactory = false,
  });

  PedalPreset copyWith({
    String? id,
    String? name,
    String? category,
    List<PedalState>? chain,
    bool? isFactory,
  }) {
    return PedalPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      chain: chain ?? this.chain,
      isFactory: isFactory ?? this.isFactory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'chain': chain.map((p) => p.toJson()).toList(),
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
    );
  }
}

// ── Default parameters per effect type ──

Map<String, double> defaultParams(EffectType type) {
  return switch (type) {
    EffectType.noiseGate => {'threshold': -40, 'release': 50},
    EffectType.compressor => {'threshold': -24, 'ratio': 4, 'attack': 3, 'release': 250},
    EffectType.drive => {'gain': 50, 'tone': 50, 'level': 70},
    EffectType.eq => {'low': 0, 'lowMid': 0, 'mid': 0, 'hiMid': 0, 'high': 0},
    EffectType.amp => {'gain': 50, 'bass': 50, 'mid': 50, 'treble': 50, 'volume': 70},
    EffectType.cabinet => {'mix': 100},
    EffectType.chorus => {'rate': 40, 'depth': 50, 'mix': 40},
    EffectType.delay => {'time': 400, 'feedback': 35, 'mix': 30},
    EffectType.reverb => {'decay': 50, 'mix': 30},
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
  PedalPreset(id: 'clean_studio', name: 'Clean Studio', category: 'Clean', isFactory: true, chain: [
    createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -20, 'ratio': 3, 'attack': 5, 'release': 200}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 2, 'lowMid': 0, 'mid': 1, 'hiMid': 2, 'high': 3}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 30, 'mix': 20}),
  ]),
  PedalPreset(id: 'warm_jazz', name: 'Warm Jazz', category: 'Jazz', isFactory: true, chain: [
    createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -18, 'ratio': 2.5, 'attack': 10, 'release': 300}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 3, 'lowMid': 2, 'mid': -1, 'hiMid': -2, 'high': -3}),
    createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 20, 'depth': 30, 'mix': 20}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 45, 'mix': 25}),
  ]),
  PedalPreset(id: 'blues_crunch', name: 'Blues Crunch', category: 'Blues', isFactory: true, chain: [
    createDefaultPedal(EffectType.compressor),
    createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 40, 'tone': 55, 'level': 65}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 2, 'lowMid': 3, 'mid': 1, 'hiMid': 0, 'high': -1}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 35, 'mix': 20}),
  ]),
  PedalPreset(id: 'classic_rock', name: 'Classic Rock', category: 'Rock', isFactory: true, chain: [
    createDefaultPedal(EffectType.noiseGate).copyWith(params: {'threshold': -45, 'release': 40}),
    createDefaultPedal(EffectType.compressor),
    createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 65, 'tone': 60, 'level': 70}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 3, 'lowMid': 2, 'mid': 4, 'hiMid': 1, 'high': 2}),
    createDefaultPedal(EffectType.delay).copyWith(params: {'time': 350, 'feedback': 25, 'mix': 20}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 40, 'mix': 25}),
  ]),
  PedalPreset(id: 'hard_rock', name: 'Hard Rock', category: 'Rock', isFactory: true, chain: [
    createDefaultPedal(EffectType.noiseGate).copyWith(params: {'threshold': -40, 'release': 30}),
    createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -22, 'ratio': 5, 'attack': 2, 'release': 150}),
    createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 80, 'tone': 65, 'level': 72}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 4, 'lowMid': 1, 'mid': 5, 'hiMid': 3, 'high': 2}),
    createDefaultPedal(EffectType.delay).copyWith(params: {'time': 300, 'feedback': 20, 'mix': 15}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 30, 'mix': 15}),
  ]),
  PedalPreset(id: 'metal', name: 'Metal', category: 'Metal', isFactory: true, chain: [
    createDefaultPedal(EffectType.noiseGate).copyWith(params: {'threshold': -35, 'release': 20}),
    createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -20, 'ratio': 6, 'attack': 1, 'release': 100}),
    createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 95, 'tone': 70, 'level': 75}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 5, 'lowMid': -2, 'mid': 6, 'hiMid': 4, 'high': 3}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 20, 'mix': 10}),
  ]),
  PedalPreset(id: 'acoustic_sim', name: 'Acoustic Sim', category: 'Clean', isFactory: true, chain: [
    createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -15, 'ratio': 3, 'attack': 8, 'release': 250}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': -2, 'lowMid': -1, 'mid': 3, 'hiMid': 4, 'high': 5}),
    createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 15, 'depth': 20, 'mix': 15}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 50, 'mix': 30}),
  ]),
  PedalPreset(id: 'funk_clean', name: 'Funk Clean', category: 'Funk', isFactory: true, chain: [
    createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -18, 'ratio': 5, 'attack': 2, 'release': 150}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 1, 'lowMid': -1, 'mid': 2, 'hiMid': 4, 'high': 3}),
    createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 50, 'depth': 40, 'mix': 25}),
  ]),
  PedalPreset(id: 'ambient', name: 'Ambient', category: 'Ambient', isFactory: true, chain: [
    createDefaultPedal(EffectType.compressor),
    createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 25, 'depth': 60, 'mix': 50}),
    createDefaultPedal(EffectType.delay).copyWith(params: {'time': 500, 'feedback': 55, 'mix': 45}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 80, 'mix': 55}),
  ]),
  PedalPreset(id: 'lofi', name: 'Lo-Fi', category: 'Creative', isFactory: true, chain: [
    createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 20, 'tone': 30, 'level': 60}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 2, 'lowMid': 1, 'mid': -2, 'hiMid': -4, 'high': -6}),
    createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 35, 'depth': 45, 'mix': 35}),
    createDefaultPedal(EffectType.delay).copyWith(params: {'time': 250, 'feedback': 40, 'mix': 30}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 60, 'mix': 40}),
  ]),
  PedalPreset(id: 'country', name: 'Country', category: 'Country', isFactory: true, chain: [
    createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -16, 'ratio': 3.5, 'attack': 5, 'release': 200}),
    createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 25, 'tone': 65, 'level': 70}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 1, 'lowMid': 0, 'mid': 2, 'hiMid': 3, 'high': 4}),
    createDefaultPedal(EffectType.delay).copyWith(params: {'time': 280, 'feedback': 30, 'mix': 25}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 35, 'mix': 20}),
  ]),
  PedalPreset(id: 'worship', name: 'Worship', category: 'Worship', isFactory: true, chain: [
    createDefaultPedal(EffectType.compressor).copyWith(params: {'threshold': -18, 'ratio': 3, 'attack': 8, 'release': 300}),
    createDefaultPedal(EffectType.drive).copyWith(params: {'gain': 30, 'tone': 50, 'level': 65}),
    createDefaultPedal(EffectType.eq).copyWith(params: {'low': 1, 'lowMid': 2, 'mid': 0, 'hiMid': 2, 'high': 3}),
    createDefaultPedal(EffectType.chorus).copyWith(params: {'rate': 20, 'depth': 35, 'mix': 30}),
    createDefaultPedal(EffectType.delay).copyWith(params: {'time': 450, 'feedback': 40, 'mix': 35}),
    createDefaultPedal(EffectType.reverb).copyWith(params: {'decay': 65, 'mix': 45}),
  ]),
];
