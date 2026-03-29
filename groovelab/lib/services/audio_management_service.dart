import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/audio/audio_service.dart';
import '../core/audio/native_audio_bridge.dart';
import '../core/constants.dart';
import '../models/take.dart';
import '../models/session.dart';
import '../features/timing_analysis/timing_analyzer.dart';
import '../features/timing_analysis/timing_providers.dart';
import '../providers/app_providers.dart';
import 'persistence_service.dart';

/// Extracted from app.dart — manages audio lifecycle, playback control,
/// recording, and timing analysis coordination.
/// Reduces app.dart from 2157 lines by ~400 lines of business logic.
class AudioManagementService {
  final Ref _ref;

  StreamSubscription<BeatEvent>? _beatSub;
  StreamSubscription<OnsetEvent>? _onsetSub;
  StreamSubscription<RecordingEvent>? _recSub;
  Timer? _recordingTimer;

  DateTime? _sessionStart;
  int _barCount = 0;
  bool _waitingForFirstBeat = false;
  final List<DateTime> _tapTimes = [];

  // Callbacks for UI
  void Function()? onBeatPulse;
  void Function(bool mounted)? onMountedCheck;

  AudioManagementService(this._ref);

  AudioService get _audio => _ref.read(audioServiceProvider);
  PersistenceService get _persistence => _ref.read(persistenceProvider);

  /// Initialize audio engine and set up event listeners
  Future<void> init({
    required void Function() onBeatPulse,
  }) async {
    this.onBeatPulse = onBeatPulse;
    await _audio.init();
    _setupBeatListener();
    _setupOnsetListener();
    _setupRecordingListener();
  }

  void _setupBeatListener() {
    _beatSub = _audio.beatEvents.listen((event) {
      if (event.isDrumStep) {
        _ref.read(drumStepProvider.notifier).state = event.beatIndex;
        if (_ref.read(hapticModeProvider)) {
          HapticFeedback.lightImpact();
        }
      } else {
        _ref.read(currentBeatProvider.notifier).state = event.beatIndex;
        onBeatPulse?.call();

        if (_waitingForFirstBeat) {
          final analyzer = _ref.read(timingAnalyzerProvider);
          if (analyzer != null) {
            analyzer.startSession(event.timestampUs);
            _waitingForFirstBeat = false;
          }
        }

        // Auto BPM increase / speed trainer
        if (event.beatIndex == 0) {
          _barCount++;
          _handleSpeedTrainer();
        }
      }
    });
  }

  void _handleSpeedTrainer() {
    if (!_ref.read(autoIncreaseProvider)) return;
    final interval = _ref.read(incrementBarsProvider);
    if (_barCount <= 0 || _barCount % interval != 0) return;

    final currentBpm = _ref.read(bpmProvider);
    final target = _ref.read(targetBpmProvider);
    if (currentBpm >= target) {
      _ref.read(speedTrainerReachedProvider.notifier).state = true;
      return;
    }

    final increment = _ref.read(incrementBpmProvider);
    final newBpm = (currentBpm + increment).clamp(20, target);
    _ref.read(bpmProvider.notifier).state = newBpm;
    _audio.updateBpm(newBpm);
    if (newBpm >= target) {
      _ref.read(speedTrainerReachedProvider.notifier).state = true;
    }
  }

  void _setupOnsetListener() {
    _onsetSub = _audio.onsetEvents.listen((event) {
      final analyzer = _ref.read(timingAnalyzerProvider);
      if (analyzer == null) return;
      final onset = analyzer.processOnset(event);
      if (onset != null) {
        final onsets = [..._ref.read(liveOnsetsProvider), onset];
        _ref.read(liveOnsetsProvider.notifier).state = onsets;
      }
    });
  }

  void _setupRecordingListener() {
    _recSub = _audio.recordingEvents.listen((event) {
      _ref.read(isRecordingProvider.notifier).state = event.isRecording;
    });
  }

  /// Toggle metronome/drums playback
  Future<void> togglePlay() async {
    final playing = _ref.read(playingProvider);
    final tabIdx = _ref.read(tabIndexProvider);

    if (playing) {
      await _stopPlayback(tabIdx);
    } else {
      await _startPlayback(tabIdx);
    }
  }

  Future<void> _stopPlayback(int tabIdx) async {
    if (tabIdx == 1) {
      await _audio.stopDrumPattern();
    } else {
      await _audio.stopMetronome();
    }
    _ref.read(playingProvider.notifier).state = false;
    _ref.read(currentBeatProvider.notifier).state = -1;
    _ref.read(drumStepProvider.notifier).state = -1;

    await _logSession(tabIdx);
  }

