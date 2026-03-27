import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'native_audio_bridge.dart';
import 'sound_generator.dart';
import 'web_audio_bridge.dart';

/// High-level audio service that manages the native bridge,
/// pre-loads sounds, and exposes reactive state to the UI.
///
/// On web: uses WebAudioBridge (JavaScript Web Audio API)
/// On native: uses NativeAudioBridge (platform channels → iOS/Android)
class AudioService {
  final NativeAudioBridge _bridge = NativeAudioBridge();
  final WebAudioBridge _webBridge = WebAudioBridge();
  bool _initialized = false;
  bool _fallbackMode = false;
  bool _useWeb = false;

  NativeAudioBridge get bridge => _bridge;
  bool get isNativeAvailable => _initialized && !_fallbackMode;

  /// Initialize the appropriate engine and pre-load all sounds.
  Future<void> init() async {
    if (kIsWeb) {
      // Web platform: use JavaScript Web Audio API
      await _initWeb();
    } else {
      // Native platform: use platform channels
      await _initNative();
    }
  }

  Future<void> _initWeb() async {
    try {
      await _webBridge.init();
      await _preloadSoundsWeb();
      _useWeb = true;
      _initialized = true;
      debugPrint('AudioService: Web Audio engine initialized');
    } catch (e) {
      debugPrint('AudioService: Web Audio init failed ($e)');
      _fallbackMode = true;
      _initialized = true;
    }
  }

  Future<void> _initNative() async {
    try {
      await _bridge.init();
      await _preloadSounds();
      _initialized = true;
      debugPrint('AudioService: Native engine initialized');
    } on PlatformException catch (e) {
      debugPrint('AudioService: Native init failed ($e), using fallback');
      _fallbackMode = true;
      _initialized = true;
    } on MissingPluginException {
      debugPrint('AudioService: No native plugin, using fallback');
      _fallbackMode = true;
      _initialized = true;
    }
  }

  /// Sound definitions shared by both web and native preloading
  static final _soundGenerators = <String, Uint8List Function()>{
    'click_accent': () => SoundGenerator.generateClick(1200, 0.03, 0.9),
    'click_normal': () => SoundGenerator.generateClick(800, 0.03, 0.7),
    'click_ghost': () => SoundGenerator.generateClick(800, 0.03, 0.3),
    'click_sub': () => SoundGenerator.generateClick(600, 0.02, 0.3),
    'digital_accent': () => SoundGenerator.generateClick(1500, 0.02, 0.9),
    'digital_normal': () => SoundGenerator.generateClick(1000, 0.02, 0.7),
    'hihat_click': () => SoundGenerator.generateNoise(0.03, 0.5, 8000),
    'clave_accent': () => SoundGenerator.generateClick(2500, 0.02, 0.8),
    'clave_normal': () => SoundGenerator.generateClick(2000, 0.02, 0.6),
    'cowbell_accent': () => SoundGenerator.generateClick(800, 0.06, 0.7),
    'cowbell_normal': () => SoundGenerator.generateClick(600, 0.06, 0.5),
    'beep_accent': () => SoundGenerator.generateSine(880, 0.04, 0.7),
    'beep_normal': () => SoundGenerator.generateSine(660, 0.04, 0.5),
    'rimshot_accent': () => SoundGenerator.generateRimshot(accent: true),
    'rimshot_normal': () => SoundGenerator.generateRimshot(),
    'shaker_accent': () => SoundGenerator.generateShaker(accent: true),
    'shaker_normal': () => SoundGenerator.generateShaker(),
    'tambourine_accent': () => SoundGenerator.generateTambourine(accent: true),
    'tambourine_normal': () => SoundGenerator.generateTambourine(),
    'kick': () => SoundGenerator.generateKick(),
    'snare': () => SoundGenerator.generateSnare(),
    'hihat': () => SoundGenerator.generateHiHat(),
    'hihat_open': () => SoundGenerator.generateHiHat(open: true),
    'ride': () => SoundGenerator.generateRide(),
    // ── Expert 4: Pro click presets ──────────────────────────────
    'woodblock_accent': () => SoundGeneratorPro.generateWoodBlock(accent: true),
    'woodblock_normal': () => SoundGeneratorPro.generateWoodBlock(),
    'sineburst_accent': () => SoundGeneratorPro.generateSineBurst(accent: true),
    'sineburst_normal': () => SoundGeneratorPro.generateSineBurst(),
    'clave_hq_accent':  () => SoundGeneratorPro.generateClaveHQ(accent: true),
    'clave_hq_normal':  () => SoundGeneratorPro.generateClaveHQ(),
    // ── New drum sounds ─────────────────────────────────────────
    'tom_rack':         () => SoundGeneratorPro.generateTom(pitch: 0),
    'tom_floor':        () => SoundGeneratorPro.generateTom(pitch: 1),
    'crash':            () => SoundGeneratorPro.generateCrash(),
    'clap':             () => SoundGeneratorPro.generateClap(),
    'conga_open':       () => SoundGeneratorPro.generateConga(open: true),
    'conga_slap':       () => SoundGeneratorPro.generateConga(open: false),
    'ghost_snare':      () => SoundGeneratorPro.generateGhostSnare(),
    'kick_pro':         () => SoundGeneratorPro.generateKickPro(),
    // ── New click presets ───────────────────────────────────────
    'stick_accent':     () => SoundGeneratorPro.generateStickClick(),
    'stick_normal':     () => SoundGeneratorPro.generateStickClick(),
    'tick_accent':      () => SoundGeneratorPro.generateMechanicalTick(accent: true),
    'tick_normal':      () => SoundGeneratorPro.generateMechanicalTick(accent: false),
    '808cowbell_accent': () => SoundGeneratorPro.generate808Cowbell(),
    '808cowbell_normal': () => SoundGeneratorPro.generate808Cowbell(),
  };

