import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loop Station state providers.
final loopLayerCountProvider = StateProvider<int>((ref) => 0);
final loopIsPlayingProvider = StateProvider<bool>((ref) => false);
final loopIsRecordingProvider = StateProvider<bool>((ref) => false);
final loopDurationProvider = StateProvider<Duration>((ref) => Duration.zero);
final loopLayersProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final loopPositionProvider = StateProvider<double>((ref) => 0.0);
final inputLevelProvider = StateProvider<double>((ref) => 0.0);
final inputMonitoringProvider = StateProvider<bool>((ref) => false);
final guideMutedProvider = StateProvider<bool>((ref) => false);
final guideVolumeProvider = StateProvider<double>((ref) => 0.7);
final loopMasterVolumeProvider = StateProvider<double>((ref) => 1.0);
final monitorVolumeProvider = StateProvider<double>((ref) => 0.5);
