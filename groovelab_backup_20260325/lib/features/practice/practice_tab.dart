import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/audio/audio_service.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';

class PracticeTab extends ConsumerStatefulWidget {
  final VoidCallback onTogglePlay;
  final VoidCallback onSaveData;

  const PracticeTab({
    super.key,
    required this.onTogglePlay,
    required this.onSaveData,
  });

  @override
  ConsumerState<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends ConsumerState<PracticeTab> {
  // Routine advancement
  Timer? _routineTimer;
  int _currentRoutineStep = 0;
  List<Map<String, dynamic>> _routineSteps = [];

  @override
  void dispose() {
    _routineTimer?.cancel();
    super.dispose();
  }

  void _runRoutine(Map<String, dynamic> routine) {
    final steps = (routine['steps'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (steps.isEmpty) return;

    // Cancel any existing routine
    _routineTimer?.cancel();
    _routineSteps = steps;
    _currentRoutineStep = 0;

    // Apply first step
    _applyRoutineStep(0);
    ref.read(tabIndexProvider.notifier).state = 0; // Go to metronome tab

    if (!ref.read(playingProvider)) {
      widget.onTogglePlay();
    }

    // Schedule auto-advancement if more than one step
    if (steps.length > 1) {
      _scheduleNextRoutineStep();
    }
  }

  void _applyRoutineStep(int index) {
    if (index >= _routineSteps.length) return;
    final step = _routineSteps[index];
    final audio = ref.read(audioServiceProvider);

    ref.read(bpmProvider.notifier).state = step['bpm'] as int;
    audio.updateBpm(step['bpm'] as int);

    final tsLabel = step['timeSig'] as String;
    final ts = timeSignatures.firstWhere(
      (t) => t.label == tsLabel,
      orElse: () => const TimeSig(4, 4, '4/4'),
    );
    ref.read(timeSigProvider.notifier).state = ts;
    ref.read(accentPatternProvider.notifier).state =
        List.generate(ts.num, (i) => i == 0 ? 1.0 : 0.7);
    audio.updateTimeSignature(ts.num, ts.den);
  }

  void _scheduleNextRoutineStep() {
    if (_currentRoutineStep >= _routineSteps.length) return;
    final step = _routineSteps[_currentRoutineStep];
    final durationSecs = step['durationSecs'] as int? ?? 60;

    _routineTimer = Timer(Duration(seconds: durationSecs), () {
      if (!mounted) return;
      _currentRoutineStep++;
      if (_currentRoutineStep < _routineSteps.length) {
        _applyRoutineStep(_currentRoutineStep);
        // Show step change notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Step ${_currentRoutineStep + 1}/${_routineSteps.length}: '
              '${_routineSteps[_currentRoutineStep]['bpm']} BPM',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _scheduleNextRoutineStep();
      } else {
        // Routine complete
        if (ref.read(playingProvider)) {
          widget.onTogglePlay();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Routine complete!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _showCreateRoutineDialog() {
    if (!mounted) return;
    final nameCtrl = TextEditingController();
    final steps = <Map<String, dynamic>>[];
    final currentBpm = ref.read(bpmProvider);
    final currentTimeSig = ref.read(timeSigProvider);
    // Default first step
    steps.add({'bpm': currentBpm, 'timeSig': currentTimeSig.label, 'durationSecs': 120});

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text(tr(ref.read(langProvider), 'newRoutine'),
            style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 16)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.outfit(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: tr(ref.read(langProvider), 'routineName'),
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                      filled: true, fillColor: AppColors.bgInput,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...steps.asMap().entries.map((entry) {
                    final i = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text('${i + 1}.', style: AppTheme.monoStyle(size: 12, color: AppColors.textMuted)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${step["bpm"]} BPM · ${step["timeSig"]} · ${(step["durationSecs"] as int) ~/ 60}min',
                              style: AppTheme.monoStyle(size: 11, color: AppColors.textSecondary))),
                            GestureDetector(
                              onTap: () => setDialogState(() => steps.removeAt(i)),
                              child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      final lastBpm = steps.isNotEmpty ? (steps.last['bpm'] as int) + 10 : ref.read(bpmProvider);
                      setDialogState(() => steps.add({
                        'bpm': lastBpm.clamp(20, 500),
                        'timeSig': ref.read(timeSigProvider).label,
                        'durationSecs': 120,
                      }));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 14, color: AppColors.accent),
                        Text(' ${tr(ref.read(langProvider), "addStep")}',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.accent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr(ref.read(langProvider), 'enterName'),
                      style: GoogleFonts.outfit(color: Colors.white)),
                    backgroundColor: AppColors.danger,
                    duration: const Duration(seconds: 2),
                  ));
                  return;
                }
                if (steps.isEmpty) return;
                final routine = {
                  'id': const Uuid().v4(),
                  'name': name,
                  'steps': steps,
                };
                final routines = [...ref.read(routinesProvider), routine];
                ref.read(routinesProvider.notifier).state = routines;
                ref.read(persistenceProvider).saveRoutines(routines);
                HapticFeedback.mediumImpact();
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('\u2713 $name',
                    style: GoogleFonts.outfit(color: Colors.white)),
                  backgroundColor: AppColors.accent,
                  duration: const Duration(seconds: 2),
                ));
              },
              child: Text(tr(ref.read(langProvider), 'save'),
                style: GoogleFonts.outfit(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final autoInc = ref.watch(autoIncreaseProvider);
    final incBpm = ref.watch(incrementBpmProvider);
    final incBars = ref.watch(incrementBarsProvider);
    final intTrain = ref.watch(intervalTrainingProvider);
    final clkBars = ref.watch(clickBarsProvider);
    final silBars = ref.watch(silentBarsProvider);
    final rndSil = ref.watch(randomSilenceProvider);
    final silProb = ref.watch(silenceProbProvider);
    final playing = ref.watch(playingProvider);
    final bpm = ref.watch(bpmProvider);
    final timeSig = ref.watch(timeSigProvider);
    final targetBpm = ref.watch(targetBpmProvider);
    final reached = ref.watch(speedTrainerReachedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Speed Trainer card (enhanced auto-increase)
          _practiceCard(
            tr(lang, 'speedTrainer'), tr(lang, 'speedTrainerDesc'), autoInc,
            (v) {
              ref.read(autoIncreaseProvider.notifier).state = v;
              ref.read(speedTrainerReachedProvider.notifier).state = false;
            },
            autoInc ? Column(children: [
              _sliderRow('+BPM', incBpm, 1, 20, '+$incBpm',
                  (v) => ref.read(incrementBpmProvider.notifier).state = v),
              _sliderRow(tr(lang, 'every'), incBars, 1, 16, '$incBars ${tr(lang, "bars")}',
                  (v) => ref.read(incrementBarsProvider.notifier).state = v),
              _sliderRow(tr(lang, 'targetBpm'), targetBpm, 40, 500, '$targetBpm',
                  (v) {
                    ref.read(targetBpmProvider.notifier).state = v;
                    ref.read(speedTrainerReachedProvider.notifier).state = false;
                    widget.onSaveData();
                  }),
              const SizedBox(height: 8),
              _speedTrainerProgress(bpm, targetBpm, reached),
            ]) : null,
          ),
          _practiceCard(
            tr(lang, 'intervalTraining'), tr(lang, 'intervalDesc'), intTrain,
            (v) {
              ref.read(intervalTrainingProvider.notifier).state = v;
              if (playing) {
                ref.read(audioServiceProvider).updateIntervalTraining(
                  v, ref.read(clickBarsProvider), ref.read(silentBarsProvider));
              }
            },
            intTrain ? Column(children: [
              _sliderRow(tr(lang, 'click'), clkBars, 1, 16, '$clkBars ${tr(lang, "bars")}',
                  (v) {
                    ref.read(clickBarsProvider.notifier).state = v;
                    if (playing) {
                      ref.read(audioServiceProvider).updateIntervalTraining(true, v, ref.read(silentBarsProvider));
                    }
                  }),
              _sliderRow(tr(lang, 'silent'), silBars, 1, 16, '$silBars ${tr(lang, "bars")}',
                  (v) {
                    ref.read(silentBarsProvider.notifier).state = v;
                    if (playing) {
                      ref.read(audioServiceProvider).updateIntervalTraining(true, ref.read(clickBarsProvider), v);
                    }
                  }),
            ]) : null,
          ),
          _practiceCard(
            tr(lang, 'randomSilence'), tr(lang, 'randomDesc'), rndSil,
            (v) {
              ref.read(randomSilenceProvider.notifier).state = v;
              if (playing) {
                ref.read(audioServiceProvider).updateRandomSilence(v, ref.read(silenceProbProvider));
              }
            },
            rndSil ? _sliderRow(tr(lang, 'probability'), silProb, 5, 80, '$silProb%',
                (v) {
                  ref.read(silenceProbProvider.notifier).state = v;
                  if (playing) {
                    ref.read(audioServiceProvider).updateRandomSilence(true, v);
                  }
                }) : null,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppTheme.transportButton(isPlaying: playing, onTap: widget.onTogglePlay, size: 58),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('$bpm BPM \u00b7 ${timeSig.label}', style: AppTheme.monoStyle(
                  size: 13, color: AppColors.textSecondary,
                )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Saved Routines
          _buildRoutinesPanel(lang),
        ],
      ),
    );
  }

  Widget _buildRoutinesPanel(String lang) {
    final routines = ref.watch(routinesProvider);

    return _panel(tr(lang, 'savedRoutines'), Column(
      children: [
        if (routines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(tr(lang, 'noRoutinesYet'),
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted)),
          ),
        ...routines.map((routine) {
          final steps = (routine['steps'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final totalMins = steps.fold<int>(0, (sum, s) => sum + (s['durationSecs'] as int? ?? 60)) ~/ 60;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.queue_music_rounded, size: 17, color: AppColors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routine['name'] as String? ?? 'Routine',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text('${steps.length} steps \u00b7 ~$totalMins min',
                      style: AppTheme.monoStyle(size: 10, color: AppColors.textMuted)),
                  ],
                )),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _runRoutine(routine);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent2]),
                    ),
                    child: Text(tr(lang, 'runRoutine'),
                      style: AppTheme.monoStyle(size: 11, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final updated = routines.where((r) => r['id'] != routine['id']).toList();
                    ref.read(routinesProvider.notifier).state = updated;
                    ref.read(persistenceProvider).saveRoutines(updated);
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bgCard),
                    child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        // Quick routine builder
        _buildQuickRoutineCreator(lang),
      ],
    ));
  }

  Widget _buildQuickRoutineCreator(String lang) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showCreateRoutineDialog();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.5),
          color: AppColors.accent.withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(tr(lang, 'newRoutine'),
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }

  Widget _speedTrainerProgress(int bpm, int target, bool reached) {
    final progress = target > 20 ? ((bpm - 20) / (target - 20)).clamp(0.0, 1.0) : 1.0;
    final color = reached ? AppColors.accent2 : AppColors.accent;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 6),
              Text('$bpm BPM', style: AppTheme.monoStyle(size: 13, weight: FontWeight.w700, color: color)),
            ]),
            if (reached)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.accent2.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.accent2.withValues(alpha: 0.4)),
                ),
                child: Text(tr(ref.read(langProvider), 'reached'),
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent2)),
              )
            else
              Text('→ $target BPM', style: AppTheme.monoStyle(size: 12, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: reached
                      ? [AppColors.accent2, const Color(0xFF34D399)]
                      : [AppColors.accent, AppColors.accent2],
                  ),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: -1)],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _panel(String title, Widget content) {
    return AppTheme.premiumPanel(title: title.toUpperCase(), content: content);
  }

  Widget _practiceCard(String title, String desc, bool enabled, Function(bool) onToggle, Widget? content) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: enabled ? AppColors.accent.withValues(alpha: 0.04) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? AppColors.accent.withValues(alpha: 0.35) : AppColors.border,
          width: enabled ? 1.5 : 1,
        ),
        boxShadow: enabled ? [
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.08), blurRadius: 16, spreadRadius: -2),
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: enabled
                      ? [AppColors.accent, AppColors.accent2]
                      : [AppColors.border, AppColors.border],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: GoogleFonts.outfit(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                                )),
                                const SizedBox(height: 2),
                                Text(desc, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted, height: 1.3)),
                              ],
                            ),
                          ),
                          Switch(value: enabled, activeColor: AppColors.accent, onChanged: onToggle),
                        ],
                      ),
                      if (content != null) ...[const SizedBox(height: 12), content],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sliderRow(String label, int value, int min, int max, String display, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label, style: GoogleFonts.outfit(
            fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted,
          ))),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.bgInput,
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ),
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(display, style: AppTheme.monoStyle(
              size: 11, weight: FontWeight.w600, color: AppColors.accent,
            ), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