  Future<void> _preloadSounds() async {
    for (final entry in _soundGenerators.entries) {
      final data = entry.value();
      await _bridge.loadSound(entry.key, data);
      await Future.delayed(Duration.zero);
    }
  }

  Future<void> _preloadSoundsWeb() async {
    for (final entry in _soundGenerators.entries) {
      final data = entry.value();
      await _webBridge.loadSound(entry.key, data);
      await Future.delayed(Duration.zero);
    }
  }

  // ── Metronome ──

  Future<void> startMetronome({
    required int bpm,
    required int beatsPerBar,
    required int beatUnit,
    int subdivision = 1,
    int swingPercent = 0,
    String clickSound = 'Wood',
    List<double> accentPattern = const [1.0, 0.7, 0.7, 0.7],
    bool hapticEnabled = false,
  }) async {
    if (!_initialized) await init();
    if (_useWeb) {
      await _webBridge.startMetronome(
        bpm: bpm,
        beatsPerBar: beatsPerBar,
        beatUnit: beatUnit,
        subdivision: subdivision,
        swingPercent: swingPercent,
        clickSound: clickSound,
        accentPattern: accentPattern,
        hapticEnabled: hapticEnabled,
      );
    } else {
      await _bridge.startMetronome(
        bpm: bpm,
        beatsPerBar: beatsPerBar,
        beatUnit: beatUnit,
        subdivision: subdivision,
        swingPercent: swingPercent,
        clickSound: clickSound,
        accentPattern: accentPattern,
        hapticEnabled: hapticEnabled,
      );
    }
  }

  Future<void> stopMetronome() =>
      _useWeb ? _webBridge.stopMetronome() : _bridge.stopMetronome();

  Future<void> updateBpm(int bpm) =>
      _useWeb ? _webBridge.updateBpm(bpm) : _bridge.updateBpm(bpm);

  Future<void> updateTimeSignature(int beats, int unit) =>
      _useWeb ? _webBridge.updateTimeSignature(beats, unit) : _bridge.updateTimeSignature(beats, unit);

  Future<void> updateSubdivision(int sub) =>
      _useWeb ? _webBridge.updateSubdivision(sub) : _bridge.updateSubdivision(sub);

  Future<void> updateSwing(int pct) =>
      _useWeb ? _webBridge.updateSwing(pct) : _bridge.updateSwing(pct);

  Future<void> updateClickSound(String s) =>
      _useWeb ? _webBridge.updateClickSound(s) : _bridge.updateClickSound(s);

  Future<void> updateAccentPattern(List<double> p) =>
      _useWeb ? _webBridge.updateAccentPattern(p) : _bridge.updateAccentPattern(p);

  Future<void> setHapticMode(bool e) =>
      _useWeb ? _webBridge.setHapticMode(e) : _bridge.setHapticMode(e);

