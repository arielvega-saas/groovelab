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
    // On native, we can't do sync calls to platform channel
    // Return minimal state that won't break the UI
    return {'state': 'idle', 'layerCount': 0};
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
    }
  }

  void _handleError(dynamic error) {
    debugPrint('NativeAudioBridge event error: $error');
  }

  void dispose() {
    _eventSubscription?.cancel();
    _beatController.close();
    _onsetController.close();
    _recordingController.close();
    _midiController.close();
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
