import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to native audio engines via platform channels.
/// iOS: AVAudioEngine + mach_absolute_time scheduling
/// Android: Oboe (AAudio) + high-priority thread
class NativeAudioBridge {
  static const _methodChannel = MethodChannel('com.groovelab/audio_engine');
  static const _eventChannel = EventChannel('com.groovelab/audio_events');

  StreamSubscription? _eventSubscription;
  final _beatController = StreamController<BeatEvent>.broadcast();
  final _onsetController = StreamController<OnsetEvent>.broadcast();
  final _recordingController = StreamController<RecordingEvent>.broadcast();

  // ── Tuner stream (native) ──
  final _tunerController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of tuner pitch data from native pitch detection
  Stream<Map<String, dynamic>> get tunerEvents => _tunerController.stream;

  // ── Loop Station streams (native) ──
  final _loopPositionController = StreamController<double>.broadcast();
  final _inputLevelController = StreamController<double>.broadcast();
  final _overdubAutoStopController = StreamController<Map<String, dynamic>>.broadcast();
  final _loopStateController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of loop playback position (0.0 - 1.0)
  Stream<double> get loopPosition => _loopPositionController.stream;

  /// Stream of input level (0.0 - 1.0)
  Stream<double> get inputLevel => _inputLevelController.stream;

  /// Stream of overdub auto-stop events
  Stream<Map<String, dynamic>> get overdubAutoStop => _overdubAutoStopController.stream;

  /// Stream of loop state changes from native
  Stream<Map<String, dynamic>> get loopStateEvents => _loopStateController.stream;

  // Cached native loop state (updated via events)
  Map<String, dynamic> _cachedLoopState = {'state': 'idle', 'layerCount': 0};

  /// Stream of beat events from the native metronome
  Stream<BeatEvent> get beatEvents => _beatController.stream;

  /// Stream of detected onsets from native audio analysis
  Stream<OnsetEvent> get onsetEvents => _onsetController.stream;

