// Conditional export: uses real Web Audio implementation on web,
// no-op stub on native platforms (iOS/Android/desktop).
export 'web_audio_stub.dart' if (dart.library.html) 'web_audio_impl.dart';