  Future<void> _logSession(int tabIdx) async {
    if (_sessionStart == null) return;

    final elapsed = DateTime.now().difference(_sessionStart!).inSeconds.toDouble();
    _ref.read(totalPracticeTimeProvider.notifier).state += elapsed;
    _ref.read(sessionCountProvider.notifier).state += 1;

    final session = PracticeSession(
      id: const Uuid().v4(),
      startTime: _sessionStart!,
      endTime: DateTime.now(),
      bpmStart: _ref.read(bpmProvider),
      bpmEnd: _ref.read(bpmProvider),
      timeSignature: _ref.read(timeSigProvider).label,
      drumStyle: tabIdx == 1 ? _ref.read(drumStyleProvider) : '',
      takesRecorded: _ref.read(takesProvider).length,
      averageDeviation: _ref.read(currentMetricsProvider)?.averageDeviationMs,
      consistencyScore: _ref.read(currentMetricsProvider)?.consistencyScore.toDouble(),
    );
    await _persistence.addSession(session);

    final history = [..._ref.read(sessionsHistoryProvider), session];
    _ref.read(sessionsHistoryProvider.notifier).state = history;

    _sessionStart = null;
    _ref.read(speedTrainerReachedProvider.notifier).state = false;
  }

  Future<void> _startPlayback(int tabIdx) async {
    _sessionStart = DateTime.now();
    _barCount = 0;
    _ref.read(playingProvider.notifier).state = true;

    final bpm = _ref.read(bpmProvider);
    final timeSig = _ref.read(timeSigProvider);
    final subdivision = _ref.read(subdivisionProvider);
    final swing = _ref.read(swingProvider);
    final clickSound = _ref.read(clickSoundProvider);
    final accents = _ref.read(accentPatternProvider);
    final haptic = _ref.read(hapticModeProvider);

    if (tabIdx == 1) {
      await _startDrums(bpm, swing);
    } else {
      await _startMetronome(bpm, timeSig, subdivision, swing, clickSound, accents, haptic);
    }
  }

  Future<void> _startDrums(int bpm, int swing) async {
    final drumStyle = _ref.read(drumStyleProvider);
    final customPattern = _ref.read(customDrumPatternProvider);
    final dTimeSig = _ref.read(drumTimeSigProvider);
    final dAccents = _ref.read(drumAccentPatternProvider);
    final totalSteps = drumTotalSteps(dTimeSig.num, dTimeSig.den);
    final rawPattern = customPattern ?? drumPatterns[drumStyle] ?? {};
    final pattern = adaptDrumPattern(rawPattern, totalSteps);
    await _audio.startDrumPattern(
      bpm: bpm,
      pattern: pattern.map((k, v) => MapEntry(k, List<int>.from(v))),
      swingPercent: swing,
      drumBeats: dTimeSig.num,
      drumBeatUnit: dTimeSig.den,
      drumAccentPattern: dAccents,
    );
    // Send effective volumes (respecting mute/solo state)
    final effectiveVols = computeEffectiveDrumVolumes(
      volumes: _ref.read(drumVolumesProvider),
      mutes: _ref.read(drumMuteProvider),
      solos: _ref.read(drumSoloProvider),
    );
    await _audio.updateDrumVolumes(effectiveVols);
  }

  Future<void> _startMetronome(int bpm, TimeSig timeSig, int subdivision, int swing, String clickSound, List<double> accents, bool haptic) async {
    final countIn = _ref.read(countInBarsProvider);
    await _audio.updateCountIn(countIn);

    await _audio.startMetronome(
      bpm: bpm,
      beatsPerBar: timeSig.num,
      beatUnit: timeSig.den,
      subdivision: subdivision,
      swingPercent: swing,
      clickSound: clickSound,
      accentPattern: accents,
      hapticEnabled: haptic,
    );

    final hf = _ref.read(humanFeelProvider);
    if (hf > 0) await _audio.updateHumanFeel(hf);
    final polyEnabled = _ref.read(polyrhythmEnabledProvider);
    if (polyEnabled) {
      await _audio.updatePolyrhythm(true, _ref.read(polyrhythmValueProvider));
    }
    await _audio.updateIntervalTraining(
      _ref.read(intervalTrainingProvider),
      _ref.read(clickBarsProvider),
      _ref.read(silentBarsProvider),
    );
    await _audio.updateRandomSilence(
      _ref.read(randomSilenceProvider),
      _ref.read(silenceProbProvider),
    );
  }