  Future<void> updateHumanFeel(int pct) =>
      _useWeb ? _webBridge.updateHumanFeel(pct) : _bridge.updateHumanFeel(pct);

  Future<void> updateCountIn(int bars) =>
      _useWeb ? _webBridge.updateCountIn(bars) : Future.value();

  Future<void> updatePolyrhythm(bool enabled, int value) =>
      _useWeb ? _webBridge.updatePolyrhythm(enabled, value) : _bridge.updatePolyrhythm(enabled, value);

  Future<void> updateIntervalTraining(bool enabled, int clickBars, int silentBars) =>
      _useWeb ? _webBridge.updateIntervalTraining(enabled, clickBars, silentBars) : Future.value();

  Future<void> updateRandomSilence(bool enabled, int probability) =>
      _useWeb ? _webBridge.updateRandomSilence(enabled, probability) : Future.value();

  // ── Drums ──

  Future<void> startDrumPattern({
    required int bpm,
    required Map<String, List<int>> pattern,
    int swingPercent = 0,
    int drumBeats = 4,
    int drumBeatUnit = 4,
    List<double> drumAccentPattern = const [],
  }) => _useWeb
      ? _webBridge.startDrumPattern(bpm: bpm, pattern: pattern, swingPercent: swingPercent,
          drumBeats: drumBeats, drumBeatUnit: drumBeatUnit, drumAccentPattern: drumAccentPattern)
      : _bridge.startDrumPattern(bpm: bpm, pattern: pattern, swingPercent: swingPercent);

  Future<void> stopDrumPattern() =>
      _useWeb ? _webBridge.stopDrumPattern() : _bridge.stopDrumPattern();

  Future<void> updateDrumPattern(Map<String, List<int>> p) =>
      _useWeb ? _webBridge.updateDrumPattern(p) : _bridge.updateDrumPattern(p);

  Future<void> updateDrumVolumes(Map<String, double> v) =>
      _useWeb ? _webBridge.updateDrumVolumes(v) : _bridge.updateDrumVolumes(v);

  Future<void> updateDrumTimeSig(int beats, int beatUnit) =>
      _useWeb ? _webBridge.updateDrumTimeSig(beats, beatUnit) : Future.value();

  Future<void> updateDrumAccentPattern(List<double> p) =>
      _useWeb ? _webBridge.updateDrumAccentPattern(p) : Future.value();

  // ── Recording ──

  Future<void> startRecording() => _bridge.startRecording();
  Future<String?> stopRecording() => _bridge.stopRecording();
  Future<void> enableOnsetDetection({
    double threshold = 0.1,
    int minIntervalMs = 50,
  }) => _bridge.enableOnsetDetection(
    threshold: threshold,
    minIntervalMs: minIntervalMs,
  );
  Future<void> disableOnsetDetection() => _bridge.disableOnsetDetection();

  // ── Web Recording ──

  Future<String> startWebRecording() => _webBridge.startWebRecording();
  Future<bool> stopWebRecording() => _webBridge.stopWebRecording();
  String getLastRecordingUrl() => _webBridge.getLastRecordingUrl();
  bool hasWebRecording() => _webBridge.hasRecording();
  Future<bool> playWebRecording() => _webBridge.playRecording();
  Future<bool> stopWebPlayback() => _webBridge.stopPlayback();
  Future<bool> discardWebRecording() => _webBridge.discardRecording();
  Future<void> resumeAudioContext() => _webBridge.resumeContext();

  // ── Latency ──

  Future<double> getOutputLatency() =>
      _useWeb ? _webBridge.getOutputLatency() : _bridge.getOutputLatency();

  Future<double> getInputLatency() =>
      _useWeb ? _webBridge.getInputLatency() : _bridge.getInputLatency();

  // ── Loop Station ──
  // CRITICAL: All methods must check _useWeb to avoid calling web stub on native

