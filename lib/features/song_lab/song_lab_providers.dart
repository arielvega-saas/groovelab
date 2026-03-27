import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'song_lab_models.dart';

// Transport
final songLabStateProvider = StateProvider<SongLabTransportState>((ref) => SongLabTransportState.idle);
final songLabPositionProvider = StateProvider<double>((ref) => 0.0);
final songLabDurationProvider = StateProvider<double>((ref) => 0.0);

// Active project
final activeSongProjectProvider = StateProvider<SongProject?>((ref) => null);
final songLabStemsProvider = StateProvider<List<Stem>>((ref) => []);

// Playback
final songLabSpeedProvider = StateProvider<double>((ref) => 1.0);
final songLabPitchShiftProvider = StateProvider<int>((ref) => 0);
final songLabLoopRegionProvider = StateProvider<LoopRegion?>((ref) => null);
final songLabClickEnabledProvider = StateProvider<bool>((ref) => false);
final songLabCountInProvider = StateProvider<bool>((ref) => false);

// Sections/chords
final songLabSectionsProvider = StateProvider<List<SongSection>>((ref) => []);
final songLabChordsProvider = StateProvider<List<ChordEntry>>((ref) => []);
final songLabCurrentSectionProvider = StateProvider<String?>((ref) => null);
final songLabCurrentChordProvider = StateProvider<String?>((ref) => null);

// Stem separation
final stemSeparationStatusProvider = StateProvider<SeparationStatus>((ref) => SeparationStatus.idle);
final stemSeparationProgressProvider = StateProvider<double>((ref) => 0.0);

// Recording
final songLabRecordingProvider = StateProvider<bool>((ref) => false);

// Library
final songLabProjectsProvider = StateProvider<List<SongProject>>((ref) => []);

// UI
final songLabSelectedStemProvider = StateProvider<int?>((ref) => null);
final songLabShowSectionsProvider = StateProvider<bool>((ref) => true);

// Internal view tab selection (0=Player, 1=Stems, 2=Chords, 3=Export)
final songLabViewIndexProvider = StateProvider<int>((ref) => 0);

// Export settings
final songLabExportFormatProvider = StateProvider<String>((ref) => 'wav');
final songLabExportModeProvider = StateProvider<String>((ref) => 'fullMix');
final songLabExportIncludeClickProvider = StateProvider<bool>((ref) => false);
