import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';

/// Drums-specific state providers.
final drumStyleProvider = StateProvider<String>((ref) => 'Rock');
final drumStepProvider = StateProvider<int>((ref) => -1);
final customDrumPatternProvider = StateProvider<Map<String, List<int>>?>((ref) => null);
final drumVolumesProvider = StateProvider<Map<String, double>>((ref) =>
    {'kick': 1.0, 'snare': 1.0, 'hihat': 1.0, 'ride': 1.0});
final drumTimeSigProvider = StateProvider<TimeSig>((ref) => const TimeSig(4, 4, '4/4'));
final drumAccentPatternProvider = StateProvider<List<double>>((ref) => [1.0, 0.7, 0.7, 0.7]);

/// Per-track mute state: { 'kick': false, 'snare': false, ... }
final drumMuteProvider = StateProvider<Map<String, bool>>((ref) =>
    {'kick': false, 'snare': false, 'hihat': false, 'ride': false});

/// Per-track solo state: { 'kick': false, 'snare': false, ... }
final drumSoloProvider = StateProvider<Map<String, bool>>((ref) =>
    {'kick': false, 'snare': false, 'hihat': false, 'ride': false});

/// Computes effective volumes considering mute/solo state.
/// When any track is soloed, only soloed tracks play (unless also muted).
/// Mute always silences a track regardless of solo state.
Map<String, double> computeEffectiveDrumVolumes({
  required Map<String, double> volumes,
  required Map<String, bool> mutes,
  required Map<String, bool> solos,
}) {
  final anySolo = solos.values.any((s) => s);
  final effective = <String, double>{};
  for (final key in volumes.keys) {
    final isMuted = mutes[key] ?? false;
    final isSoloed = solos[key] ?? false;
    if (isMuted) {
      effective[key] = 0.0;
    } else if (anySolo && !isSoloed) {
      effective[key] = 0.0;
    } else {
      effective[key] = volumes[key] ?? 1.0;
    }
  }
  return effective;
}