  /// Toggle recording (native only — web uses separate MediaRecorder flow)
  Future<void> toggleRecording() async {
    if (kIsWeb) {
      _ref.read(tabIndexProvider.notifier).state = 2;
      return;
    }

    final isRec = _ref.read(isRecordingProvider);
    if (isRec) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _stopRecording() async {
    _waitingForFirstBeat = false;
    _ref.read(isRecordingProvider.notifier).state = false;
    await _audio.disableOnsetDetection();
    final path = await _audio.stopRecording();
    _recordingTimer?.cancel();

    final analyzer = _ref.read(timingAnalyzerProvider);
    if (analyzer != null) {
      final metrics = analyzer.calculateMetrics();
      _ref.read(currentMetricsProvider.notifier).state = metrics;

      final take = Take(
        id: const Uuid().v4(),
        sessionId: '',
        timestamp: DateTime.now(),
        bpm: _ref.read(bpmProvider),
        timeSignature: _ref.read(timeSigProvider).label,
        duration: _ref.read(recordingDurationProvider),
        audioFilePath: path,
        onsets: analyzer.onsets,
        metrics: metrics,
      );
      final takes = [..._ref.read(takesProvider), take];
      _ref.read(takesProvider.notifier).state = takes;
      _ref.read(showTimingOverlayProvider.notifier).state = true;
      await _persistence.saveTake(take);
    }
  }

  Future<void> _startRecording() async {
    _ref.read(liveOnsetsProvider.notifier).state = [];
    _ref.read(recordingDurationProvider.notifier).state = Duration.zero;
    _ref.read(isRecordingProvider.notifier).state = true;

    final bpm = _ref.read(bpmProvider);
    final timeSig = _ref.read(timeSigProvider);
    final subdivision = _ref.read(subdivisionProvider);
    final analyzer = TimingAnalyzer(
      bpm: bpm,
      beatsPerBar: timeSig.num,
      subdivision: subdivision,
    );

    await _audio.enableOnsetDetection(threshold: 0.08, minIntervalMs: 40);
    await _audio.startRecording();

    _ref.read(timingAnalyzerProvider.notifier).state = analyzer;
    _waitingForFirstBeat = true;

    final recStart = DateTime.now();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _ref.read(recordingDurationProvider.notifier).state =
          DateTime.now().difference(recStart);
    });
  }

  /// Tap tempo detection
  void onTapTempo() {
    final now = DateTime.now();
    if (_tapTimes.isNotEmpty && now.difference(_tapTimes.last).inMilliseconds > 2000) {
      _tapTimes.clear();
    }
    _tapTimes.add(now);
    if (_tapTimes.length > 8) _tapTimes.removeAt(0);

    if (_tapTimes.length >= 2) {
      double totalMs = 0;
      for (int i = 1; i < _tapTimes.length; i++) {
        totalMs += _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds;
      }
      final avgMs = totalMs / (_tapTimes.length - 1);
      final newBpm = (60000 / avgMs).round().clamp(20, 500);
      _ref.read(bpmProvider.notifier).state = newBpm;
      if (_ref.read(playingProvider)) {
        _audio.updateBpm(newBpm);
      }
    }
  }

  /// Emergency stop all audio sources
  Future<void> stopAllAudio() async {
    await _audio.stopMetronome();
    await _audio.stopDrumPattern();
    await _audio.stopLoopPlayback();
    await _audio.stopAllPads();
    await _audio.stopActivePad();
    await _audio.stopWebRecording();
    await _audio.songLabStop();

    _ref.read(playingProvider.notifier).state = false;
    _ref.read(currentBeatProvider.notifier).state = -1;
    _ref.read(drumStepProvider.notifier).state = -1;
    _ref.read(loopIsPlayingProvider.notifier).state = false;
    _ref.read(loopIsRecordingProvider.notifier).state = false;
  }

  /// Check if any audio is currently active
  bool get isAnyAudioActive =>
    _ref.read(playingProvider) ||
    _ref.read(loopIsPlayingProvider) ||
    _ref.read(loopIsRecordingProvider);

  void dispose() {
    _beatSub?.cancel();
    _onsetSub?.cancel();
    _recSub?.cancel();
    _recordingTimer?.cancel();
  }
}

/// Riverpod provider for AudioManagementService
final audioManagementProvider = Provider<AudioManagementService>((ref) {
  final service = AudioManagementService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
