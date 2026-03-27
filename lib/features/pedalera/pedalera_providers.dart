import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pedalera_models.dart';

// Active signal chain
final pedalChainProvider = StateProvider<List<PedalState>>((ref) => []);

// Active preset
final activePresetProvider = StateProvider<PedalPreset?>((ref) => null);

// Available presets (factory + user)
final pedalPresetsProvider = StateProvider<List<PedalPreset>>((ref) => factoryPresets);

// Input/output monitoring
final pedalInputActiveProvider = StateProvider<bool>((ref) => false);
final pedalOutputLevelProvider = StateProvider<double>((ref) => 0.0);
final pedalLatencyMsProvider = StateProvider<double>((ref) => 0.0);

// UI state
final pedalSelectedIndexProvider = StateProvider<int?>((ref) => null);
final pedalLiveModeProvider = StateProvider<bool>((ref) => false);

// Preset category filter
final pedalCategoryFilterProvider = StateProvider<String>((ref) => 'All');
