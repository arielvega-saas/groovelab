import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/audio/audio_service.dart';
import '../../core/widgets/neumorphic_dialog.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';

class MetronomeTab extends ConsumerStatefulWidget {
  final VoidCallback onTogglePlay;
  final VoidCallback onTapTempo;
  final double beatPulse;
  final VoidCallback onSaveData;

  const MetronomeTab({
    super.key,
    required this.onTogglePlay,
    required this.onTapTempo,
    required this.beatPulse,
    required this.onSaveData,
  });

  @override
  ConsumerState<MetronomeTab> createState() => _MetronomeTabState();
}

class _MetronomeTabState extends ConsumerState<MetronomeTab> {

  // ── Tempo Trainer state ──
  int _barCount = 1;
  int _trainerStart = 80;
  int _trainerEnd = 160;
  int _trainerStep = 10;
  int _trainerEvery = 2;
  bool _trainerRunning = false;
  int _trainerBarsElapsed = 0;

  void _showBpmInput(BuildContext context, WidgetRef ref, int currentBpm, bool playing) {
    final controller = TextEditingController(text: '$currentBpm');
    void applyBpm(String val, BuildContext ctx) {
      final newBpm = int.tryParse(val);
      if (newBpm != null) {
        final clamped = newBpm.clamp(20, 500);
        ref.read(bpmProvider.notifier).state = clamped;
        if (playing) ref.read(audioServiceProvider).updateBpm(clamped);
      }
      Navigator.of(ctx).pop();
    }
    NeumorphicDialog.show(
      context: context,
      title: 'SET BPM',
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.accent,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.accent),
          ),
          filled: true,
          fillColor: AppColors.bgInset,
          hintText: '20-500',
          hintStyle: GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.textMuted),
        ),
        onSubmitted: (val) => applyBpm(val, context),
      ),
      actions: [
        NeumorphicDialogButton(
          label: 'Cancel',
          onTap: () => Navigator.of(context).pop(),
        ),
        NeumorphicDialogButton(
          label: 'Set',
          isPrimary: true,
          onTap: () => applyBpm(controller.text, context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bpm = ref.watch(bpmProvider);
    final playing = ref.watch(playingProvider);
    final timeSig = ref.watch(timeSigProvider);
    final currentBeat = ref.watch(currentBeatProvider);
    final accents = ref.watch(accentPatternProvider);
    final clickSound = ref.watch(clickSoundProvider);
    final tempoName = getTempoName(bpm);
    final progress = (bpm - 20) / 480;

    // ── Bar counter & Tempo Trainer advancement ──
    ref.listen<bool>(playingProvider, (prev, next) {
      if (next == true && (prev == false || prev == null)) {
        setState(() { _barCount = 1; _trainerBarsElapsed = 0; });
      }
    });
    ref.listen<int>(currentBeatProvider, (prev, next) {
      if (next == 0 && prev != null && prev != 0) {
        setState(() {
          _barCount++;
          if (_trainerRunning) {
            _trainerBarsElapsed++;
            if (_trainerBarsElapsed >= _trainerEvery) {
              _trainerBarsElapsed = 0;
              final cur = ref.read(bpmProvider);
              final stepped = (cur + _trainerStep).clamp(_trainerStart, _trainerEnd);
              if (stepped >= _trainerEnd) _trainerRunning = false;
              ref.read(bpmProvider.notifier).state = stepped;
              if (ref.read(playingProvider)) {
                ref.read(audioServiceProvider).updateBpm(stepped);
              }
            }
          }
        });
      }
    });

    return LayoutBuilder(builder: (context, constraints) {
      final availH = constraints.maxHeight;
      // BIGGER knob sizes
      final knobSize = availH < 520 ? 220.0 : availH < 650 ? 270.0 : 310.0;
      final innerSize = knobSize * 0.52;

      return Column(
        children: [
          // ══════════════════════════════════════════════════════
          //  MAIN SECTION — clean, centered layout
          // ══════════════════════════════════════════════════════
          Expanded(
            child: Container(
              color: AppColors.bgDark,
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              child: Column(
                children: [
                  // ── LCD Info Bar (n-Track / Pro Metronome style) ──
                  if (availH >= 500)
                    _buildLcdInfoBar(clickSound, currentBeat, tempoName),

                  // ── Beat Blocks — animated vertical bars ──
                  _BeatBlocksDisplay(
                    numBeats: timeSig.num,
                    currentBeat: currentBeat,
                    accents: accents,
                    isPlaying: playing,
                    height: availH < 520 ? 30.0 : 42.0,
                    onTapBeat: (i) {
                      HapticFeedback.selectionClick();
                      final newAccents = List<double>.from(accents);
                      if (newAccents[i] >= 0.9) {
                        newAccents[i] = 0.7;
                      } else if (newAccents[i] >= 0.5) {
                        newAccents[i] = 0.0;
                      } else {
                        newAccents[i] = 1.0;
                      }
                      ref.read(accentPatternProvider.notifier).state = newAccents;
                      if (playing) ref.read(audioServiceProvider).updateAccentPattern(newAccents);
                    },
                  ),

                  // ── BPM KNOB (BIG, centered, no side panels) ──
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          final delta = -d.delta.dy * 0.5;
                          final newBpm = (bpm + delta.round()).clamp(20, 500);
                          ref.read(bpmProvider.notifier).state = newBpm;
                          if (playing) ref.read(audioServiceProvider).updateBpm(newBpm);
                        },
                        child: SizedBox(
                          width: knobSize, height: knobSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: Size(knobSize, knobSize),
                                painter: _KnobPainter(
                                  progress: progress,
                                  beatPulse: widget.beatPulse,
                                  isPlaying: playing,
                                ),
                              ),
                              Container(
                                width: innerSize, height: innerSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.bgInset,
                                  border: const Border.fromBorderSide(AppColors.neumorphicBorder),
                                  boxShadow: [
                                    const BoxShadow(
                                      color: Color(0xFF121212), blurRadius: 6,
                                      offset: Offset(3, 3), spreadRadius: -2,
                                    ),
                                    const BoxShadow(
                                      color: Color(0xFF2A2A2A), blurRadius: 6,
                                      offset: Offset(-3, -3), spreadRadius: -2,
                                    ),
                                    if (playing) BoxShadow(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.60 * (0.25 + widget.beatPulse * 0.35)),
                                      blurRadius: 8 + widget.beatPulse * 14,
                                    ),
                                  ],
                                ),
                                child: GestureDetector(
                                  onTap: () => _showBpmInput(context, ref, bpm, playing),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 60),
                                        style: playing
                                            ? AppTheme.lcdStyle(
                                                size: (innerSize * 0.33 + widget.beatPulse * 2).clamp(28, 48),
                                                weight: FontWeight.w800,
                                                color: AppColors.accent,
                                                glow: true,
                                              )
                                            : AppTheme.monoStyle(
                                                size: (innerSize * 0.33).clamp(28, 44),
                                                weight: FontWeight.w800,
                                                color: AppColors.textSecondary,
                                              ),
                                        child: Text('$bpm'),
                                      ),
                                      Text('TAP TO EDIT', style: GoogleFonts.outfit(
                                        fontSize: 7,
                                        color: playing
                                            ? AppColors.accent.withValues(alpha: 0.50)
                                            : AppColors.textMuted.withValues(alpha: 0.5),
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w600,
                                      )),
                                      Text('BPM', style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        color: playing
                                            ? AppColors.accent.withValues(alpha: 0.60)
                                            : AppColors.textMuted,
                                        letterSpacing: 4,
                                        fontWeight: FontWeight.w600,
                                        shadows: playing ? [
                                          Shadow(
                                            color: AppColors.accent.withValues(alpha: 0.50),
                                            blurRadius: 8,
                                          ),
                                        ] : null,
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Transport Controls ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppTheme.bpmStepButton(label: '−5', onTap: () {
                        final n = (bpm - 5).clamp(20, 500);
                        ref.read(bpmProvider.notifier).state = n;
                        if (playing) ref.read(audioServiceProvider).updateBpm(n);
                      }),
                      AppTheme.bpmStepButton(label: '−1', onTap: () {
                        final n = (bpm - 1).clamp(20, 500);
                        ref.read(bpmProvider.notifier).state = n;
                        if (playing) ref.read(audioServiceProvider).updateBpm(n);
                      }),
                      const SizedBox(width: 10),
                      AppTheme.transportButton(
                        isPlaying: playing,
                        onTap: widget.onTogglePlay,
                        size: 66,
                        pulseValue: widget.beatPulse,
                      ),
                      const SizedBox(width: 10),
                      AppTheme.bpmStepButton(label: '+1', onTap: () {
                        final n = (bpm + 1).clamp(20, 500);
                        ref.read(bpmProvider.notifier).state = n;
                        if (playing) ref.read(audioServiceProvider).updateBpm(n);
                      }),
                      AppTheme.bpmStepButton(label: '+5', onTap: () {
                        final n = (bpm + 5).clamp(20, 500);
                        ref.read(bpmProvider.notifier).state = n;
                        if (playing) ref.read(audioServiceProvider).updateBpm(n);
                      }),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // ── Tap Tempo ──
                  GestureDetector(
                    onTap: widget.onTapTempo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: AppColors.bgPanel,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          width: 0.7,
                        ),
                        boxShadow: AppColors.neumorphicRaised(scale: 0.75),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, size: 14, color: AppColors.accent.withValues(alpha: 0.75)),
                          const SizedBox(width: 7),
                          Text('TAP TEMPO', style: AppTheme.lcdStyle(
                            size: 10, weight: FontWeight.w600, color: AppColors.accent, glow: false,
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // ── Bottom compact bar: [Time Sig] [Click Sound] [Settings] ──
          Container(
            color: AppColors.bgDark,
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgPanel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
                boxShadow: AppColors.neumorphicRaised(scale: 0.5),
              ),
              child: Row(
                children: [
                  // ── Time Signature indicator ──
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showTimeSigPicker(context, ref, playing),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.accent.withValues(alpha: 0.08),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_note_outlined, size: 13, color: AppColors.accent.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(timeSig.label,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // ── Click Sound indicator ──
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showClickSoundPicker(context, ref, playing),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.accent2.withValues(alpha: 0.08),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volume_up_rounded, size: 13, color: AppColors.accent2.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(clickSound,
                                style: GoogleFonts.outfit(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: AppColors.accent2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // ── Settings button ──
                  GestureDetector(
                    onTap: () => _showSettingsSheet(context, ref, playing),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.textMuted.withValues(alpha: 0.08),
                      ),
                      child: Icon(Icons.settings, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  // ══════════════════════════════════════════════════════
  //  SETTINGS BOTTOM SHEET — all controls organized
  // ══════════════════════════════════════════════════════

  void _showSettingsSheet(BuildContext context, WidgetRef ref, bool playing, {int initialSection = -1}) {
    final lang = ref.read(langProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, watchRef, _) {
            final timeSig = watchRef.watch(timeSigProvider);
            final subdivision = watchRef.watch(subdivisionProvider);
            final clickSound = watchRef.watch(clickSoundProvider);
            final swingAmt = watchRef.watch(swingProvider);
            final haptic = watchRef.watch(hapticModeProvider);
            final bpm = watchRef.watch(bpmProvider);
            final playing = watchRef.watch(playingProvider);

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 36, height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text('SETTINGS', style: GoogleFonts.outfit(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary, letterSpacing: 2.0,
                      )),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // ═══ SUBDIVISION ═══
                            _settingsSectionHeader(tr(lang, 'subdivision')),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _subBtn(1, tr(lang, 'quarter'), subdivision),
                                _subBtn(2, tr(lang, 'eighth'), subdivision),
                                _subBtn(3, tr(lang, 'triplet'), subdivision),
                                _subBtn(4, tr(lang, 'sixteenth'), subdivision),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ═══ COUNT-IN ═══
                            _settingsSectionHeader(tr(lang, 'countIn')),
                            const SizedBox(height: 6),
                            Row(
                              children: [0, 1, 2, 4].map((bars) {
                                final active = watchRef.watch(countInBarsProvider) == bars;
                                final label = bars == 0 ? 'Off' : '$bars';
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: AppTheme.chip(
                                      label: label,
                                      active: active,
                                      activeColor: AppColors.accent2,
                                      onTap: () {
                                        ref.read(countInBarsProvider.notifier).state = bars;
                                      },
                                      fontSize: 11,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),

                            // ═══ SWING ═══
                            _settingsSectionHeader(tr(lang, 'swingHuman')),
                            const SizedBox(height: 6),
                            AppTheme.premiumSlider(
                              value: swingAmt.toDouble(),
                              min: 0, max: 100,
                              label: tr(lang, 'swing'),
                              valueText: '$swingAmt%',
                              onChanged: (v) {
                                ref.read(swingProvider.notifier).state = v.round();
                                if (playing) ref.read(audioServiceProvider).updateSwing(v.round());
                              },
                            ),
                            const SizedBox(height: 12),

                            // ═══ TEMPO TRAINER ═══
                            _buildTempoTrainerPanel(lang, bpm, playing),
                            const SizedBox(height: 6),

                            // ═══ POLYRHYTHM (if !kIsWeb) ═══
                            if (!kIsWeb) ...[
                              _buildPolyrhythmPanel(timeSig, lang),
                              const SizedBox(height: 6),
                            ],

                            // ═══ HAPTIC (if !kIsWeb) ═══
                            if (!kIsWeb)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: AppColors.bgPanel,
                                  border: Border.all(color: AppColors.border, width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.vibration, size: 16, color: haptic ? AppColors.accent : AppColors.textMuted),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('HAPTIC FEEDBACK', style: GoogleFonts.outfit(
                                        fontSize: 12, fontWeight: FontWeight.w600,
                                        color: haptic ? AppColors.accent : AppColors.textSecondary,
                                        letterSpacing: 0.8,
                                      )),
                                    ),
                                    Switch(
                                      value: haptic,
                                      activeColor: AppColors.accent,
                                      onChanged: (v) {
                                        ref.read(hapticModeProvider.notifier).state = v;
                                        if (playing) ref.read(audioServiceProvider).setHapticMode(v);
                                      },
                                    ),
                                  ],
                                ),
                              ),

                            // ═══ ACCENT LEGEND ═══
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _accentLegendDot(AppColors.warm, tr(lang, 'accent')),
                                const SizedBox(width: 10),
                                _accentLegendDot(AppColors.accent, tr(lang, 'normal')),
                                const SizedBox(width: 10),
                                _accentLegendDot(AppColors.border, tr(lang, 'muted')),
                                const SizedBox(width: 10),
                                Text('tap blocks to toggle', style: GoogleFonts.outfit(
                                  fontSize: 7, color: AppColors.textMuted, fontStyle: FontStyle.italic,
                                )),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
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

  Widget _settingsSectionHeader(String title) {
    return Row(
      children: [
        Text(title.toUpperCase(), style: GoogleFonts.outfit(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: AppColors.textMuted, letterSpacing: 1.5,
        )),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 0.5, color: AppColors.borderLight.withValues(alpha: 0.3)),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  //  CLICK SOUND PICKER — bottom sheet with grid of sounds
  // ══════════════════════════════════════════════════════

  void _showTimeSigPicker(BuildContext context, WidgetRef ref, bool playing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, watchRef, _) {
            final currentTs = watchRef.watch(timeSigProvider);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text('TIME SIGNATURE', style: GoogleFonts.outfit(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.accent, letterSpacing: 1.8,
                  )),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.0,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: timeSignatures.map((ts) {
                      final active = currentTs.label == ts.label;
                      return AppTheme.chip(
                        label: ts.label,
                        active: active,
                        activeColor: AppColors.accent,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(timeSigProvider.notifier).state = ts;
                          final newAccents = List<double>.generate(ts.num, (i) => i == 0 ? 1.0 : 0.7);
                          ref.read(accentPatternProvider.notifier).state = newAccents;
                          if (playing) {
                            ref.read(audioServiceProvider).updateTimeSignature(ts.num, ts.den);
                            ref.read(audioServiceProvider).updateAccentPattern(newAccents);
                          }
                          Navigator.pop(ctx);
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        fontSize: 12,
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showClickSoundPicker(BuildContext context, WidgetRef ref, bool playing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, watchRef, _) {
            final currentSound = watchRef.watch(clickSoundProvider);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text('CLICK SOUND', style: GoogleFonts.outfit(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.accent2, letterSpacing: 1.8,
                  )),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.0,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: clickSoundNames.map((s) {
                      final active = currentSound == s;
                      return AppTheme.chip(
                        label: s,
                        active: active,
                        activeColor: AppColors.accent2,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(clickSoundProvider.notifier).state = s;
                          if (playing) ref.read(audioServiceProvider).updateClickSound(s);
                          Navigator.pop(ctx);
                        },
                        fontSize: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  //  POLYRHYTHM — panel for settings sheet
  // ══════════════════════════════════════════════════════

  Widget _buildPolyrhythmPanel(TimeSig timeSig, String lang) {
    final enabled = ref.watch(polyrhythmEnabledProvider);
    final polyValue = ref.watch(polyrhythmValueProvider);
    final primaryBeats = timeSig.num;

    return _practiceCard(
      tr(lang, 'polyrhythm'), '$polyValue : $primaryBeats',
      enabled,
      (v) {
        ref.read(polyrhythmEnabledProvider.notifier).state = v;
        if (ref.read(playingProvider)) {
          ref.read(audioServiceProvider).updatePolyrhythm(v, ref.read(polyrhythmValueProvider));
        }
      },
      enabled ? Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$polyValue', style: AppTheme.monoStyle(size: 28, weight: FontWeight.w800, color: AppColors.accent3)),
              Text(' : ', style: AppTheme.monoStyle(size: 28, color: AppColors.textMuted)),
              Text('$primaryBeats', style: AppTheme.monoStyle(size: 28, weight: FontWeight.w800, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [2, 3, 4, 5, 6, 7].map((v) {
              final active = polyValue == v;
              return AppTheme.chip(
                label: '$v',
                active: active,
                activeColor: AppColors.accent3,
                onTap: () {
                  ref.read(polyrhythmValueProvider.notifier).state = v;
                  if (ref.read(playingProvider)) {
                    ref.read(audioServiceProvider).updatePolyrhythm(true, v);
                  }
                },
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildPolyrhythmGrid(primaryBeats, polyValue),
        ],
      ) : null,
    );
  }

  Widget _buildPolyrhythmGrid(int primary, int poly) {
    final lcmVal = _lcm(primary, poly);
    final slots = lcmVal;
    final primaryHits = List.generate(slots, (i) => i % (slots ~/ primary) == 0);
    final polyHits = List.generate(slots, (i) => i % (slots ~/ poly) == 0);

    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 24, child: Text('$primary', style: AppTheme.monoStyle(size: 10, color: AppColors.accent))),
            ...List.generate(slots, (i) => Expanded(
              child: Container(
                height: 16, margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: primaryHits[i] ? AppColors.accent : AppColors.bgInput,
                ),
              ),
            )),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(width: 24, child: Text('$poly', style: AppTheme.monoStyle(size: 10, color: AppColors.accent3))),
            ...List.generate(slots, (i) => Expanded(
              child: Container(
                height: 16, margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: polyHits[i] ? AppColors.accent3 : AppColors.bgInput,
                ),
              ),
            )),
          ],
        ),
      ],
    );
  }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
  int _lcm(int a, int b) => (a * b) ~/ _gcd(a, b);

  Widget _accentLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.outfit(fontSize: 9, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _subBtn(int value, String label, int current) {
    final active = current == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: AppTheme.chip(
          label: label,
          active: active,
          onTap: () {
            ref.read(subdivisionProvider.notifier).state = value;
            if (ref.read(playingProvider)) {
              ref.read(audioServiceProvider).updateSubdivision(value);
            }
          },
          fontSize: 11,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  LCD INFO BAR — n-Track / Pro Metronome style
  // ══════════════════════════════════════════════════════

  Widget _buildLcdInfoBar(String clickSound, int currentBeat, String tempoName) {
    final lcdLabel = GoogleFonts.robotoMono(
      fontSize: 7, fontWeight: FontWeight.w500,
      color: const Color(0xFF3A4E2A), letterSpacing: 1.2,
    );
    final lcdValue = GoogleFonts.robotoMono(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: const Color(0xFF8EC828),
    );
    final displaySound = clickSound.length > 9
        ? clickSound.substring(0, 9).toUpperCase()
        : clickSound.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF060A06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF182014), width: 0.6),
        boxShadow: const [
          BoxShadow(color: Color(0xFF020402), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // SOUND
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('SOUND', style: lcdLabel),
            Text(displaySound, style: lcdValue, overflow: TextOverflow.ellipsis),
          ])),
          Container(width: 0.5, height: 24, color: const Color(0xFF1A2814)),
          // BAR.BEAT
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('BAR \u00B7 BEAT', style: lcdLabel),
            Text('$_barCount.${currentBeat + 1}', style: lcdValue),
          ])),
          Container(width: 0.5, height: 24, color: const Color(0xFF1A2814)),
          // TEMPO NAME
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('TEMPO', style: lcdLabel),
            Text(
              tempoName.toUpperCase(),
              style: lcdValue.copyWith(fontSize: tempoName.length > 8 ? 8.0 : 10.0),
              overflow: TextOverflow.ellipsis,
            ),
          ])),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  TEMPO TRAINER PANEL
  // ══════════════════════════════════════════════════════

  Widget _buildTempoTrainerPanel(String lang, int bpm, bool playing) {
    return _practiceCard(
      'TEMPO TRAINER',
      '$_trainerStart \u2192 $_trainerEnd BPM  \u00B7  +$_trainerStep every $_trainerEvery bars',
      _trainerRunning,
      (enabled) {
        setState(() {
          _trainerRunning = enabled;
          _trainerBarsElapsed = 0;
          if (enabled) {
            final startBpm = _trainerStart.clamp(20, 300);
            ref.read(bpmProvider.notifier).state = startBpm;
            if (playing) ref.read(audioServiceProvider).updateBpm(startBpm);
          }
        });
      },
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _trainerDisplay('START', _trainerStart, 'BPM',
              (v) => setState(() => _trainerStart = v.clamp(20, 300))),
            const SizedBox(width: 8),
            _trainerDisplay('END', _trainerEnd, 'BPM',
              (v) => setState(() => _trainerEnd = v.clamp(20, 300))),
            const SizedBox(width: 8),
            _trainerDisplay('+STEP', _trainerStep, 'BPM',
              (v) => setState(() => _trainerStep = v.clamp(1, 50))),
            const SizedBox(width: 8),
            _trainerDisplay('EVERY', _trainerEvery, 'bars',
              (v) => setState(() => _trainerEvery = v.clamp(1, 16))),
          ]),
          const SizedBox(height: 8),
          Text(
            'Swipe up/down on each display to adjust  \u00B7  toggle switch to start',
            style: GoogleFonts.outfit(fontSize: 9, color: AppColors.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _trainerDisplay(String label, int value, String unit, Function(int) onChanged) {
    return Expanded(
      child: GestureDetector(
        onPanUpdate: (d) => onChanged(value + (-d.delta.dy * 0.4).round()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF070B07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF182014), width: 0.7),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: GoogleFonts.robotoMono(
              fontSize: 7, color: const Color(0xFF3A4E2A), letterSpacing: 0.8,
            )),
            const SizedBox(height: 3),
            Text('$value', style: GoogleFonts.robotoMono(
              fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF8EC828),
            )),
            Text(unit, style: GoogleFonts.robotoMono(
              fontSize: 6, color: const Color(0xFF3A4E2A),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _practiceCard(String title, String desc, bool enabled, Function(bool) onToggle, Widget? content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassCard(
        borderColor: enabled ? AppColors.accent.withValues(alpha: 0.2) : null,
        glowColor: enabled ? AppColors.accent : null,
      ),
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
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                    )),
                    const SizedBox(height: 2),
                    Text(desc, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Switch(value: enabled, activeColor: AppColors.accent, onChanged: onToggle),
            ],
          ),
          if (content != null) ...[const SizedBox(height: 12), content],
        ],
      ),
    );
  }
}

/// Premium audio knob painter — studio-grade dial with gradient arc, ticks & LED indicator.
///
/// Expert 3 upgrades:
///   * Dual-color progress arc (cyan -> green) with 3.5px core + wide outer glow
///   * Beat-pulse: LED expands + arc brightens on each click event
///   * Tick BPM zones: grey (slow), accent (mid), accent2 (fast) coloring
class _KnobPainter extends CustomPainter {
  final double progress; // 0.0 - 1.0
  final double beatPulse;
  final bool isPlaying;

  _KnobPainter({required this.progress, required this.beatPulse, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 4;
    final innerR = outerR - 22;
    final tickR  = outerR - 3;

    // ── Neumorphic outer ring — metallic sweep gradient ──
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFF1A1A1A), Color(0xFF2C2C2C), Color(0xFF191919),
          Color(0xFF2C2C2C), Color(0xFF1A1A1A),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerR))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawCircle(center, outerR - 11, ringPaint);

    // ── Neumorphic top-left light bevel ──
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerR - 11),
      3.93, 1.57, false,
      Paint()
        ..color = const Color(0xFF303030).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22,
    );

    // ── Outer edge line ──
    canvas.drawCircle(center, outerR, Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);

    // ── Knurled grip marks (Pro Metronome / n-Track style) ──
    const numKnurls = 72;
    final rMid = outerR - 11.0; // center of the ring band
    for (int k = 0; k < numKnurls; k++) {
      final angle = (k / numKnurls) * 2 * pi;
      final inner2 = rMid - 5.5;
      final outer2 = rMid + 5.5;
      // Base knurl line (dark groove)
      canvas.drawLine(
        Offset(center.dx + inner2 * cos(angle), center.dy + inner2 * sin(angle)),
        Offset(center.dx + outer2 * cos(angle), center.dy + outer2 * sin(angle)),
        Paint()
          ..color = const Color(0xFF282828)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
      // Highlight edge (top half gets a lighter edge for 3D feel)
      final inTop  = angle > pi * 1.05 && angle < pi * 1.95;
      if (!inTop) {
        canvas.drawLine(
          Offset(center.dx + (inner2 + 1) * cos(angle), center.dy + (inner2 + 1) * sin(angle)),
          Offset(center.dx + (inner2 + 3) * cos(angle), center.dy + (inner2 + 3) * sin(angle)),
          Paint()
            ..color = const Color(0xFF4A4A4A).withValues(alpha: 0.55)
            ..strokeWidth = 0.8
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── Inner neumorphic shadow ring ──
    canvas.drawCircle(center, innerR + 1, Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
    canvas.drawCircle(center, innerR - 1, Paint()
      ..color = const Color(0xFF2A2A2A).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // ── Inner display fill — deep inset ──
    canvas.drawCircle(center, innerR, Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1D1D1D), const Color(0xFF121212)],
        center: const Alignment(-0.25, -0.25),
      ).createShader(Rect.fromCircle(center: center, radius: innerR)));

    // ── Tick marks — 3 color zones ──
    const totalTicks = 40;
    const startAngle = 2.35619; // 135 degrees
    const sweepAngle = 4.71239; // 270 degrees
    for (int i = 0; i <= totalTicks; i++) {
      final frac    = i / totalTicks;
      final angle   = startAngle + sweepAngle * frac;
      final isMajor = i % 5 == 0;
      final isLit   = frac <= progress;

      // Zone coloring: slow (cyan), mid (green), fast (orange)
      Color litColor;
      if (frac < 0.4) {
        litColor = AppColors.accent.withValues(alpha: isMajor ? 0.95 : 0.55);
      } else if (frac < 0.75) {
        litColor = AppColors.accent2.withValues(alpha: isMajor ? 0.90 : 0.50);
      } else {
        litColor = AppColors.warm.withValues(alpha: isMajor ? 0.88 : 0.48);
      }

      final innerTick = tickR - (isMajor ? 11 : 5);
      canvas.drawLine(
        Offset(center.dx + innerTick * cos(angle), center.dy + innerTick * sin(angle)),
        Offset(center.dx + tickR * cos(angle), center.dy + tickR * sin(angle)),
        Paint()
          ..color = isLit ? litColor : (isMajor ? const Color(0xFF323232) : const Color(0xFF252525))
          ..strokeWidth = isMajor ? 2.2 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Active arc — dual-color gradient: cyan -> green with glow ──
    if (isPlaying && progress > 0) {
      final arcRect = Rect.fromCircle(center: center, radius: innerR + 4);
      final arcEnd  = sweepAngle * progress;

      // Zone: determine blend color at current progress
      final Color arcEndColor = progress < 0.4
          ? AppColors.accent
          : progress < 0.75
              ? AppColors.accent2
              : AppColors.warm;

      // Wide outer ambient glow
      canvas.drawArc(
        arcRect, startAngle, arcEnd, false,
        Paint()
          ..shader = SweepGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.0),
              AppColors.accent.withValues(alpha: 0.10 + beatPulse * 0.08),
              arcEndColor.withValues(alpha: 0.14 + beatPulse * 0.10),
            ],
            stops: [0.0, startAngle / (2 * pi), (startAngle + arcEnd) / (2 * pi)],
          ).createShader(Rect.fromCircle(center: center, radius: innerR + 4))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Mid glow ring
      canvas.drawArc(
        arcRect, startAngle, arcEnd, false,
        Paint()
          ..color = arcEndColor.withValues(alpha: 0.22 + beatPulse * 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Core arc — solid + bright
      canvas.drawArc(
        arcRect, startAngle, arcEnd, false,
        Paint()
          ..color = arcEndColor.withValues(alpha: 0.80 + beatPulse * 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── LED position indicator dot ──
    final posAngle = startAngle + sweepAngle * progress;
    final dotR   = outerR - 11;
    final dotPos = Offset(
      center.dx + dotR * cos(posAngle),
      center.dy + dotR * sin(posAngle),
    );

    // Beat-pulse outer halo — expands on each beat
    if (beatPulse > 0.01) {
      canvas.drawCircle(dotPos, 10 + beatPulse * 8, Paint()
        ..color = AppColors.accent.withValues(alpha: beatPulse * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    // Inner glow
    canvas.drawCircle(dotPos, 7 + beatPulse * 3, Paint()
      ..color = AppColors.accent.withValues(alpha: 0.20 + beatPulse * 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // LED body
    canvas.drawCircle(dotPos, 5.0 + beatPulse * 1.0, Paint()..color = AppColors.accent);
    // LED specular highlight
    canvas.drawCircle(
      Offset(dotPos.dx - 1.4, dotPos.dy - 1.4), 1.6,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _KnobPainter old) =>
    old.progress != progress || old.beatPulse != beatPulse || old.isPlaying != isPlaying;
}

// ═══════════════════════════════════════════════════════════════
//  BEAT BLOCKS DISPLAY
//  Animated vertical bars — Pro Metronome / n-Track style.
//  Each bar jumps to full height on its beat then decays to rest.
//  Tap a bar to cycle: accent -> normal -> muted -> accent.
// ═══════════════════════════════════════════════════════════════

class _BeatBlocksDisplay extends StatelessWidget {
  final int numBeats;
  final int currentBeat;
  final List<double> accents;
  final bool isPlaying;
  final double height;
  final void Function(int) onTapBeat;

  const _BeatBlocksDisplay({
    required this.numBeats,
    required this.currentBeat,
    required this.accents,
    required this.isPlaying,
    required this.height,
    required this.onTapBeat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF060A0E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A2232), width: 0.7),
        boxShadow: const [
          BoxShadow(color: Color(0xFF030507), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(numBeats, (i) {
            final isAccent = i < accents.length && accents[i] >= 0.9;
            final isMuted  = i < accents.length && accents[i] < 0.3;
            final isActive = isPlaying && currentBeat == i;

            // Pro Metronome palette: accent = warm orange, normal = cyan, muted = dim
            final barColor = isAccent
                ? AppColors.warm       // orange
                : AppColors.accent;    // cyan

            final restColor = isMuted
                ? const Color(0xFF141820)
                : isAccent
                    ? AppColors.warm.withValues(alpha: 0.14)
                    : AppColors.accent.withValues(alpha: 0.10);

            // Active bar height (full), rest bar height (fraction of container)
            final maxH   = height - 16;
            final activeH = isAccent ? maxH : maxH * 0.82;
            final restH   = isMuted  ? 5.0  : maxH * 0.28;

            return Expanded(
              child: GestureDetector(
                onTap: () => onTapBeat(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // ── The animated bar ──
                      AnimatedContainer(
                        duration: isActive
                            ? const Duration(milliseconds: 30)   // fast attack
                            : const Duration(milliseconds: 380), // slow phosphor decay
                        curve: Curves.easeOut,
                        width: double.infinity,
                        height: isActive ? activeH : restH,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: isActive ? barColor : restColor,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: barColor.withValues(alpha: 0.65),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: barColor.withValues(alpha: 0.30),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // ── Beat number dot ──
                      AnimatedContainer(
                        duration: isActive
                            ? const Duration(milliseconds: 30)
                            : const Duration(milliseconds: 350),
                        width: isActive ? 5 : 3,
                        height: isActive ? 5 : 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? barColor
                              : isMuted
                                  ? const Color(0xFF1A1E24)
                                  : barColor.withValues(alpha: 0.25),
                          boxShadow: isActive
                              ? [BoxShadow(color: barColor.withValues(alpha: 0.7), blurRadius: 6)]
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