  Future<String> startLoopRecording() =>
      _useWeb ? _webBridge.startLoopRecording() : _bridge.startLoopRecording();
  Future<Map<String, dynamic>> stopLoopRecording() async {
    if (_useWeb) return _webBridge.stopLoopRecording();
    final result = await _bridge.stopLoopRecording();
    // On native, fetch waveform data for all layers after recording stops
    if (!_useWeb && result['success'] == true) {
      final layerCount = (result['layerCount'] as int?) ?? 0;
      for (int i = 0; i < layerCount; i++) {
        if (!_nativeLayerWaveforms.containsKey(i)) {
          final waveform = await _bridge.safeInvoke<List>('getLayerWaveform', {'index': i, 'numSamples': 80});
          if (waveform != null) {
            _nativeLayerWaveforms[i] = waveform.map((e) => (e as num).toDouble()).toList();
          }
        }
      }
    }
    return result;
  }
  Future<void> startLoopPlayback() =>
      _useWeb ? _webBridge.startLoopPlayback() : _bridge.startLoopPlayback();
  Future<void> stopLoopPlayback() =>
      _useWeb ? _webBridge.stopLoopPlayback() : _bridge.stopLoopPlayback();
  Future<void> undoLoopLayer() =>
      _useWeb ? _webBridge.undoLoopLayer() : _bridge.undoLoopLayer();
  Future<void> clearLoop() {
    _nativeLayerWaveforms.clear();
    return _useWeb ? _webBridge.clearLoop() : _bridge.clearLoop();
  }
  Future<void> setLoopLayerVolume(int index, double volume) =>
      _useWeb ? _webBridge.setLoopLayerVolume(index, volume) : _bridge.setLoopLayerVolume(index, volume);
  Map<String, dynamic> getLoopState() =>
      _useWeb ? _webBridge.getLoopState() : _bridge.getLoopState();

  // ── Loop Station - enhanced ──

  Future<void> setLayerMute(int index, bool muted) =>
      _useWeb ? _webBridge.setLayerMute(index, muted) : _bridge.setLayerMute(index, muted);
  Future<void> setLayerSolo(int index, bool solo) =>
      _useWeb ? _webBridge.setLayerSolo(index, solo) : _bridge.setLayerSolo(index, solo);
  Future<void> setLayerPan(int index, double pan) =>
      _useWeb ? _webBridge.setLayerPan(index, pan) : _bridge.setLayerPan(index, pan);
  Future<void> deleteLoopLayer(int index) =>
      _useWeb ? _webBridge.deleteLoopLayer(index) : _bridge.deleteLoopLayer(index);
  Future<void> renameLoopLayer(int index, String name) =>
      _useWeb ? _webBridge.renameLoopLayer(index, name) : _bridge.renameLoopLayer(index, name);

  Future<void> startInputMonitoring() =>
      _useWeb ? _webBridge.startInputMonitoring() : Future.value();
  Future<void> stopInputMonitoring() =>
      _useWeb ? _webBridge.stopInputMonitoring() : Future.value();
  Future<void> setMonitorVolume(double vol) =>
      _useWeb ? _webBridge.setMonitorVolume(vol) : Future.value();

  Future<void> setGuideVolume(double vol) =>
      _useWeb ? _webBridge.setGuideVolume(vol) : Future.value();
  Future<void> setLoopMasterVolume(double vol) =>
      _useWeb ? _webBridge.setLoopMasterVolume(vol) : Future.value();
  Future<void> muteGuide(bool muted) =>
      _useWeb ? _webBridge.muteGuide(muted) : Future.value();

  Future<String> exportLoopMixdown(String format, {bool includeGuide = false}) =>
      _useWeb ? _webBridge.exportLoopMixdown(format, includeGuide: includeGuide) : Future.value('');

  List<double> getLayerWaveform(int index, int numSamples) =>
      _useWeb ? _webBridge.getLayerWaveform(index, numSamples) : _nativeLayerWaveforms[index] ?? List.filled(numSamples, 0.0);

  // Cache for native layer waveforms (populated after stopLoopRecording)
  final Map<int, List<double>> _nativeLayerWaveforms = {};

  Future<void> startInputLevelMeter(void Function(double level) callback) =>
      _useWeb ? _webBridge.startInputLevelMeter(callback) : Future.value();
  Future<void> stopInputLevelMeter() =>
      _useWeb ? _webBridge.stopInputLevelMeter() : Future.value();

  Future<void> startTuner(void Function(Map<String, dynamic> data) callback, {String? deviceId}) =>
      _useWeb ? _webBridge.startTuner(callback, deviceId: deviceId) : Future.value();
  Future<void> stopTuner() =>
      _useWeb ? _webBridge.stopTuner() : Future.value();
  Future<void> playDrumHit(String track, {double volume = 1.0}) async {
    if (!_initialized) await init();
    if (_useWeb) {
      await _webBridge.playDrumHit(track);
    } else {
      await _bridge.safeInvoke('playSound', {'key': track, 'volume': volume});
    }
  }
  Future<List<Map<String, String>>> getAudioInputDevices() =>
      _useWeb ? _webBridge.getAudioInputDevices() : Future.value([]);

