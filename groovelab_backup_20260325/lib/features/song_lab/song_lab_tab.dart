import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';
import 'song_lab_models.dart';
import 'song_lab_providers.dart';
import 'file_picker_bridge.dart';
import 'widgets/song_lab_waveform_painter.dart';
import 'widgets/song_lab_transport_bar.dart';
import 'widgets/song_lab_segmented_control.dart';
import 'widgets/song_lab_empty_state.dart';
import 'widgets/song_lab_header.dart';

// ═══════════════════════════════════════════════════════════════════
//  SONG LAB TAB — Single-screen professional workstation
//  Fixed layout: Header | Segmented Control | Content | Transport
//  NO vertical scrolling — fits mobile screen entirely.
// ═══════════════════════════════════════════════════════════════════

class SongLabTab extends ConsumerStatefulWidget {
  const SongLabTab({super.key});

  @override
  ConsumerState<SongLabTab> createState() => _SongLabTabState();
}

class _SongLabTabState extends ConsumerState<SongLabTab>
    with TickerProviderStateMixin {
  // ── Streams ──
  StreamSubscription<double>? _positionSub;

  // ── Local state ──
  String? _trackName;
  double _position = 0.0;
  double _duration = 0.0;
  bool _isPlaying = false;
  bool _isSeparating = false;
  double _separationProgress = 0.0;
  bool _loopEnabled = false;
  double _masterVolume = 1.0;
  int _viewIndex = 0; // 0=Player, 1=Stems, 2=Chords, 3=Export

  // ── Waveform data ──
  List<double> _masterWaveform = [];

  // ── A-B loop drag state ──
  bool _isDraggingA = false;
  bool _isDraggingB = false;

  // ── Export state ──
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String _exportFormat = 'wav';
  SongLabExportMode _exportMode = SongLabExportMode.fullMix;
  bool _exportIncludeClick = false;

  // ── Pitch detection ──
  List<Map<String, dynamic>> _detectedNotes = [];
  bool _clickEnabled = false;
  int _clickBpm = 120;

  // ── Animation ──
  late AnimationController _playPulse;
  late AnimationController _separatingAnim;

  @override
  void initState() {
    super.initState();
    _playPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _separatingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _setupStreams();
  }

  void _setupStreams() {
    final audio = ref.read(audioServiceProvider);
    _positionSub = audio.songLabPosition.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      ref.read(songLabPositionProvider.notifier).state = pos;
      _updateCurrentSection(pos);
    });
  }

  void _updateCurrentSection(double pos) {
    final sections = ref.read(songLabSectionsProvider);
    final chords = ref.read(songLabChordsProvider);
    for (final s in sections) {
      if (pos >= s.startTime && pos < s.endTime) {
        ref.read(songLabCurrentSectionProvider.notifier).state = s.label;
        break;
      }
    }
    for (final c in chords) {
      if (pos >= c.startTime && pos < c.endTime) {
        ref.read(songLabCurrentChordProvider.notifier).state = c.chord;
        break;
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playPulse.dispose();
    _separatingAnim.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _importAudio() async {
    // CLEAR previous state
    final audio = ref.read(audioServiceProvider);
    await audio.songLabClearAll();
    ref.read(songLabStemsProvider.notifier).state = [];
    ref.read(songLabSectionsProvider.notifier).state = [];
    ref.read(songLabChordsProvider.notifier).state = [];
    ref.read(songLabLoopRegionProvider.notifier).state = null;
    ref.read(stemSeparationStatusProvider.notifier).state = SeparationStatus.idle;
    setState(() {
      _position = 0.0;
      _duration = 0.0;
      _isPlaying = false;
      _masterWaveform = [];
      _loopEnabled = false;
    });

    try {
      // Platform-conditional file picker (web uses dart:html, native uses stub)
      final fileData = await pickAudioFileWeb();
      if (fileData == null) {
        // User cancelled — ensure state is clean
        ref.read(songLabStateProvider.notifier).state = SongLabTransportState.idle;
        return;
      }
      final bytes = fileData['bytes'] as Uint8List;
      final fileName = fileData['name'] as String;

      ref.read(songLabStateProvider.notifier).state = SongLabTransportState.loading;
      setState(() {
        _trackName = fileName;
        _isPlaying = false;
      });

      final info = await audio.songLabLoadTrack(bytes, fileName, 'fullMix');

      final dur = (info['duration'] as num?)?.toDouble() ?? 0.0;
      setState(() {
        _duration = dur;
        _masterWaveform = audio.songLabGetWaveform(0, 200);
      });

      ref.read(songLabDurationProvider.notifier).state = dur;
      ref.read(songLabStateProvider.notifier).state = SongLabTransportState.ready;

      // Run pitch detection
      try {
        final notes = audio.songLabDetectPitch();
        setState(() => _detectedNotes = notes);
      } catch (e) {
        debugPrint('SongLab: pitch detection failed: $e');
      }
      ref.read(activeSongProjectProvider.notifier).state = SongProject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
        durationSeconds: dur,
        createdAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('SongLab: import failed: $e');
      ref.read(songLabStateProvider.notifier).state = SongLabTransportState.idle;
    }
  }

  Future<void> _separateStems() async {
    final audio = ref.read(audioServiceProvider);
    setState(() {
      _isSeparating = true;
      _separationProgress = 0.0;
    });
    ref.read(stemSeparationStatusProvider.notifier).state = SeparationStatus.processing;

    final progressTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _separationProgress = (_separationProgress + 0.02).clamp(0.0, 0.95);
      });
      ref.read(stemSeparationProgressProvider.notifier).state = _separationProgress;
    });

    try {
      final result = await audio.songLabMockSeparate(0);
      progressTimer.cancel();

      final success = result['success'] as bool? ?? false;
      if (!success) {
        throw Exception('Stem separation returned unsuccessful');
      }

      final stemCount = (result['stemCount'] as num?)?.toInt() ?? 4;
      final stemIndices = (result['stemIndices'] as List?)?.cast<int>() ?? List.generate(stemCount, (i) => i + 1);
      final stemTypes = [StemType.vocals, StemType.drums, StemType.bass, StemType.guitar, StemType.piano, StemType.other];
      final stemNames = ['Vocals', 'Drums', 'Bass', 'Guitar', 'Keys', 'Other'];

      final stems = <Stem>[];
      for (int i = 0; i < stemCount && i < stemTypes.length; i++) {
        final trackIdx = i < stemIndices.length ? stemIndices[i] : i + 1;
        stems.add(Stem(
          index: trackIdx,
          name: stemNames[i],
          type: stemTypes[i],
          color: Stem.colorForType(stemTypes[i]),
          waveform: audio.songLabGetWaveform(trackIdx, 200),
          isLoaded: true,
        ));
      }

      ref.read(songLabStemsProvider.notifier).state = stems;
      ref.read(stemSeparationStatusProvider.notifier).state = SeparationStatus.completed;

      if (_duration > 0) {
        _generateMockSections();
      }

      setState(() {
        _isSeparating = false;
        _separationProgress = 1.0;
      });

      // Run pitch detection on vocals stem for better accuracy
      try {
        final vocalsIdx = stemIndices.isNotEmpty ? stemIndices[0] : 1;
        final notes = audio.songLabDetectPitch(vocalsIdx);
        setState(() => _detectedNotes = notes);
        debugPrint('SongLab: detected ${notes.length} notes from vocals stem');
      } catch (e) {
        debugPrint('SongLab: pitch detection after separation failed: $e');
      }

      // Auto-switch to Stems view
      setState(() => _viewIndex = 1);
    } catch (e) {
      progressTimer.cancel();
      debugPrint('SongLab: separation failed: $e');
      ref.read(stemSeparationStatusProvider.notifier).state = SeparationStatus.failed;
      setState(() {
        _isSeparating = false;
        _separationProgress = 0.0;
      });
    }
  }

  void _generateMockSections() {
    final dur = _duration;
    if (dur <= 0) return;
    final sectionTypes = [
      SectionType.intro,
      SectionType.verse,
      SectionType.chorus,
      SectionType.verse,
      SectionType.chorus,
      SectionType.bridge,
      SectionType.chorus,
      SectionType.outro,
    ];
    final sectionLabels = [
      'Intro', 'Verse 1', 'Chorus 1', 'Verse 2',
      'Chorus 2', 'Bridge', 'Final Chorus', 'Outro',
    ];
    final chordProgressions = ['C', 'Am', 'F', 'G', 'Dm', 'Em', 'Bb', 'C'];

    final segLen = dur / sectionTypes.length;
    final sections = <SongSection>[];
    final chords = <ChordEntry>[];

    for (int i = 0; i < sectionTypes.length; i++) {
      final start = segLen * i;
      final end = segLen * (i + 1);
      sections.add(SongSection(
        label: sectionLabels[i],
        type: sectionTypes[i],
        startTime: start,
        endTime: end,
        chord: chordProgressions[i],
        color: SongSection.colorForSection(sectionTypes[i]),
      ));

      final halfLen = (end - start) / 2;
      chords.add(ChordEntry(
        startTime: start,
        endTime: start + halfLen,
        chord: chordProgressions[i],
      ));
      chords.add(ChordEntry(
        startTime: start + halfLen,
        endTime: end,
        chord: chordProgressions[(i + 1) % chordProgressions.length],
      ));
    }

    ref.read(songLabSectionsProvider.notifier).state = sections;
    ref.read(songLabChordsProvider.notifier).state = chords;
  }

  void _togglePlayPause() {
    final audio = ref.read(audioServiceProvider);
    if (_isPlaying) {
      audio.songLabPause();
      ref.read(songLabStateProvider.notifier).state = SongLabTransportState.paused;
    } else {
      audio.songLabPlay();
      ref.read(songLabStateProvider.notifier).state = SongLabTransportState.playing;
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _stop() {
    final audio = ref.read(audioServiceProvider);
    audio.songLabStop();
    setState(() {
      _isPlaying = false;
      _position = 0.0;
    });
    ref.read(songLabStateProvider.notifier).state = SongLabTransportState.ready;
    ref.read(songLabPositionProvider.notifier).state = 0.0;
  }

  void _seek(double pos) {
    final audio = ref.read(audioServiceProvider);
    audio.songLabSeek(pos);
    setState(() => _position = pos);
    ref.read(songLabPositionProvider.notifier).state = pos;
  }

  void _skipForward() => _seek((_position + 5.0).clamp(0.0, _duration));
  void _skipBackward() => _seek((_position - 5.0).clamp(0.0, _duration));

  void _toggleLoop() {
    final audio = ref.read(audioServiceProvider);
    if (_loopEnabled) {
      audio.songLabClearLoopRegion();
      ref.read(songLabLoopRegionProvider.notifier).state = null;
    } else {
      final a = _position;
      final b = (_position + 10.0).clamp(0.0, _duration);
      audio.songLabSetLoopRegion(a, b);
      ref.read(songLabLoopRegionProvider.notifier).state = LoopRegion(startTime: a, endTime: b);
    }
    setState(() => _loopEnabled = !_loopEnabled);
  }

  void _setSpeed(double speed) {
    final audio = ref.read(audioServiceProvider);
    audio.songLabSetSpeed(speed);
    ref.read(songLabSpeedProvider.notifier).state = speed;
  }

  void _setPitch(int semitones) {
    final audio = ref.read(audioServiceProvider);
    audio.songLabSetPitchShift(semitones);
    ref.read(songLabPitchShiftProvider.notifier).state = semitones;
  }

  void _setStemVolume(int index, double volume) {
    final audio = ref.read(audioServiceProvider);
    audio.songLabSetTrackVolume(index, volume);
    final stems = ref.read(songLabStemsProvider);
    final updated = stems.map((s) => s.index == index ? s.copyWith(volume: volume) : s).toList();
    ref.read(songLabStemsProvider.notifier).state = updated;
  }

  void _toggleStemMute(int index) {
    final audio = ref.read(audioServiceProvider);
    final stems = ref.read(songLabStemsProvider);
    final stem = stems.firstWhere((s) => s.index == index);
    audio.songLabSetTrackMute(index, !stem.muted);
    final updated = stems.map((s) => s.index == index ? s.copyWith(muted: !s.muted) : s).toList();
    ref.read(songLabStemsProvider.notifier).state = updated;
  }

  void _toggleStemSolo(int index) {
    final audio = ref.read(audioServiceProvider);
    final stems = ref.read(songLabStemsProvider);
    final stem = stems.firstWhere((s) => s.index == index);
    audio.songLabSetTrackSolo(index, !stem.solo);
    final updated = stems.map((s) => s.index == index ? s.copyWith(solo: !s.solo) : s).toList();
    ref.read(songLabStemsProvider.notifier).state = updated;
  }

  void _setStemPan(int index, double pan) {
    final audio = ref.read(audioServiceProvider);
    audio.songLabSetTrackPan(index, pan);
    final stems = ref.read(songLabStemsProvider);
    final updated = stems.map((s) => s.index == index ? s.copyWith(pan: pan) : s).toList();
    ref.read(songLabStemsProvider.notifier).state = updated;
  }

  Future<void> _doExport() async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    final progressTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _exportProgress = (_exportProgress + 0.03).clamp(0.0, 0.95);
      });
    });

    try {
      final audio = ref.read(audioServiceProvider);
      final result = await audio.songLabExportMixdown();
      progressTimer.cancel();

      if (result.isEmpty) throw Exception('Export returned empty result');

      setState(() {
        _isExporting = false;
        _exportProgress = 1.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export complete — file downloaded',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: AppColors.accent2.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      progressTimer.cancel();
      setState(() {
        _isExporting = false;
        _exportProgress = 0.0;
      });
      debugPrint('SongLab: export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _discardProject() {
    final audio = ref.read(audioServiceProvider);
    audio.songLabStop();
    audio.songLabClearAll();
    ref.read(songLabStemsProvider.notifier).state = [];
    ref.read(songLabSectionsProvider.notifier).state = [];
    ref.read(songLabChordsProvider.notifier).state = [];
    ref.read(songLabLoopRegionProvider.notifier).state = null;
    ref.read(stemSeparationStatusProvider.notifier).state = SeparationStatus.idle;
    ref.read(songLabSpeedProvider.notifier).state = 1.0;
    ref.read(songLabPitchShiftProvider.notifier).state = 0;
    ref.read(songLabStateProvider.notifier).state = SongLabTransportState.idle;
    setState(() {
      _trackName = null;
      _position = 0.0;
      _duration = 0.0;
      _isPlaying = false;
      _masterWaveform = [];
      _loopEnabled = false;
      _viewIndex = 0;
    });
  }

  Future<void> _saveModifiedMp3() async {
    try {
      setState(() {
        _isExporting = true;
        _exportProgress = 0.0;
      });

      final progressTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _exportProgress = (_exportProgress + 0.03).clamp(0.0, 0.95);
        });
      });

      final audio = ref.read(audioServiceProvider);
      final result = await audio.songLabExportMixdown();
      progressTimer.cancel();

      setState(() {
        _isExporting = false;
        _exportProgress = 1.0;
      });

      // Save project to library
      final project = ref.read(activeSongProjectProvider);
      if (project != null) {
        final projects = ref.read(songLabProjectsProvider);
        final exists = projects.any((p) => p.id == project.id);
        if (!exists) {
          ref.read(songLabProjectsProvider.notifier).state = [...projects, project];
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved & exported successfully', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: AppColors.bgPanel,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportProgress = 0.0;
      });
      debugPrint('SongLab: save failed: $e');
    }
  }

  String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getCurrentNote() {
    if (_detectedNotes.isEmpty) return '';
    for (final note in _detectedNotes) {
      final t = (note['time'] as num?)?.toDouble() ?? 0;
      final end = (note['endTime'] as num?)?.toDouble() ?? 0;
      if (_position >= t && _position < end) {
        final name = note['note'] as String? ?? '';
        final oct = note['octave'] as int? ?? 4;
        return name.isEmpty ? '' : '$name$oct';
      }
    }
    return '';
  }

  String _getCurrentChord() {
    if (_detectedNotes.isEmpty) return '';
    for (final note in _detectedNotes) {
      final t = (note['time'] as num?)?.toDouble() ?? 0;
      final end = (note['endTime'] as num?)?.toDouble() ?? 0;
      if (_position >= t && _position < end) {
        return note['chord'] as String? ?? '';
      }
    }
    return '';
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SETTINGS MODAL
  // ═══════════════════════════════════════════════════════════════════

  void _showSettingsModal() {
    final speed = ref.read(songLabSpeedProvider);
    final pitch = ref.read(songLabPitchShiftProvider);
    final clickEnabled = ref.read(songLabClickEnabledProvider);
    final countIn = ref.read(songLabCountInProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentSpeed = ref.watch(songLabSpeedProvider);
            final currentPitch = ref.watch(songLabPitchShiftProvider);
            final currentClick = ref.watch(songLabClickEnabledProvider);
            final currentCountIn = ref.watch(songLabCountInProvider);

            return DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.3,
              maxChildSize: 0.75,
              builder: (_, controller) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bgPanel,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(
                      top: BorderSide(color: AppColors.borderLight, width: 1),
                      left: BorderSide(color: AppColors.borderLight, width: 1),
                      right: BorderSide(color: AppColors.borderLight, width: 1),
                    ),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.textMuted,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Title
                      Text(
                        'SETTINGS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Speed control
                      _settingsSectionLabel('SPEED', Icons.speed_rounded, AppColors.accent),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: _sliderTheme(AppColors.accent),
                              child: Slider(
                                value: currentSpeed,
                                min: 0.25,
                                max: 2.0,
                                divisions: 35,
                                onChanged: (v) {
                                  _setSpeed(double.parse(v.toStringAsFixed(2)));
                                  setModalState(() {});
                                },
                              ),
                            ),
                          ),
                          Container(
                            width: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.bgInset,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '${currentSpeed.toStringAsFixed(2)}x',
                              style: AppTheme.monoStyle(
                                size: 11,
                                color: currentSpeed != 1.0 ? AppColors.accent : AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Speed presets
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((p) {
                          final isSelected = (currentSpeed - p).abs() < 0.01;
                          return GestureDetector(
                            onTap: () {
                              _setSpeed(p);
                              setModalState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgInset,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isSelected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
                                ),
                              ),
                              child: Text(
                                '${p}x',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  color: isSelected ? AppColors.accent : AppColors.textMuted,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),
                      Container(height: 1, color: AppColors.border),
                      const SizedBox(height: 16),

                      // Pitch control
                      _settingsSectionLabel('PITCH', Icons.music_note_rounded, AppColors.accent3),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _settingsPitchBtn('-1', currentPitch > -12, () {
                            _setPitch(currentPitch - 1);
                            setModalState(() {});
                          }),
                          const SizedBox(width: 12),
                          Container(
                            width: 56,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.bgDeepest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: currentPitch != 0 ? AppColors.accent3.withValues(alpha: 0.4) : AppColors.border,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${currentPitch > 0 ? '+' : ''}$currentPitch',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: currentPitch != 0 ? AppColors.accent3 : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _settingsPitchBtn('+1', currentPitch < 12, () {
                            _setPitch(currentPitch + 1);
                            setModalState(() {});
                          }),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Container(height: 1, color: AppColors.border),
                      const SizedBox(height: 16),

                      // Click track toggle
                      _settingsToggleRow(
                        'Click Track',
                        Icons.timer_rounded,
                        currentClick,
                        (v) {
                          ref.read(songLabClickEnabledProvider.notifier).state = v;
                          setState(() => _clickEnabled = v);
                          final audio = ref.read(audioServiceProvider);
                          audio.songLabToggleClick(v, _clickBpm);
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 10),

                      // Count-in toggle
                      _settingsToggleRow(
                        'Count-In',
                        Icons.looks_4_rounded,
                        currentCountIn,
                        (v) {
                          ref.read(songLabCountInProvider.notifier).state = v;
                          setModalState(() {});
                        },
                      ),

                      const SizedBox(height: 20),

                      // Reset all
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            _setSpeed(1.0);
                            _setPitch(0);
                            ref.read(songLabClickEnabledProvider.notifier).state = false;
                            ref.read(songLabCountInProvider.notifier).state = false;
                            setModalState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.bgInset,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'Reset All',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _settingsSectionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _settingsPitchBtn(String label, bool enabled, VoidCallback onTap) {
    final radius = BorderRadius.circular(8);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        splashColor: AppColors.accent3.withValues(alpha: 0.2),
        child: Container(
          width: 44,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.bgPanel,
            borderRadius: radius,
            border: Border.all(color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.3)),
            boxShadow: AppColors.neumorphicRaised(scale: 0.4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: enabled ? AppColors.textSecondary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsToggleRow(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 28,
          child: Switch(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  LIBRARY MODAL
  // ═══════════════════════════════════════════════════════════════════

  void _showLibraryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final projects = ref.watch(songLabProjectsProvider);

            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.75,
              builder: (_, controller) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bgPanel,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(
                      top: BorderSide(color: AppColors.borderLight, width: 1),
                      left: BorderSide(color: AppColors.borderLight, width: 1),
                      right: BorderSide(color: AppColors.borderLight, width: 1),
                    ),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.textMuted,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Title
                      Row(
                        children: [
                          Text(
                            'LIBRARY',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _importAudio();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 14, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Import New',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (projects.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.library_music_rounded, size: 40, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'No saved projects',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Import audio to get started',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...projects.map((project) => _buildLibraryProjectRow(project, ctx, setModalState)),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLibraryProjectRow(SongProject project, BuildContext ctx, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.bgInset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.audiotrack_rounded, size: 16, color: AppColors.accent),
        ),
        title: Text(
          project.title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatTime(project.durationSeconds)} - ${project.createdAt.month}/${project.createdAt.day}/${project.createdAt.year}',
          style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
        ),
        trailing: GestureDetector(
          onTap: () {
            final updated = ref.read(songLabProjectsProvider)
                .where((p) => p.id != project.id)
                .toList();
            ref.read(songLabProjectsProvider.notifier).state = updated;
            setModalState(() {});
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.danger),
          ),
        ),
        onTap: () {
          Navigator.of(ctx).pop();
          // Load project — clear and reload
          _importAudio();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD — Main layout
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final stems = ref.watch(songLabStemsProvider);
    final sections = ref.watch(songLabSectionsProvider);
    final currentChord = ref.watch(songLabCurrentChordProvider);
    final currentSection = ref.watch(songLabCurrentSectionProvider);
    final sepStatus = ref.watch(stemSeparationStatusProvider);
    final loopRegion = ref.watch(songLabLoopRegionProvider);
    final transportState = ref.watch(songLabStateProvider);

    return Container(
      color: AppColors.bgDeepest,
      child: Column(
        children: [
          SongLabHeader(
            trackName: _trackName,
            isPlaying: _isPlaying,
            duration: _duration,
            lang: lang,
            onSave: () {
              final project = ref.read(activeSongProjectProvider);
              if (project != null) {
                final projects = List<SongProject>.from(ref.read(songLabProjectsProvider));
                projects.removeWhere((p) => p.id == project.id);
                projects.insert(0, project.copyWith(lastOpenedAt: DateTime.now()));
                ref.read(songLabProjectsProvider.notifier).state = projects;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Project saved', style: GoogleFonts.outfit(color: Colors.white)),
                    backgroundColor: AppColors.bgPanel,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            onLibrary: _showLibraryModal,
            onSettings: _showSettingsModal,
            onDiscard: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.bgPanel,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Discard Project?', style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                  )),
                  content: Text('This will remove the current track and all changes.',
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _discardProject();
                      },
                      child: Text('Discard', style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, color: AppColors.danger,
                      )),
                    ),
                  ],
                ),
              );
            },
          ),
          SongLabSegmentedControl(
            viewIndex: _viewIndex,
            onViewChanged: (i) => setState(() => _viewIndex = i),
            lang: lang,
            hasStemsAvailable: stems.isNotEmpty,
          ),
          Expanded(
            child: _trackName == null
                ? SongLabEmptyState(
                    isLoading: transportState == SongLabTransportState.loading,
                    onImport: _importAudio,
                    lang: lang,
                  )
                : IndexedStack(
                    index: _viewIndex,
                    children: [
                      _buildPlayerView(sections, loopRegion, currentSection, currentChord, sepStatus, transportState),
                      _buildStemsView(stems, sepStatus),
                      _buildChordsView(sections, currentChord, currentSection),
                      _buildExportView(),
                    ],
                  ),
          ),
          if (_trackName != null)
            SongLabTransportBar(
              duration: _duration,
              position: _position,
              isPlaying: _isPlaying,
              loopEnabled: _loopEnabled,
              loopRegion: loopRegion != null ? (loopRegion.startTime, loopRegion.endTime) : null,
              onSkipBackward: _skipBackward,
              onStop: _stop,
              onPlayPause: _togglePlayPause,
              onSkipForward: _skipForward,
              onToggleLoop: _toggleLoop,
              playPulseAnimation: _playPulse,
            ),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════════
  //  PLAYER VIEW (viewIndex == 0)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPlayerView(
    List<SongSection> sections,
    LoopRegion? loopRegion,
    String? currentSection,
    String? currentChord,
    SeparationStatus sepStatus,
    SongLabTransportState transportState,
  ) {
    final isLoading = transportState == SongLabTransportState.loading;

    return Column(
      children: [
        // Waveform (Expanded)
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            decoration: BoxDecoration(
              color: AppColors.bgInset,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                children: [
                  // Section color overlays
                  if (sections.isNotEmpty)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final totalWidth = constraints.maxWidth;
                          return Stack(
                            children: sections.map((s) {
                              final left = _duration > 0 ? (s.startTime / _duration) * totalWidth : 0.0;
                              final width = _duration > 0 ? ((s.endTime - s.startTime) / _duration) * totalWidth : 0.0;
                              return Positioned(
                                left: left,
                                width: width,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  color: s.color.withValues(alpha: 0.06),
                                  alignment: Alignment.topCenter,
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    s.label,
                                    style: GoogleFonts.outfit(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w600,
                                      color: s.color.withValues(alpha: 0.6),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),

                  // Waveform painter
                  Positioned.fill(
                    child: GestureDetector(
                      onTapDown: (details) {
                        if (_duration <= 0) return;
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final localX = details.localPosition.dx;
                        final width = box.size.width - 16; // account for margin
                        final seekPos = (localX / width) * _duration;
                        _seek(seekPos.clamp(0.0, _duration));
                      },
                      onHorizontalDragUpdate: (details) {
                        if (_duration <= 0) return;
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final localX = details.localPosition.dx;
                        final width = box.size.width;

                        // Check A-B loop marker dragging
                        if (_loopEnabled && loopRegion != null) {
                          final aX = (loopRegion.startTime / _duration) * width;
                          final bX = (loopRegion.endTime / _duration) * width;

                          if (_isDraggingA || (!_isDraggingB && (localX - aX).abs() < 20)) {
                            _isDraggingA = true;
                            final newA = (localX / width * _duration).clamp(0.0, loopRegion.endTime - 0.5);
                            final audio = ref.read(audioServiceProvider);
                            audio.songLabSetLoopRegion(newA, loopRegion.endTime);
                            ref.read(songLabLoopRegionProvider.notifier).state =
                                LoopRegion(startTime: newA, endTime: loopRegion.endTime);
                            return;
                          }
                          if (_isDraggingB || (localX - bX).abs() < 20) {
                            _isDraggingB = true;
                            final newB = (localX / width * _duration).clamp(loopRegion.startTime + 0.5, _duration);
                            final audio = ref.read(audioServiceProvider);
                            audio.songLabSetLoopRegion(loopRegion.startTime, newB);
                            ref.read(songLabLoopRegionProvider.notifier).state =
                                LoopRegion(startTime: loopRegion.startTime, endTime: newB);
                            return;
                          }
                        }

                        final seekPos = (localX / width) * _duration;
                        _seek(seekPos.clamp(0.0, _duration));
                      },
                      onHorizontalDragEnd: (_) {
                        _isDraggingA = false;
                        _isDraggingB = false;
                      },
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: SongLabWaveformPainter(
                          waveform: _masterWaveform,
                          position: _duration > 0 ? _position / _duration : 0.0,
                          loopRegion: _loopEnabled ? loopRegion : null,
                          duration: _duration,
                          accentColor: _isPlaying ? AppColors.accent : AppColors.accent.withValues(alpha: 0.6),
                          loopColorA: AppColors.accent2,
                          loopColorB: AppColors.warm,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Section pills row (~30px)
        if (sections.isNotEmpty)
          SizedBox(
            height: 30,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final s = sections[index];
                final isCurrent = currentSection == s.label;
                return GestureDetector(
                  onTap: () => _seek(s.startTime),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCurrent ? s.color.withValues(alpha: 0.25) : s.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent ? s.color.withValues(alpha: 0.6) : s.color.withValues(alpha: 0.2),
                        width: isCurrent ? 1.5 : 1,
                      ),
                      boxShadow: isCurrent
                          ? [BoxShadow(color: s.color.withValues(alpha: 0.15), blurRadius: 4)]
                          : null,
                    ),
                    child: Text(
                      s.label,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? s.color : s.color.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Info row with note display (~28px)
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              if (currentSection != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getCurrentSectionColor(sections, currentSection),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  currentSection,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (currentChord != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '\u2022',
                    style: TextStyle(fontSize: 8, color: AppColors.textMuted),
                  ),
                ),
                Text(
                  currentChord,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent2,
                  ),
                ),
              ],
              // Real-time detected note + chord
              if (_detectedNotes.isNotEmpty) ...[
                const SizedBox(width: 6),
                // Note badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note, size: 9, color: AppColors.accent),
                      const SizedBox(width: 2),
                      Text(
                        _getCurrentNote().isEmpty ? '—' : _getCurrentNote(),
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                // Chord badge
                if (_getCurrentChord().isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent2.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.accent2.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      _getCurrentChord(),
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent2),
                    ),
                  ),
                ],
              ],
              if (_duration > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '\u2022',
                    style: TextStyle(fontSize: 8, color: AppColors.textMuted),
                  ),
                ),
                Text(
                  '120 BPM',
                  style: AppTheme.monoStyle(size: 9, color: AppColors.textMuted),
                ),
              ],
              const Spacer(),
              if (sepStatus == SeparationStatus.completed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'STEMS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent2,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Action buttons row (~40px)
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Import Audio button
              Expanded(
                child: HardwareButton(
                  onTap: isLoading ? null : _importAudio,
                  isDisabled: isLoading,
                  surfaceColor: AppColors.bgPanel,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Change Audio',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Separate Stems button
              if (sepStatus != SeparationStatus.completed)
                Expanded(
                  child: _isSeparating
                      ? AnimatedBuilder(
                          animation: _separatingAnim,
                          builder: (_, __) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: AppColors.bgPanel,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.warm.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: _separationProgress,
                                    backgroundColor: AppColors.bgInset,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color.lerp(AppColors.warm, AppColors.accent, _separatingAnim.value)!,
                                    ),
                                    minHeight: 3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(_separationProgress * 100).toInt()}%',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 8,
                                    color: AppColors.warm,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : HardwareButton(
                          onTap: _duration > 0 ? _separateStems : null,
                          isDisabled: _duration <= 0,
                          glowColor: AppColors.warm,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.call_split_rounded, size: 14, color: AppColors.warm),
                              const SizedBox(width: 4),
                              Text(
                                'Separate Stems',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warm,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Color _getCurrentSectionColor(List<SongSection> sections, String? label) {
    if (label == null) return AppColors.textMuted;
    for (final s in sections) {
      if (s.label == label) return s.color;
    }
    return AppColors.textMuted;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STEMS VIEW (viewIndex == 1)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStemsView(List<Stem> stems, SeparationStatus sepStatus) {
    if (sepStatus != SeparationStatus.completed || stems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_split_rounded, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No stems available',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Separate stems from the Player tab first',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            if (sepStatus == SeparationStatus.processing)
              Column(
                children: [
                  SizedBox(
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _separationProgress,
                        backgroundColor: AppColors.bgInset,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warm),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Separating... ${(_separationProgress * 100).toInt()}%',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.warm),
                  ),
                ],
              )
            else if (_duration > 0)
              HardwareButton(
                onTap: _separateStems,
                glowColor: AppColors.warm,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_split_rounded, size: 16, color: AppColors.warm),
                    const SizedBox(width: 6),
                    Text(
                      'Separate Stems',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warm,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Stem header
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 13, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'STEM MIXER',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.bgInset,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${stems.length} stems',
                  style: GoogleFonts.outfit(fontSize: 9, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),

        // Stem rows (Expanded)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: stems.length,
            itemBuilder: (context, index) => _buildStemRow(stems[index]),
          ),
        ),

        // Divider
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: AppColors.border,
        ),

        // Master volume row (~40px)
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.bgInset,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Icon(Icons.speaker_rounded, size: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Text(
                'Master',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: _sliderTheme(AppColors.textPrimary),
                  child: Slider(
                    value: _masterVolume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      setState(() => _masterVolume = v);
                      final audio = ref.read(audioServiceProvider);
                      audio.songLabSetTrackVolume(0, v);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  '${(_masterVolume * 100).round()}',
                  style: AppTheme.monoStyle(size: 9, color: AppColors.textMuted),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStemRow(Stem stem) {
    final color = stem.color;
    final isMuted = stem.muted;
    final isSolo = stem.solo;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main row: icon + name + volume slider + M/S
          Row(
            children: [
              // Stem type icon with colored dot
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(Stem.iconForType(stem.type), size: 13, color: color),
              ),
              const SizedBox(width: 8),

              // Stem name
              SizedBox(
                width: 44,
                child: Text(
                  stem.name,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isMuted ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),

              // Volume slider
              Expanded(
                child: SliderTheme(
                  data: _sliderTheme(isMuted ? AppColors.textMuted : color),
                  child: Slider(
                    value: stem.volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: isMuted ? null : (v) => _setStemVolume(stem.index, v),
                  ),
                ),
              ),

              // Volume %
              SizedBox(
                width: 24,
                child: Text(
                  '${(stem.volume * 100).round()}',
                  style: AppTheme.monoStyle(
                    size: 9,
                    color: isMuted ? AppColors.textMuted : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 4),

              // Mute button
              _miniToggleButton(
                label: 'M',
                isActive: isMuted,
                activeColor: AppColors.danger,
                onTap: () => _toggleStemMute(stem.index),
              ),
              const SizedBox(width: 3),

              // Solo button
              _miniToggleButton(
                label: 'S',
                isActive: isSolo,
                activeColor: AppColors.warm,
                onTap: () => _toggleStemSolo(stem.index),
              ),
            ],
          ),

          // Pan control row (compact)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 0, bottom: 0),
            child: Row(
              children: [
                Text(
                  'PAN',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Text('L', style: GoogleFonts.jetBrainsMono(fontSize: 7, color: AppColors.textMuted)),
                Expanded(
                  child: SliderTheme(
                    data: _sliderTheme(AppColors.textSecondary, trackHeight: 2),
                    child: Slider(
                      value: stem.pan,
                      min: -1.0,
                      max: 1.0,
                      onChanged: isMuted ? null : (v) => _setStemPan(stem.index, v),
                    ),
                  ),
                ),
                Text('R', style: GoogleFonts.jetBrainsMono(fontSize: 7, color: AppColors.textMuted)),
                const SizedBox(width: 2),
                SizedBox(
                  width: 24,
                  child: Text(
                    stem.pan == 0
                        ? 'C'
                        : '${stem.pan > 0 ? 'R' : 'L'}${(stem.pan.abs() * 100).round()}',
                    style: AppTheme.monoStyle(size: 7, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniToggleButton({
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(5);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: activeColor.withValues(alpha: 0.3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.30) : AppColors.bgInset,
            borderRadius: radius,
            border: Border.all(
              color: isActive ? activeColor.withValues(alpha: 0.85) : AppColors.border,
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: activeColor.withValues(alpha: 0.35), blurRadius: 8)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isActive ? activeColor : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CHORDS VIEW (viewIndex == 2)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildChordsView(
    List<SongSection> sections,
    String? currentChord,
    String? currentSection,
  ) {
    final chords = ref.watch(songLabChordsProvider);

    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.piano_rounded, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No section data',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Separate stems to analyze sections',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Section timeline bar (Expanded top portion)
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            decoration: BoxDecoration(
              color: AppColors.bgInset,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final totalHeight = constraints.maxHeight;
                  return GestureDetector(
                    onTapDown: (details) {
                      if (_duration <= 0) return;
                      final seekPos = (details.localPosition.dx / totalWidth) * _duration;
                      _seek(seekPos.clamp(0.0, _duration));
                    },
                    child: Stack(
                      children: [
                        // Section colored blocks proportional to duration
                        ...sections.map((s) {
                          final left = (s.startTime / _duration) * totalWidth;
                          final width = ((s.endTime - s.startTime) / _duration) * totalWidth;
                          final isCurrent = currentSection == s.label;
                          return Positioned(
                            left: left,
                            width: width,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: s.color.withValues(alpha: isCurrent ? 0.3 : 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: isCurrent
                                    ? Border.all(color: s.color.withValues(alpha: 0.6), width: 1.5)
                                    : Border.all(color: s.color.withValues(alpha: 0.15)),
                                boxShadow: isCurrent
                                    ? [BoxShadow(color: s.color.withValues(alpha: 0.2), blurRadius: 6)]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    s.label,
                                    style: GoogleFonts.outfit(
                                      fontSize: width > 50 ? 10 : 8,
                                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                      color: isCurrent ? s.color : s.color.withValues(alpha: 0.7),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  if (width > 40 && s.chord != null)
                                    Text(
                                      s.chord!,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: s.color.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  if (width > 60)
                                    Text(
                                      '${_formatTime(s.startTime)}-${_formatTime(s.endTime)}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 7,
                                        color: s.color.withValues(alpha: 0.4),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),

                        // Playback position indicator
                        if (_duration > 0)
                          Positioned(
                            left: (_position / _duration) * totalWidth - 1,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2,
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary,
                                borderRadius: BorderRadius.circular(1),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.textPrimary.withValues(alpha: 0.5),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Section grid (~180px, Wrap of tappable cards)
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.6,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final s = sections[index];
                final isCurrent = currentSection == s.label;
                return GestureDetector(
                  onTap: () => _seek(s.startTime),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent ? s.color.withValues(alpha: 0.2) : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? s.color.withValues(alpha: 0.5) : AppColors.border,
                        width: isCurrent ? 1.5 : 1,
                      ),
                      boxShadow: isCurrent
                          ? [BoxShadow(color: s.color.withValues(alpha: 0.15), blurRadius: 4)]
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                s.label,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                  color: isCurrent ? s.color : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_formatTime(s.startTime)} - ${_formatTime(s.endTime)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Chord progression row (~36px)
        if (chords.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: chords.length,
              itemBuilder: (context, index) {
                final chord = chords[index];
                final isCurrent = currentChord == chord.chord &&
                    _position >= chord.startTime &&
                    _position < chord.endTime;
                return GestureDetector(
                  onTap: () => _seek(chord.startTime),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.accent2.withValues(alpha: 0.2)
                          : AppColors.bgInset,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.accent2.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                      boxShadow: isCurrent
                          ? [BoxShadow(color: AppColors.accent2.withValues(alpha: 0.15), blurRadius: 4)]
                          : null,
                    ),
                    child: Text(
                      chord.chord,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                        color: isCurrent ? AppColors.accent2 : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Current info row (~24px)
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                'Now: ',
                style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
              ),
              if (currentSection != null)
                Text(
                  currentSection,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (currentChord != null) ...[
                Text(
                  ' \u2022 Chord: ',
                  style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
                ),
                Text(
                  currentChord,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  EXPORT VIEW (viewIndex == 3)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildExportView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.ios_share_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'EXPORT',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Export mode selection (radio buttons)
          _exportModeRadio('Full Mix', SongLabExportMode.fullMix, Icons.merge_type_rounded),
          _exportModeRadio('Stems Only', SongLabExportMode.stemsOnly, Icons.call_split_rounded),
          _exportModeRadio('Custom Mix', SongLabExportMode.customMix, Icons.tune_rounded),

          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // Format selection row
          Text(
            'FORMAT',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _formatButton('WAV', 'wav'),
              const SizedBox(width: 8),
              _formatButton('MP3', 'mp3'),
            ],
          ),

          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // Options
          Row(
            children: [
              Text(
                'Include Click Track',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: Switch(
                  value: _exportIncludeClick,
                  onChanged: (v) => setState(() => _exportIncludeClick = v),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Export progress
          if (_isExporting) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _exportProgress,
                backgroundColor: AppColors.bgInset,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Exporting... ${(_exportProgress * 100).toInt()}%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Export button (full width, gradient)
          GestureDetector(
            onTap: (_duration > 0 && !_isExporting) ? _doExport : null,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: (_duration > 0 && !_isExporting)
                    ? const LinearGradient(
                        colors: [AppColors.accent, AppColors.accentDim],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: (_duration > 0 && !_isExporting) ? null : AppColors.bgInput,
                borderRadius: BorderRadius.circular(10),
                boxShadow: (_duration > 0 && !_isExporting)
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: (_duration > 0 && !_isExporting)
                        ? AppColors.bgDeepest
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isExporting ? 'Exporting...' : 'Export',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: (_duration > 0 && !_isExporting)
                          ? AppColors.bgDeepest
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _exportModeRadio(String label, SongLabExportMode mode, IconData icon) {
    final isSelected = _exportMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _exportMode = mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: AppColors.bgDeepest)
                  : null,
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 16, color: isSelected ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatButton(String label, String format) {
    final isSelected = _exportFormat == format;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _exportFormat = format),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgInset,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.1), blurRadius: 4)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════════
  //  SLIDER THEME HELPER
  // ═══════════════════════════════════════════════════════════════════

  SliderThemeData _sliderTheme(Color activeColor, {double trackHeight = 3}) {
    return SliderThemeData(
      activeTrackColor: activeColor,
      inactiveTrackColor: AppColors.bgInput,
      thumbColor: activeColor,
      overlayColor: activeColor.withValues(alpha: 0.1),
      trackHeight: trackHeight,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    );
  }
}
