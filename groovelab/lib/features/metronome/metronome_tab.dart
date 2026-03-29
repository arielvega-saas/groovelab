import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';
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
        style: AppFonts.jetBrainsMono(
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
          hintStyle: AppFonts.jetBrainsMono(fontSize: 14, color: AppColors.textMuted),
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
      final knobSize = availH < 520 ? 200.0 : availH < 650 ? 250.0 : 290.0;

      return Container(
        color: AppColors.bgDark,
        child: Column(
          children: [
            // ══════════════════════════════════════════════════════
            //  MAIN SECTION
            // ══════════════════════════════════════════════════════
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Column(
                  children: [
                    // ── Beat indicator dots ──
                    _BeatDotsDisplay(
                      numBeats: timeSig.num,
                      currentBeat: currentBeat,
                      accents: accents,
                      isPlaying: playing,
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
                    const SizedBox(height: 8),

                    // ── BPM Circular Dial ──
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
                                // Dial painter with tick marks
                                CustomPaint(
                                  size: Size(knobSize, knobSize),
                                  painter: _DialPainter(
                                    progress: progress,
                                    beatPulse: widget.beatPulse,
                                    isPlaying: playing,
                                  ),
                                ),
                                // Inner display area
                                GestureDetector(
                                  onTap: () => _showBpmInput(context, ref, bpm, playing),
                                  child: Container(
                                    width: knobSize * 0.55,
                                    height: knobSize * 0.55,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.bgInset,
                                      border: Border.all(
                                        color: playing
                                            ? AppColors.accent.withValues(alpha: 0.25)
                                            : const Color(0xFF2A2A2A),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        const BoxShadow(
                                          color: Color(0xFF0A0A0A),
                                          blurRadius: 8,
                                          offset: Offset(2, 2),
                                          spreadRadius: -1,
                                        ),
                                        if (playing) BoxShadow(
                                          color: AppColors.accent.withValues(
                                            alpha: 0.15 + widget.beatPulse * 0.20),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // BPM number -- large monospace
                                        Text(
                                          '$bpm',
                                          style: AppFonts.jetBrainsMono(
                                            fontSize: knobSize * 0.18,
                                            fontWeight: FontWeight.w800,
                                            color: playing ? AppColors.accent : AppColors.textPrimary,
                                            shadows: playing ? [
                                              Shadow(
                                                color: AppColors.accent.withValues(alpha: 0.60),
                                                blurRadius: 12,
                                              ),
                                            ] : null,
                                          ),
                                        ),
                                        // BPM label
                                        Text('BPM', style: AppFonts.outfit(
                                          fontSize: 9,
                                          color: playing
                                              ? AppColors.accent.withValues(alpha: 0.60)
                                              : AppColors.textMuted,
                                          letterSpacing: 3,
                                          fontWeight: FontWeight.w600,
                                        )),
                                        const SizedBox(height: 2),
                                        // Tempo name
                                        Text(tempoName, style: AppFonts.outfit(
                                          fontSize: 10,
                                          color: playing
                                              ? AppColors.accent.withValues(alpha: 0.50)
                                              : AppColors.textMuted.withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.5,
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

                    // ── Transport row: -5 -1 [PLAY] +1 +5 ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppTheme.bpmStepButton(label: '\u22125', onTap: () {
                          final n = (bpm - 5).clamp(20, 500);
                          ref.read(bpmProvider.notifier).state = n;
                          if (playing) ref.read(audioServiceProvider).updateBpm(n);
                        }),
                        AppTheme.bpmStepButton(label: '\u22121', onTap: () {
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
                    const SizedBox(height: 6),

                    // ── TAP TEMPO button ──
                    GestureDetector(
                      onTap: widget.onTapTempo,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: AppColors.bgPanel,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.30),
                            width: 1.0,
                          ),
                          boxShadow: AppColors.neumorphicRaised(scale: 0.6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text('TAP', style: AppFonts.jetBrainsMono(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
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
                    // ── Time Signature ──
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
                                style: AppFonts.jetBrainsMono(
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
                    // ── Click Sound ──
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
                                  style: AppFonts.outfit(
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
                    // ── Settings ──
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
        ),
      );
    });
  }

  // ══════════════════════════════════════════════════════
  //  SETTINGS BOTTOM SHEET
  // ══════════════════════════════════════════════════════

  void _showSettingsSheet(BuildContext context, WidgetRef ref, bool playing) {
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
                      Container(
                        width: 36, height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text('SETTINGS', style: AppFonts.outfit(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary, letterSpacing: 2.0,
                      )),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
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

                            _buildTempoTrainerPanel(lang, bpm, playing),
                            const SizedBox(height: 6),

                            if (!kIsWeb) ...[
                              _buildPolyrhythmPanel(timeSig, lang),
                              const SizedBox(height: 6),
                            ],

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
                                      child: Text('HAPTIC FEEDBACK', style: AppFonts.outfit(
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
                                Text('tap blocks to toggle', style: AppFonts.outfit(
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
        Text(title.toUpperCase(), style: AppFonts.outfit(
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
  //  TIME SIG & CLICK SOUND PICKERS
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
                  Text('TIME SIGNATURE', style: AppFonts.outfit(
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
                  Text('CLICK SOUND', style: AppFonts.outfit(
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
  //  POLYRHYTHM
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
        Text(label, style: AppFonts.outfit(fontSize: 9, color: AppColors.textMuted)),
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
  //  TEMPO TRAINER
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
            style: AppFonts.outfit(fontSize: 9, color: AppColors.textMuted, fontStyle: FontStyle.italic),
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
            Text(label, style: AppFonts.robotoMono(
              fontSize: 7, color: const Color(0xFF3A4E2A), letterSpacing: 0.8,
            )),
            const SizedBox(height: 3),
            Text('$value', style: AppFonts.robotoMono(
              fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF8EC828),
            )),
            Text(unit, style: AppFonts.robotoMono(
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
                    Text(title, style: AppFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                    )),
                    const SizedBox(height: 2),
                    Text(desc, style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
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

// ═══════════════════════════════════════════════════════════════
//  DIAL PAINTER — Clean circular gauge with tick marks
//  BIAS FX 2 style: ticks around edge, cyan accent arc
// ═══════════════════════════════════════════════════════════════

class _DialPainter extends CustomPainter {
  final double progress; // 0.0 - 1.0
  final double beatPulse;
  final bool isPlaying;

  _DialPainter({required this.progress, required this.beatPulse, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 6;
    final tickR = outerR - 2;

    const startAngle = 2.35619; // 135 degrees
    const sweepAngle = 4.71239; // 270 degrees

    // ── Background track arc ──
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerR - 8),
      startAngle, sweepAngle, false,
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // ── Tick marks (40 total) ──
    const totalTicks = 40;
    for (int i = 0; i <= totalTicks; i++) {
      final frac = i / totalTicks;
      final angle = startAngle + sweepAngle * frac;
      final isMajor = i % 5 == 0;
      final isLit = frac <= progress;

      Color tickColor;
      if (isLit) {
        if (frac < 0.4) {
          tickColor = AppColors.accent.withValues(alpha: isMajor ? 0.90 : 0.50);
        } else if (frac < 0.75) {
          tickColor = AppColors.accent2.withValues(alpha: isMajor ? 0.85 : 0.45);
        } else {
          tickColor = AppColors.warm.withValues(alpha: isMajor ? 0.85 : 0.45);
        }
      } else {
        tickColor = isMajor ? const Color(0xFF2E2E2E) : const Color(0xFF222222);
      }

      final innerTick = tickR - (isMajor ? 14 : 7);
      canvas.drawLine(
        Offset(center.dx + innerTick * cos(angle), center.dy + innerTick * sin(angle)),
        Offset(center.dx + tickR * cos(angle), center.dy + tickR * sin(angle)),
        Paint()
          ..color = tickColor
          ..strokeWidth = isMajor ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Active arc glow (when playing) ──
    if (isPlaying && progress > 0) {
      final arcRect = Rect.fromCircle(center: center, radius: outerR - 8);
      final arcEnd = sweepAngle * progress;

      final Color arcColor = progress < 0.4
          ? AppColors.accent
          : progress < 0.75
              ? AppColors.accent2
              : AppColors.warm;

      // Soft glow
      canvas.drawArc(
        arcRect, startAngle, arcEnd, false,
        Paint()
          ..color = arcColor.withValues(alpha: 0.12 + beatPulse * 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Core arc
      canvas.drawArc(
        arcRect, startAngle, arcEnd, false,
        Paint()
          ..color = arcColor.withValues(alpha: 0.70 + beatPulse * 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── LED position indicator ──
    final posAngle = startAngle + sweepAngle * progress;
    final dotR = outerR - 8;
    final dotPos = Offset(
      center.dx + dotR * cos(posAngle),
      center.dy + dotR * sin(posAngle),
    );

    if (beatPulse > 0.01) {
      canvas.drawCircle(dotPos, 8 + beatPulse * 6, Paint()
        ..color = AppColors.accent.withValues(alpha: beatPulse * 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    canvas.drawCircle(dotPos, 5.0, Paint()..color = AppColors.accent);
    canvas.drawCircle(
      Offset(dotPos.dx - 1.2, dotPos.dy - 1.2), 1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.80),
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
    old.progress != progress || old.beatPulse != beatPulse || old.isPlaying != isPlaying;
}

// ═══════════════════════════════════════════════════════════════
//  BEAT DOTS DISPLAY — BIAS FX 2 style
//  Clean dots that light up on active beat.
//  Downbeat (accent) = brighter color, larger.
//  FIX: Only active beat highlights; others keep base color.
// ═══════════════════════════════════════════════════════════════

class _BeatDotsDisplay extends StatelessWidget {
  final int numBeats;
  final int currentBeat;
  final List<double> accents;
  final bool isPlaying;
  final void Function(int) onTapBeat;

  const _BeatDotsDisplay({
    required this.numBeats,
    required this.currentBeat,
    required this.accents,
    required this.isPlaying,
    required this.onTapBeat,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(numBeats, (i) {
          final isAccent = i < accents.length && accents[i] >= 0.9;
          final isMuted = i < accents.length && accents[i] < 0.3;
          final isActive = isPlaying && currentBeat == i;

          // Base color for this beat type
          final Color baseColor = isMuted
              ? const Color(0xFF1E1E1E)
              : isAccent
                  ? AppColors.warm
                  : AppColors.accent;

          // Active = full brightness, rest = dim base color
          final Color dotColor = isActive
              ? baseColor
              : isMuted
                  ? const Color(0xFF1E1E1E)
                  : baseColor.withValues(alpha: 0.25);

          final double dotSize = isActive
              ? (isAccent ? 20.0 : 16.0)
              : (isAccent ? 14.0 : 12.0);

          return GestureDetector(
            onTap: () => onTapBeat(i),
            child: Container(
              width: 44, height: 44,
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: isActive
                    ? const Duration(milliseconds: 40)
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.65),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.30),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ] : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
