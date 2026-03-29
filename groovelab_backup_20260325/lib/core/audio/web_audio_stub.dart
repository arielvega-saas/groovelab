import 'dart:async';
import 'dart:typed_data';
import 'native_audio_bridge.dart';

/// Stub implementation for non-web platforms.
/// All methods are no-ops. The real audio goes through NativeAudioBridge.
class WebAudioBridge {
  final _beatController = StreamController<BeatEvent>.broadcast();
  final _midiController = StreamController<MidiEvent>.broadcast();
  final _overdubStopController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<BeatEvent> get beatEvents => _beatController.stream;
  Stream<MidiEvent> get midiEvents => _midiController.stream;
  Stream<Map<String, dynamic>> get overdubAutoStop => _overdubStopController.stream;

  Future<void> init() async {}

  Future<void> loadSound(String key, Uint8List wavData) async {}

  Future<void> startMetronome({
    required int bpm,
    required int beatsPerBar,
    required int beatUnit,
    required int subdivision,
    required int swingPercent,
    required String clickSound,
    required List<double> accentPattern,
    required bool hapticEnabled,
  }) async {}

  Future<void> stopMetronome() async {}
  Future<void> updateBpm(int bpm) async {}
  Future<void> updateTimeSignature(int beatsPerBar, int beatUnit) async {}
  Future<void> updateSubdivision(int sub) async {}
  Future<void> updateSwing(int pct) async {}
  Future<void> updateClickSound(String name) async {}
  Future<void> updateAccentPattern(List<double> pattern) async {}
  Future<void> updateHumanFeel(int pct) async {}
  Future<void> updateCountIn(int bars) async {}
  Future<void> setHapticMode(bool enabled) async {}
  Future<void> updatePolyrhythm(bool enabled, int value) async {}
  Future<void> updateIntervalTraining(bool enabled, int clickBars, int silentBars) async {}
  Future<void> updateRandomSilence(bool enabled, int probability) async {}

  Future<void> startDrumPattern({
    required int bpm,
    required Map<String, List<int>> pattern,
    required int swingPercent,
    int drumBeats = 4,
    int drumBeatUnit = 4,
    List<double> drumAccentPattern = const [],
  }) async {}

  Future<void> stopDrumPattern() async {}
  Future<void> updateDrumPattern(Map<String, List<int>> p) async {}
  Future<void> updateDrumVolumes(Map<String, double> v) async {}
  Future<void> updateDrumTimeSig(int beats, int beatUnit) async {}
  Future<void> updateDrumAccentPattern(List<double> p) async {}

  Future<double> getOutputLatency() async => 0;
  Future<double> getInputLatency() async => 0;

  // Web Recording stubs
  Future<String> startWebRecording() async => 'error';
  Future<bool> stopWebRecording() async => false;
  String getLastRecordingUrl() => '';
  bool hasRecording() => false;
  Future<bool> playRecording() async => false;
  Future<bool> stopPlayback() async => false;
  Future<bool> discardRecording() async => false;
  Future<void> resumeContext() async {}

  // Loop Station stubs
  Future<String> startLoopRecording() async => 'error';
  Future<Map<String, dynamic>> stopLoopRecording() async => {'success': false, 'layerCount': 0};
  Future<void> startLoopPlayback() async {}
  Future<void> stopLoopPlayback() async {}
  Future<void> undoLoopLayer() async {}
  Future<void> clearLoop() async {}
  Future<void> setLoopLayerVolume(int index, double volume) async {}
  Map<String, dynamic> getLoopState() => {'layerCount': 0, 'duration': 0.0, 'isPlaying': false, 'isRecording': false};

  // Loop Station - enhanced stubs
  Future<void> setLayerMute(int index, bool muted) async {}
  Future<void> setLayerSolo(int index, bool solo) async {}
  Future<void> setLayerPan(int index, double pan) async {}
  Future<void> deleteLoopLayer(int index) async {}
  Future<void> renameLoopLayer(int index, String name) async {}
  Future<void> startInputMonitoring() async {}
  Future<void> stopInputMonitoring() async {}
  Future<void> setMonitorVolume(double vol) async {}
  Future<void> setGuideVolume(double vol) async {}
  Future<void> setLoopMasterVolume(double vol) async {}
  Future<void> muteGuide(bool muted) async {}
  Future<String> exportLoopMixdown(String format, {bool includeGuide = false}) async => '';
  List<double> getLayerWaveform(int index, int numSamples) => List.filled(numSamples, 0.0);
  Future<void> startInputLevelMeter(void Function(double level) callback) async {}
  Future<void> stopInputLevelMeter() async {}

  // Tuner stubs
  Future<void> startTuner(void Function(Map<String, dynamic> data) callback, {String? deviceId}) async {}
  Future<void> stopTuner() async {}

