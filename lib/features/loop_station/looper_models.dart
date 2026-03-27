import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Expanded transport state machine for the looper.
enum LoopTransportState {
  /// No layers recorded, ready to begin.
  idle,

  /// Waiting for user action after count-in has been configured.
  armed,

  /// Count-in is playing before recording starts.
  countIn,

  /// Recording the first layer (defines loop length).
  recording,

  /// Brief transition: first layer recorded, starting playback.
  closingLoop,

  /// Loop is playing back.
  playing,

  /// Recording a new layer over the existing loop.
  overdubbing,

  /// Playback is paused (loop data exists).
  paused,

  /// Playback is stopped (loop data exists).
  stopped,

  /// An export operation is in progress.
  exporting,
}

/// All possible events that can be fed into [LoopStateMachine].
enum LoopTransportEvent {
  tapRecord,
  tapStop,
  tapPlay,
  tapOverdub,
  tapPause,
  countInFinished,
  loopClosed,
  recordingFinished,
  overdubFinished,
  exportRequested,
  exportFinished,
  exportFailed,
  deleteLayer,
  undoLayer,
  clearAll,
}

/// Source type for the guide track.
enum GuideSource { none, metronome, drums }

/// Determines how the guide track restarts relative to the loop.
enum GuideRestartMode { followLoop, restartFromBar1 }

/// Determines which layers are included in an export.
enum ExportMode {
  /// All unmuted layers mixed down to a single file.
  fullMix,

  /// All unmuted layers plus the guide track.
  fullMixWithGuide,

  /// Only the layers whose indices appear in [ExportSettings.selectedLayerIndices].
  selectedLayers,

  /// Each layer exported as an individual stem file.
  stems,
}

// ---------------------------------------------------------------------------
// LoopLayer
// ---------------------------------------------------------------------------

/// Represents a single recorded layer within a loop session.
@immutable
class LoopLayer {
  const LoopLayer({
    required this.index,
    this.name = '',
    this.volume = 1.0,
    this.pan = 0.0,
    this.muted = false,
    this.solo = false,
    this.includedInExport = true,
    this.waveform = const [],
    required this.createdAt,
    this.duration = 0.0,
  });

  /// Zero-based index identifying this layer within the session.
  final int index;

  /// User-facing display name (e.g. "Layer 1", "Guitar").
  final String name;

  /// Playback volume in the range 0.0 – 1.0.
  final double volume;

  /// Stereo pan in the range -1.0 (full left) to 1.0 (full right).
  final double pan;

  /// Whether the layer is muted during playback.
  final bool muted;

  /// Whether this layer is soloed (only soloed layers are audible).
  final bool solo;

  /// Whether this layer should be included when exporting.
  final bool includedInExport;

  /// Normalised waveform amplitude data for visualisation.
  final List<double> waveform;

  /// Timestamp when the layer was created.
  final DateTime createdAt;

  /// Duration of the layer in seconds.
  final double duration;

