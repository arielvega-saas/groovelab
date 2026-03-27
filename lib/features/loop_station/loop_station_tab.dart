import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/audio/audio_service.dart';
import '../../core/audio/native_audio_bridge.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';
import 'waveform_painter.dart';
import 'looper_models.dart';
import 'web_download_bridge.dart';

// ═══════════════════════════════════════════════════════════════════
//  MAIN LOOP STATION TAB — Compact single-screen layout
// ═══════════════════════════════════════════════════════════════════

class LoopStationTab extends ConsumerStatefulWidget {
  final VoidCallback onTogglePlay;
  const LoopStationTab({super.key, required this.onTogglePlay});
  @override
  ConsumerState<LoopStationTab> createState() => _LoopStationTabState();
}

class _LoopStationTabState extends ConsumerState<LoopStationTab>
    with TickerProviderStateMixin {

  // ── State Machine ──
  final LoopStateMachine _sm = LoopStateMachine();

  // ── State ──
  double _inputLevel = 0.0;
  double _loopPosition = 0.0;
  bool _isExporting = false;
  bool _drumsPlaying = false;
  bool _guideDrumsExpanded = false;
  bool _guideMetronomeExpanded = false;
  bool _guidePrefsExpanded = false;
  int _countInBeatsLeft = 0;
  int _selectedLayerIndex = -1;
  List<LoopLayer> _layers = [];

  // ── Guide config ──
  GuideTrackConfig _guideConfig = const GuideTrackConfig();

  // ── Export config ──
  ExportMode _exportMode = ExportMode.fullMix;
  // ignore: unused_field
  bool _guideIncludeInExport = false;

  // ── Beat info ──
  int _currentBar = 0;
  int _totalBars = 0;
  int _beatInBar = 0;
  int _beatsPerBar = 4;

  // ── Subscriptions ──
  StreamSubscription<double>? _positionSub;
  StreamSubscription<double>? _levelSub;
  StreamSubscription<MidiEvent>? _midiSub;
  StreamSubscription<Map<String, dynamic>>? _overdubStopSub;

  // ── Animation ──
  late AnimationController _recPulse;
  late AnimationController _countInAnim;
  late AnimationController _progressGlow;
  late AnimationController _levelSmooth;
  double _smoothedLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _recPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _countInAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _progressGlow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _levelSmooth = AnimationController(vsync: this, duration: const Duration(milliseconds: 80))
      ..addListener(() {
        if (mounted) setState(() {
          _smoothedLevel = _smoothedLevel + (_inputLevel - _smoothedLevel) * _levelSmooth.value;
        });
      });
    _setupStreams();
  }

  void _setupStreams() {
    final audio = ref.read(audioServiceProvider);
    _positionSub = audio.loopPosition.listen((pos) {
      if (mounted) {
        setState(() => _loopPosition = pos);
        _updateBeatInfo();
      }
    });
    _levelSub = audio.inputLevel.listen((level) {
      if (mounted) {
        setState(() => _inputLevel = level);
        _levelSmooth.forward(from: 0);
      }
    });
    _midiSub = audio.midiEvents.listen((event) {
      if (mounted) {
        ref.read(lastMidiEventProvider.notifier).state =
            '${event.type}: ${event.note} (vel: ${event.velocity})';
      }
    });
    _overdubStopSub = audio.overdubAutoStop.listen((data) {
      if (!mounted) return;
      final count = data['layerCount'] as int? ?? 0;
      final dur = data['duration'] as double? ?? 0.0;
      ref.read(loopLayerCountProvider.notifier).state = count;
      ref.read(loopDurationProvider.notifier).state = Duration(milliseconds: (dur * 1000).round());
      ref.read(loopIsRecordingProvider.notifier).state = false;
      ref.read(loopIsPlayingProvider.notifier).state = true;
      setState(() {
        _layers = List.generate(count, (i) {
          if (i < _layers.length && i != count - 1) return _layers[i];
          return LoopLayer(
            index: i,
            name: i < _layers.length ? _layers[i].name : 'Layer ${i + 1}',
            volume: i < _layers.length ? _layers[i].volume : 1.0,
            pan: i < _layers.length ? _layers[i].pan : 0.0,
            muted: i < _layers.length ? _layers[i].muted : false,
            solo: i < _layers.length ? _layers[i].solo : false,
            waveform: audio.getLayerWaveform(i, 80),
            createdAt: DateTime.now(),
          );
        });
      });
      _sm.forceState(LoopTransportState.playing);
    });
  }

  void _updateBeatInfo() {
    final audio = ref.read(audioServiceProvider);
    final info = audio.getLoopBeatInfo();
    _currentBar = info['bar'] ?? 0;
    _totalBars = info['totalBars'] ?? 0;
    _beatInBar = info['beatInBar'] ?? 0;
    _beatsPerBar = info['beatsPerBar'] ?? 4;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _levelSub?.cancel();
    _midiSub?.cancel();
    _overdubStopSub?.cancel();
    _recPulse.dispose();
    _countInAnim.dispose();
    _progressGlow.dispose();
    _levelSmooth.dispose();
    super.dispose();
  }

  void _refreshLayerData() {
    final audio = ref.read(audioServiceProvider);
    final state = audio.getLoopState();
    final count = (state['layerCount'] as int?) ?? 0;

    // Sync recording state from JS (fallback for auto-stop)
    final jsIsRecording = (state['isRecording'] as bool?) ?? false;
    final dartIsRecording = ref.read(loopIsRecordingProvider);
    if (dartIsRecording && !jsIsRecording) {
      // JS stopped recording but Dart doesn't know yet
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(loopIsRecordingProvider.notifier).state = false;
        ref.read(loopLayerCountProvider.notifier).state = count;
        final dur = (state['duration'] as double?) ?? 0.0;
        if (dur > 0) {
          ref.read(loopDurationProvider.notifier).state = Duration(milliseconds: (dur * 1000).round());
        }
        if (count > 0 && !ref.read(loopIsPlayingProvider)) {
          final jsIsPlaying = (state['isPlaying'] as bool?) ?? false;
          if (jsIsPlaying) ref.read(loopIsPlayingProvider.notifier).state = true;
        }
      });
    }

    if (count != _layers.length) {
      final newLayers = <LoopLayer>[];
      for (int i = 0; i < count; i++) {
        if (i < _layers.length) {
          var layer = _layers[i];
          if (layer.waveform.isEmpty) {
            layer = layer.copyWith(waveform: audio.getLayerWaveform(i, 80));
          }
          newLayers.add(layer);
        } else {
          newLayers.add(LoopLayer(
            index: i, name: 'Layer ${i + 1}',
            waveform: audio.getLayerWaveform(i, 80),
            createdAt: DateTime.now(),
          ));
        }
      }
      _layers = newLayers;
    }
  }

  LoopTransportState _syncState() {
    final loopRecording = ref.read(loopIsRecordingProvider);
    final loopPlaying = ref.read(loopIsPlayingProvider);
    final layerCount = ref.read(loopLayerCountProvider);
    if (_sm.state == LoopTransportState.countIn ||
        _sm.state == LoopTransportState.exporting ||
        _sm.state == LoopTransportState.closingLoop) return _sm.state;
    if (loopRecording) {
      _sm.forceState(layerCount > 0 ? LoopTransportState.overdubbing : LoopTransportState.recording);
    } else if (loopPlaying) {
      _sm.forceState(LoopTransportState.playing);
    } else if (layerCount > 0) {
      if (_sm.state != LoopTransportState.paused) _sm.forceState(LoopTransportState.stopped);
    } else {
      _sm.forceState(LoopTransportState.idle);
    }
    return _sm.state;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD — Compact single-screen layout
  //
  //  1. Status bar: "RECORDING · Bar 3.2 · 00:12"    (~28px)
  //  2. Input level meter (thin bar)                   (~8px)
  //  3. Circular progress / waveform display           (~120px)
  //  4. Transport: [REC] [OVERDUB] [STOP] [PLAY]       (~50px)
  //  5. Layer list (compact strips, scrollable)         (~remaining)
  //  6. Bottom: [Undo] [Export] [Guide] [Vol]           (~40px)
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    ref.watch(loopIsRecordingProvider);
    ref.watch(loopIsPlayingProvider);
    final layerCount = ref.watch(loopLayerCountProvider);
    final loopDuration = ref.watch(loopDurationProvider);
    final monitoring = ref.watch(inputMonitoringProvider);
    final guideMuted = ref.watch(guideMutedProvider);
    final guideVol = ref.watch(guideVolumeProvider);
    final masterVol = ref.watch(loopMasterVolumeProvider);
    // monitorVol, midiEnabled, midiDevices used by guide modal
    ref.watch(monitorVolumeProvider);
    ref.watch(midiEnabledProvider);
    ref.watch(midiDevicesProvider);
    final metPlaying = ref.watch(playingProvider);

    final phase = _syncState();
    _sm.countInEnabled = ref.watch(countInBarsProvider) > 0;

    if (ref.read(loopIsRecordingProvider)) {
      _recPulse.repeat(reverse: true);
    } else {
      _recPulse.stop();
      _recPulse.value = 0;
    }
    _refreshLayerData();

    final durSec = loopDuration.inMilliseconds / 1000;
    final posSec = durSec * _loopPosition;
    final loopRecording = ref.read(loopIsRecordingProvider);
    final loopPlaying = ref.read(loopIsPlayingProvider);

    final isRecPhase = phase == LoopTransportState.recording || phase == LoopTransportState.overdubbing;

    return Stack(
      children: [
        // Pulsing red border when recording
        AnimatedBuilder(
          animation: _recPulse,
          builder: (_, child) => Container(
            decoration: isRecPhase ? BoxDecoration(
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.15 + _recPulse.value * 0.25),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: _recPulse.value * 0.12),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ],
            ) : null,
            child: child,
          ),
          child: Column(
            children: [
              // ══════════════════════════════════════════════════════
              //  1. STATUS BAR — compact one-liner
              // ══════════════════════════════════════════════════════
              _buildCompactStatusBar(lang, phase, layerCount, posSec, durSec),

              // ══════════════════════════════════════════════════════
              //  2. INPUT LEVEL METER — segmented VU arc
              // ══════════════════════════════════════════════════════
              _buildVuMeterArc(),

              // ══════════════════════════════════════════════════════
              //  3. CIRCULAR PROGRESS / WAVEFORM RING
              // ══════════════════════════════════════════════════════
              _buildCompactProgress(phase, layerCount, posSec, durSec),

              // ══════════════════════════════════════════════════════
              //  4. TRANSPORT — compact row of small buttons
              // ══════════════════════════════════════════════════════
              _buildCompactTransport(lang, phase, layerCount, loopRecording, loopPlaying),

              // ══════════════════════════════════════════════════════
              //  5. LAYER LIST — compact strips, takes remaining space
              // ══════════════════════════════════════════════════════
              Expanded(
                child: _buildCompactLayerList(lang, layerCount, loopRecording, loopPlaying),
              ),

              // ══════════════════════════════════════════════════════
              //  6. BOTTOM BAR — [Undo] [Export] [Guide] [Vol]
              // ══════════════════════════════════════════════════════
              if (layerCount > 0)
                _buildBottomBar(lang, masterVol, layerCount, durSec, monitoring, guideMuted, guideVol, metPlaying),
            ],
          ),
        ),
        if (phase == LoopTransportState.countIn) _buildCountInOverlay(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  1. COMPACT STATUS BAR — "RECORDING · Bar 3.2 · 00:12"
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCompactStatusBar(String lang, LoopTransportState phase, int layerCount, double posSec, double durSec) {
    final sc = _getPhaseConfig(phase, lang);
    final isActive = phase == LoopTransportState.playing || phase == LoopTransportState.recording || phase == LoopTransportState.overdubbing;

    final parts = <String>[sc.label];
    if (isActive && layerCount > 0) {
      parts.add('Bar ${_currentBar + 1}${_totalBars > 0 ? '/$_totalBars' : ''}.${_beatInBar + 1}');
    }
    if (layerCount > 0) {
      parts.add(_formatTime(isActive ? posSec : durSec));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.bgDark,
      child: Row(children: [
        // Pulsing status dot
        AnimatedBuilder(
          animation: _recPulse,
          builder: (_, __) => Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (phase == LoopTransportState.recording || phase == LoopTransportState.overdubbing)
                  ? sc.color.withValues(alpha: 0.5 + _recPulse.value * 0.5) : sc.color,
              boxShadow: (phase == LoopTransportState.recording || phase == LoopTransportState.overdubbing)
                  ? [BoxShadow(color: sc.color.withValues(alpha: 0.4), blurRadius: 6)] : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Status text
        Expanded(
          child: Text(
            parts.join(' \u00B7 '),
            style: AppFonts.spaceMono(fontSize: 10, fontWeight: FontWeight.w700, color: sc.color, letterSpacing: 0.3),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Beat dots (compact)
        if (isActive && layerCount > 0) ...[
          ...List.generate(_beatsPerBar.clamp(1, 8), (i) => Container(
            width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: i <= _beatInBar ? sc.color : sc.color.withValues(alpha: 0.15)),
          )),
          const SizedBox(width: 6),
        ],
        // BPM badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: AppColors.bgDeepest, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border)),
          child: Text('${ref.watch(bpmProvider)}', style: AppTheme.monoStyle(size: 10, weight: FontWeight.w700, color: AppColors.accent)),
        ),
        if (layerCount > 0) ...[
          const SizedBox(width: 4),
          Text('$layerCount', style: AppTheme.monoStyle(size: 9, color: AppColors.textMuted)),
          Icon(Icons.layers, size: 10, color: AppColors.textMuted),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  2. SEGMENTED VU METER ARC — 12 segments, green/yellow/red
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildVuMeterArc() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: SizedBox(
        height: 24,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _VuMeterArcPainter(
              level: _smoothedLevel.clamp(0.0, 1.0),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  3. COMPACT PROGRESS — circular ring (reduced to 100px)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCompactProgress(LoopTransportState phase, int layerCount, double posSec, double durSec) {
    final isFirstRec = phase == LoopTransportState.recording && layerCount == 0;
    final showRing = layerCount > 0 || isFirstRec;

    if (!showRing) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: 100, height: 100,
        child: isFirstRec ? _buildCompactRecordingTimer() : _buildCompactProgressRing(phase, posSec, durSec),
      ),
    );
  }

  Widget _buildCompactRecordingTimer() {
    return AnimatedBuilder(animation: _recPulse, builder: (_, __) => Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.danger.withValues(alpha: 0.04 + _recPulse.value * 0.04),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3 + _recPulse.value * 0.3), width: 2.5),
        boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: _recPulse.value * 0.2), blurRadius: 16, spreadRadius: 1)],
      ),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle,
          color: AppColors.danger.withValues(alpha: 0.5 + _recPulse.value * 0.5))),
        const SizedBox(height: 4),
        Text('REC', style: AppFonts.spaceMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
      ])),
    ));
  }

  Widget _buildCompactProgressRing(LoopTransportState phase, double posSec, double durSec) {
    final isActive = phase == LoopTransportState.playing || phase == LoopTransportState.recording || phase == LoopTransportState.overdubbing;
    final isRec = phase == LoopTransportState.recording;
    final isOverdub = phase == LoopTransportState.overdubbing;

    // State-based ring color: green first layer, orange overdub, cyan playback
    final Color ringColor;
    if (isRec) {
      ringColor = AppColors.accent2; // green for first layer
    } else if (isOverdub) {
      ringColor = AppColors.warm; // orange/amber for overdubbing
    } else if (phase == LoopTransportState.playing) {
      ringColor = AppColors.accent; // cyan during playback
    } else {
      ringColor = AppColors.textSecondary;
    }

    // Collect composite waveform from all layers
    List<double> compositeWaveform = [];
    if (_layers.isNotEmpty) {
      final sampleCount = 64;
      compositeWaveform = List<double>.filled(sampleCount, 0);
      for (final layer in _layers) {
        if (layer.waveform.isNotEmpty && !layer.muted) {
          for (int i = 0; i < sampleCount; i++) {
            final srcIdx = (i * layer.waveform.length / sampleCount).floor().clamp(0, layer.waveform.length - 1);
            compositeWaveform[i] = (compositeWaveform[i] + layer.waveform[srcIdx]).clamp(0.0, 1.0);
          }
        }
      }
    }

    // Time text style with red glow when recording
    final timeStyle = (isRec || isOverdub)
        ? AppTheme.lcdStyle(size: 16, weight: FontWeight.w800, color: AppColors.danger, glow: true, glowAlpha: 0.6)
        : AppTheme.monoStyle(size: 16, weight: FontWeight.w800, color: isActive ? ringColor : AppColors.textSecondary);

    return AnimatedBuilder(animation: _progressGlow, builder: (_, __) => RepaintBoundary(
      child: CustomPaint(
        painter: _WaveformRingPainter(
          progress: _loopPosition.clamp(0.0, 1.0),
          ringColor: ringColor,
          bgColor: AppColors.bgInset,
          borderColor: AppColors.border,
          glowIntensity: isActive ? _progressGlow.value * 0.3 : 0,
          isRecording: isRec || isOverdub,
          waveform: compositeWaveform,
        ),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_formatTime(posSec), style: timeStyle),
          Text(_formatTime(durSec), style: AppTheme.monoStyle(size: 9, color: AppColors.textMuted)),
        ])),
      ),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════
  //  4. COMPACT TRANSPORT — single tight row of 40x40 buttons
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCompactTransport(String lang, LoopTransportState phase, int layerCount, bool loopRecording, bool loopPlaying) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // REC / STOP REC
          _compactTransportBtn(
            icon: loopRecording ? Icons.stop_rounded : Icons.fiber_manual_record,
            color: AppColors.danger,
            isActive: loopRecording,
            glow: loopRecording,
            onTap: () => _handleRecord(),
            label: loopRecording ? 'STOP' : 'REC',
          ),
          const SizedBox(width: 8),
          // OVERDUB
          _compactTransportBtn(
            icon: Icons.fiber_manual_record,
            color: AppColors.accent3,
            isActive: phase == LoopTransportState.overdubbing,
            enabled: layerCount > 0 && !loopRecording,
            onTap: (layerCount > 0 && !loopRecording) ? () => _handleRecord() : null,
            label: 'OVD',
          ),
          const SizedBox(width: 8),
          // STOP
          _compactTransportBtn(
            icon: Icons.stop_rounded,
            color: AppColors.textSecondary,
            enabled: layerCount > 0 && (loopPlaying || loopRecording),
            onTap: (layerCount > 0 && (loopPlaying || loopRecording)) ? () => _handleStop() : null,
            label: 'STOP',
          ),
          const SizedBox(width: 8),
          // PLAY / PAUSE
          _compactTransportBtn(
            icon: loopPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: AppColors.accent2,
            isActive: loopPlaying,
            enabled: layerCount > 0 && !loopRecording,
            onTap: (layerCount > 0 && !loopRecording) ? () => _handlePlayPause() : null,
            label: loopPlaying ? 'PAUSE' : 'PLAY',
          ),
          const SizedBox(width: 8),
          // CLEAR
          _compactTransportBtn(
            icon: Icons.delete_sweep_rounded,
            color: AppColors.warning,
            enabled: layerCount > 0 && !loopRecording,
            onTap: (layerCount > 0 && !loopRecording) ? () => _handleClearConfirm(lang) : null,
            label: 'CLR',
          ),
        ],
      ),
    );
  }

  Widget _compactTransportBtn({
    required IconData icon, required Color color, String label = '',
    bool isActive = false, bool glow = false, bool enabled = true, VoidCallback? onTap,
  }) {
    final ec = enabled ? color : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? ec : ec.withValues(alpha: enabled ? 0.10 : 0.04),
            border: Border.all(color: ec.withValues(alpha: enabled ? 0.5 : 0.1), width: isActive ? 2 : 1),
            boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 14, spreadRadius: 2)] : null,
          ),
          child: Icon(icon, size: 18, color: isActive ? AppColors.bgDeepest : ec),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppFonts.outfit(fontSize: 8, fontWeight: FontWeight.w600,
          color: ec.withValues(alpha: enabled ? 0.7 : 0.3))),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  5. COMPACT LAYER LIST — 24px per layer, horizontal strips
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCompactLayerList(String lang, int layerCount, bool recording, bool playing) {
    if (layerCount == 0) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.mic_none_rounded, size: 28, color: AppColors.accent.withValues(alpha: 0.2)),
          const SizedBox(height: 6),
          Text(tr(lang, 'loopEmpty'), textAlign: TextAlign.center,
            style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF666666))),
          const SizedBox(height: 2),
          Text(tr(lang, 'connectMic'), textAlign: TextAlign.center,
            style: AppFonts.outfit(fontSize: 10, color: const Color(0xFF555555))),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mixer header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(children: [
              const Icon(Icons.tune_rounded, size: 11, color: Color(0xFF777777)),
              const SizedBox(width: 6),
              Text(tr(lang, 'mixer').toUpperCase(),
                style: AppFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700,
                  color: const Color(0xFF777777), letterSpacing: 1.2)),
              const Spacer(),
              _infoChip(Icons.layers_rounded, '$layerCount', AppColors.accent2),
            ]),
          ),
          Container(height: 0.5, color: const Color(0xFF3A3A3A)),
          // Layer strips — scrollable
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: layerCount,
              itemBuilder: (ctx, i) => _buildCompactLayerStrip(lang, i, layerCount, recording),
            ),
          ),
          // Linear progress bar at bottom of mixer
          if (layerCount > 0)
            _buildThinLinearProgress(playing),
        ],
      ),
    );
  }

  Widget _buildCompactLayerStrip(String lang, int index, int layerCount, bool recording) {
    final layer = index < _layers.length
        ? _layers[index]
        : LoopLayer(index: index, name: 'Layer ${index + 1}', createdAt: DateTime.now());
    final isLast = index == layerCount - 1;
    final isRecordingThis = recording && isLast;
    final color = _getLayerColor(index);
    final isPlaying = ref.watch(loopIsPlayingProvider);
    final isSelected = _selectedLayerIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedLayerIndex = _selectedLayerIndex == index ? -1 : index),
      onDoubleTap: () => _handleRenameLayer(index, layer.name),
      child: Container(
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color.withValues(alpha: 0.25) : Colors.transparent),
        ),
        child: Row(children: [
          // Color bar (thicker)
          Container(width: 3, margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: layer.muted ? AppColors.textMuted.withValues(alpha: 0.2) : color,
              borderRadius: BorderRadius.circular(2),
              boxShadow: (!layer.muted && isPlaying) ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)] : null,
            )),
          const SizedBox(width: 4),
          // LED-style mute/solo indicator dots
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mute LED
              Container(width: 5, height: 5,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: layer.muted ? AppColors.warning : AppColors.warning.withValues(alpha: 0.1),
                  boxShadow: layer.muted ? [BoxShadow(color: AppColors.warning.withValues(alpha: 0.5), blurRadius: 3)] : null)),
              const SizedBox(height: 2),
              // Solo LED
              Container(width: 5, height: 5,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: layer.solo ? AppColors.accent2 : AppColors.accent2.withValues(alpha: 0.1),
                  boxShadow: layer.solo ? [BoxShadow(color: AppColors.accent2.withValues(alpha: 0.5), blurRadius: 3)] : null)),
            ],
          ),
          const SizedBox(width: 4),
          // REC indicator
          if (isRecordingThis)
            AnimatedBuilder(animation: _recPulse, builder: (_, __) => Container(
              width: 6, height: 6, margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: AppColors.danger.withValues(alpha: 0.5 + _recPulse.value * 0.5),
                boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: _recPulse.value * 0.4), blurRadius: 4)]),
            )),
          // Name (monospace)
          SizedBox(
            width: 48,
            child: Text(layer.name,
              style: AppFonts.spaceMono(fontSize: 9, fontWeight: FontWeight.w500,
                color: layer.muted ? AppColors.textMuted : color.withValues(alpha: 0.85)),
              overflow: TextOverflow.ellipsis),
          ),
          // Mini waveform thumbnail
          Expanded(
            child: Container(
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: color.withValues(alpha: 0.06)),
              ),
              child: layer.waveform.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: WaveformPainter(
                            waveform: layer.waveform,
                            color: layer.muted ? AppColors.textMuted.withValues(alpha: 0.12) : color.withValues(alpha: 0.6),
                            progress: _loopPosition,
                            showProgress: isPlaying,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          ),
          // Volume mini-slider
          SizedBox(
            width: 56,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: layer.muted ? AppColors.textMuted : color,
                inactiveTrackColor: AppColors.bgInput,
                thumbColor: layer.muted ? AppColors.textMuted : color,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(value: layer.volume, min: 0, max: 1, onChanged: (v) {
                _updateLayer(index, layer.copyWith(volume: v));
                ref.read(audioServiceProvider).setLoopLayerVolume(index, v);
              }),
            ),
          ),
          // Mute button
          GestureDetector(
            onTap: () {
              _updateLayer(index, layer.copyWith(muted: !layer.muted));
              ref.read(audioServiceProvider).setLayerMute(index, !layer.muted);
            },
            child: Container(width: 20, height: 20,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
                color: layer.muted ? AppColors.warning.withValues(alpha: 0.15) : Colors.transparent,
                border: Border.all(color: layer.muted ? AppColors.warning.withValues(alpha: 0.5) : AppColors.border, width: 0.5)),
              child: Center(child: Text('M', style: AppFonts.spaceMono(fontSize: 8, fontWeight: FontWeight.w700,
                color: layer.muted ? AppColors.warning : AppColors.textMuted)))),
          ),
          const SizedBox(width: 2),
          // Solo button
          GestureDetector(
            onTap: () {
              _updateLayer(index, layer.copyWith(solo: !layer.solo));
              ref.read(audioServiceProvider).setLayerSolo(index, !layer.solo);
            },
            child: Container(width: 20, height: 20,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
                color: layer.solo ? AppColors.accent2.withValues(alpha: 0.15) : Colors.transparent,
                border: Border.all(color: layer.solo ? AppColors.accent2.withValues(alpha: 0.5) : AppColors.border, width: 0.5)),
              child: Center(child: Text('S', style: AppFonts.spaceMono(fontSize: 8, fontWeight: FontWeight.w700,
                color: layer.solo ? AppColors.accent2 : AppColors.textMuted)))),
          ),
          const SizedBox(width: 2),
          // Delete button
          if (!recording)
            GestureDetector(
              onTap: () => _handleDeleteLayerConfirm(lang, index),
              child: Icon(Icons.close, size: 14, color: AppColors.danger.withValues(alpha: 0.4)),
            ),
          const SizedBox(width: 4),
        ]),
      ),
    );
  }

  Widget _buildThinLinearProgress(bool playing) {
    if (!playing) return const SizedBox.shrink();
    final phase = _syncState();
    return Container(
      height: 3,
      margin: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(children: [
          Container(width: double.infinity, color: AppColors.bgInput),
          FractionallySizedBox(widthFactor: _loopPosition.clamp(0, 1), child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors:
              phase == LoopTransportState.recording || phase == LoopTransportState.overdubbing
                  ? [AppColors.danger, AppColors.accent3] : [AppColors.accent, AppColors.accent2])))),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  6. BOTTOM BAR — [Undo] [Export] [Guide] [MasterVol]
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(String lang, double masterVol, int layerCount, double durSec,
      bool monitoring, bool guideMuted, double guideVol, bool metPlaying) {
    final loopRecording = ref.read(loopIsRecordingProvider);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.bgDark,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(children: [
        // Undo
        _bottomBarBtn(Icons.undo_rounded, 'Undo', AppColors.accent,
          enabled: layerCount > 0 && !loopRecording,
          onTap: (layerCount > 0 && !loopRecording) ? () => _handleUndo() : null),
        const SizedBox(width: 4),
        // Export
        _bottomBarBtn(
          _isExporting ? Icons.hourglass_empty : Icons.download_rounded,
          tr(lang, 'exportWav').split(' ').first,
          AppColors.accent2,
          enabled: layerCount > 0 && !loopRecording && !_isExporting,
          onTap: (layerCount > 0 && !loopRecording && !_isExporting) ? () => _showExportSheet(lang, layerCount, durSec) : null,
        ),
        const SizedBox(width: 4),
        // Guide settings
        _bottomBarBtn(Icons.music_note_rounded, tr(lang, 'guideTrack').split(' ').first,
          (_drumsPlaying || metPlaying) ? AppColors.accent3 : AppColors.textMuted,
          onTap: () => _showGuideSheet(lang, monitoring, guideMuted, guideVol, metPlaying)),
        const SizedBox(width: 4),
        // Input monitoring toggle
        _bottomBarBtn(
          monitoring ? Icons.headset : Icons.headset_off,
          'Mon',
          monitoring ? AppColors.accent : AppColors.textMuted,
          onTap: () async {
            final audio = ref.read(audioServiceProvider);
            if (monitoring) {
              await audio.stopInputMonitoring(); await audio.stopInputLevelMeter();
              ref.read(inputMonitoringProvider.notifier).state = false;
            } else {
              await audio.resumeAudioContext(); await audio.startInputMonitoring();
              await audio.startInputLevelMeter((level) { if (mounted) setState(() => _inputLevel = level); });
              ref.read(inputMonitoringProvider.notifier).state = true;
            }
          },
        ),
        const Spacer(),
        // Master volume mini-slider
        Icon(Icons.volume_up_rounded, size: 14, color: AppColors.accent.withValues(alpha: 0.6)),
        SizedBox(
          width: 80,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.bgInput,
              thumbColor: AppColors.accent,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(value: masterVol, min: 0, max: 1, onChanged: (v) {
              ref.read(loopMasterVolumeProvider.notifier).state = v;
              ref.read(audioServiceProvider).setLoopMasterVolume(v);
            }),
          ),
        ),
        SizedBox(width: 24, child: Text('${(masterVol * 100).round()}%',
          style: AppTheme.monoStyle(size: 8, color: AppColors.accent), textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _bottomBarBtn(IconData icon, String label, Color color, {bool enabled = true, VoidCallback? onTap}) {
    final ec = enabled ? color : AppColors.textMuted.withValues(alpha: 0.4);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: ec.withValues(alpha: 0.06),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: ec),
          const SizedBox(width: 3),
          Text(label, style: AppFonts.outfit(fontSize: 9, fontWeight: FontWeight.w600, color: ec)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  GUIDE SETTINGS BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════════

  void _showGuideSheet(String lang, bool monitoring, bool guideMuted, double guideVol, bool metPlaying) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (ctx) => _GuideSettingsSheet(
        lang: lang,
        monitoring: monitoring,
        guideMuted: guideMuted,
        guideVol: guideVol,
        metPlaying: metPlaying,
        drumsPlaying: _drumsPlaying,
        guideConfig: _guideConfig,
        guideMetronomeExpanded: _guideMetronomeExpanded,
        guideDrumsExpanded: _guideDrumsExpanded,
        guidePrefsExpanded: _guidePrefsExpanded,
        ref: ref,
        recPulse: _recPulse,
        onTogglePlay: widget.onTogglePlay,
        onDrumsToggle: (playing) => setState(() => _drumsPlaying = playing),
        onGuideConfigChanged: (config) => setState(() => _guideConfig = config),
        onMetronomeExpandToggle: () => setState(() => _guideMetronomeExpanded = !_guideMetronomeExpanded),
        onDrumsExpandToggle: () => setState(() => _guideDrumsExpanded = !_guideDrumsExpanded),
        onPrefsExpandToggle: () => setState(() => _guidePrefsExpanded = !_guidePrefsExpanded),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  EXPORT BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════════

  void _showExportSheet(String lang, int layerCount, double durSec) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final isEs = lang == 'es'; final isPt = lang == 'pt';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text(isEs ? 'EXPORTAR LOOP' : isPt ? 'EXPORTAR LOOP' : 'EXPORT LOOP',
              style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1)),
            const SizedBox(height: 6),
            Row(children: [
              _infoChip(Icons.loop, '${durSec.toStringAsFixed(1)}s', AppColors.accent), const SizedBox(width: 8),
              _infoChip(Icons.layers, '$layerCount ${layerCount == 1 ? tr(lang, 'layer') : tr(lang, 'layers')}', AppColors.accent2),
            ]),
            const SizedBox(height: 12),
            Text(isEs ? 'MODO' : isPt ? 'MODO' : 'MODE',
              style: AppFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _exportModeChip(ExportMode.fullMix, isEs ? 'Mezcla final' : isPt ? 'Mixagem final' : 'Full Mix', Icons.merge_type),
              _exportModeChip(ExportMode.fullMixWithGuide, isEs ? 'Mezcla + Guia' : isPt ? 'Mixagem + Guia' : 'Mix + Guide', Icons.music_note),
              _exportModeChip(ExportMode.stems, 'Stems', Icons.view_list),
            ]),
            const SizedBox(height: 8),
            if (_exportMode == ExportMode.fullMixWithGuide)
              Text(isEs ? 'Incluira metronomo/bateria en la exportacion' : isPt ? 'Incluira metronomo/bateria na exportacao' : 'Will include metronome/drums in export',
                style: AppFonts.outfit(fontSize: 10, color: AppColors.accent2.withValues(alpha: 0.7))),
            if (_exportMode == ExportMode.stems)
              Text(isEs ? 'Cada capa se exportara como archivo individual' : isPt ? 'Cada camada sera exportada individualmente' : 'Each layer will be exported individually',
                style: AppFonts.outfit(fontSize: 10, color: AppColors.accent.withValues(alpha: 0.7))),
            Text(isEs ? 'La exportacion respeta Mute y Solo de cada capa' : isPt ? 'A exportacao respeita Mute e Solo de cada camada' : 'Export respects each layer\'s Mute and Solo settings',
              style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted.withValues(alpha: 0.6))),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () { Navigator.pop(ctx); _handleExport(); },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent2])),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.download_rounded, size: 18, color: AppColors.bgDeepest), const SizedBox(width: 8),
                  Text(_exportMode == ExportMode.stems
                      ? (isEs ? 'Exportar Stems' : isPt ? 'Exportar Stems' : 'Export Stems')
                      : tr(lang, 'exportWav'),
                    style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.bgDeepest)),
                ])),
            ),
          ]),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  COUNT-IN OVERLAY
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCountInOverlay() {
    return Container(color: AppColors.bgDeepest.withValues(alpha: 0.9), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('COUNT IN', style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 2)),
      const SizedBox(height: 20),
      AnimatedBuilder(animation: _countInAnim, builder: (_, __) => Transform.scale(scale: 1.0 + _countInAnim.value * 0.3,
        child: Text('${_countInBeatsLeft > 0 ? _countInBeatsLeft : "GO!"}',
          style: AppFonts.jetBrainsMono(fontSize: 72, fontWeight: FontWeight.w800,
            color: AppColors.accent.withValues(alpha: 1.0 - _countInAnim.value * 0.5))))),
    ])));
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ACTION HANDLERS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _handleRecord() async {
    final audio = ref.read(audioServiceProvider);
    final loopRecording = ref.read(loopIsRecordingProvider);

    if (loopRecording) {
      final result = await audio.stopLoopRecording();
      final success = result['success'] == true;
      if (success) {
        final count = (result['layerCount'] as int?) ?? 0;
        final dur = (result['duration'] as double?) ?? 0.0;
        ref.read(loopLayerCountProvider.notifier).state = count;
        ref.read(loopDurationProvider.notifier).state = Duration(milliseconds: (dur * 1000).round());
        ref.read(loopIsPlayingProvider.notifier).state = true;
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) setState(() {
          _layers = List.generate(count, (i) {
            if (i < _layers.length && i != count - 1) return _layers[i];
            return LoopLayer(index: i, name: i < _layers.length ? _layers[i].name : 'Layer ${i + 1}',
              volume: i < _layers.length ? _layers[i].volume : 1.0, pan: i < _layers.length ? _layers[i].pan : 0.0,
              muted: i < _layers.length ? _layers[i].muted : false, solo: i < _layers.length ? _layers[i].solo : false,
              waveform: audio.getLayerWaveform(i, 80), createdAt: DateTime.now());
          });
        });
      }
      ref.read(loopIsRecordingProvider.notifier).state = false;
      _sm.forceState(LoopTransportState.playing);
    } else {
      await audio.resumeAudioContext();
      final layerCount = ref.read(loopLayerCountProvider);
      final isOverdub = layerCount > 0;
      if (isOverdub) {
        try {
          final devices = await audio.checkAudioOutputDevices();
          if (devices['hasHeadphones'] != true && mounted) {
            final lang = ref.read(langProvider);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(lang == 'es' ? 'Usa auriculares para evitar feedback en overdub'
                  : lang == 'pt' ? 'Use fones de ouvido para evitar feedback no overdub'
                  : 'Use headphones to avoid feedback during overdub',
                style: AppFonts.outfit(color: Colors.white)),
              backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)));
          }
        } catch (_) {}
      }
      // Auto-start guide if configured
      if (_guideConfig.autoStartOnRecord && !ref.read(playingProvider) && !_drumsPlaying) {
        widget.onTogglePlay();
      }
      final result = await audio.startLoopRecording();
      if (result == 'recording' || result == 'overdubbing') {
        ref.read(loopIsRecordingProvider.notifier).state = true;
        _sm.forceState(isOverdub ? LoopTransportState.overdubbing : LoopTransportState.recording);
        if (isOverdub) ref.read(loopIsPlayingProvider.notifier).state = true;
      } else if (result == 'permission_denied' && mounted) {
        final lang = ref.read(langProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang == 'es' ? 'Permiso de microfono denegado' : lang == 'pt' ? 'Permissao de microfone negada' : 'Microphone permission denied',
            style: AppFonts.outfit(color: Colors.white)), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating));
      } else if (result == 'no_microphone' && mounted) {
        final lang = ref.read(langProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang == 'es' ? 'No se encontro microfono' : lang == 'pt' ? 'Nenhum microfone encontrado' : 'No microphone found',
            style: AppFonts.outfit(color: Colors.white)), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _handlePlayPause() async {
    final audio = ref.read(audioServiceProvider);
    final playing = ref.read(loopIsPlayingProvider);
    if (playing) {
      await audio.stopLoopPlayback();
      ref.read(loopIsPlayingProvider.notifier).state = false;
      _sm.forceState(LoopTransportState.paused);
      // Keep guide if configured
      if (!_guideConfig.keepAfterStop) {
        if (ref.read(playingProvider)) { widget.onTogglePlay(); }
        if (_drumsPlaying) { await audio.stopDrumPattern(); setState(() => _drumsPlaying = false); }
      }
    } else {
      await audio.startLoopPlayback();
      ref.read(loopIsPlayingProvider.notifier).state = true;
      _sm.forceState(LoopTransportState.playing);
      // Auto-start guide if configured
      if (_guideConfig.autoStartOnPlay && !ref.read(playingProvider) && !_drumsPlaying) {
        widget.onTogglePlay();
      }
    }
  }

  Future<void> _handleStop() async {
    final audio = ref.read(audioServiceProvider);
    final loopRecording = ref.read(loopIsRecordingProvider);
    if (loopRecording) {
      final result = await audio.stopLoopRecording();
      if (result['success'] == true) {
        final count = (result['layerCount'] as int?) ?? 0;
        final dur = (result['duration'] as double?) ?? 0.0;
        ref.read(loopLayerCountProvider.notifier).state = count;
        ref.read(loopDurationProvider.notifier).state = Duration(milliseconds: (dur * 1000).round());
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) setState(() {
          _layers = List.generate(count, (i) {
            if (i < _layers.length && i != count - 1) return _layers[i];
            return LoopLayer(index: i, name: i < _layers.length ? _layers[i].name : 'Layer ${i + 1}',
              waveform: audio.getLayerWaveform(i, 80), createdAt: DateTime.now());
          });
        });
      }
      ref.read(loopIsRecordingProvider.notifier).state = false;
    }
    await audio.stopLoopPlayback();
    ref.read(loopIsPlayingProvider.notifier).state = false;
    _sm.forceState(LoopTransportState.stopped);
    if (!_guideConfig.keepAfterStop) {
      if (ref.read(playingProvider)) widget.onTogglePlay();
      if (_drumsPlaying) { await audio.stopDrumPattern(); setState(() => _drumsPlaying = false); }
    }
  }

  Future<void> _handleUndo() async {
    final audio = ref.read(audioServiceProvider);
    await audio.undoLoopLayer();
    final state = audio.getLoopState();
    final count = (state['layerCount'] as int?) ?? 0;
    ref.read(loopLayerCountProvider.notifier).state = count;
    setState(() {
      if (_layers.length > count) _layers = _layers.sublist(0, count);
      if (_selectedLayerIndex >= count) _selectedLayerIndex = -1;
    });
    if (count == 0) {
      ref.read(loopIsPlayingProvider.notifier).state = false;
      ref.read(loopDurationProvider.notifier).state = Duration.zero;
      _sm.forceState(LoopTransportState.idle);
    }
  }

  Future<void> _handleClearConfirm(String lang) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text(tr(lang, 'clearAll'), style: AppFonts.outfit(color: AppColors.textPrimary)),
      content: Text(lang == 'es' ? 'Se borraran todas las capas grabadas.' : lang == 'pt' ? 'Todas as camadas gravadas serao apagadas.' : 'All recorded layers will be deleted.',
        style: AppFonts.outfit(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: Text(lang == 'es' ? 'Cancelar' : lang == 'pt' ? 'Cancelar' : 'Cancel', style: AppFonts.outfit(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr(lang, 'clearAll'), style: AppFonts.outfit(color: AppColors.danger, fontWeight: FontWeight.w700))),
      ]));
    if (confirmed == true) await _handleClear();
  }

  Future<void> _handleClear() async {
    final audio = ref.read(audioServiceProvider);
    await audio.stopLoopPlayback(); await audio.clearLoop();
    ref.read(loopLayerCountProvider.notifier).state = 0;
    ref.read(loopIsPlayingProvider.notifier).state = false;
    ref.read(loopIsRecordingProvider.notifier).state = false;
    ref.read(loopDurationProvider.notifier).state = Duration.zero;
    setState(() { _layers.clear(); _selectedLayerIndex = -1; });
    _sm.forceState(LoopTransportState.idle);
  }

  Future<void> _handleDeleteLayerConfirm(String lang, int index) async {
    final name = index < _layers.length ? _layers[index].name : 'Layer ${index + 1}';
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text(lang == 'es' ? 'Eliminar $name?' : lang == 'pt' ? 'Excluir $name?' : 'Delete $name?',
        style: AppFonts.outfit(color: AppColors.textPrimary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: Text(lang == 'es' ? 'Cancelar' : lang == 'pt' ? 'Cancelar' : 'Cancel', style: AppFonts.outfit(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: Text(lang == 'es' ? 'Eliminar' : lang == 'pt' ? 'Excluir' : 'Delete',
            style: AppFonts.outfit(color: AppColors.danger, fontWeight: FontWeight.w700))),
      ]));
    if (confirmed == true) await _handleDeleteLayer(index);
  }

  Future<void> _handleDeleteLayer(int index) async {
    final audio = ref.read(audioServiceProvider);
    await audio.deleteLoopLayer(index);
    final state = audio.getLoopState();
    final count = (state['layerCount'] as int?) ?? 0;
    ref.read(loopLayerCountProvider.notifier).state = count;
    setState(() {
      _layers.clear();
      for (int i = 0; i < count; i++) _layers.add(LoopLayer(index: i, name: 'Layer ${i + 1}', waveform: audio.getLayerWaveform(i, 80), createdAt: DateTime.now()));
      if (_selectedLayerIndex >= count) _selectedLayerIndex = -1;
    });
    if (count == 0) {
      ref.read(loopIsPlayingProvider.notifier).state = false;
      ref.read(loopDurationProvider.notifier).state = Duration.zero;
      _sm.forceState(LoopTransportState.idle);
    }
  }

  Future<void> _handleRenameLayer(int index, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final lang = ref.read(langProvider);
    final newName = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text(lang == 'es' ? 'Renombrar capa' : lang == 'pt' ? 'Renomear camada' : 'Rename Layer',
        style: AppFonts.outfit(color: AppColors.textPrimary)),
      content: TextField(controller: controller, autofocus: true,
        style: AppFonts.outfit(color: AppColors.textPrimary),
        decoration: InputDecoration(filled: true, fillColor: AppColors.bgInput,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border))),
        onSubmitted: (v) => Navigator.pop(ctx, v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text(lang == 'es' ? 'Cancelar' : lang == 'pt' ? 'Cancelar' : 'Cancel', style: AppFonts.outfit(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text('OK', style: AppFonts.outfit(color: AppColors.accent, fontWeight: FontWeight.w700))),
      ]));
    if (newName != null && newName.isNotEmpty && index < _layers.length) {
      _updateLayer(index, _layers[index].copyWith(name: newName));
      ref.read(audioServiceProvider).renameLoopLayer(index, newName);
    }
    controller.dispose();
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    _sm.forceState(LoopTransportState.exporting);
    try {
      final audio = ref.read(audioServiceProvider);
      if (_exportMode == ExportMode.stems) {
        final stems = await audio.exportStems();
        for (final stem in stems) {
          final url = stem['url'] as String? ?? '';
          final name = stem['name'] as String? ?? 'stem';
          if (url.isNotEmpty) _triggerDownload(url, 'groovelab-$name.wav');
        }
      } else {
        final includeGuide = _exportMode == ExportMode.fullMixWithGuide;
        final url = await audio.exportLoopMixdown('wav', includeGuide: includeGuide);
        if (url.isNotEmpty) _triggerDownload(url, 'groovelab-loop.wav');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
      _sm.forceState(LoopTransportState.stopped);
    }
  }

  void _triggerDownload(String url, [String filename = 'groovelab-loop.wav']) {
    triggerWebDownload(url, filename);
  }

  void _updateLayer(int index, LoopLayer updated) {
    setState(() { if (index < _layers.length) _layers[index] = updated; });
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════

  // ignore: unused_element
  SliderThemeData _sliderTheme(Color color) =>
      AppTheme.neumorphicSliderTheme(color, grooveHeight: 5, thumbRadius: 9);

  String _formatTime(double seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds.toInt() % 60).toString().padLeft(2, '0');
    final ms = ((seconds * 10).toInt() % 10).toString();
    return '$min:$sec.$ms';
  }

  Color _getLayerColor(int index) {
    const colors = [
      AppColors.accent,        // cyan
      AppColors.accent2,       // green
      AppColors.warm,          // orange
      Color(0xFF8B5CF6),       // purple
      Color(0xFF3B82F6),       // blue
      Color(0xFFEC4899),       // pink
    ];
    return colors[index % colors.length];
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color), const SizedBox(width: 4),
        Text(text, style: AppTheme.monoStyle(size: 10, weight: FontWeight.w600, color: color)),
      ]));
  }

  Widget _exportModeChip(ExportMode mode, String label, IconData icon) {
    final active = _exportMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _exportMode = mode),
      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
          color: active ? AppColors.accent.withValues(alpha: 0.14) : AppColors.bgInput,
          border: Border.all(color: active ? AppColors.accent.withValues(alpha: 0.6) : AppColors.border, width: active ? 1.5 : 1),
          boxShadow: active ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: -2)] : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: AppFonts.outfit(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active ? AppColors.accent : AppColors.textMuted)),
        ])),
    );
  }

  _PhaseConfig _getPhaseConfig(LoopTransportState phase, String lang) {
    return switch (phase) {
      LoopTransportState.idle => _PhaseConfig(
        label: lang == 'es' ? 'LISTO PARA GRABAR' : lang == 'pt' ? 'PRONTO PARA GRAVAR' : 'READY TO RECORD', color: AppColors.textMuted),
      LoopTransportState.armed => _PhaseConfig(
        label: lang == 'es' ? 'ARMADO' : lang == 'pt' ? 'ARMADO' : 'ARMED', color: AppColors.warning),
      LoopTransportState.countIn => _PhaseConfig(label: 'COUNT-IN', color: AppColors.warning),
      LoopTransportState.recording => _PhaseConfig(
        label: lang == 'es' ? 'GRABANDO' : lang == 'pt' ? 'GRAVANDO' : 'RECORDING', color: AppColors.danger),
      LoopTransportState.closingLoop => _PhaseConfig(
        label: lang == 'es' ? 'CERRANDO LOOP' : lang == 'pt' ? 'FECHANDO LOOP' : 'CLOSING LOOP', color: AppColors.accent3),
      LoopTransportState.playing => _PhaseConfig(
        label: lang == 'es' ? 'REPRODUCIENDO' : lang == 'pt' ? 'REPRODUZINDO' : 'PLAYING', color: AppColors.accent2),
      LoopTransportState.overdubbing => _PhaseConfig(
        label: 'OVERDUB', color: AppColors.accent3),
      LoopTransportState.paused => _PhaseConfig(
        label: lang == 'es' ? 'PAUSADO' : lang == 'pt' ? 'PAUSADO' : 'PAUSED', color: AppColors.warning),
      LoopTransportState.stopped => _PhaseConfig(
        label: lang == 'es' ? 'DETENIDO' : lang == 'pt' ? 'PARADO' : 'STOPPED', color: AppColors.textSecondary),
      LoopTransportState.exporting => _PhaseConfig(
        label: lang == 'es' ? 'EXPORTANDO' : lang == 'pt' ? 'EXPORTANDO' : 'EXPORTING', color: AppColors.accent),
    };
  }
}

