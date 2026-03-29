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