  /// Stream of recording state changes
  Stream<RecordingEvent> get recordingEvents => _recordingController.stream;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _methodChannel.invokeMethod('init');
      _eventSubscription = _eventChannel
          .receiveBroadcastStream()
          .listen(_handleEvent, onError: _handleError);
      _initialized = true;
    } on PlatformException catch (e) {
      debugPrint('NativeAudioBridge init failed: ${e.message}');
      rethrow;
    }
  }

  /// Safe invoke that catches platform errors and prevents crashes
  /// when audio hardware is unavailable (e.g., session interrupted).
  Future<T?> safeInvoke<T>(String method, [dynamic args]) async {
    try {
      return await _methodChannel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('NativeAudioBridge.$method failed: ${e.message}');
      return null;
    } on MissingPluginException {
      debugPrint('NativeAudioBridge.$method: plugin not available');
      return null;
    }
  }

  /// Load a sound into the native engine's buffer pool.
  /// [key] is the identifier, [wavData] is raw WAV bytes.
  Future<void> loadSound(String key, Uint8List wavData) async {
    await safeInvoke('loadSound', {
      'key': key,
      'data': wavData,
    });
  }

  /// Start the native metronome with given parameters.
  Future<void> startMetronome({
    required int bpm,
    required int beatsPerBar,
    required int beatUnit,
    required int subdivision,
    required int swingPercent,
    required String clickSound,
    required List<double> accentPattern,
    required bool hapticEnabled,
  }) async {
    await _methodChannel.invokeMethod('startMetronome', {
      'bpm': bpm,
      'beatsPerBar': beatsPerBar,
      'beatUnit': beatUnit,
      'subdivision': subdivision,
      'swingPercent': swingPercent,
      'clickSound': clickSound,
      'accentPattern': accentPattern,
      'hapticEnabled': hapticEnabled,
    });
  }

  Future<void> stopMetronome() async {
    await safeInvoke('stopMetronome');
  }

  /// Update BPM without restarting the metronome (seamless transition).
  Future<void> updateBpm(int bpm) async {
    await safeInvoke('updateBpm', {'bpm': bpm});
  }

  /// Update time signature without restart.
  Future<void> updateTimeSignature(int beatsPerBar, int beatUnit) async {
    await safeInvoke('updateTimeSignature', {
      'beatsPerBar': beatsPerBar,
      'beatUnit': beatUnit,
    });
  }

  /// Update subdivision without restart.
  Future<void> updateSubdivision(int subdivision) async {
    await safeInvoke('updateSubdivision', {
      'subdivision': subdivision,
    });
  }

  /// Update swing amount (0-100).
  Future<void> updateSwing(int swingPercent) async {
    await safeInvoke('updateSwing', {
      'swingPercent': swingPercent,
    });
  }

  /// Update click sound type.
  Future<void> updateClickSound(String clickSound) async {
    await safeInvoke('updateClickSound', {
      'clickSound': clickSound,
    });
  }

  /// Update accent pattern.
  Future<void> updateAccentPattern(List<double> pattern) async {
    await safeInvoke('updateAccentPattern', {
      'pattern': pattern,
    });
  }

  /// Enable/disable haptic feedback mode.
  Future<void> setHapticMode(bool enabled) async {
    await safeInvoke('setHapticMode', {
      'enabled': enabled,
    });
  }

  /// Update human feel (velocity/timing randomization 0-50).
  Future<void> updateHumanFeel(int percent) async {
    await safeInvoke('updateHumanFeel', {
      'percent': percent,
    });
  }

  /// Update polyrhythm settings.
  Future<void> updatePolyrhythm(bool enabled, int value) async {
    await safeInvoke('updatePolyrhythm', {
      'enabled': enabled,
      'value': value,
    });
  }

  // ── DRUM MACHINE ──

  /// Start drum pattern playback.
  Future<void> startDrumPattern({
    required int bpm,
    required Map<String, List<int>> pattern,
    required int swingPercent,
  }) async {
    await safeInvoke('startDrumPattern', {
      'bpm': bpm,
      'pattern': pattern,
      'swingPercent': swingPercent,
    });
  }

  Future<void> stopDrumPattern() async {
    await safeInvoke('stopDrumPattern');
  }

  /// Update drum pattern without restart.
  Future<void> updateDrumPattern(Map<String, List<int>> pattern) async {
    await safeInvoke('updateDrumPattern', {
      'pattern': pattern,
    });
  }

  /// Update per-track drum volumes (0.0 - 1.0).
  Future<void> updateDrumVolumes(Map<String, double> volumes) async {
    await safeInvoke('updateDrumVolumes', {
      'volumes': volumes,
    });
  }

  // ── RECORDING ──

  /// Start recording from microphone.
  /// Returns immediately, audio is captured in native layer.
  Future<void> startRecording() async {
    await safeInvoke('startRecording');
  }

  /// Stop recording and return the file path of the recorded audio.
  Future<String?> stopRecording() async {
    return await safeInvoke<String>('stopRecording');
  }

  /// Enable onset detection during recording.
  Future<void> enableOnsetDetection({
    double threshold = 0.1,
    int minIntervalMs = 50,
  }) async {
    await safeInvoke('enableOnsetDetection', {
      'threshold': threshold,
      'minIntervalMs': minIntervalMs,
    });
  }

  Future<void> disableOnsetDetection() async {
    await safeInvoke('disableOnsetDetection');
  }

  /// Get the measured audio output latency in milliseconds.
  Future<double> getOutputLatency() async {
    return await safeInvoke<double>('getOutputLatency') ?? 0;
  }

  /// Get the measured audio input latency in milliseconds.
  Future<double> getInputLatency() async {
    return await safeInvoke<double>('getInputLatency') ?? 0;
  }

  // ── TUNER ──

  /// Start native pitch detection tuner.
  Future<void> startTuner() async {
    await safeInvoke('startTuner');
  }

  /// Stop native pitch detection tuner.
  Future<void> stopTuner() async {
    await safeInvoke('stopTuner');
  }

  // ── NATIVE MIDI (CoreMIDI on iOS) ──

  final _midiController = StreamController<MidiEvent>.broadcast();
  Stream<MidiEvent> get midiEvents => _midiController.stream;

  Future<bool> initMidi() async {
    return await safeInvoke<bool>('initMidi') ?? false;
  }

  Future<List<Map<String, dynamic>>> getMidiDevices() async {
    final result = await safeInvoke<List<dynamic>>('getMidiDevices');
    if (result == null) return [];
    return result.map((d) => Map<String, dynamic>.from(d as Map)).toList();
  }

  Future<void> sendMidiNoteOn(int note, int velocity, {int channel = 0}) async {
    await safeInvoke('sendMidiNoteOn', {
      'note': note, 'velocity': velocity, 'channel': channel,
    });
  }

  Future<void> sendMidiNoteOff(int note, {int channel = 0}) async {
    await safeInvoke('sendMidiNoteOff', {'note': note, 'channel': channel});
  }

  Future<void> sendMidiCC(int controller, int value, {int channel = 0}) async {
    await safeInvoke('sendMidiCC', {
      'controller': controller, 'value': value, 'channel': channel,
    });
  }

  Future<void> sendMidiProgramChange(int program, {int channel = 0}) async {
    await safeInvoke('sendMidiProgramChange', {'program': program, 'channel': channel});
  }

  Future<void> startMidiClock(double bpm) async {
    await safeInvoke('startMidiClock', {'bpm': bpm});
  }

  Future<void> stopMidiClock() async {
    await safeInvoke('stopMidiClock');
  }

  Future<void> updateMidiClockBpm(double bpm) async {
    await safeInvoke('updateMidiClockBpm', {'bpm': bpm});
  }

  Future<void> disconnectMidi() async {
    await safeInvoke('disconnectMidi');
  }

  // ── LOOP STATION (Native) ──

  Future<String> startLoopRecording() async {
    final result = await safeInvoke<String>('startLoopRecording');
    return result ?? 'error';
  }

  Future<Map<String, dynamic>> stopLoopRecording() async {
    final result = await safeInvoke<Map>('stopLoopRecording');
    if (result != null) return Map<String, dynamic>.from(result);
    return {'success': false, 'layerCount': 0};
  }

  Future<void> startLoopPlayback() => safeInvoke('startLoopPlayback');
  Future<void> stopLoopPlayback() => safeInvoke('stopLoopPlayback');
  Future<void> undoLoopLayer() => safeInvoke('undoLoopLayer');
  Future<void> clearLoop() => safeInvoke('clearLoop');

  Future<void> setLoopLayerVolume(int index, double volume) =>
      safeInvoke('setLoopLayerVolume', {'index': index, 'volume': volume});
  Future<void> setLayerMute(int index, bool muted) =>
      safeInvoke('setLayerMute', {'index': index, 'muted': muted});
  Future<void> setLayerSolo(int index, bool solo) =>
      safeInvoke('setLayerSolo', {'index': index, 'solo': solo});
  Future<void> setLayerPan(int index, double pan) =>
      safeInvoke('setLayerPan', {'index': index, 'pan': pan});
  Future<void> deleteLoopLayer(int index) =>
      safeInvoke('deleteLoopLayer', {'index': index});
  Future<void> renameLoopLayer(int index, String name) =>
      safeInvoke('renameLoopLayer', {'index': index, 'name': name});

  Map<String, dynamic> getLoopState() {
    // Return cached state updated via native events
    return _cachedLoopState;
  }

  Future<Map<String, dynamic>> getLoopStateAsync() async {
    final result = await safeInvoke<Map>('getLoopState');
    if (result != null) return Map<String, dynamic>.from(result);
    return {'state': 'idle', 'layerCount': 0};
  }

  // ── EVENT HANDLING ──

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    switch (type) {
      case 'beat':
        _beatController.add(BeatEvent(
          beatIndex: event['beatIndex'] as int,
          measureIndex: event['measureIndex'] as int,
          isAccent: event['isAccent'] as bool,
          timestampUs: event['timestampUs'] as int,
        ));
        break;
      case 'drumStep':
        _beatController.add(BeatEvent(
          beatIndex: event['step'] as int,
          measureIndex: event['measureIndex'] as int? ?? 0,
          isAccent: false,
          timestampUs: event['timestampUs'] as int? ?? 0,
          isDrumStep: true,
        ));
        break;
      case 'onset':
        _onsetController.add(OnsetEvent(
          timestampUs: event['timestampUs'] as int,
          amplitude: (event['amplitude'] as num).toDouble(),
          frequency: (event['frequency'] as num?)?.toDouble(),
        ));
        break;
      case 'recordingState':
        _recordingController.add(RecordingEvent(
          isRecording: event['isRecording'] as bool,
          durationMs: event['durationMs'] as int? ?? 0,
          filePath: event['filePath'] as String?,
        ));
        break;
      case 'midi':
        final kind = event['kind'] as String? ?? '';
        _midiController.add(MidiEvent(
          status: event['status'] as int? ?? 0,
          note: event['data1'] as int? ?? event['note'] as int? ?? 0,
          velocity: event['data2'] as int? ?? event['velocity'] as int? ?? 0,
          type: kind,
          action: '',
        ));
        break;
      case 'midiDeviceChange':
        // Notify listeners about device changes
        _midiController.add(const MidiEvent(
          status: 0, note: 0, velocity: 0,
          type: 'deviceChange', action: 'refresh',
        ));
        break;

      // ── Loop Station events from native ──
      case 'loopState':
        final stateStr = event['state'] as String? ?? 'idle';
        final layerCount = event['layerCount'] as int? ?? 0;
        final duration = (event['loopDuration'] as num?)?.toDouble() ?? 0.0;
        _cachedLoopState = {
          'state': stateStr,
          'layerCount': layerCount,
          'duration': duration,
          'isRecording': stateStr == 'recording' || stateStr == 'overdubbing',
          'isPlaying': stateStr == 'playing',
        };
        _loopStateController.add(_cachedLoopState);

        // Detect overdub auto-stop: state transitions to idle after overdubbing
        // The auto-stop sends a loopState event after stopRecording() completes
        break;

      case 'layerCount':
        final count = event['count'] as int? ?? 0;
        _cachedLoopState = {..._cachedLoopState, 'layerCount': count};
        _loopStateController.add(_cachedLoopState);
        break;

      case 'loopPosition':
        final pos = (event['position'] as num?)?.toDouble() ?? 0.0;
        _loopPositionController.add(pos);
        break;

      case 'inputLevel':
        final level = (event['level'] as num?)?.toDouble() ?? 0.0;
        _inputLevelController.add(level);
        break;

      case 'overdubAutoStop':
        final layerCount = event['layerCount'] as int? ?? 0;
        final duration = (event['duration'] as num?)?.toDouble() ?? 0.0;
        _overdubAutoStopController.add({
          'layerCount': layerCount,
          'duration': duration,
        });
        break;

      case 'tunerPitch':
        _tunerController.add(Map<String, dynamic>.from(event));
        break;

      case 'songLabPosition':
        final pos = (event['position'] as num?)?.toDouble() ?? 0.0;
        _songLabPositionController.add(pos);
        break;

      case 'songLabState':
        _cachedSongLabState = Map<String, dynamic>.from(event);
        break;
    }
  }

  void _handleError(dynamic error) {
    debugPrint('NativeAudioBridge event error: $error');
  }

  // ── METRONOME ENHANCEMENTS ──

  Future<void> updateCountIn(int bars) =>
      safeInvoke('updateCountIn', {'bars': bars});

  Future<void> updateIntervalTraining(bool enabled, int clickBars, int silentBars) =>
      safeInvoke('updateIntervalTraining', {
        'enabled': enabled,
        'clickBars': clickBars,
        'silentBars': silentBars,
      });

  Future<void> updateRandomSilence(bool enabled, int probability) =>
      safeInvoke('updateRandomSilence', {
        'enabled': enabled,
        'probability': probability,
      });

  Future<void> updateDrumTimeSig(int beats, int beatUnit) =>
      safeInvoke('updateDrumTimeSig', {'beats': beats, 'beatUnit': beatUnit});

  Future<void> updateDrumAccentPattern(List<double> pattern) =>
      safeInvoke('updateDrumAccentPattern', {'pattern': pattern});

  Future<void> setGuideVolume(double volume) =>
      safeInvoke('setGuideVolume', {'volume': volume});

  Future<void> muteGuide(bool muted) =>
      safeInvoke('muteGuide', {'muted': muted});

  // ── LOOP STATION ENHANCEMENTS ──

  Future<void> startInputMonitoring() =>
      safeInvoke('startInputMonitoring');

  Future<void> stopInputMonitoring() =>
      safeInvoke('stopInputMonitoring');

  Future<void> setMonitorVolume(double volume) =>
      safeInvoke('setMonitorVolume', {'volume': volume});

  Future<void> setLoopMasterVolume(double volume) =>
      safeInvoke('setLoopMasterVolume', {'volume': volume});

  Future<String> exportLoopMixdown(String format, {bool includeGuide = false}) async {
    final result = await safeInvoke<String>('exportLoopMixdown', {
      'format': format,
      'includeGuide': includeGuide,
    });
    return result ?? '';
  }

  Future<List<Map<String, dynamic>>> exportStems() async {
    final result = await safeInvoke<List>('exportStems');
    if (result == null) return [];
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String> exportSelectedLayers(List<int> indices) async {
    final result = await safeInvoke<String>('exportSelectedLayers', {'indices': indices});
    return result ?? '';
  }

  Future<void> startInputLevelMeter() =>
      safeInvoke('startInputLevelMeter');

  Future<void> stopInputLevelMeter() =>
      safeInvoke('stopInputLevelMeter');

  Future<List<Map<String, String>>> getAudioInputDevices() async {
    final result = await safeInvoke<List>('getAudioInputDevices');
    if (result == null) return [];
    return result.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  Map<String, int> getLoopBeatInfo() {
    return {'currentBeat': 0, 'totalBeats': 0};
  }

  // ── SONG LAB ENHANCEMENTS ──

  Future<void> songLabSetTrackPan(int index, double pan) =>
      safeInvoke('songLabSetTrackPan', {'index': index, 'pan': pan});

  Future<void> songLabSetTrackMute(int index, bool muted) =>
      safeInvoke('songLabSetTrackMute', {'index': index, 'muted': muted});

  Future<void> songLabSetTrackSolo(int index, bool solo) =>
      safeInvoke('songLabSetTrackSolo', {'index': index, 'solo': solo});

  Future<void> songLabSetPitchShift(int semitones) =>
      safeInvoke('songLabSetPitchShift', {'semitones': semitones});

  Future<void> songLabSetLoopRegion(double start, double end) =>
      safeInvoke('songLabSetLoopRegion', {'start': start, 'end': end});

  Future<void> songLabClearLoopRegion() =>
      safeInvoke('songLabClearLoopRegion');

  double songLabGetPosition() => 0.0;

  Map<String, dynamic> songLabGetState() => _cachedSongLabState;

  Future<String> songLabExportMixdown() async {
    final result = await safeInvoke<String>('songLabExportMixdown');
    return result ?? '';
  }

  Future<Map<String, dynamic>> songLabMockSeparate(int trackIndex) async {
    final result = await safeInvoke<Map>('songLabMockSeparate', {'trackIndex': trackIndex});
    if (result != null) return Map<String, dynamic>.from(result);
    return {};
  }

  // ── SONG LAB (Native) ──

  final _songLabPositionController = StreamController<double>.broadcast();
  Map<String, dynamic> _cachedSongLabState = {};

  Stream<double> get songLabPosition => _songLabPositionController.stream;

  Future<Map<String, dynamic>> songLabLoadTrack(Uint8List audioData, String name, String stemType) async {
    final result = await safeInvoke<Map>('songLabLoadTrack', {
      'data': audioData,
      'name': name,
      'stemType': stemType,
    });
    if (result != null) {
      // Fetch waveform data after successful load
      if (result['error'] == null) {
        await _fetchSongLabWaveform();
      }
      return Map<String, dynamic>.from(result);
    }
    return {'error': 'native_call_failed'};
  }

  Future<void> _fetchSongLabWaveform() async {
    final result = await safeInvoke<List>('songLabGetWaveform', {'numSamples': 200});
    if (result != null) {
      _cachedSongLabWaveform = result.map((e) => (e as num).toDouble()).toList();
    }
  }

  Future<void> songLabPlay() => safeInvoke('songLabPlay');
  Future<void> songLabPause() => safeInvoke('songLabPause');
  Future<void> songLabStop() => safeInvoke('songLabStop');
  Future<void> songLabSeek(double position) => safeInvoke('songLabSeek', {'position': position});
  Future<void> songLabSetTrackVolume(int index, double volume) => safeInvoke('songLabSetTrackVolume', {'index': index, 'volume': volume});
  Future<void> songLabSetSpeed(double speed) => safeInvoke('songLabSetSpeed', {'speed': speed});
  Future<void> songLabClearAll() => safeInvoke('songLabClearAll');

  List<double> songLabGetWaveform(int trackIndex, int numSamples) {
    // Waveform data is generated on the native side and cached
    // For native, we return the cached waveform or empty
    return _cachedSongLabWaveform.isNotEmpty ? _cachedSongLabWaveform : List.filled(numSamples, 0.0);
  }

  List<double> _cachedSongLabWaveform = [];

  // ── PAD ENGINE (Native) ──

  Future<void> loadPadSound(String key, Uint8List wavData) async {
    await safeInvoke('loadPadSound', {
      'key': key,
      'data': wavData,
    });
  }

  Future<void> playPad(String key) => safeInvoke('playPad', {'key': key});
  Future<void> stopPad(String key) => safeInvoke('stopPad', {'key': key});
  Future<void> stopAllPads() => safeInvoke('stopAllPads');

  Future<void> setPadVolume(String key, double volume) =>
      safeInvoke('setPadVolume', {'key': key, 'volume': volume});

  Future<void> setPadPan(String key, double pan) =>
      safeInvoke('setPadPan', {'key': key, 'pan': pan});

  Future<void> setPadMasterVolume(double volume) =>
      safeInvoke('setPadMasterVolume', {'volume': volume});

  Future<void> crossfadeToPad(String fromKey, String toKey, double duration) =>
      safeInvoke('crossfadeToPad', {
        'fromKey': fromKey,
        'toKey': toKey,
        'duration': duration,
      });

  void dispose() {
    _eventSubscription?.cancel();
    _beatController.close();
    _onsetController.close();
    _recordingController.close();
    _tunerController.close();
    _midiController.close();
    _loopPositionController.close();
    _inputLevelController.close();
    _overdubAutoStopController.close();
    _loopStateController.close();
    _songLabPositionController.close();
    _methodChannel.invokeMethod('dispose');
  }
}

// ── Event models ──

class BeatEvent {
  final int beatIndex;
  final int measureIndex;
  final bool isAccent;
  final int timestampUs;
  final bool isDrumStep;

  const BeatEvent({
    required this.beatIndex,
    required this.measureIndex,
    required this.isAccent,
    required this.timestampUs,
    this.isDrumStep = false,
  });
}

class OnsetEvent {
  final int timestampUs;
  final double amplitude;
  final double? frequency;

  const OnsetEvent({
    required this.timestampUs,
    required this.amplitude,
    this.frequency,
  });
}

class RecordingEvent {
  final bool isRecording;
  final int durationMs;
  final String? filePath;

  const RecordingEvent({
    required this.isRecording,
    required this.durationMs,
    this.filePath,
  });
}

class MidiEvent {
  final int status;    // 0x90=noteOn, 0x80=noteOff, 0xB0=CC
  final int note;      // MIDI note number 0-127
  final int velocity;  // 0-127
  final String type;   // 'noteOn', 'noteOff', 'cc'
  final String action; // mapped action: 'kick', 'snare', 'hihat', 'tap', 'bpm', etc.

  const MidiEvent({
    required this.status,
    required this.note,
    required this.velocity,
    required this.type,
    this.action = '',
  });
}
