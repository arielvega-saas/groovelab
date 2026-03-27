import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'native_audio_bridge.dart';

/// Web implementation of the audio bridge using JavaScript Web Audio API.
/// Communicates with the GrooveLabWebAudio JS class defined in web_audio_engine.js.
class WebAudioBridge {
  final _beatController = StreamController<BeatEvent>.broadcast();
  final _midiController = StreamController<MidiEvent>.broadcast();
  final _loopPositionController = StreamController<double>.broadcast();
  final _inputLevelController = StreamController<double>.broadcast();
  final _overdubStopController = StreamController<Map<String, dynamic>>.broadcast();
  final _songLabPositionController = StreamController<double>.broadcast();
  bool _initialized = false;

  Stream<BeatEvent> get beatEvents => _beatController.stream;
  Stream<MidiEvent> get midiEvents => _midiController.stream;
  Stream<double> get loopPosition => _loopPositionController.stream;
  Stream<double> get inputLevel => _inputLevelController.stream;
  Stream<Map<String, dynamic>> get overdubAutoStop => _overdubStopController.stream;
  Stream<double> get songLabPosition => _songLabPositionController.stream;

  JSObject get _audio => globalContext['grooveLabAudio']! as JSObject;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _audio.callMethod('init'.toJS);

      // Set up beat callback from JS → Dart
      _audio['onBeatCallback'] = ((
        JSNumber beatIndex,
        JSNumber measureIndex,
        JSBoolean isAccent,
        JSBoolean isDrumStep,
      ) {
        _beatController.add(BeatEvent(
          beatIndex: beatIndex.toDartInt,
          measureIndex: measureIndex.toDartInt,
          isAccent: isAccent.toDart,
          timestampUs: DateTime.now().microsecondsSinceEpoch,
          isDrumStep: isDrumStep.toDart,
        ));
      }).toJS;

      _initialized = true;

      _audio['onLoopPositionCallback'] = ((JSNumber pos) {
        _loopPositionController.add(pos.toDartDouble);
      }).toJS;

      _audio['onInputLevelCallback'] = ((JSNumber level) {
        _inputLevelController.add(level.toDartDouble);
      }).toJS;

      _audio['onOverdubAutoStopCallback'] = ((JSNumber layerCount, JSNumber duration, JSNumber layerIndex) {
        _overdubStopController.add({
          'layerCount': layerCount.toDartInt,
          'duration': duration.toDartDouble,
          'layerIndex': layerIndex.toDartInt,
        });
      }).toJS;

      _audio['onSongLabPositionCallback'] = ((JSNumber pos) {
        _songLabPositionController.add(pos.toDartDouble);
      }).toJS;

