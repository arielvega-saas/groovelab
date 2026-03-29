import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recording state providers.
final isRecordingProvider = StateProvider<bool>((ref) => false);
final recordingDurationProvider = StateProvider<Duration>((ref) => Duration.zero);
final webRecStateProvider = StateProvider<String>((ref) => 'idle');
final webRecHasRecordingProvider = StateProvider<bool>((ref) => false);