  void setLoopPositionCallback(void Function(double position) callback) {
    if (_useWeb) _webBridge.setLoopPositionCallback(callback);
  }

  Future<void> setMidiLoopMapping(String action, int noteNumber) =>
      _useWeb ? _webBridge.setMidiLoopMapping(action, noteNumber) : Future.value();

  Stream<double> get loopPosition => _useWeb ? _webBridge.loopPosition : _bridge.loopPosition;
  Stream<double> get inputLevel => _useWeb ? _webBridge.inputLevel : _bridge.inputLevel;
  Stream<Map<String, dynamic>> get overdubAutoStop => _useWeb ? _webBridge.overdubAutoStop : _bridge.overdubAutoStop;

  // ── Loop Beat Info ──

  Map<String, int> getLoopBeatInfo() =>
      _useWeb ? _webBridge.getLoopBeatInfo() : {'currentBeat': 0, 'totalBeats': 0};

  // ── Export Stems ──

  Future<List<Map<String, dynamic>>> exportStems() =>
      _useWeb ? _webBridge.exportStems() : Future.value([]);
  Future<String> exportSelectedLayers(List<int> indices) =>
      _useWeb ? _webBridge.exportSelectedLayers(indices) : Future.value('');

  // ── PAD System ──

  Future<Map<String, dynamic>> loadPad(Uint8List audioData, String name, String key, double tempo) =>
      _useWeb ? _webBridge.loadPad(audioData, name, key, tempo) : Future.value({'error': 'native_not_supported'});
  Future<Map<String, dynamic>> loadPadFromUrl(String url, String name, String key, double tempo) =>
      _useWeb ? _webBridge.loadPadFromUrl(url, name, key, tempo) : Future.value({'error': 'native_not_supported'});
  Future<bool> playPad(int index, bool loop) =>
      _useWeb ? _webBridge.playPad(index, loop) : Future.value(false);
  Future<bool> stopPad(int index) =>
      _useWeb ? _webBridge.stopPad(index) : Future.value(false);
  Future<void> stopAllPads() =>
      _useWeb ? _webBridge.stopAllPads() : Future.value();
  Future<void> setPadVolume(int index, double volume) =>
      _useWeb ? _webBridge.setPadVolume(index, volume) : Future.value();
  Future<void> setPadPan(int index, double pan) =>
      _useWeb ? _webBridge.setPadPan(index, pan) : Future.value();
  Future<void> setPadPitch(int index, double semitones) =>
      _useWeb ? _webBridge.setPadPitch(index, semitones) : Future.value();
  Future<void> setPadTempo(int index, double targetBpm) =>
      _useWeb ? _webBridge.setPadTempo(index, targetBpm) : Future.value();
  Future<bool> removePad(int index) =>
      _useWeb ? _webBridge.removePad(index) : Future.value(false);
  List<Map<String, dynamic>> getPadState() =>
      _useWeb ? _webBridge.getPadState() : [];
  Future<void> setPadMasterVolume(double volume) =>
      _useWeb ? _webBridge.setPadMasterVolume(volume) : Future.value();
  Future<void> setPadRouting(double padPan, double guidePan) =>
      _useWeb ? _webBridge.setPadRouting(padPan, guidePan) : Future.value();
  Future<Map<String, dynamic>> checkAudioOutputDevices() =>
      _useWeb ? _webBridge.checkAudioOutputDevices() : Future.value({});