      debugPrint('WebAudioBridge: initialized');
    } catch (e) {
      debugPrint('WebAudioBridge: init failed: $e');
    }
  }

  Future<void> loadSound(String key, Uint8List wavData) async {
    if (!_initialized) return;
    try {
      // Convert Uint8List to JS ArrayBuffer
      final jsArrayBuffer = wavData.buffer.toJS;
      final promise = _audio.callMethodVarArgs(
        'loadSound'.toJS,
        [key.toJS, jsArrayBuffer],
      );
      // Await the JS Promise
      if (promise != null) {
        await (promise as JSPromise).toDart;
      }
    } catch (e) {
      debugPrint('WebAudioBridge: loadSound $key failed: $e');
    }
  }

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
    if (!_initialized) return;
    // Resume audio context (browser autoplay policy)
    try {
      final ctx = _audio['ctx'] as JSObject?;
      if (ctx != null) {
        final state = (ctx['state'] as JSString?)?.toDart;
        if (state == 'suspended') {
          final p = ctx.callMethod('resume'.toJS);
          if (p != null) await (p as JSPromise).toDart;
        }
      }
    } catch (_) {}

    _audio.callMethodVarArgs('startMetronome'.toJS, [
      bpm.toJS,
      beatsPerBar.toJS,
      beatUnit.toJS,
      subdivision.toJS,
      swingPercent.toJS,
      clickSound.toJS,
      accentPattern.jsify(),
      hapticEnabled.toJS,
    ]);
  }

  Future<void> stopMetronome() async {
    if (!_initialized) return;
    _audio.callMethod('stopMetronome'.toJS);
  }

  Future<void> updateBpm(int bpm) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateBpm'.toJS, [bpm.toJS]);
  }

  Future<void> updateTimeSignature(int beatsPerBar, int beatUnit) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateTimeSignature'.toJS, [
      beatsPerBar.toJS,
      beatUnit.toJS,
    ]);
  }

  Future<void> updateSubdivision(int sub) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateSubdivision'.toJS, [sub.toJS]);
  }

  Future<void> updateSwing(int pct) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateSwing'.toJS, [pct.toJS]);
  }

  Future<void> updateClickSound(String name) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateClickSound'.toJS, [name.toJS]);
  }

  Future<void> updateAccentPattern(List<double> pattern) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateAccentPattern'.toJS, [pattern.jsify()]);
  }

  Future<void> updateHumanFeel(int pct) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateHumanFeel'.toJS, [pct.toJS]);
  }

  Future<void> updateCountIn(int bars) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateCountIn'.toJS, [bars.toJS]);
  }

  Future<void> setHapticMode(bool enabled) async {
    // No-op on web (no haptic)
  }

  Future<void> updatePolyrhythm(bool enabled, int value) async {
    // Simplified for web
  }

  Future<void> updateIntervalTraining(bool enabled, int clickBars, int silentBars) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateIntervalTraining'.toJS, [
      enabled.toJS, clickBars.toJS, silentBars.toJS,
    ]);
  }

  Future<void> updateRandomSilence(bool enabled, int probability) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateRandomSilence'.toJS, [
      enabled.toJS, probability.toJS,
    ]);
  }

  // ── Drum Machine ──

  Future<void> startDrumPattern({
    required int bpm,
    required Map<String, List<int>> pattern,
    required int swingPercent,
    int drumBeats = 4,
    int drumBeatUnit = 4,
    List<double> drumAccentPattern = const [],
  }) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('startDrumPattern'.toJS, [
      bpm.toJS,
      pattern.jsify(),
      swingPercent.toJS,
      drumBeats.toJS,
      drumBeatUnit.toJS,
      drumAccentPattern.jsify(),
    ]);
  }

  Future<void> stopDrumPattern() async {
    if (!_initialized) return;
    _audio.callMethod('stopDrumPattern'.toJS);
  }

  Future<void> updateDrumPattern(Map<String, List<int>> p) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateDrumPattern'.toJS, [p.jsify()]);
  }

  Future<void> updateDrumVolumes(Map<String, double> v) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateDrumVolumes'.toJS, [v.jsify()]);
  }

  Future<void> updateDrumTimeSig(int beats, int beatUnit) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateDrumTimeSig'.toJS, [beats.toJS, beatUnit.toJS]);
  }

  Future<void> updateDrumAccentPattern(List<double> p) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('updateDrumAccentPattern'.toJS, [p.jsify()]);
  }

  // ── Latency ──

  Future<double> getOutputLatency() async {
    if (!_initialized) return 0;
    try {
      final result = _audio.callMethod('getOutputLatency'.toJS);
      if (result != null) {
        return (result as JSNumber).toDartDouble;
      }
    } catch (_) {}
    return 0;
  }

  Future<double> getInputLatency() async => 0; // No mic input on web

  // ── Web Recording ──

  Future<String> startWebRecording() async {
    if (!_initialized) return 'error';
    try {
      final promise = _audio.callMethod('startWebRecording'.toJS);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        return (result as JSString).toDart;
      }
    } catch (e) {
      debugPrint('WebAudioBridge: startWebRecording failed: $e');
    }
    return 'error';
  }

  Future<bool> stopWebRecording() async {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethod('stopWebRecording'.toJS);
      return result != null && (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: stopWebRecording failed: $e');
    }
    return false;
  }

  String getLastRecordingUrl() {
    if (!_initialized) return '';
    try {
      final result = _audio.callMethod('getLastRecordingUrl'.toJS);
      if (result != null) return (result as JSString).toDart;
    } catch (_) {}
    return '';
  }

  bool hasRecording() {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethod('hasRecording'.toJS);
      return result != null && (result as JSBoolean).toDart;
    } catch (_) {}
    return false;
  }

  Future<bool> playRecording() async {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethod('playRecording'.toJS);
      return result != null && (result as JSBoolean).toDart;
    } catch (_) {}
    return false;
  }

  Future<bool> stopPlayback() async {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethod('stopPlayback'.toJS);
      return result != null && (result as JSBoolean).toDart;
    } catch (_) {}
    return false;
  }

  Future<bool> discardRecording() async {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethod('discardRecording'.toJS);
      return result != null && (result as JSBoolean).toDart;
    } catch (_) {}
    return false;
  }

  Future<void> resumeContext() async {
    if (!_initialized) return;
    try {
      final promise = _audio.callMethod('resumeContext'.toJS);
      if (promise != null) {
        await (promise as JSPromise).toDart;
      }
    } catch (_) {}
  }

  // ── Loop Station ──

  Future<String> startLoopRecording() async {
    if (!_initialized) return 'error';
    try {
      final promise = _audio.callMethod('startLoopRecording'.toJS);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        return (result as JSString).toDart;
      }
    } catch (e) {
      debugPrint('WebAudioBridge: startLoopRecording failed: $e');
    }
    return 'error';
  }

  Future<Map<String, dynamic>> stopLoopRecording() async {
    if (!_initialized) return {'success': false, 'layerCount': 0};
    try {
      final promise = _audio.callMethod('stopLoopRecording'.toJS);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) {
          final jsObj = result as JSObject;
          return {
            'success': ((jsObj['success'] as JSBoolean?)?.toDart) ?? false,
            'layerCount': ((jsObj['layerCount'] as JSNumber?)?.toDartInt) ?? 0,
            'duration': ((jsObj['duration'] as JSNumber?)?.toDartDouble) ?? 0.0,
            'layerIndex': ((jsObj['layerIndex'] as JSNumber?)?.toDartInt) ?? -1,
          };
        }
      }
    } catch (e) {
      debugPrint('WebAudioBridge: stopLoopRecording failed: $e');
    }
    return {'success': false, 'layerCount': 0};
  }

  Future<void> startLoopPlayback() async {
    if (!_initialized) return;
    try {
      _audio.callMethod('startLoopPlayback'.toJS);
    } catch (e) {
      debugPrint('WebAudioBridge: startLoopPlayback failed: $e');
    }
  }

  Future<void> stopLoopPlayback() async {
    if (!_initialized) return;
    try {
      _audio.callMethod('stopLoopPlayback'.toJS);
    } catch (e) {
      debugPrint('WebAudioBridge: stopLoopPlayback failed: $e');
    }
  }

  Future<void> undoLoopLayer() async {
    if (!_initialized) return;
    try {
      _audio.callMethod('undoLastLayer'.toJS);
    } catch (e) {
      debugPrint('WebAudioBridge: undoLoopLayer failed: $e');
    }
  }

  Future<void> clearLoop() async {
    if (!_initialized) return;
    try {
      _audio.callMethod('clearLoop'.toJS);
    } catch (e) {
      debugPrint('WebAudioBridge: clearLoop failed: $e');
    }
  }

  Future<void> setLoopLayerVolume(int index, double volume) async {
    if (!_initialized) return;
    try {
      _audio.callMethodVarArgs('setLayerVolume'.toJS, [index.toJS, volume.toJS]);
    } catch (e) {
      debugPrint('WebAudioBridge: setLoopLayerVolume failed: $e');
    }
  }

  Map<String, dynamic> getLoopState() {
    if (!_initialized) {
      return {'layerCount': 0, 'duration': 0.0, 'isPlaying': false, 'isRecording': false, 'layers': <Map<String, dynamic>>[]};
    }
    try {
      final result = _audio.callMethod('getLoopState'.toJS);
      if (result != null) {
        final jsObj = result as JSObject;
        final layers = <Map<String, dynamic>>[];
        try {
          final jsLayers = jsObj['layers'];
          if (jsLayers != null) {
            final jsArray = jsLayers as JSArray;
            for (int i = 0; i < jsArray.length; i++) {
              final layerObj = jsArray[i] as JSObject;
              layers.add({
                'index': ((layerObj['index'] as JSNumber?)?.toDartInt) ?? i,
                'name': ((layerObj['name'] as JSString?)?.toDart) ?? 'Layer ${i + 1}',
                'volume': ((layerObj['volume'] as JSNumber?)?.toDartDouble) ?? 1.0,
                'muted': ((layerObj['muted'] as JSBoolean?)?.toDart) ?? false,
                'solo': ((layerObj['solo'] as JSBoolean?)?.toDart) ?? false,
                'pan': ((layerObj['pan'] as JSNumber?)?.toDartDouble) ?? 0.0,
              });
            }
          }
        } catch (_) {}
        return {
          'layerCount': ((jsObj['layerCount'] as JSNumber?)?.toDartInt) ?? 0,
          'duration': ((jsObj['duration'] as JSNumber?)?.toDartDouble) ?? 0.0,
          'isPlaying': ((jsObj['isPlaying'] as JSBoolean?)?.toDart) ?? false,
          'isRecording': ((jsObj['isRecording'] as JSBoolean?)?.toDart) ?? false,
          'layers': layers,
        };
      }
    } catch (e) {
      debugPrint('WebAudioBridge: getLoopState failed: $e');
    }
    return {'layerCount': 0, 'duration': 0.0, 'isPlaying': false, 'isRecording': false, 'layers': <Map<String, dynamic>>[]};
  }

  // ── Per-layer controls ──

  Future<void> setLayerMute(int index, bool muted) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setLayerMute'.toJS, [index.toJS, muted.toJS]);
  }

  Future<void> setLayerSolo(int index, bool solo) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setLayerSolo'.toJS, [index.toJS, solo.toJS]);
  }

  Future<void> setLayerPan(int index, double pan) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setLayerPan'.toJS, [index.toJS, pan.toJS]);
  }

  Future<void> deleteLoopLayer(int index) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('deleteLayer'.toJS, [index.toJS]);
  }

  Future<void> renameLoopLayer(int index, String name) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('renameLayer'.toJS, [index.toJS, name.toJS]);
  }

  // ── Input monitoring ──

  Future<void> startInputMonitoring() async {
    if (!_initialized) return;
    try {
      final promise = _audio.callMethod('startInputMonitoring'.toJS);
      if (promise != null) await (promise as JSPromise).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: startInputMonitoring failed: $e');
    }
  }

  Future<void> stopInputMonitoring() async {
    if (!_initialized) return;
    _audio.callMethod('stopInputMonitoring'.toJS);
  }

  Future<void> setMonitorVolume(double vol) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setMonitorVolume'.toJS, [vol.toJS]);
  }

  // ── Guide track ──

  Future<void> setGuideVolume(double vol) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setGuideVolume'.toJS, [vol.toJS]);
  }

  Future<void> setLoopMasterVolume(double vol) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setLoopMasterVolume'.toJS, [vol.toJS]);
  }

  Future<void> muteGuide(bool muted) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('muteGuide'.toJS, [muted.toJS]);
  }

  // ── Export ──

  Future<String> exportLoopMixdown(String format, {bool includeGuide = false}) async {
    if (!_initialized) return '';
    try {
      final promise = _audio.callMethodVarArgs('exportMixdown'.toJS, [format.toJS, includeGuide.toJS]);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) return (result as JSString).toDart;
      }
    } catch (e) {
      debugPrint('WebAudioBridge: exportMixdown failed: $e');
    }
    return '';
  }

  // ── Waveform ──

  List<double> getLayerWaveform(int index, int numSamples) {
    if (!_initialized) return [];
    try {
      final result = _audio.callMethodVarArgs('getLayerWaveform'.toJS, [index.toJS, numSamples.toJS]);
      if (result != null) {
        final jsArray = result as JSArray;
        return List.generate(jsArray.length, (i) => (jsArray[i] as JSNumber).toDartDouble);
      }
    } catch (e) {
      debugPrint('WebAudioBridge: getLayerWaveform failed: $e');
    }
    return [];
  }

  // ── Input level meter ──

  Future<void> startInputLevelMeter(void Function(double level) callback) async {
    if (!_initialized) return;
    try {
      _audio['onInputLevelCallback'] = ((JSNumber level) {
        callback(level.toDartDouble);
      }).toJS;
      final promise = _audio.callMethod('startInputLevelMeter'.toJS);
      if (promise != null) await (promise as JSPromise).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: startInputLevelMeter failed: $e');
    }
  }

  Future<void> stopInputLevelMeter() async {
    if (!_initialized) return;
    _audio.callMethod('stopInputLevelMeter'.toJS);
  }

  // ── Tuner / Pitch Detection ──

  Future<void> startTuner(void Function(Map<String, dynamic> data) callback, {String? deviceId}) async {
    if (!_initialized) return;
    try {
      _audio['onTunerCallback'] = ((JSObject data) {
        final map = <String, dynamic>{
          'frequency': (data['frequency'] as JSNumber).toDartDouble,
          'note': (data['note'] as JSString).toDart,
          'octave': (data['octave'] as JSNumber).toDartInt,
          'cents': (data['cents'] as JSNumber).toDartInt,
          'inTune': (data['inTune'] as JSBoolean).toDart,
          'level': (data['level'] as JSNumber).toDartDouble,
        };
        callback(map);
      }).toJS;
      final promise = _audio.callMethodVarArgs('startTuner'.toJS, [(deviceId ?? '').toJS]);
      if (promise != null) await (promise as JSPromise).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: startTuner failed: $e');
    }
  }

  Future<void> stopTuner() async {
    if (!_initialized) return;
    _audio.callMethod('stopTuner'.toJS);
  }

  Future<void> playDrumHit(String track) async {
    try {
      _audio.callMethodVarArgs('playDrumHit'.toJS, [track.toJS]);
    } catch (e) {
      debugPrint('WebAudioBridge: playDrumHit failed: $e');
    }
  }

  Future<List<Map<String, String>>> getAudioInputDevices() async {
    if (!_initialized) return [];
    try {
      final promise = _audio.callMethod('getAudioInputDevices'.toJS);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result == null) return [];
        final jsArray = result as JSArray;
        final devices = <Map<String, String>>[];
        for (int i = 0; i < jsArray.length; i++) {
          final item = jsArray[i] as JSObject;
          devices.add({
            'id': ((item['id'] as JSString?)?.toDart) ?? '',
            'name': ((item['name'] as JSString?)?.toDart) ?? 'Audio Input ${i + 1}',
          });
        }
        return devices;
      }
    } catch (e) {
      debugPrint('WebAudioBridge: getAudioInputDevices failed: $e');
    }
    return [];
  }

  // ── Loop position callback ──

  void setLoopPositionCallback(void Function(double position) callback) {
    if (!_initialized) return;
    _audio['onLoopPositionCallback'] = ((JSNumber pos) {
      callback(pos.toDartDouble);
    }).toJS;
  }

  // ── MIDI loop mapping ──

  Future<void> setMidiLoopMapping(String action, int noteNumber) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setMidiLoopMapping'.toJS, [action.toJS, noteNumber.toJS]);
  }

  // ── MIDI ──

  Future<List<Map<String, String>>> initMidi() async {
    if (!_initialized) return [];
    try {
      // Set up MIDI event callback from JS → Dart
      _audio['onMidiEvent'] = ((
        JSNumber status,
        JSNumber note,
        JSNumber velocity,
        JSString type,
        JSString action,
      ) {
        _midiController.add(MidiEvent(
          status: status.toDartInt,
          note: note.toDartInt,
          velocity: velocity.toDartInt,
          type: type.toDart,
          action: action.toDart,
        ));
      }).toJS;

      final promise = _audio.callMethod('initMidi'.toJS);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        return _parseDeviceList(result);
      }
    } catch (e) {
      debugPrint('WebAudioBridge: initMidi failed: $e');
    }
    return [];
  }

  List<Map<String, String>> getMidiDevices() {
    if (!_initialized) return [];
    try {
      final result = _audio.callMethod('getMidiDevices'.toJS);
      return _parseDeviceList(result);
    } catch (e) {
      debugPrint('WebAudioBridge: getMidiDevices failed: $e');
    }
    return [];
  }

  Future<void> disconnectMidi() async {
    if (!_initialized) return;
    try {
      _audio.callMethod('disconnectMidi'.toJS);
    } catch (e) {
      debugPrint('WebAudioBridge: disconnectMidi failed: $e');
    }
  }

  List<Map<String, String>> _parseDeviceList(JSAny? jsResult) {
    if (jsResult == null) return [];
    try {
      final jsArray = jsResult as JSArray;
      final devices = <Map<String, String>>[];
      for (int i = 0; i < jsArray.length; i++) {
        final item = jsArray[i] as JSObject;
        devices.add({
          'id': ((item['id'] as JSString?)?.toDart) ?? '',
          'name': ((item['name'] as JSString?)?.toDart) ?? 'Unknown',
          'manufacturer': ((item['manufacturer'] as JSString?)?.toDart) ?? 'Unknown',
        });
      }
      return devices;
    } catch (e) {
      debugPrint('WebAudioBridge: _parseDeviceList failed: $e');
      return [];
    }
  }

  // ── Loop Beat Info ──

  Map<String, int> getLoopBeatInfo() {
    if (!_initialized) return {'beat': 0, 'bar': 0, 'totalBeats': 0, 'totalBars': 0, 'beatInBar': 0, 'beatsPerBar': 4};
    try {
      final result = _audio.callMethod('getLoopBeatInfo'.toJS);
      if (result != null) {
        final jsObj = result as JSObject;
        return {
          'beat': ((jsObj['beat'] as JSNumber?)?.toDartInt) ?? 0,
          'bar': ((jsObj['bar'] as JSNumber?)?.toDartInt) ?? 0,
          'totalBeats': ((jsObj['totalBeats'] as JSNumber?)?.toDartInt) ?? 0,
          'totalBars': ((jsObj['totalBars'] as JSNumber?)?.toDartInt) ?? 0,
          'beatInBar': ((jsObj['beatInBar'] as JSNumber?)?.toDartInt) ?? 0,
          'beatsPerBar': ((jsObj['beatsPerBar'] as JSNumber?)?.toDartInt) ?? 4,
        };
      }
    } catch (e) {
      debugPrint('WebAudioBridge: getLoopBeatInfo failed: $e');
    }
    return {'beat': 0, 'bar': 0, 'totalBeats': 0, 'totalBars': 0, 'beatInBar': 0, 'beatsPerBar': 4};
  }

  // ── Export Stems ──

  Future<List<Map<String, dynamic>>> exportStems() async {
    if (!_initialized) return [];
    try {
      final promise = _audio.callMethod('exportStems'.toJS);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) {
          final jsArray = result as JSArray;
          final stems = <Map<String, dynamic>>[];
          for (int i = 0; i < jsArray.length; i++) {
            final stemObj = jsArray[i] as JSObject;
            stems.add({
              'index': ((stemObj['index'] as JSNumber?)?.toDartInt) ?? i,
              'name': ((stemObj['name'] as JSString?)?.toDart) ?? 'Layer ${i + 1}',
              'url': ((stemObj['url'] as JSString?)?.toDart) ?? '',
              'size': ((stemObj['size'] as JSNumber?)?.toDartInt) ?? 0,
            });
          }
          return stems;
        }
      }
    } catch (e) {
      debugPrint('WebAudioBridge: exportStems failed: $e');
    }
    return [];
  }

  Future<String> exportSelectedLayers(List<int> indices) async {
    if (!_initialized) return '';
    try {
      final promise = _audio.callMethodVarArgs('exportSelectedLayers'.toJS, [indices.jsify()]);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) return (result as JSString).toDart;
      }
    } catch (e) {
      debugPrint('WebAudioBridge: exportSelectedLayers failed: $e');
    }
    return '';
  }

  // ── PAD System ──

  Future<Map<String, dynamic>> loadPad(Uint8List audioData, String name, String key, double tempo) async {
    if (!_initialized) return {'success': false, 'error': 'not initialized'};
    try {
      final jsArrayBuffer = audioData.buffer.toJS;
      final promise = _audio.callMethodVarArgs(
        'loadPad'.toJS,
        [jsArrayBuffer, name.toJS, key.toJS, tempo.toJS],
      );
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) {
          final jsObj = result as JSObject;
          return {
            'success': ((jsObj['success'] as JSBoolean?)?.toDart) ?? false,
            'padIndex': ((jsObj['padIndex'] as JSNumber?)?.toDartInt) ?? -1,
            'duration': ((jsObj['duration'] as JSNumber?)?.toDartDouble) ?? 0.0,
          };
        }
      }
    } catch (e) {
      debugPrint('WebAudioBridge: loadPad failed: $e');
    }
    return {'success': false};
  }

  Future<Map<String, dynamic>> loadPadFromUrl(String url, String name, String key, double tempo) async {
    if (!_initialized) return {'success': false, 'error': 'not initialized'};
    try {
      final promise = _audio.callMethodVarArgs(
        'loadPadFromUrl'.toJS,
        [url.toJS, name.toJS, key.toJS, tempo.toJS],
      );
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) {
          final jsObj = result as JSObject;
          return {
            'success': ((jsObj['success'] as JSBoolean?)?.toDart) ?? false,
            'padIndex': ((jsObj['padIndex'] as JSNumber?)?.toDartInt) ?? -1,
            'duration': ((jsObj['duration'] as JSNumber?)?.toDartDouble) ?? 0.0,
          };
        }
      }
    } catch (e) {
      debugPrint('WebAudioBridge: loadPadFromUrl failed: $e');
    }
    return {'success': false};
  }

  Future<bool> playPad(int index, bool loop) async {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethodVarArgs('playPad'.toJS, [index.toJS, loop.toJS]);
      return result != null && (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: playPad failed: $e');
    }
    return false;
  }

  Future<bool> stopPad(int index) async {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethodVarArgs('stopPad'.toJS, [index.toJS]);
      return result != null && (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: stopPad failed: $e');
    }
    return false;
  }

  Future<void> stopAllPads() async {
    if (!_initialized) return;
    _audio.callMethod('stopAllPads'.toJS);
  }

  Future<void> setPadVolume(int index, double volume) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPadVolume'.toJS, [index.toJS, volume.toJS]);
  }

  Future<void> setPadPan(int index, double pan) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPadPan'.toJS, [index.toJS, pan.toJS]);
  }

  Future<void> setPadPitch(int index, double semitones) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPadPitch'.toJS, [index.toJS, semitones.toJS]);
  }

  Future<void> setPadTempo(int index, double targetBpm) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPadTempo'.toJS, [index.toJS, targetBpm.toJS]);
  }

  Future<bool> removePad(int index) async {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethodVarArgs('removePad'.toJS, [index.toJS]);
      return result != null && (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: removePad failed: $e');
    }
    return false;
  }

  List<Map<String, dynamic>> getPadState() {
    if (!_initialized) return [];
    try {
      final result = _audio.callMethod('getPadState'.toJS);
      if (result != null) {
        final jsArray = result as JSArray;
        final pads = <Map<String, dynamic>>[];
        for (int i = 0; i < jsArray.length; i++) {
          final padObj = jsArray[i] as JSObject;
          pads.add({
            'index': ((padObj['index'] as JSNumber?)?.toDartInt) ?? i,
            'name': ((padObj['name'] as JSString?)?.toDart) ?? 'Pad ${i + 1}',
            'key': ((padObj['key'] as JSString?)?.toDart) ?? 'C',
            'tempo': ((padObj['tempo'] as JSNumber?)?.toDartDouble) ?? 120.0,
            'volume': ((padObj['volume'] as JSNumber?)?.toDartDouble) ?? 1.0,
            'pan': ((padObj['pan'] as JSNumber?)?.toDartDouble) ?? 0.0,
            'playing': ((padObj['playing'] as JSBoolean?)?.toDart) ?? false,
            'loop': ((padObj['loop'] as JSBoolean?)?.toDart) ?? false,
            'duration': ((padObj['duration'] as JSNumber?)?.toDartDouble) ?? 0.0,
          });
        }
        return pads;
      }
    } catch (e) {
      debugPrint('WebAudioBridge: getPadState failed: $e');
    }
    return [];
  }

  Future<void> setPadMasterVolume(double volume) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPadMasterVolume'.toJS, [volume.toJS]);
  }

  Future<void> setPadRouting(double padPan, double guidePan) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPadRouting'.toJS, [padPan.toJS, guidePan.toJS]);
  }

  // ── PAD Crossfade Engine ──

  Future<bool> setActivePadSound(int index) async {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethodVarArgs('setActivePadSound'.toJS, [index.toJS]);
      return result != null && (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: setActivePadSound failed: $e');
    }
    return false;
  }

  int getActivePadIndex() {
    if (!_initialized) return -1;
    try {
      final result = _audio.callMethod('getActivePadIndex'.toJS);
      if (result != null) return (result as JSNumber).toDartInt;
    } catch (_) {}
    return -1;
  }

  String? getActivePadKey() {
    if (!_initialized) return null;
    try {
      final result = _audio.callMethod('getActivePadKey'.toJS);
      if (result != null) {
        final s = (result as JSString).toDart;
        return s.isEmpty ? null : s;
      }
    } catch (_) {}
    return null;
  }

  Future<void> setPadTransition(String mode, double time) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPadTransition'.toJS, [mode.toJS, time.toJS]);
  }

  Future<void> setPadHold(bool hold) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPadHold'.toJS, [hold.toJS]);
  }

  bool isPadHolding() {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethod('isPadHolding'.toJS);
      return result != null && (result as JSBoolean).toDart;
    } catch (_) {}
    return false;
  }

  Future<bool> playPadAtKey(String targetKey, {double? crossfadeTime}) async {
    if (!_initialized) return false;
    try {
      final args = <JSAny>[targetKey.toJS];
      if (crossfadeTime != null) args.add(crossfadeTime.toJS);
      final result = _audio.callMethodVarArgs('playPadAtKey'.toJS, args);
      return result != null && (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: playPadAtKey failed: $e');
    }
    return false;
  }

  Future<bool> fadeOutActivePad({double? fadeTime}) async {
    if (!_initialized) return false;
    try {
      final args = <JSAny>[];
      if (fadeTime != null) args.add(fadeTime.toJS);
      final result = _audio.callMethodVarArgs('fadeOutActivePad'.toJS, args);
      return result != null && (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: fadeOutActivePad failed: $e');
    }
    return false;
  }

  Future<bool> stopActivePad() async {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethod('stopActivePad'.toJS);
      return result != null && (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: stopActivePad failed: $e');
    }
    return false;
  }

  bool isActivePadPlaying() {
    if (!_initialized) return false;
    try {
      final result = _audio.callMethod('isActivePadPlaying'.toJS);
      return result != null && (result as JSBoolean).toDart;
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>> checkAudioOutputDevices() async {
    if (!_initialized) return {'hasHeadphones': false, 'outputDevices': []};
    try {
      final promise = _audio.callMethod('checkAudioOutputDevices'.toJS);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) {
          final jsObj = result as JSObject;
          return {
            'hasHeadphones': ((jsObj['hasHeadphones'] as JSBoolean?)?.toDart) ?? false,
          };
        }
      }
    } catch (e) {
      debugPrint('WebAudioBridge: checkAudioOutputDevices failed: $e');
    }
    return {'hasHeadphones': false};
  }

  // ── Song Lab ──

  Future<Map<String, dynamic>> songLabLoadTrack(Uint8List audioData, String name, String stemType) async {
    if (!_initialized) return {'success': false};
    try {
      final jsArrayBuffer = audioData.buffer.toJS;
      final promise = _audio.callMethodVarArgs('songLabLoadTrack'.toJS, [jsArrayBuffer, name.toJS, stemType.toJS]);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) {
          final jsObj = result as JSObject;
          return {
            'success': ((jsObj['success'] as JSBoolean?)?.toDart) ?? false,
            'trackIndex': ((jsObj['trackIndex'] as JSNumber?)?.toDartInt) ?? -1,
            'duration': ((jsObj['duration'] as JSNumber?)?.toDartDouble) ?? 0.0,
          };
        }
      }
    } catch (e) {
      debugPrint('WebAudioBridge: songLabLoadTrack failed: $e');
    }
    return {'success': false};
  }

  Future<void> songLabPlay() async {
    if (!_initialized) return;
    _audio.callMethod('songLabPlay'.toJS);
  }

  Future<void> songLabPause() async {
    if (!_initialized) return;
    _audio.callMethod('songLabPause'.toJS);
  }

  Future<void> songLabStop() async {
    if (!_initialized) return;
    _audio.callMethod('songLabStop'.toJS);
  }

  Future<void> songLabSeek(double position) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('songLabSeek'.toJS, [position.toJS]);
  }

  Future<void> songLabSetTrackVolume(int index, double volume) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('songLabSetTrackVolume'.toJS, [index.toJS, volume.toJS]);
  }

  Future<void> songLabSetTrackPan(int index, double pan) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('songLabSetTrackPan'.toJS, [index.toJS, pan.toJS]);
  }

  Future<void> songLabSetTrackMute(int index, bool muted) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('songLabSetTrackMute'.toJS, [index.toJS, muted.toJS]);
  }

  Future<void> songLabSetTrackSolo(int index, bool solo) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('songLabSetTrackSolo'.toJS, [index.toJS, solo.toJS]);
  }

  Future<void> songLabSetSpeed(double speed) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('songLabSetSpeed'.toJS, [speed.toJS]);
  }

  Future<void> songLabSetPitchShift(int semitones) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('songLabSetPitchShift'.toJS, [semitones.toJS]);
  }

  Future<void> songLabSetLoopRegion(double start, double end) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('songLabSetLoopRegion'.toJS, [start.toJS, end.toJS]);
  }

  Future<void> songLabClearLoopRegion() async {
    if (!_initialized) return;
    _audio.callMethod('songLabClearLoopRegion'.toJS);
  }

  double songLabGetPosition() {
    if (!_initialized) return 0.0;
    try {
      final result = _audio.callMethod('songLabGetPosition'.toJS);
      if (result != null) return (result as JSNumber).toDartDouble;
    } catch (_) {}
    return 0.0;
  }

  Map<String, dynamic> songLabGetState() {
    if (!_initialized) return {'playing': false, 'duration': 0.0, 'position': 0.0, 'trackCount': 0};
    try {
      final result = _audio.callMethod('songLabGetState'.toJS);
      if (result != null) {
        final jsObj = result as JSObject;
        return {
          'playing': ((jsObj['playing'] as JSBoolean?)?.toDart) ?? false,
          'duration': ((jsObj['duration'] as JSNumber?)?.toDartDouble) ?? 0.0,
          'position': ((jsObj['position'] as JSNumber?)?.toDartDouble) ?? 0.0,
          'trackCount': ((jsObj['trackCount'] as JSNumber?)?.toDartInt) ?? 0,
          'speed': ((jsObj['speed'] as JSNumber?)?.toDartDouble) ?? 1.0,
          'pitchShift': ((jsObj['pitchShift'] as JSNumber?)?.toDartInt) ?? 0,
        };
      }
    } catch (e) {
      debugPrint('WebAudioBridge: songLabGetState failed: $e');
    }
    return {'playing': false, 'duration': 0.0, 'position': 0.0, 'trackCount': 0};
  }

  List<double> songLabGetWaveform(int trackIndex, int numSamples) {
    if (!_initialized) return [];
    try {
      final result = _audio.callMethodVarArgs('songLabGetWaveform'.toJS, [trackIndex.toJS, numSamples.toJS]);
      if (result != null) {
        final jsArray = result as JSArray;
        return List.generate(jsArray.length, (i) => (jsArray[i] as JSNumber).toDartDouble);
      }
    } catch (e) {
      debugPrint('WebAudioBridge: songLabGetWaveform failed: $e');
    }
    return [];
  }

  Future<void> songLabClearAll() async {
    if (!_initialized) return;
    _audio.callMethod('songLabClearAll'.toJS);
  }

  Future<Map<String, dynamic>> songLabMockSeparate(int trackIndex) async {
    if (!_initialized) return {'success': false};
    try {
      final promise = _audio.callMethodVarArgs('songLabMockSeparate'.toJS, [trackIndex.toJS]);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) {
          final jsObj = result as JSObject;
          final stemIndices = <int>[];
          try {
            final jsArr = jsObj['stemIndices'] as JSArray?;
            if (jsArr != null) {
              for (int i = 0; i < jsArr.length; i++) {
                stemIndices.add((jsArr[i] as JSNumber).toDartInt);
              }
            }
          } catch (_) {}
          return {
            'success': ((jsObj['success'] as JSBoolean?)?.toDart) ?? false,
            'stemCount': ((jsObj['stemCount'] as JSNumber?)?.toDartInt) ?? 0,
            'stemIndices': stemIndices,
          };
        }
      }
    } catch (e) {
      debugPrint('WebAudioBridge: songLabMockSeparate failed: $e');
    }
    return {'success': false};
  }

  Future<String> songLabExportMixdown() async {
    if (!_initialized) return '';
    try {
      final promise = _audio.callMethod('songLabExportMixdown'.toJS);
      if (promise != null) {
        final result = await (promise as JSPromise).toDart;
        if (result != null) return (result as JSString).toDart;
      }
    } catch (e) {
      debugPrint('WebAudioBridge: songLabExportMixdown failed: $e');
    }
    return '';
  }

  List<Map<String, dynamic>> songLabDetectPitch([int trackIndex = 0]) {
    try {
      final result = _audio.callMethod('songLabDetectPitch'.toJS, trackIndex.toJS) as JSArray;
      return result.toDart.map((item) {
        final obj = item as JSObject;
        String chord = '';
        try { chord = (obj['chord'] as JSString).toDart; } catch (_) {}
        return {
          'time': (obj['time'] as JSNumber).toDartDouble,
          'endTime': (obj['endTime'] as JSNumber).toDartDouble,
          'frequency': (obj['frequency'] as JSNumber).toDartDouble,
          'note': (obj['note'] as JSString).toDart,
          'octave': (obj['octave'] as JSNumber).toDartInt,
          'midi': (obj['midi'] as JSNumber).toDartInt,
          'chord': chord,
        };
      }).toList();
    } catch (e) {
      debugPrint('songLabDetectPitch error: $e');
      return [];
    }
  }

  void songLabToggleClick(bool enabled, int bpm) {
    try {
      _audio.callMethod('songLabToggleClick'.toJS, enabled.toJS, bpm.toJS);
    } catch (e) {
      debugPrint('songLabToggleClick error: $e');
    }
  }

  // ── Pedalera ──

  Future<void> initPedalera() async {
    if (!_initialized) return;
    try {
      final promise = _audio.callMethod('initPedalera'.toJS);
      if (promise != null) await (promise as JSPromise).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: initPedalera failed: $e');
    }
  }

  Future<void> setPedalChain(List<Map<String, dynamic>> chainConfig) async {
    if (!_initialized) return;
    try {
      // Convert Dart list of maps to JSON string and parse in JS
      final jsonStr = chainConfig.map((pedal) {
        final params = pedal['params'] as Map<String, double>? ?? {};
        final paramsStr = params.entries.map((e) => '"${e.key}":${e.value}').join(',');
        return '{"type":"${pedal['type']}","enabled":${pedal['enabled']},"params":{$paramsStr}}';
      }).join(',');
      final jsChain = globalContext.callMethod('eval'.toJS, '[$jsonStr]'.toJS);
      final promise = _audio.callMethodVarArgs('setPedalChain'.toJS, [jsChain]);
      if (promise != null) await (promise as JSPromise).toDart;
    } catch (e) {
      debugPrint('WebAudioBridge: setPedalChain failed: $e');
    }
  }

  Future<void> setPedalParam(int pedalIndex, String paramName, double value) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPedalParam'.toJS, [pedalIndex.toJS, paramName.toJS, value.toJS]);
  }

  Future<void> setPedalBypass(int pedalIndex, bool bypassed) async {
    if (!_initialized) return;
    _audio.callMethodVarArgs('setPedalBypass'.toJS, [pedalIndex.toJS, bypassed.toJS]);
  }

  Future<void> stopPedalera() async {
    if (!_initialized) return;
    _audio.callMethod('stopPedalera'.toJS);
  }

  double getPedalLatency() {
    if (!_initialized) return 0.0;
    try {
      final result = _audio.callMethod('getPedalLatency'.toJS);
      return (result as JSNumber).toDartDouble;
    } catch (e) {
      return 0.0;
    }
  }

  // ── Cleanup ──

  void dispose() {
    if (_initialized) {
      _audio.callMethod('dispose'.toJS);
    }
    _beatController.close();
    _midiController.close();
    _loopPositionController.close();
    _inputLevelController.close();
    _overdubStopController.close();
    _songLabPositionController.close();
  }
}
