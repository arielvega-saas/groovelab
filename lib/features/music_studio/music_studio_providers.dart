import 'package:flutter_riverpod/flutter_riverpod.dart';

// Backend API URL
final musicStudioBackendUrlProvider = StateProvider<String>((ref) => 'http://localhost:8000');

// Active project ID
final musicStudioProjectIdProvider = StateProvider<String?>((ref) => null);

// Processing state (loading/analyzing/separating)
final musicStudioProcessingProvider = StateProvider<bool>((ref) => false);

// Stems separation ready
final musicStudioStemsReadyProvider = StateProvider<bool>((ref) => false);

// Chord detection ready
final musicStudioChordsReadyProvider = StateProvider<bool>((ref) => false);

// Lyrics extraction ready
final musicStudioLyricsReadyProvider = StateProvider<bool>((ref) => false);