class _PhaseConfig {
  final String label;
  final Color color;
  const _PhaseConfig({required this.label, required this.color});
}

// ═══════════════════════════════════════════════════════════════════
//  CIRCULAR WAVEFORM RING PAINTER — annular arc with waveform modulation
// ═══════════════════════════════════════════════════════════════════

class _WaveformRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color bgColor;
  final Color borderColor;
  final double glowIntensity;
  final bool isRecording;
  final List<double> waveform;

  _WaveformRingPainter({
    required this.progress,
    required this.ringColor,
    required this.bgColor,
    required this.borderColor,
    this.glowIntensity = 0,
    this.isRecording = false,
    this.waveform = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const baseStroke = 6.0;
    const maxWaveStroke = 10.0;

    // Background ring with subtle border
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = maxWaveStroke + 2;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawCircle(center, radius - maxWaveStroke / 2 - 1, borderPaint);
    canvas.drawCircle(center, radius + maxWaveStroke / 2 + 1, borderPaint);

    // Draw waveform-modulated ring (full circle, dimmed after playhead)
    if (waveform.isNotEmpty) {
      final sampleCount = waveform.length;
      for (int i = 0; i < sampleCount; i++) {
        final frac = i / sampleCount;
        final angle = -math.pi / 2 + frac * 2 * math.pi;
        final nextAngle = -math.pi / 2 + (i + 1) / sampleCount * 2 * math.pi;
        final amp = waveform[i].clamp(0.0, 1.0);
        final strokeW = baseStroke + amp * (maxWaveStroke - baseStroke);

        final isBeforePlayhead = frac <= progress;
        final paint = Paint()
          ..color = isBeforePlayhead
              ? ringColor.withValues(alpha: 0.7 + amp * 0.3)
              : ringColor.withValues(alpha: 0.08 + amp * 0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          angle,
          nextAngle - angle + 0.02,
          false,
          paint,
        );
      }
    } else {
      // Simple progress arc when no waveform data
      final dimPaint = Paint()
        ..color = ringColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseStroke;
      canvas.drawCircle(center, radius, dimPaint);

      if (progress > 0) {
        final progressPaint = Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseStroke
          ..strokeCap = StrokeCap.round;

        // Glow pass
        if (glowIntensity > 0) {
          final glowPaint = Paint()
            ..color = ringColor.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = baseStroke + 2
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowIntensity * 6);
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            -math.pi / 2,
            progress * 2 * math.pi,
            false,
            glowPaint,
          );
        }

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          progress * 2 * math.pi,
          false,
          progressPaint,
        );
      }
    }

    // Playhead dot
    if (progress > 0) {
      final angle = -math.pi / 2 + progress * 2 * math.pi;
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);

      // Glow behind dot
      canvas.drawCircle(
        Offset(dotX, dotY), 6,
        Paint()..color = ringColor.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Solid dot
      canvas.drawCircle(
        Offset(dotX, dotY), 4,
        Paint()..color = ringColor..style = PaintingStyle.fill,
      );
      // White center
      canvas.drawCircle(
        Offset(dotX, dotY), 1.5,
        Paint()..color = const Color(0xFFFFFFFF)..style = PaintingStyle.fill,
      );
    }

    // Recording indicator dot at top
    if (isRecording) {
      canvas.drawCircle(
        Offset(center.dx, center.dy - radius - 12), 3,
        Paint()..color = const Color(0xFFFF3B30)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(
        Offset(center.dx, center.dy - radius - 12), 2.5,
        Paint()..color = const Color(0xFFFF3B30),
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformRingPainter old) =>
      old.progress != progress || old.ringColor != ringColor ||
      old.glowIntensity != glowIntensity || old.isRecording != isRecording ||
      old.waveform != waveform;
}

// ═══════════════════════════════════════════════════════════════════
//  SEGMENTED VU METER ARC PAINTER — 12 segments, green/yellow/red
// ═══════════════════════════════════════════════════════════════════

class _VuMeterArcPainter extends CustomPainter {
  final double level;
  static const int segmentCount = 12;

  _VuMeterArcPainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 2);
    final radius = size.height + 2;
    const startAngle = math.pi + 0.3; // slight inset from edges
    const sweepAngle = math.pi - 0.6;
    const segmentGap = 0.03;
    const segmentSweep = (sweepAngle - segmentGap * (segmentCount - 1)) / segmentCount;
    const strokeWidth = 4.0;

    for (int i = 0; i < segmentCount; i++) {
      final frac = (i + 1) / segmentCount;
      final angle = startAngle + i * (segmentSweep + segmentGap);
      final isLit = frac <= level;

      Color segColor;
      if (frac <= 0.6) {
        segColor = AppColors.accent2; // green
      } else if (frac <= 0.8) {
        segColor = AppColors.warning; // yellow/amber
      } else {
        segColor = AppColors.danger; // red
      }

      final paint = Paint()
        ..color = isLit ? segColor : segColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Glow for lit segments
      if (isLit && frac > 0.6) {
        final glowPaint = Paint()
          ..color = segColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          angle, segmentSweep, false, glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle, segmentSweep, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VuMeterArcPainter old) => old.level != level;
}

// ═══════════════════════════════════════════════════════════════════
//  GUIDE SETTINGS BOTTOM SHEET — full guide controls in a modal
// ═══════════════════════════════════════════════════════════════════

class _GuideSettingsSheet extends StatefulWidget {
  final String lang;
  final bool monitoring;
  final bool guideMuted;
  final double guideVol;
  final bool metPlaying;
  final bool drumsPlaying;
  final GuideTrackConfig guideConfig;
  final bool guideMetronomeExpanded;
  final bool guideDrumsExpanded;
  final bool guidePrefsExpanded;
  final WidgetRef ref;
  final AnimationController recPulse;
  final VoidCallback onTogglePlay;
  final ValueChanged<bool> onDrumsToggle;
  final ValueChanged<GuideTrackConfig> onGuideConfigChanged;
  final VoidCallback onMetronomeExpandToggle;
  final VoidCallback onDrumsExpandToggle;
  final VoidCallback onPrefsExpandToggle;

  const _GuideSettingsSheet({
    required this.lang,
    required this.monitoring,
    required this.guideMuted,
    required this.guideVol,
    required this.metPlaying,
    required this.drumsPlaying,
    required this.guideConfig,
    required this.guideMetronomeExpanded,
    required this.guideDrumsExpanded,
    required this.guidePrefsExpanded,
    required this.ref,
    required this.recPulse,
    required this.onTogglePlay,
    required this.onDrumsToggle,
    required this.onGuideConfigChanged,
    required this.onMetronomeExpandToggle,
    required this.onDrumsExpandToggle,
    required this.onPrefsExpandToggle,
  });

  @override
  State<_GuideSettingsSheet> createState() => _GuideSettingsSheetState();
}

class _GuideSettingsSheetState extends State<_GuideSettingsSheet> {
  late bool _drumsPlaying;
  late bool _metExpanded;
  late bool _drumsExpanded;
  late bool _prefsExpanded;
  late GuideTrackConfig _guideConfig;

  @override
  void initState() {
    super.initState();
    _drumsPlaying = widget.drumsPlaying;
    _metExpanded = widget.guideMetronomeExpanded;
    _drumsExpanded = widget.guideDrumsExpanded;
    _prefsExpanded = widget.guidePrefsExpanded;
    _guideConfig = widget.guideConfig;
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final ref = widget.ref;
    final guideMuted = ref.read(guideMutedProvider);
    final guideVol = ref.read(guideVolumeProvider);
    final metPlaying = ref.read(playingProvider);
    final guideActive = metPlaying || _drumsPlaying;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          // Title
          Row(children: [
            Icon(Icons.music_note_rounded, size: 16, color: guideActive ? (_drumsPlaying ? AppColors.accent3 : AppColors.accent2) : AppColors.textMuted),
            const SizedBox(width: 8),
            Text(tr(lang, 'guideTrack').toUpperCase(),
              style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1.5)),
            const Spacer(),
            if (guideActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: (_drumsPlaying ? AppColors.accent3 : AppColors.accent2).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: _drumsPlaying ? AppColors.accent3 : AppColors.accent2, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(_drumsPlaying ? ref.read(drumStyleProvider) : tr(lang, 'metronomeGuide'),
                    style: AppFonts.outfit(fontSize: 9, fontWeight: FontWeight.w600, color: _drumsPlaying ? AppColors.accent3 : AppColors.accent2)),
                ]),
              ),
          ]),
          const SizedBox(height: 12),

          // BPM control
          _buildBpmControl(ref, guideActive),
          const SizedBox(height: 10),

          // Guide volume
          _buildGuideVolume(lang, ref, guideMuted, guideVol),
          const SizedBox(height: 10),

          // Count-in selector
          _buildCountInSelector(lang, ref),
          const SizedBox(height: 10),

          // Guide preferences
          _buildGuidePreferences(lang),
          const SizedBox(height: 10),

          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),

          // Metronome guide row
          _buildMetronomeGuideRow(lang, ref, metPlaying),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),

          // Drums guide row
          _buildDrumsGuideRow(lang, ref),
        ]),
      ),
    );
  }

  Widget _buildBpmControl(WidgetRef ref, bool guideActive) {
    final bpm = ref.read(bpmProvider);
    return Row(children: [
      _bpmAdjustBtn(ref, Icons.remove, -1, -10, guideActive), const SizedBox(width: 6),
      Expanded(child: SliderTheme(
        data: AppTheme.neumorphicSliderTheme(AppColors.accent, grooveHeight: 6, thumbRadius: 10),
        child: Slider(value: bpm.toDouble(), min: 20, max: 300, onChanged: (v) {
          final n = v.round(); ref.read(bpmProvider.notifier).state = n;
          if (guideActive) ref.read(audioServiceProvider).updateBpm(n);
        }),
      )),
      const SizedBox(width: 6), _bpmAdjustBtn(ref, Icons.add, 1, 10, guideActive), const SizedBox(width: 8),
      Container(width: 52, padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: AppColors.bgDeepest, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
        child: Text('$bpm', textAlign: TextAlign.center, style: AppTheme.monoStyle(size: 16, weight: FontWeight.w800, color: AppColors.accent))),
    ]);
  }

  Widget _bpmAdjustBtn(WidgetRef ref, IconData icon, int tap, int longPress, bool guideActive) {
    final bpm = ref.read(bpmProvider);
    return GestureDetector(
      onTap: () { final n = (bpm + tap).clamp(20, 300); ref.read(bpmProvider.notifier).state = n; if (guideActive) ref.read(audioServiceProvider).updateBpm(n); setState(() {}); },
      onLongPress: () { final n = (bpm + longPress).clamp(20, 300); ref.read(bpmProvider.notifier).state = n; if (guideActive) ref.read(audioServiceProvider).updateBpm(n); setState(() {}); },
      child: Container(width: 36, height: 36,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.bgElevated, border: Border.all(color: AppColors.border)),
        child: Icon(icon, size: 18, color: AppColors.textSecondary)),
    );
  }

  Widget _buildGuideVolume(String lang, WidgetRef ref, bool guideMuted, double guideVol) {
    return Row(children: [
      GestureDetector(
        onTap: () { final m = !guideMuted; ref.read(guideMutedProvider.notifier).state = m; ref.read(audioServiceProvider).muteGuide(m); setState(() {}); },
        child: Container(width: 36, height: 36,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
            color: guideMuted ? AppColors.warning.withValues(alpha: 0.1) : AppColors.bgInput,
            border: Border.all(color: guideMuted ? AppColors.warning.withValues(alpha: 0.5) : AppColors.border)),
          child: Icon(guideMuted ? Icons.volume_off : Icons.volume_up, size: 18,
            color: guideMuted ? AppColors.warning : AppColors.textSecondary)),
      ),
      const SizedBox(width: 8),
      Expanded(child: SliderTheme(
        data: AppTheme.neumorphicSliderTheme(guideMuted ? AppColors.textMuted : AppColors.accent, grooveHeight: 6, thumbRadius: 9),
        child: Slider(value: guideVol, min: 0, max: 1, onChanged: guideMuted ? null : (v) {
          ref.read(guideVolumeProvider.notifier).state = v; ref.read(audioServiceProvider).setGuideVolume(v); setState(() {});
        }),
      )),
      SizedBox(width: 34, child: Text('${(guideVol * 100).round()}%',
        style: AppTheme.monoStyle(size: 10, weight: FontWeight.w600, color: guideMuted ? AppColors.textMuted.withValues(alpha: 0.4) : AppColors.accent), textAlign: TextAlign.right)),
    ]);
  }

  Widget _buildCountInSelector(String lang, WidgetRef ref) {
    final countIn = ref.read(countInBarsProvider);
    return Row(children: [
      Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted), const SizedBox(width: 6),
      Text('Count-in', style: AppFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
      const SizedBox(width: 10),
      ...[0, 1, 2, 4].map((v) {
        final active = countIn == v; final label = v == 0 ? 'OFF' : '$v bar${v > 1 ? 's' : ''}';
        return Padding(padding: const EdgeInsets.only(right: 4), child: GestureDetector(
          onTap: () { ref.read(countInBarsProvider.notifier).state = v; ref.read(audioServiceProvider).updateCountIn(v); setState(() {}); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              color: active ? AppColors.accent.withValues(alpha: 0.12) : AppColors.bgInput,
              border: Border.all(color: active ? AppColors.accent : AppColors.border)),
            child: Text(label, style: AppFonts.outfit(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.accent : AppColors.textMuted))),
        ));
      }),
    ]);
  }

  Widget _buildGuidePreferences(String lang) {
    final isEs = lang == 'es'; final isPt = lang == 'pt';
    return Column(children: [
      GestureDetector(
        onTap: () { setState(() => _prefsExpanded = !_prefsExpanded); widget.onPrefsExpandToggle(); },
        child: Row(children: [
          Icon(Icons.settings, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(isEs ? 'Preferencias de guia' : isPt ? 'Preferencias do guia' : 'Guide Preferences',
            style: AppFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const Spacer(),
          Icon(_prefsExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.textMuted),
        ]),
      ),
      if (_prefsExpanded) ...[
        const SizedBox(height: 8),
        _guidePrefToggle(
          isEs ? 'Auto-iniciar guia al grabar' : isPt ? 'Auto-iniciar guia ao gravar' : 'Auto-start guide on record',
          _guideConfig.autoStartOnRecord,
          (v) { setState(() => _guideConfig = _guideConfig.copyWith(autoStartOnRecord: v)); widget.onGuideConfigChanged(_guideConfig); },
        ),
        _guidePrefToggle(
          isEs ? 'Auto-iniciar guia al reproducir' : isPt ? 'Auto-iniciar guia ao reproduzir' : 'Auto-start guide on play',
          _guideConfig.autoStartOnPlay,
          (v) { setState(() => _guideConfig = _guideConfig.copyWith(autoStartOnPlay: v)); widget.onGuideConfigChanged(_guideConfig); },
        ),
        _guidePrefToggle(
          isEs ? 'Mantener guia despues de stop' : isPt ? 'Manter guia apos stop' : 'Keep guide after stop',
          _guideConfig.keepAfterStop,
          (v) { setState(() => _guideConfig = _guideConfig.copyWith(keepAfterStop: v)); widget.onGuideConfigChanged(_guideConfig); },
        ),
        const SizedBox(height: 4),
        Row(children: [
          Text(isEs ? 'Reinicio:' : isPt ? 'Reinicio:' : 'Restart:', style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          ...[GuideRestartMode.followLoop, GuideRestartMode.restartFromBar1].map((mode) {
            final active = _guideConfig.restartMode == mode;
            final label = mode == GuideRestartMode.followLoop
                ? (isEs ? 'Seguir loop' : isPt ? 'Seguir loop' : 'Follow loop')
                : (isEs ? 'Desde compas 1' : isPt ? 'Do compasso 1' : 'From bar 1');
            return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
              onTap: () { setState(() => _guideConfig = _guideConfig.copyWith(restartMode: mode)); widget.onGuideConfigChanged(_guideConfig); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                  color: active ? AppColors.accent.withValues(alpha: 0.12) : AppColors.bgInput,
                  border: Border.all(color: active ? AppColors.accent : AppColors.border)),
                child: Text(label, style: AppFonts.outfit(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? AppColors.accent : AppColors.textMuted)),
              ),
            ));
          }),
        ]),
      ],
    ]);
  }

  Widget _guidePrefToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(children: [
        Container(width: 16, height: 16,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
            border: Border.all(color: value ? AppColors.accent2 : AppColors.borderLight),
            color: value ? AppColors.accent2.withValues(alpha: 0.15) : Colors.transparent),
          child: value ? Icon(Icons.check, size: 10, color: AppColors.accent2) : null),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppFonts.outfit(fontSize: 10, color: AppColors.textSecondary))),
      ]),
    ));
  }

  Widget _buildMetronomeGuideRow(String lang, WidgetRef ref, bool metPlaying) {
    final clickSound = ref.read(clickSoundProvider);
    final subdivision = ref.read(subdivisionProvider);
    final timeSig = ref.read(timeSigProvider);
    return Column(children: [
      Row(children: [
        Icon(Icons.timer, size: 16, color: AppColors.accent), const SizedBox(width: 8),
        Text(tr(lang, 'metronomeGuide'), style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const Spacer(),
        GestureDetector(onTap: () { setState(() => _metExpanded = !_metExpanded); widget.onMetronomeExpandToggle(); },
          child: Container(padding: const EdgeInsets.all(4),
            child: Icon(_metExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.textMuted))),
        const SizedBox(width: 8),
        _guidePlayButton(playing: metPlaying, color: AppColors.accent2, onTap: () {
          if (_drumsPlaying) { ref.read(audioServiceProvider).stopDrumPattern(); setState(() => _drumsPlaying = false); widget.onDrumsToggle(false); }
          widget.onTogglePlay();
        }),
      ]),
      if (_metExpanded) ...[
        const SizedBox(height: 10),
        SizedBox(height: 30, child: ListView(scrollDirection: Axis.horizontal,
          children: clickSoundNames.map((s) {
            final active = clickSound == s;
            return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
              onTap: () { ref.read(clickSoundProvider.notifier).state = s; if (metPlaying) ref.read(audioServiceProvider).updateClickSound(s); setState(() {}); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                  color: active ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgElevated,
                  border: Border.all(color: active ? AppColors.accent : AppColors.border)),
                child: Text(s, style: AppFonts.outfit(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? AppColors.accent : AppColors.textMuted))),
            ));
          }).toList())),
        const SizedBox(height: 8),
        Row(children: [
          Text(tr(lang, 'subdivision'), style: AppFonts.outfit(fontSize: 9, color: AppColors.textMuted)), const SizedBox(width: 6),
          ...[1, 2, 3, 4].map((v) {
            final active = subdivision == v; final labels = {1: '1/4', 2: '1/8', 3: '3', 4: '1/16'};
            return Padding(padding: const EdgeInsets.only(right: 4), child: GestureDetector(
              onTap: () { ref.read(subdivisionProvider.notifier).state = v; if (metPlaying) ref.read(audioServiceProvider).updateSubdivision(v); setState(() {}); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                  color: active ? AppColors.accent : AppColors.bgInput, border: Border.all(color: active ? AppColors.accent : AppColors.border)),
                child: Text(labels[v]!, style: AppTheme.monoStyle(size: 9, weight: FontWeight.w600, color: active ? AppColors.bgDeepest : AppColors.textMuted))),
            ));
          }),
          const Spacer(),
          Text(tr(lang, 'timeSignature'), style: AppFonts.outfit(fontSize: 9, color: AppColors.textMuted)), const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.bgInput, border: Border.all(color: AppColors.border)),
            child: PopupMenuButton<TimeSig>(padding: EdgeInsets.zero, constraints: const BoxConstraints(), color: AppColors.bgCard,
              onSelected: (ts) {
                ref.read(timeSigProvider.notifier).state = ts;
                final newAccents = List<double>.generate(ts.num, (i) => i == 0 ? 1.0 : 0.7);
                ref.read(accentPatternProvider.notifier).state = newAccents;
                if (metPlaying) { ref.read(audioServiceProvider).updateTimeSignature(ts.num, ts.den); ref.read(audioServiceProvider).updateAccentPattern(newAccents); }
                setState(() {});
              },
              itemBuilder: (_) => timeSignatures.map((ts) => PopupMenuItem(value: ts,
                child: Text(ts.label, style: AppTheme.monoStyle(size: 13, color: ts.label == timeSig.label ? AppColors.accent : AppColors.textPrimary)))).toList(),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(timeSig.label, style: AppTheme.monoStyle(size: 11, weight: FontWeight.w700, color: AppColors.accent)),
                const SizedBox(width: 2), Icon(Icons.arrow_drop_down, size: 14, color: AppColors.textMuted),
              ]),
            ),
          ),
        ]),
      ],
    ]);
  }

  Widget _buildDrumsGuideRow(String lang, WidgetRef ref) {
    final drumStyle = ref.read(drumStyleProvider);
    return Column(children: [
      Row(children: [
        Icon(Icons.grid_on, size: 16, color: AppColors.accent3), const SizedBox(width: 8),
        Text(tr(lang, 'drumsGuide'), style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const Spacer(),
        GestureDetector(onTap: () { setState(() => _drumsExpanded = !_drumsExpanded); widget.onDrumsExpandToggle(); },
          child: Container(padding: const EdgeInsets.all(4),
            child: Icon(_drumsExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.textMuted))),
        const SizedBox(width: 8),
        _guidePlayButton(playing: _drumsPlaying, color: AppColors.accent3, onTap: () async {
          final audio = ref.read(audioServiceProvider);
          if (_drumsPlaying) {
            await audio.stopDrumPattern(); setState(() => _drumsPlaying = false); widget.onDrumsToggle(false);
          } else {
            if (ref.read(playingProvider)) { await audio.stopMetronome(); ref.read(playingProvider.notifier).state = false; }
            final style = ref.read(drumStyleProvider); final customPattern = ref.read(customDrumPatternProvider);
            final dTimeSig = ref.read(drumTimeSigProvider); final dAccents = ref.read(drumAccentPatternProvider);
            final totalSteps = drumTotalSteps(dTimeSig.num, dTimeSig.den);
            final rawPattern = customPattern ?? drumPatterns[style] ?? {};
            final pattern = adaptDrumPattern(rawPattern, totalSteps);
            await audio.startDrumPattern(bpm: ref.read(bpmProvider), pattern: pattern.map((k, v) => MapEntry(k, List<int>.from(v))),
              swingPercent: ref.read(swingProvider), drumBeats: dTimeSig.num, drumBeatUnit: dTimeSig.den, drumAccentPattern: dAccents);
            await audio.updateDrumVolumes(ref.read(drumVolumesProvider));
            setState(() => _drumsPlaying = true); widget.onDrumsToggle(true);
          }
        }),
      ]),
      if (_drumsExpanded) ...[
        const SizedBox(height: 10),
        SizedBox(height: 30, child: ListView(scrollDirection: Axis.horizontal,
          children: drumStyles.map((style) {
            final active = drumStyle == style;
            return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
              onTap: () async {
                ref.read(drumStyleProvider.notifier).state = style; ref.read(customDrumPatternProvider.notifier).state = null;
                if (_drumsPlaying) {
                  final dTimeSig = ref.read(drumTimeSigProvider); final totalSteps = drumTotalSteps(dTimeSig.num, dTimeSig.den);
                  final pattern = adaptDrumPattern(drumPatterns[style] ?? {}, totalSteps);
                  await ref.read(audioServiceProvider).updateDrumPattern(pattern.map((k, v) => MapEntry(k, List<int>.from(v))));
                }
                setState(() {});
              },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                  color: active ? AppColors.accent3.withValues(alpha: 0.15) : AppColors.bgElevated,
                  border: Border.all(color: active ? AppColors.accent3 : AppColors.border)),
                child: Text(style, style: AppFonts.outfit(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? AppColors.accent3 : AppColors.textMuted))),
            ));
          }).toList())),
        const SizedBox(height: 8),
        Builder(builder: (_) {
          final dTimeSig = ref.read(drumTimeSigProvider); final dAccents = ref.read(drumAccentPatternProvider);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(tr(lang, 'timeSignature'), style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)), const SizedBox(width: 8),
              Expanded(child: SizedBox(height: 28, child: ListView(scrollDirection: Axis.horizontal,
                children: timeSignatures.map((ts) {
                  final active = dTimeSig.label == ts.label;
                  return Padding(padding: const EdgeInsets.only(right: 4), child: GestureDetector(
                    onTap: () {
                      ref.read(drumTimeSigProvider.notifier).state = ts;
                      final newAccents = List<double>.generate(ts.num, (i) => i == 0 ? 1.0 : 0.7);
                      ref.read(drumAccentPatternProvider.notifier).state = newAccents;
                      ref.read(customDrumPatternProvider.notifier).state = null;
                      if (_drumsPlaying) {
                        final audio = ref.read(audioServiceProvider);
                        audio.updateDrumTimeSig(ts.num, ts.den); audio.updateDrumAccentPattern(newAccents);
                        final style = ref.read(drumStyleProvider); final newSteps = drumTotalSteps(ts.num, ts.den);
                        final adapted = adaptDrumPattern(drumPatterns[style]!, newSteps); audio.updateDrumPattern(adapted);
                      }
                      setState(() {});
                    },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                        color: active ? AppColors.accent3.withValues(alpha: 0.15) : AppColors.bgElevated,
                        border: Border.all(color: active ? AppColors.accent3 : AppColors.border)),
                      child: Text(ts.label, style: AppTheme.monoStyle(size: 11, color: active ? AppColors.accent3 : AppColors.textMuted))),
                  ));
                }).toList()))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Text(tr(lang, 'accentPat'), style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)), const SizedBox(width: 8),
              ...List.generate(dTimeSig.num, (i) {
                final vol = i < dAccents.length ? dAccents[i] : 0.7;
                return GestureDetector(
                  onTap: () {
                    final na = List<double>.from(dAccents);
                    if (na[i] >= 0.9) { na[i] = 0.7; } else if (na[i] >= 0.5) { na[i] = 0.0; } else { na[i] = 1.0; }
                    ref.read(drumAccentPatternProvider.notifier).state = na;
                    if (_drumsPlaying) ref.read(audioServiceProvider).updateDrumAccentPattern(na);
                    setState(() {});
                  },
                  child: Container(width: 28, height: 28, margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: vol == 0 ? AppColors.bgInput : vol >= 0.9 ? AppColors.accent3 : AppColors.bgElevated,
                      border: Border.all(color: vol >= 0.9 ? AppColors.accent3 : vol >= 0.5 ? AppColors.accent2Dim : AppColors.border)),
                    child: Center(child: Text('${i + 1}', style: AppTheme.monoStyle(size: 9, color: vol >= 0.9 ? AppColors.bgDeepest : AppColors.textMuted)))),
                );
              }),
            ]),
          ]);
        }),
      ],
    ]);
  }

  Widget _guidePlayButton({required bool playing, required Color color, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
        color: playing ? color.withValues(alpha: 0.15) : AppColors.bgElevated,
        border: Border.all(color: playing ? color : AppColors.border, width: playing ? 1.5 : 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(playing ? Icons.stop : Icons.play_arrow, size: 16, color: playing ? color : AppColors.textMuted),
        const SizedBox(width: 4),
        Text(playing ? 'STOP' : 'PLAY', style: AppFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: playing ? color : AppColors.textMuted)),
      ])));
  }
}
