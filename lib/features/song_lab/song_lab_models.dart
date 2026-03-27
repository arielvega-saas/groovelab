import 'package:flutter/material.dart';

// Stem types for separation
enum StemType { vocals, drums, bass, guitar, piano, other, fullMix }

// Transport state
enum SongLabTransportState { idle, loading, processing, ready, playing, paused, recording }

// Stem separation status
enum SeparationStatus { idle, processing, completed, failed }

// Export mode
enum SongLabExportMode { fullMix, stemsOnly, customMix, withRecording }

// Song section type
enum SectionType { intro, verse, preChorus, chorus, bridge, solo, outro, instrumental, unknown }

/// Individual audio stem
@immutable
class Stem {
  final int index;
  final String name;
  final StemType type;
  final double volume;
  final double pan;
  final bool muted;
  final bool solo;
  final List<double> waveform;
  final Color color;
  final bool isLoaded;

  const Stem({
    required this.index,
    required this.name,
    required this.type,
    this.volume = 1.0,
    this.pan = 0.0,
    this.muted = false,
    this.solo = false,
    this.waveform = const [],
    this.color = const Color(0xFF00E5C8),
    this.isLoaded = false,
  });

  Stem copyWith({int? index, String? name, StemType? type, double? volume, double? pan, bool? muted, bool? solo, List<double>? waveform, Color? color, bool? isLoaded}) {
    return Stem(index: index ?? this.index, name: name ?? this.name, type: type ?? this.type, volume: volume ?? this.volume, pan: pan ?? this.pan, muted: muted ?? this.muted, solo: solo ?? this.solo, waveform: waveform ?? this.waveform, color: color ?? this.color, isLoaded: isLoaded ?? this.isLoaded);
  }

  static Color colorForType(StemType type) {
    return switch (type) {
      StemType.vocals => const Color(0xFFE84393),
      StemType.drums => const Color(0xFFFF9F43),
      StemType.bass => const Color(0xFF00E5C8),
      StemType.guitar => const Color(0xFF6C5CE7),
      StemType.piano => const Color(0xFF00B894),
      StemType.other => const Color(0xFF74B9FF),
      StemType.fullMix => const Color(0xFFDFE6E9),
    };
  }

  static IconData iconForType(StemType type) {
    return switch (type) {
      StemType.vocals => Icons.mic,
      StemType.drums => Icons.album,
      StemType.bass => Icons.graphic_eq,
      StemType.guitar => Icons.music_note,
      StemType.piano => Icons.piano,
      StemType.other => Icons.equalizer,
      StemType.fullMix => Icons.merge_type,
    };
  }
}

/// Song section (verse, chorus, etc)
@immutable
class SongSection {
  final String label;
  final SectionType type;
  final double startTime;
  final double endTime;
  final String? chord;
  final Color color;

  const SongSection({required this.label, required this.type, required this.startTime, required this.endTime, this.chord, this.color = const Color(0xFF636E72)});

  SongSection copyWith({String? label, SectionType? type, double? startTime, double? endTime, String? chord, Color? color}) {
    return SongSection(label: label ?? this.label, type: type ?? this.type, startTime: startTime ?? this.startTime, endTime: endTime ?? this.endTime, chord: chord ?? this.chord, color: color ?? this.color);
  }

  static Color colorForSection(SectionType type) {
    return switch (type) {
      SectionType.intro => const Color(0xFF6C5CE7),
      SectionType.verse => const Color(0xFF00B894),
      SectionType.preChorus => const Color(0xFFFDAA5B),
      SectionType.chorus => const Color(0xFFE84393),
      SectionType.bridge => const Color(0xFF74B9FF),
      SectionType.solo => const Color(0xFFFF9F43),
      SectionType.outro => const Color(0xFF636E72),
      SectionType.instrumental => const Color(0xFF00E5C8),
      SectionType.unknown => const Color(0xFF2D3436),
    };
  }
}

/// A-B Loop region
@immutable
class LoopRegion {
  final double startTime;
  final double endTime;
  const LoopRegion({required this.startTime, required this.endTime});
}

/// Chord entry for timeline
@immutable
class ChordEntry {
  final double startTime;
  final double endTime;
  final String chord;
  const ChordEntry({required this.startTime, required this.endTime, required this.chord});
}

/// Song project
@immutable
class SongProject {
  final String id;
  final String title;
  final String? artist;
  final double bpm;
  final String key;
  final double durationSeconds;
  final List<Stem> stems;
  final List<SongSection> sections;
  final List<ChordEntry> chords;
  final bool hasStemSeparation;
  final DateTime createdAt;
  final DateTime lastOpenedAt;

  const SongProject({required this.id, required this.title, this.artist, this.bpm = 120.0, this.key = 'C', this.durationSeconds = 0.0, this.stems = const [], this.sections = const [], this.chords = const [], this.hasStemSeparation = false, required this.createdAt, required this.lastOpenedAt});

  SongProject copyWith({String? id, String? title, String? artist, double? bpm, String? key, double? durationSeconds, List<Stem>? stems, List<SongSection>? sections, List<ChordEntry>? chords, bool? hasStemSeparation, DateTime? createdAt, DateTime? lastOpenedAt}) {
    return SongProject(id: id ?? this.id, title: title ?? this.title, artist: artist ?? this.artist, bpm: bpm ?? this.bpm, key: key ?? this.key, durationSeconds: durationSeconds ?? this.durationSeconds, stems: stems ?? this.stems, sections: sections ?? this.sections, chords: chords ?? this.chords, hasStemSeparation: hasStemSeparation ?? this.hasStemSeparation, createdAt: createdAt ?? this.createdAt, lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt);
  }
}

/// Export settings for Song Lab
@immutable
class SongLabExportSettings {
  final SongLabExportMode mode;
  final String format;
  final bool includeClick;
  final bool includeRecording;
  final Set<int> selectedStemIndices;

  const SongLabExportSettings({this.mode = SongLabExportMode.fullMix, this.format = 'wav', this.includeClick = false, this.includeRecording = true, this.selectedStemIndices = const {}});
}