  // ── PAD Crossfade Engine ──
  Future<bool> setActivePadSound(int index) =>
      _useWeb ? _webBridge.setActivePadSound(index) : Future.value(false);
  int getActivePadIndex() => _useWeb ? _webBridge.getActivePadIndex() : -1;
  String? getActivePadKey() => _useWeb ? _webBridge.getActivePadKey() : null;
  Future<void> setPadTransition(String mode, double time) =>
      _useWeb ? _webBridge.setPadTransition(mode, time) : Future.value();
  Future<void> setPadHold(bool hold) =>
      _useWeb ? _webBridge.setPadHold(hold) : Future.value();
  bool isPadHolding() => _useWeb ? _webBridge.isPadHolding() : false;
  Future<bool> playPadAtKey(String targetKey, {double? crossfadeTime}) =>
      _useWeb ? _webBridge.playPadAtKey(targetKey, crossfadeTime: crossfadeTime) : Future.value(false);
  Future<bool> fadeOutActivePad({double? fadeTime}) =>
      _useWeb ? _webBridge.fadeOutActivePad(fadeTime: fadeTime) : Future.value(false);
  Future<bool> stopActivePad() =>
      _useWeb ? _webBridge.stopActivePad() : Future.value(false);
  bool isActivePadPlaying() => _useWeb ? _webBridge.isActivePadPlaying() : false;

  // ── Song Lab ──

  Future<Map<String, dynamic>> songLabLoadTrack(Uint8List audioData, String name, String stemType) =>
      _useWeb ? _webBridge.songLabLoadTrack(audioData, name, stemType) : _bridge.songLabLoadTrack(audioData, name, stemType);
  Future<void> songLabPlay() =>
      _useWeb ? _webBridge.songLabPlay() : _bridge.songLabPlay();
  Future<void> songLabPause() =>
      _useWeb ? _webBridge.songLabPause() : _bridge.songLabPause();
  Future<void> songLabStop() =>
      _useWeb ? _webBridge.songLabStop() : _bridge.songLabStop();
  Future<void> songLabSeek(double position) =>
      _useWeb ? _webBridge.songLabSeek(position) : _bridge.songLabSeek(position);
  Future<void> songLabSetTrackVolume(int index, double volume) =>
      _useWeb ? _webBridge.songLabSetTrackVolume(index, volume) : _bridge.songLabSetTrackVolume(index, volume);
  Future<void> songLabSetTrackPan(int index, double pan) =>
      _useWeb ? _webBridge.songLabSetTrackPan(index, pan) : Future.value();
  Future<void> songLabSetTrackMute(int index, bool muted) =>
      _useWeb ? _webBridge.songLabSetTrackMute(index, muted) : Future.value();
  Future<void> songLabSetTrackSolo(int index, bool solo) =>
      _useWeb ? _webBridge.songLabSetTrackSolo(index, solo) : Future.value();
  Future<void> songLabSetSpeed(double speed) =>
      _useWeb ? _webBridge.songLabSetSpeed(speed) : _bridge.songLabSetSpeed(speed);
  Future<void> songLabSetPitchShift(int semitones) =>
      _useWeb ? _webBridge.songLabSetPitchShift(semitones) : Future.value();
  Future<void> songLabSetLoopRegion(double start, double end) =>
      _useWeb ? _webBridge.songLabSetLoopRegion(start, end) : Future.value();
  Future<void> songLabClearLoopRegion() =>
      _useWeb ? _webBridge.songLabClearLoopRegion() : Future.value();
  double songLabGetPosition() =>
      _useWeb ? _webBridge.songLabGetPosition() : 0.0;
  Map<String, dynamic> songLabGetState() =>
      _useWeb ? _webBridge.songLabGetState() : {};
  List<double> songLabGetWaveform(int trackIndex, int numSamples) =>
      _useWeb ? _webBridge.songLabGetWaveform(trackIndex, numSamples) : _bridge.songLabGetWaveform(trackIndex, numSamples);
  Future<void> songLabClearAll() =>
      _useWeb ? _webBridge.songLabClearAll() : _bridge.songLabClearAll();
  Future<Map<String, dynamic>> songLabMockSeparate(int trackIndex) =>
      _useWeb ? _webBridge.songLabMockSeparate(trackIndex) : Future.value({});
  Future<String> songLabExportMixdown() =>
      _useWeb ? _webBridge.songLabExportMixdown() : Future.value('');
  Stream<double> get songLabPosition =>
      _useWeb ? _webBridge.songLabPosition : _bridge.songLabPosition;
  List<Map<String, dynamic>> songLabDetectPitch([int trackIndex = 0]) =>
      _useWeb ? _webBridge.songLabDetectPitch(trackIndex) : [];
  void songLabToggleClick(bool enabled, int bpm) {
    if (_useWeb) _webBridge.songLabToggleClick(enabled, bpm);
  }

  // ── PEDALERA ──

