import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pedalera_models.dart';

// ── Active signal chain ──
final pedalChainProvider = StateProvider<List<PedalState>>((ref) => []);

// ── Active preset ──
final activePresetProvider = StateProvider<PedalPreset?>((ref) => null);

// ── Available presets (factory + user) ──
final pedalPresetsProvider = StateProvider<List<PedalPreset>>((ref) => factoryPresets);

// ── Input/output monitoring ──
final pedalInputActiveProvider = StateProvider<bool>((ref) => false);
final pedalOutputLevelProvider = StateProvider<double>((ref) => 0.0);
final pedalLatencyMsProvider = StateProvider<double>((ref) => 0.0);

// ── UI state ──
final pedalSelectedIndexProvider = StateProvider<int?>((ref) => null);
final pedalLiveModeProvider = StateProvider<bool>((ref) => false);

// ── Preset category filter ──
final pedalCategoryFilterProvider = StateProvider<String>((ref) => 'All');

// ── Scene providers ──

/// Index of the active scene within the current preset.
final activeSceneIndexProvider = StateProvider<int>((ref) => 0);

/// Derives from pedalPresetsProvider ensuring each preset has scenes available.
/// Currently passes presets through as-is; when a scenes field is added to
/// PedalPreset this provider will populate defaults for any preset missing them.
final presetsWithScenesProvider = Provider<List<PedalPreset>>((ref) {
  final presets = ref.watch(pedalPresetsProvider);
  return presets;
});

// ── BPM / Tempo providers ──

/// Current BPM for tempo-synced effects and metronome.
final pedalBpmProvider = StateProvider<double>((ref) => 120.0);

/// Timestamps of recent taps for calculating tap-tempo BPM.
final tapTempoTimestampsProvider = StateProvider<List<DateTime>>((ref) => []);

// ── Section content providers (amp / cabinet / mic model selection) ──

/// Index of the currently selected amp model.
final activeAmpModelProvider = StateProvider<int>((ref) => 0);

/// Index of the currently selected cabinet model.
final activeCabinetModelProvider = StateProvider<int>((ref) => 0);

/// Index of the currently selected mic model.
final activeMicModelProvider = StateProvider<int>((ref) => 0);

// ── Live mode providers ──

/// Presets loaded into the live-mode setlist.
final livePresetsProvider = StateProvider<List<PedalPreset>>((ref) => []);

/// Index of the active preset within the live-mode setlist.
final activeLivePresetIndexProvider = StateProvider<int>((ref) => 0);

// ── UI state providers ──

/// View toggle: false = pedalboard grid view, true = linear signal-chain view.
final signalChainViewProvider = StateProvider<bool>((ref) => false);

/// Which edit dropdown section is currently expanded in the editor panel.
/// Possible values: 'presets', 'scenes', 'amps', 'cabs', 'mics', or null (none).
final editExpandedSectionProvider = StateProvider<String?>((ref) => null);
