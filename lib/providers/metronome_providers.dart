import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';

/// Metronome-specific state providers.
/// Extracted from app_providers.dart for better feature isolation.

final bpmProvider = StateProvider<int>((ref) => 120);
final playingProvider = StateProvider<bool>((ref) => false);
final timeSigProvider = StateProvider<TimeSig>((ref) => const TimeSig(4, 4, '4/4'));
final subdivisionProvider = StateProvider<int>((ref) => 1);
final clickSoundProvider = StateProvider<String>((ref) => 'Wood');
final swingProvider = StateProvider<int>((ref) => 0);
final currentBeatProvider = StateProvider<int>((ref) => -1);
final accentPatternProvider = StateProvider<List<double>>((ref) => [1.0, 0.7, 0.7, 0.7]);
final hapticModeProvider = StateProvider<bool>((ref) => false);
final humanFeelProvider = StateProvider<int>((ref) => 0);
final countInBarsProvider = StateProvider<int>((ref) => 0);
final polyrhythmEnabledProvider = StateProvider<bool>((ref) => false);
final polyrhythmValueProvider = StateProvider<int>((ref) => 3);