  LoopLayer copyWith({
    int? index,
    String? name,
    double? volume,
    double? pan,
    bool? muted,
    bool? solo,
    bool? includedInExport,
    List<double>? waveform,
    DateTime? createdAt,
    double? duration,
  }) {
    return LoopLayer(
      index: index ?? this.index,
      name: name ?? this.name,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      muted: muted ?? this.muted,
      solo: solo ?? this.solo,
      includedInExport: includedInExport ?? this.includedInExport,
      waveform: waveform ?? this.waveform,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoopLayer &&
        other.index == index &&
        other.name == name &&
        other.volume == volume &&
        other.pan == pan &&
        other.muted == muted &&
        other.solo == solo &&
        other.includedInExport == includedInExport &&
        listEquals(other.waveform, waveform) &&
        other.createdAt == createdAt &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(
        index,
        name,
        volume,
        pan,
        muted,
        solo,
        includedInExport,
        Object.hashAll(waveform),
        createdAt,
        duration,
      );

  @override
  String toString() =>
      'LoopLayer(index: $index, name: $name, muted: $muted, solo: $solo, '
      'volume: $volume, pan: $pan, duration: ${duration.toStringAsFixed(2)}s)';
}

// ---------------------------------------------------------------------------
// GuideTrackConfig
// ---------------------------------------------------------------------------

/// Configuration for the guide track (metronome / drum pattern).
@immutable
class GuideTrackConfig {
  const GuideTrackConfig({
    this.source = GuideSource.none,
    this.isMuted = false,
    this.isSolo = false,
    this.volume = 0.8,
    this.followsTransport = true,
    this.restartMode = GuideRestartMode.followLoop,
    this.includeInExport = false,
    this.exportAsSeparateStem = false,
    this.autoStartOnRecord = true,
    this.autoStartOnPlay = true,
    this.keepAfterStop = false,
  });

  /// The audio source used for the guide track.
  final GuideSource source;

  /// Whether the guide track is currently muted.
  final bool isMuted;

  /// Whether the guide track is soloed.
  final bool isSolo;

  /// Volume level in the range 0.0 – 1.0.
  final double volume;

  /// When true the guide starts and stops together with the loop transport.
  final bool followsTransport;

  /// Determines restart behaviour relative to the loop boundary.
  final GuideRestartMode restartMode;

  /// Whether the guide audio is included in the exported mix.
  final bool includeInExport;

  /// When true the guide is exported as its own stem file.
  final bool exportAsSeparateStem;

  /// Automatically start the guide when a recording begins.
  final bool autoStartOnRecord;

  /// Automatically start the guide when playback begins.
  final bool autoStartOnPlay;

  /// Keep the guide playing even after the loop transport stops.
  final bool keepAfterStop;

  GuideTrackConfig copyWith({
    GuideSource? source,
    bool? isMuted,
    bool? isSolo,
    double? volume,
    bool? followsTransport,
    GuideRestartMode? restartMode,
    bool? includeInExport,
    bool? exportAsSeparateStem,
    bool? autoStartOnRecord,
    bool? autoStartOnPlay,
    bool? keepAfterStop,
  }) {
    return GuideTrackConfig(
      source: source ?? this.source,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
      volume: volume ?? this.volume,
      followsTransport: followsTransport ?? this.followsTransport,
      restartMode: restartMode ?? this.restartMode,
      includeInExport: includeInExport ?? this.includeInExport,
      exportAsSeparateStem: exportAsSeparateStem ?? this.exportAsSeparateStem,
      autoStartOnRecord: autoStartOnRecord ?? this.autoStartOnRecord,
      autoStartOnPlay: autoStartOnPlay ?? this.autoStartOnPlay,
      keepAfterStop: keepAfterStop ?? this.keepAfterStop,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GuideTrackConfig &&
        other.source == source &&
        other.isMuted == isMuted &&
        other.isSolo == isSolo &&
        other.volume == volume &&
        other.followsTransport == followsTransport &&
        other.restartMode == restartMode &&
        other.includeInExport == includeInExport &&
        other.exportAsSeparateStem == exportAsSeparateStem &&
        other.autoStartOnRecord == autoStartOnRecord &&
        other.autoStartOnPlay == autoStartOnPlay &&
        other.keepAfterStop == keepAfterStop;
  }

  @override
  int get hashCode => Object.hash(
        source,
        isMuted,
        isSolo,
        volume,
        followsTransport,
        restartMode,
        includeInExport,
        exportAsSeparateStem,
        autoStartOnRecord,
        autoStartOnPlay,
        keepAfterStop,
      );

  @override
  String toString() =>
      'GuideTrackConfig(source: $source, volume: $volume, muted: $isMuted)';
}

// ---------------------------------------------------------------------------
// ExportSettings
// ---------------------------------------------------------------------------

/// Settings that control how a looper session is exported to audio files.
@immutable
class ExportSettings {
  const ExportSettings({
    this.mode = ExportMode.fullMix,
    this.format = 'wav',
    this.normalize = true,
    this.includeGuide = false,
    this.exportGuideAsStem = false,
    this.selectedLayerIndices = const {},
  });

  /// Which layers / mix mode to use for the export.
  final ExportMode mode;

  /// Target audio format (e.g. 'wav').
  final String format;

  /// Whether to normalise the exported audio.
  final bool normalize;

  /// Whether the guide track should be mixed into the export.
  final bool includeGuide;

  /// Whether the guide track should be exported as a separate stem.
  final bool exportGuideAsStem;

  /// Layer indices to include when [mode] is [ExportMode.selectedLayers].
  final Set<int> selectedLayerIndices;

  ExportSettings copyWith({
    ExportMode? mode,
    String? format,
    bool? normalize,
    bool? includeGuide,
    bool? exportGuideAsStem,
    Set<int>? selectedLayerIndices,
  }) {
    return ExportSettings(
      mode: mode ?? this.mode,
      format: format ?? this.format,
      normalize: normalize ?? this.normalize,
      includeGuide: includeGuide ?? this.includeGuide,
      exportGuideAsStem: exportGuideAsStem ?? this.exportGuideAsStem,
      selectedLayerIndices: selectedLayerIndices ?? this.selectedLayerIndices,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExportSettings &&
        other.mode == mode &&
        other.format == format &&
        other.normalize == normalize &&
        other.includeGuide == includeGuide &&
        other.exportGuideAsStem == exportGuideAsStem &&
        setEquals(other.selectedLayerIndices, selectedLayerIndices);
  }

  @override
  int get hashCode => Object.hash(
        mode,
        format,
        normalize,
        includeGuide,
        exportGuideAsStem,
        Object.hashAll(selectedLayerIndices.toList()..sort()),
      );

  @override
  String toString() =>
      'ExportSettings(mode: $mode, format: $format, normalize: $normalize)';
}

// ---------------------------------------------------------------------------
// LooperSession
// ---------------------------------------------------------------------------

/// Top-level model that captures the full state of a looper session.
@immutable
class LooperSession {
  const LooperSession({
    required this.sessionId,
    this.bpm = 120,
    this.timeSignature = '4/4',
    this.quantizeEnabled = true,
    this.countInBars = 0,
    this.currentState = LoopTransportState.idle,
    this.loopLengthSeconds = 0.0,
    this.loopLengthBeats = 0,
    this.layers = const [],
    this.guideConfig = const GuideTrackConfig(),
    this.exportSettings = const ExportSettings(),
  });

  /// Unique identifier for this session.
  final String sessionId;

  /// Tempo in beats per minute.
  final int bpm;

  /// Time signature expressed as a string (e.g. '4/4', '3/4').
  final String timeSignature;

  /// Whether recording / overdub boundaries snap to beat boundaries.
  final bool quantizeEnabled;

  /// Number of bars to count in before recording begins (0 = disabled).
  final int countInBars;

  /// Current transport state.
  final LoopTransportState currentState;

  /// Total loop length in seconds (set after the first layer is recorded).
  final double loopLengthSeconds;

  /// Total loop length expressed in beats.
  final int loopLengthBeats;

  /// Ordered list of recorded layers.
  final List<LoopLayer> layers;

  /// Configuration for the guide track.
  final GuideTrackConfig guideConfig;

  /// Current export settings.
  final ExportSettings exportSettings;

  LooperSession copyWith({
    String? sessionId,
    int? bpm,
    String? timeSignature,
    bool? quantizeEnabled,
    int? countInBars,
    LoopTransportState? currentState,
    double? loopLengthSeconds,
    int? loopLengthBeats,
    List<LoopLayer>? layers,
    GuideTrackConfig? guideConfig,
    ExportSettings? exportSettings,
  }) {
    return LooperSession(
      sessionId: sessionId ?? this.sessionId,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      quantizeEnabled: quantizeEnabled ?? this.quantizeEnabled,
      countInBars: countInBars ?? this.countInBars,
      currentState: currentState ?? this.currentState,
      loopLengthSeconds: loopLengthSeconds ?? this.loopLengthSeconds,
      loopLengthBeats: loopLengthBeats ?? this.loopLengthBeats,
      layers: layers ?? this.layers,
      guideConfig: guideConfig ?? this.guideConfig,
      exportSettings: exportSettings ?? this.exportSettings,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LooperSession &&
        other.sessionId == sessionId &&
        other.bpm == bpm &&
        other.timeSignature == timeSignature &&
        other.quantizeEnabled == quantizeEnabled &&
        other.countInBars == countInBars &&
        other.currentState == currentState &&
        other.loopLengthSeconds == loopLengthSeconds &&
        other.loopLengthBeats == loopLengthBeats &&
        listEquals(other.layers, layers) &&
        other.guideConfig == guideConfig &&
        other.exportSettings == exportSettings;
  }

  @override
  int get hashCode => Object.hash(
        sessionId,
        bpm,
        timeSignature,
        quantizeEnabled,
        countInBars,
        currentState,
        loopLengthSeconds,
        loopLengthBeats,
        Object.hashAll(layers),
        guideConfig,
        exportSettings,
      );

  @override
  String toString() =>
      'LooperSession(id: $sessionId, bpm: $bpm, state: $currentState, '
      'layers: ${layers.length}, loop: ${loopLengthSeconds.toStringAsFixed(2)}s)';
}

// ---------------------------------------------------------------------------
// LoopStateMachine
// ---------------------------------------------------------------------------

/// A deterministic state machine that governs valid [LoopTransportState]
/// transitions in response to [LoopTransportEvent]s.
///
/// The machine does **not** carry side-effects; callers are responsible for
/// reacting to state changes (e.g. starting / stopping audio engines).
class LoopStateMachine {
  LoopStateMachine({
    LoopTransportState initialState = LoopTransportState.idle,
    this.countInEnabled = false,
  }) : _state = initialState;

  LoopTransportState _state;

  /// When true, [LoopTransportEvent.tapRecord] from [LoopTransportState.idle]
  /// transitions to [LoopTransportState.countIn] instead of
  /// [LoopTransportState.recording].
  bool countInEnabled;

  /// The current transport state.
  LoopTransportState get state => _state;

  /// Attempts to transition the state machine by processing [event].
  ///
  /// Returns the new [LoopTransportState] if the transition is valid, or
  /// `null` if the event is not allowed in the current state.
  LoopTransportState? transition(LoopTransportEvent event) {
    final newState = _getNextState(_state, event);
    if (newState != null) {
      _state = newState;
    }
    return newState;
  }

  /// Resets the machine back to [LoopTransportState.idle].
  void reset() => _state = LoopTransportState.idle;

  /// Forces the machine into [state] regardless of transition rules.
  ///
  /// Use sparingly -- this bypasses all validation.
  void forceState(LoopTransportState state) => _state = state;

  /// Returns `true` if [event] would produce a valid transition from the
  /// current state.
  bool canProcess(LoopTransportEvent event) =>
      _getNextState(_state, event) != null;

  /// Returns every [LoopTransportEvent] that is valid in the current state.
  List<LoopTransportEvent> validEvents() {
    return LoopTransportEvent.values
        .where((e) => _getNextState(_state, e) != null)
        .toList();
  }

  /// A human-readable label for the current state, suitable for display in
  /// the UI transport bar.
  String get stateLabel => switch (_state) {
        LoopTransportState.idle => 'Ready',
        LoopTransportState.armed => 'Armed',
        LoopTransportState.countIn => 'Count-in',
        LoopTransportState.recording => 'Recording',
        LoopTransportState.closingLoop => 'Closing Loop',
        LoopTransportState.playing => 'Playing',
        LoopTransportState.overdubbing => 'Overdubbing',
        LoopTransportState.paused => 'Paused',
        LoopTransportState.stopped => 'Stopped',
        LoopTransportState.exporting => 'Exporting',
      };

  // -------------------------------------------------------------------------
  // Transition table
  // -------------------------------------------------------------------------

  LoopTransportState? _getNextState(
    LoopTransportState current,
    LoopTransportEvent event,
  ) {
    return switch (current) {
      // -- idle ---------------------------------------------------------------
      LoopTransportState.idle => switch (event) {
          LoopTransportEvent.tapRecord => countInEnabled
              ? LoopTransportState.countIn
              : LoopTransportState.recording,
          _ => null,
        },

      // -- armed --------------------------------------------------------------
      LoopTransportState.armed => switch (event) {
          LoopTransportEvent.tapRecord => countInEnabled
              ? LoopTransportState.countIn
              : LoopTransportState.recording,
          LoopTransportEvent.tapStop => LoopTransportState.idle,
          _ => null,
        },

      // -- countIn ------------------------------------------------------------
      LoopTransportState.countIn => switch (event) {
          LoopTransportEvent.countInFinished => LoopTransportState.recording,
          LoopTransportEvent.tapStop => LoopTransportState.idle,
          _ => null,
        },

      // -- recording (first layer) -------------------------------------------
      LoopTransportState.recording => switch (event) {
          LoopTransportEvent.tapRecord => LoopTransportState.closingLoop,
          LoopTransportEvent.tapStop => LoopTransportState.closingLoop,
          LoopTransportEvent.recordingFinished => LoopTransportState.closingLoop,
          _ => null,
        },

      // -- closingLoop --------------------------------------------------------
      LoopTransportState.closingLoop => switch (event) {
          LoopTransportEvent.loopClosed => LoopTransportState.playing,
          _ => null,
        },

      // -- playing ------------------------------------------------------------
      LoopTransportState.playing => switch (event) {
          LoopTransportEvent.tapRecord ||
          LoopTransportEvent.tapOverdub =>
            LoopTransportState.overdubbing,
          LoopTransportEvent.tapStop => LoopTransportState.stopped,
          LoopTransportEvent.tapPause => LoopTransportState.paused,
          LoopTransportEvent.exportRequested => LoopTransportState.exporting,
          LoopTransportEvent.undoLayer => LoopTransportState.playing,
          LoopTransportEvent.deleteLayer => LoopTransportState.playing,
          LoopTransportEvent.clearAll => LoopTransportState.idle,
          _ => null,
        },

      // -- overdubbing --------------------------------------------------------
      LoopTransportState.overdubbing => switch (event) {
          LoopTransportEvent.tapRecord ||
          LoopTransportEvent.tapOverdub ||
          LoopTransportEvent.overdubFinished =>
            LoopTransportState.playing,
          LoopTransportEvent.tapStop => LoopTransportState.stopped,
          _ => null,
        },

      // -- paused -------------------------------------------------------------
      LoopTransportState.paused => switch (event) {
          LoopTransportEvent.tapPlay => LoopTransportState.playing,
          LoopTransportEvent.tapRecord ||
          LoopTransportEvent.tapOverdub =>
            LoopTransportState.overdubbing,
          LoopTransportEvent.tapStop => LoopTransportState.stopped,
          LoopTransportEvent.exportRequested => LoopTransportState.exporting,
          LoopTransportEvent.undoLayer => LoopTransportState.paused,
          LoopTransportEvent.deleteLayer => LoopTransportState.paused,
          LoopTransportEvent.clearAll => LoopTransportState.idle,
          _ => null,
        },

      // -- stopped ------------------------------------------------------------
      LoopTransportState.stopped => switch (event) {
          LoopTransportEvent.tapPlay => LoopTransportState.playing,
          LoopTransportEvent.tapRecord ||
          LoopTransportEvent.tapOverdub =>
            LoopTransportState.overdubbing,
          LoopTransportEvent.exportRequested => LoopTransportState.exporting,
          LoopTransportEvent.undoLayer => LoopTransportState.stopped,
          LoopTransportEvent.deleteLayer => LoopTransportState.stopped,
          LoopTransportEvent.clearAll => LoopTransportState.idle,
          _ => null,
        },

      // -- exporting ----------------------------------------------------------
      LoopTransportState.exporting => switch (event) {
          LoopTransportEvent.exportFinished => LoopTransportState.stopped,
          LoopTransportEvent.exportFailed => LoopTransportState.stopped,
          _ => null,
        },
    };
  }
}