  Future<void> initPedalera() =>
      _useWeb ? _webBridge.initPedalera() : _bridge.safeInvoke('initPedalera');
  Future<void> setPedalChain(List<Map<String, dynamic>> chainConfig) =>
      _useWeb ? _webBridge.setPedalChain(chainConfig)
              : _bridge.safeInvoke('setPedalChain', {'chain': chainConfig});
  Future<void> setPedalParam(int pedalIndex, String paramName, double value) =>
      _useWeb ? _webBridge.setPedalParam(pedalIndex, paramName, value)
              : _bridge.safeInvoke('setPedalParam', {'index': pedalIndex, 'param': paramName, 'value': value});
  Future<void> setPedalBypass(int pedalIndex, bool bypassed) =>
      _useWeb ? _webBridge.setPedalBypass(pedalIndex, bypassed)
              : _bridge.safeInvoke('setPedalBypass', {'index': pedalIndex, 'bypassed': bypassed});
  Future<void> stopPedalera() =>
      _useWeb ? _webBridge.stopPedalera() : _bridge.safeInvoke('stopPedalera');
  Future<double> getPedalLatencyAsync() async =>
      _useWeb ? _webBridge.getPedalLatency().toDouble()
              : await _bridge.safeInvoke<double>('getPedalLatency') ?? 0.0;
  double getPedalLatency() => _webBridge.getPedalLatency();

  // ── MIDI ──

  Future<dynamic> initMidi() =>
      _useWeb ? _webBridge.initMidi() : _bridge.initMidi();
  Future<List<dynamic>> getMidiDevices() async =>
      _useWeb ? _webBridge.getMidiDevices() : await _bridge.getMidiDevices();
  Future<void> disconnectMidi() =>
      _useWeb ? _webBridge.disconnectMidi() : _bridge.disconnectMidi();
  Stream<MidiEvent> get midiEvents =>
      _useWeb ? _webBridge.midiEvents : _bridge.midiEvents;

  // ── MIDI Send (native only — CoreMIDI on iOS) ──

  Future<void> sendMidiNoteOn(int note, int velocity, {int channel = 0}) =>
      _bridge.sendMidiNoteOn(note, velocity, channel: channel);
  Future<void> sendMidiNoteOff(int note, {int channel = 0}) =>
      _bridge.sendMidiNoteOff(note, channel: channel);
  Future<void> sendMidiCC(int controller, int value, {int channel = 0}) =>
      _bridge.sendMidiCC(controller, value, channel: channel);
  Future<void> sendMidiProgramChange(int program, {int channel = 0}) =>
      _bridge.sendMidiProgramChange(program, channel: channel);
  Future<void> startMidiClock(double bpm) => _bridge.startMidiClock(bpm);
  Future<void> stopMidiClock() => _bridge.stopMidiClock();
  Future<void> updateMidiClockBpm(double bpm) => _bridge.updateMidiClockBpm(bpm);

  // ── Audio Routing (native only) ──

  Future<Map<String, dynamic>> getAudioRoute() async {
    if (_useWeb) return {};
    final result = await _bridge.safeInvoke<Map>('getAudioRoute');
    return result != null ? Map<String, dynamic>.from(result) : {};
  }

  Future<List<Map<String, dynamic>>> getAvailableInputs() async {
    if (_useWeb) return [];
    final result = await _bridge.safeInvoke<List>('getAvailableInputs');
    return result?.map((d) => Map<String, dynamic>.from(d as Map)).toList() ?? [];
  }

  Future<bool> setPreferredInput(String uid) async {
    if (_useWeb) return false;
    return await _bridge.safeInvoke<bool>('setPreferredInput', {'uid': uid}) ?? false;
  }

  Future<void> setBufferDuration(double durationMs) async {
    if (_useWeb) return;
    await _bridge.safeInvoke('setBufferDuration', {'durationMs': durationMs});
  }

  // ── Streams ──

  Stream<BeatEvent> get beatEvents =>
      _useWeb ? _webBridge.beatEvents : _bridge.beatEvents;

  Stream<OnsetEvent> get onsetEvents => _bridge.onsetEvents;
  Stream<RecordingEvent> get recordingEvents => _bridge.recordingEvents;

  void dispose() {
    if (_useWeb) {
      _webBridge.dispose();
    } else {
      _bridge.dispose();
    }
  }
}

// ── Riverpod Providers ──

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