  // Drum hit stubs
  Future<void> playDrumHit(String track) async {}
  Future<List<Map<String, String>>> getAudioInputDevices() async => [];
  void setLoopPositionCallback(void Function(double position) callback) {}
  Future<void> setMidiLoopMapping(String action, int noteNumber) async {}

  // Loop position & input level streams
  Stream<double> get loopPosition => const Stream<double>.empty();
  Stream<double> get inputLevel => const Stream<double>.empty();

  // Loop Beat Info
  Map<String, int> getLoopBeatInfo() => {'bar': 0, 'beat': 0, 'total': 0};

  // Export Stems
  Future<List<Map<String, dynamic>>> exportStems() async => [];
  Future<String> exportSelectedLayers(List<int> indices) async => '';

  // PAD System stubs
  Future<Map<String, dynamic>> loadPad(Uint8List audioData, String name, String key, double tempo) async => {'success': false};
  Future<Map<String, dynamic>> loadPadFromUrl(String url, String name, String key, double tempo) async => {'success': false};
  Future<bool> playPad(int index, bool loop) async => false;
  Future<bool> stopPad(int index) async => false;
  Future<void> stopAllPads() async {}
  Future<void> setPadVolume(int index, double volume) async {}
  Future<void> setPadPan(int index, double pan) async {}
  Future<void> setPadPitch(int index, double semitones) async {}
  Future<void> setPadTempo(int index, double targetBpm) async {}
  Future<bool> removePad(int index) async => false;
  List<Map<String, dynamic>> getPadState() => [];
  Future<void> setPadMasterVolume(double volume) async {}
  Future<void> setPadRouting(double padPan, double guidePan) async {}
  Future<Map<String, dynamic>> checkAudioOutputDevices() async => {};

  // PAD Crossfade Engine stubs
  Future<bool> setActivePadSound(int index) async => false;
  int getActivePadIndex() => -1;
  String? getActivePadKey() => null;
  Future<void> setPadTransition(String mode, double time) async {}
  Future<void> setPadHold(bool hold) async {}
  bool isPadHolding() => false;
  Future<bool> playPadAtKey(String targetKey, {double? crossfadeTime}) async => false;
  Future<bool> fadeOutActivePad({double? fadeTime}) async => false;
  Future<bool> stopActivePad() async => false;
  bool isActivePadPlaying() => false;

  // MIDI stubs
  Future<List<Map<String, String>>> initMidi() async => [];
  List<Map<String, String>> getMidiDevices() => [];
  Future<void> disconnectMidi() async {}

  // Song Lab stubs
  final _songLabPositionController = StreamController<double>.broadcast();
  Stream<double> get songLabPosition => _songLabPositionController.stream;
  Future<Map<String, dynamic>> songLabLoadTrack(Uint8List audioData, String name, String stemType) async => {'duration': 0.0, 'sampleRate': 44100};
  Future<void> songLabPlay() async {}
  Future<void> songLabPause() async {}
  Future<void> songLabStop() async {}
  Future<void> songLabSeek(double position) async {}
  Future<void> songLabSetTrackVolume(int index, double volume) async {}
  Future<void> songLabSetTrackPan(int index, double pan) async {}
  Future<void> songLabSetTrackMute(int index, bool muted) async {}
  Future<void> songLabSetTrackSolo(int index, bool solo) async {}
  Future<void> songLabSetSpeed(double speed) async {}
  Future<void> songLabSetPitchShift(int semitones) async {}
  Future<void> songLabSetLoopRegion(double start, double end) async {}
  Future<void> songLabClearLoopRegion() async {}
  double songLabGetPosition() => 0.0;
  Map<String, dynamic> songLabGetState() => {'isPlaying': false, 'position': 0.0, 'duration': 0.0, 'trackCount': 0};
  List<double> songLabGetWaveform(int trackIndex, int numSamples) => List.filled(numSamples, 0.0);
  Future<void> songLabClearAll() async {}
  Future<Map<String, dynamic>> songLabMockSeparate(int trackIndex) async => {'success': false};
  Future<String> songLabExportMixdown() async => '';
  List<Map<String, dynamic>> songLabDetectPitch([int trackIndex = 0]) => [];
  void songLabToggleClick(bool enabled, int bpm) {}

  // Pedalera stubs
  Future<void> initPedalera() async {}
  Future<void> setPedalChain(List<Map<String, dynamic>> chainConfig) async {}
  Future<void> setPedalParam(int pedalIndex, String paramName, double value) async {}
  Future<void> setPedalBypass(int pedalIndex, bool bypassed) async {}
  Future<void> stopPedalera() async {}
  double getPedalLatency() => 0.0;

  void dispose() {
    _beatController.close();
    _midiController.close();
    _overdubStopController.close();
    _songLabPositionController.close();
  }
}
