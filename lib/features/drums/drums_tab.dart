import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/audio/audio_service.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';

class DrumsTab extends ConsumerStatefulWidget {
  final VoidCallback onTogglePlay;
  final double beatPulse;

  const DrumsTab({
    super.key,
    required this.onTogglePlay,
    required this.beatPulse,
  });

  @override
  ConsumerState<DrumsTab> createState() => _DrumsTabState();
}

class _DrumsTabState extends ConsumerState<DrumsTab> {

  void _showStylePicker(BuildContext context) {
    final drumStyle = ref.read(drumStyleProvider);
    final playing = ref.read(playingProvider);
    final dTimeSig = ref.read(drumTimeSigProvider);
    final totalSteps = drumTotalSteps(dTimeSig.num, dTimeSig.den);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text('DRUM STYLE', style: AppFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted, letterSpacing: 2,
                )),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: drumStyles.map((s) {
                    final active = drumStyle == s;
                    return GestureDetector(
                      onTap: () {
                        ref.read(drumStyleProvider.notifier).state = s;
                        ref.read(customDrumPatternProvider.notifier).state = null;
                        if (playing) {
                          final p = adaptDrumPattern(drumPatterns[s] ?? {}, totalSteps);
                          ref.read(audioServiceProvider).updateDrumPattern(p);
                        }
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppColors.accent2.withValues(alpha: 0.2) : AppColors.bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: active ? AppColors.accent2 : AppColors.border,
                            width: active ? 1.5 : 0.8,
                          ),
                        ),
                        child: Text(s, style: AppFonts.outfit(
                          fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AppColors.accent2 : AppColors.textSecondary,
                        )),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMixerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Text('MIXER', style: AppFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted, letterSpacing: 2,
                )),
                const SizedBox(height: 8),
                Consumer(builder: (_, ref, __) => _buildDrumMixer(ref)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTimeSigSheet(BuildContext context) {
    final lang = ref.read(langProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(tr(lang, 'timeSignature').toUpperCase(), style: AppFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted, letterSpacing: 2,
                )),
                const SizedBox(height: 12),
                Consumer(builder: (_, ref, __) {
                  final dTimeSig = ref.watch(drumTimeSigProvider);
                  final playing = ref.watch(playingProvider);
                  return Wrap(
                    spacing: 8, runSpacing: 8,
                    children: timeSignatures.map((ts) {
                      final active = dTimeSig.label == ts.label;
                      return GestureDetector(
                        onTap: () {
                          ref.read(drumTimeSigProvider.notifier).state = ts;
                          final newAccents = List<double>.generate(ts.num, (i) => i == 0 ? 1.0 : 0.7);
                          ref.read(drumAccentPatternProvider.notifier).state = newAccents;
                          ref.read(customDrumPatternProvider.notifier).state = null;
                          if (playing) {
                            final audio = ref.read(audioServiceProvider);
                            audio.updateDrumTimeSig(ts.num, ts.den);
                            audio.updateDrumAccentPattern(newAccents);
                            final style = ref.read(drumStyleProvider);
                            final newSteps = drumTotalSteps(ts.num, ts.den);
                            final adapted = adaptDrumPattern(drumPatterns[style]!, newSteps);
                            audio.updateDrumPattern(adapted);
                          }
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 56, height: 40,
                          decoration: BoxDecoration(
                            color: active ? AppColors.accent.withValues(alpha: 0.2) : AppColors.bgInput,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active ? AppColors.accent : AppColors.border,
                              width: active ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(child: Text(ts.label, style: AppTheme.monoStyle(
                            size: 14, weight: active ? FontWeight.w800 : FontWeight.w500,
                            color: active ? AppColors.accent : AppColors.textSecondary,
                          ))),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHumanFeelSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Consumer(builder: (_, ref, __) => _buildHumanFeelPanel(ref)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final bpm = ref.watch(bpmProvider);
    final playing = ref.watch(playingProvider);
    final drumStyle = ref.watch(drumStyleProvider);
    final drumStep = ref.watch(drumStepProvider);
    final customPattern = ref.watch(customDrumPatternProvider);
    final dTimeSig = ref.watch(drumTimeSigProvider);
    final dAccents = ref.watch(drumAccentPatternProvider);
    final totalSteps = drumTotalSteps(dTimeSig.num, dTimeSig.den);
    final stepsPerBeat = drumStepsPerBeat(dTimeSig.den);
    final rawPattern = customPattern ?? drumPatterns[drumStyle]!;
    final pattern = adaptDrumPattern(rawPattern, totalSteps);
    final currentBeat = playing && drumStep >= 0
        ? (drumStep / stepsPerBeat).floor()
        : -1;
    final humanFeel = ref.watch(humanFeelProvider);
    final swing = ref.watch(swingProvider);

    return Container(
      color: AppColors.bgDark,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Column(
        children: [
          // ══════════════════════════════════════════════════════
          //  ROW 1: TRANSPORT — Style + BPM + Play + Display (~44px)
          // ══════════════════════════════════════════════════════
          Container(
            height: 48,
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: playing ? AppColors.accent.withValues(alpha: 0.35) : AppColors.border,
                width: playing ? 1.2 : 0.8,
              ),
            ),
            child: Row(
              children: [
                // Style selector button
                GestureDetector(
                  onTap: () => _showStylePicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgPanel,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accent2.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note, size: 12, color: AppColors.accent2),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 60),
                          child: Text(drumStyle, style: AppFonts.outfit(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppColors.accent2,
                          ), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.expand_more, size: 12, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Time sig button
                GestureDetector(
                  onTap: () => _showTimeSigSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgPanel,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(dTimeSig.label, style: AppTheme.monoStyle(
                      size: 11, weight: FontWeight.w700, color: AppColors.textSecondary,
                    )),
                  ),
                ),
                const SizedBox(width: 6),
                // BPM controls
                AppTheme.bpmStepButton(label: '-5', compact: true, onTap: () {
                  final n = (bpm - 5).clamp(20, 500);
                  ref.read(bpmProvider.notifier).state = n;
                  if (playing) ref.read(audioServiceProvider).updateBpm(n);
                }),
                AppTheme.bpmStepButton(label: '-1', compact: true, onTap: () {
                  final n = (bpm - 1).clamp(20, 500);
                  ref.read(bpmProvider.notifier).state = n;
                  if (playing) ref.read(audioServiceProvider).updateBpm(n);
                }),
                const SizedBox(width: 4),
                // Play/Stop
                AppTheme.transportButton(isPlaying: playing, onTap: widget.onTogglePlay, size: 56, pulseValue: widget.beatPulse),
                const SizedBox(width: 4),
                AppTheme.bpmStepButton(label: '+1', compact: true, onTap: () {
                  final n = (bpm + 1).clamp(20, 500);
                  ref.read(bpmProvider.notifier).state = n;
                  if (playing) ref.read(audioServiceProvider).updateBpm(n);
                }),
                AppTheme.bpmStepButton(label: '+5', compact: true, onTap: () {
                  final n = (bpm + 5).clamp(20, 500);
                  ref.read(bpmProvider.notifier).state = n;
                  if (playing) ref.read(audioServiceProvider).updateBpm(n);
                }),
                const Spacer(),
                // BPM display — tappable to edit
                GestureDetector(
                  onTap: () {
                    final ctrl = TextEditingController(text: '$bpm');
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.bgPanel,
                        title: Text('Set BPM', style: AppFonts.outfit(color: AppColors.textPrimary)),
                        content: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: AppTheme.monoStyle(size: 24, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '20-500',
                            hintStyle: AppFonts.outfit(color: AppColors.textMuted),
                          ),
                          onSubmitted: (val) {
                            final n = int.tryParse(val)?.clamp(20, 500);
                            if (n != null) {
                              ref.read(bpmProvider.notifier).state = n;
                              if (playing) ref.read(audioServiceProvider).updateBpm(n);
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel', style: AppFonts.outfit(color: AppColors.textMuted)),
                          ),
                          TextButton(
                            onPressed: () {
                              final n = int.tryParse(ctrl.text)?.clamp(20, 500);
                              if (n != null) {
                                ref.read(bpmProvider.notifier).state = n;
                                if (playing) ref.read(audioServiceProvider).updateBpm(n);
                              }
                              Navigator.pop(ctx);
                            },
                            child: Text('Set', style: AppFonts.outfit(color: AppColors.accent)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$bpm', style: AppTheme.monoStyle(
                        size: 18, weight: FontWeight.w800,
                        color: playing ? AppColors.accent : AppColors.textPrimary)),
                      Text('BPM', style: AppFonts.outfit(
                        fontSize: 8, color: AppColors.textMuted, letterSpacing: 2,
                        fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ══════════════════════════════════════════════════════
          //  ROW 2: BEAT ACCENT INDICATORS (~32px)
          // ══════════════════════════════════════════════════════
          SizedBox(
            height: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(dTimeSig.num, (i) {
                final vol = i < dAccents.length ? dAccents[i] : 0.7;
                final isCurrentBeat = currentBeat == i;
                return GestureDetector(
                  onTap: () {
                    final newAccents = List<double>.from(dAccents);
                    if (newAccents[i] >= 0.9) {
                      newAccents[i] = 0.7;
                    } else if (newAccents[i] >= 0.5) {
                      newAccents[i] = 0.0;
                    } else {
                      newAccents[i] = 1.0;
                    }
                    ref.read(drumAccentPatternProvider.notifier).state = newAccents;
                    if (playing) ref.read(audioServiceProvider).updateDrumAccentPattern(newAccents);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: isCurrentBeat ? 22 : 18,
                    height: isCurrentBeat ? 22 : 18,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: vol == 0
                          ? (isCurrentBeat ? AppColors.bgInput.withValues(alpha: 0.8) : AppColors.bgInput)
                          : vol >= 0.9
                              ? (isCurrentBeat ? AppColors.accent : AppColors.accent.withValues(alpha: 0.8))
                              : (isCurrentBeat ? AppColors.bgElevated : AppColors.bgElevated),
                      border: Border.all(
                        color: isCurrentBeat
                            ? AppColors.accent
                            : vol >= 0.9
                                ? AppColors.accent
                                : vol >= 0.5
                                    ? AppColors.accent2Dim
                                    : AppColors.border,
                        width: isCurrentBeat ? 2.0 : 1.5,
                      ),
                      boxShadow: isCurrentBeat
                          ? [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(child: Text('${i + 1}',
                      style: AppTheme.monoStyle(
                        size: isCurrentBeat ? 10 : 9,
                        weight: isCurrentBeat ? FontWeight.w900 : FontWeight.w600,
                        color: isCurrentBeat
                            ? Colors.white
                            : vol >= 0.9
                                ? AppColors.bgDeepest
                                : AppColors.textSecondary,
                      ),
                    )),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 0),

          // ══════════════════════════════════════════════════════
          //  ROW 3: DRUM PADS (~44px)
          // ══════════════════════════════════════════════════════
          _buildDrumPads(pattern, drumStep, playing),
          const SizedBox(height: 0),

          // ══════════════════════════════════════════════════════
          //  ROW 4: SEQUENCER GRID (Expanded to fill remaining)
          // ══════════════════════════════════════════════════════
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bgPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 0.7),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['kick', 'snare', 'hihat', 'ride'].map((inst) {
                  final row = pattern[inst]!;
                  final trackColor = instrumentColor(inst);
                  return Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Row(
                          children: [
                            Container(
                              width: 3, height: 22,
                              decoration: BoxDecoration(
                                color: trackColor,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(color: trackColor.withValues(alpha: 0.4), blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(width: 3),
                            Expanded(child: Text(
                              inst.substring(0, 2).toUpperCase(),
                              style: AppTheme.monoStyle(
                                size: 9, color: trackColor.withValues(alpha: 0.85),
                                weight: FontWeight.w700,
                              ),
                            )),
                          ],
                        ),
                      ),
                      ...List.generate(totalSteps, (i) {
                        final on = i < row.length && row[i] == 1;
                        final isPlayhead = drumStep == i;
                        final isBeatBoundary = i % stepsPerBeat == 0;
                        return Expanded(
                          child: AppTheme.drumStepCell(
                            isOn: on,
                            isPlayhead: isPlayhead,
                            isBeatBoundary: isBeatBoundary,
                            trackColor: trackColor,
                            height: 26,
                            onTap: () {
                              final newPattern = pattern.map((k, v) =>
                                MapEntry(k, List<int>.from(v)));
                              newPattern[inst]![i] = on ? 0 : 1;
                              ref.read(customDrumPatternProvider.notifier).state = newPattern;
                              if (playing) {
                                ref.read(audioServiceProvider).updateDrumPattern(newPattern);
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 2),

          // ══════════════════════════════════════════════════════
          //  ROW 5: BOTTOM BAR — Mixer + Human Feel toggle (~36px)
          // ══════════════════════════════════════════════════════
          SizedBox(
            height: 34,
            child: Row(
              children: [
                // Mixer button
                GestureDetector(
                  onTap: () => _showMixerSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgPanel,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('MIXER', style: AppFonts.outfit(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppColors.textMuted, letterSpacing: 1,
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Human feel quick info
                GestureDetector(
                  onTap: () => _showHumanFeelSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: humanFeel > 0 || swing > 0
                          ? AppColors.warning.withValues(alpha: 0.1)
                          : AppColors.bgPanel,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: humanFeel > 0 || swing > 0
                            ? AppColors.warning.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_fix_high, size: 13,
                          color: humanFeel > 0 || swing > 0
                              ? AppColors.warning
                              : AppColors.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            humanFeel > 0 || swing > 0
                                ? 'FEEL ${swing > 0 ? "SW$swing%" : ""} ${humanFeel > 0 ? "H$humanFeel%" : ""}'
                                : 'FEEL',
                            style: AppFonts.outfit(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: humanFeel > 0 || swing > 0
                                  ? AppColors.warning
                                  : AppColors.textMuted,
                              letterSpacing: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Accent legend (compact)
                _accentLegendDot(AppColors.accent, tr(lang, 'accent')),
                const SizedBox(width: 6),
                _accentLegendDot(AppColors.accent2Dim, tr(lang, 'normal')),
                const SizedBox(width: 6),
                _accentLegendDot(AppColors.border, tr(lang, 'muted')),
              ],
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildHumanFeelPanel(WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final humanFeel = ref.watch(humanFeelProvider);
    final swing = ref.watch(swingProvider);
    final playing = ref.watch(playingProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr(lang, 'swingHuman').toUpperCase(), style: AppFonts.outfit(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textMuted, letterSpacing: 2,
        )),
        const SizedBox(height: 12),
        // Swing control
        Row(
          children: [
            SizedBox(width: 60, child: Text(tr(lang, 'swing'),
              style: AppFonts.outfit(fontSize: 12, color: AppColors.textMuted))),
            Expanded(
              child: SliderTheme(
                data: AppTheme.neumorphicSliderTheme(AppColors.accent3, grooveHeight: 5, thumbRadius: 9),
                child: Slider(
                  value: swing.toDouble(), min: 0, max: 100,
                  divisions: 20,
                  onChanged: (v) {
                    ref.read(swingProvider.notifier).state = v.round();
                    if (playing) ref.read(audioServiceProvider).updateSwing(v.round());
                  },
                ),
              ),
            ),
            SizedBox(width: 50, child: Text('$swing%',
              style: AppTheme.monoStyle(size: 12, color: AppColors.textSecondary), textAlign: TextAlign.right)),
          ],
        ),
        // Human feel (velocity randomization)
        Row(
          children: [
            SizedBox(width: 60, child: Text(tr(lang, 'feel'),
              style: AppFonts.outfit(fontSize: 12, color: AppColors.textMuted))),
            Expanded(
              child: SliderTheme(
                data: AppTheme.neumorphicSliderTheme(AppColors.warning, grooveHeight: 5, thumbRadius: 9),
                child: Slider(
                  value: humanFeel.toDouble(), min: 0, max: 50,
                  divisions: 10,
                  onChanged: (v) {
                    ref.read(humanFeelProvider.notifier).state = v.round();
                    if (playing) ref.read(audioServiceProvider).updateHumanFeel(v.round());
                  },
                ),
              ),
            ),
            SizedBox(width: 50, child: Text('$humanFeel%',
              style: AppTheme.monoStyle(size: 12, color: AppColors.textSecondary), textAlign: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          humanFeel == 0
            ? tr(lang, 'feelMachine')
            : humanFeel <= 15
              ? tr(lang, 'feelSubtle')
              : humanFeel <= 30
                ? tr(lang, 'feelNatural')
                : tr(lang, 'feelLoose'),
          style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDrumMixer(WidgetRef ref) {
    final volumes = ref.watch(drumVolumesProvider);
    final mutes = ref.watch(drumMuteProvider);
    final solos = ref.watch(drumSoloProvider);
    final playing = ref.watch(playingProvider);

    final tracks = [
      {'key': 'kick',  'label': 'Kick',   'icon': Icons.circle,                'color': AppColors.kick},
      {'key': 'snare', 'label': 'Snare',  'icon': Icons.radio_button_unchecked, 'color': AppColors.snare},
      {'key': 'hihat', 'label': 'Hi-Hat', 'icon': Icons.change_history,         'color': AppColors.hihat},
      {'key': 'ride',  'label': 'Ride',   'icon': Icons.album_outlined,         'color': AppColors.ride},
    ];

    return SizedBox(
      height: 290,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: tracks.map((t) {
          final key   = t['key']   as String;
          final label = t['label'] as String;
          final icon  = t['icon']  as IconData;
          final color = t['color'] as Color;
          final vol   = volumes[key] ?? 1.0;
          final isMuted = mutes[key] ?? false;
          final isSoloed = solos[key] ?? false;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AppTheme.logicChannelStrip(
                color: color,
                name: label,
                volume: vol,
                muted: isMuted,
                solo: isSoloed,
                onVolume: (v) {
                  final updated = Map<String, double>.from(volumes);
                  updated[key] = v;
                  ref.read(drumVolumesProvider.notifier).state = updated;
                  if (playing) {
                    final effective = computeEffectiveDrumVolumes(
                      volumes: updated, mutes: mutes, solos: solos,
                    );
                    ref.read(audioServiceProvider).updateDrumVolumes(effective);
                  }
                },
                onMute: () {
                  final updated = Map<String, bool>.from(mutes);
                  updated[key] = !isMuted;
                  ref.read(drumMuteProvider.notifier).state = updated;
                  // Send effective volumes to audio engine
                  final effective = computeEffectiveDrumVolumes(
                    volumes: volumes, mutes: updated, solos: solos,
                  );
                  ref.read(audioServiceProvider).updateDrumVolumes(effective);
                },
                onSolo: () {
                  final updated = Map<String, bool>.from(solos);
                  updated[key] = !isSoloed;
                  ref.read(drumSoloProvider.notifier).state = updated;
                  // Send effective volumes to audio engine
                  final effective = computeEffectiveDrumVolumes(
                    volumes: volumes, mutes: mutes, solos: updated,
                  );
                  ref.read(audioServiceProvider).updateDrumVolumes(effective);
                },
                trackIcon: icon,
                faderHeight: 130,
                stripWidth: 68,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _accentLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(
          shape: BoxShape.circle, color: color)),
        const SizedBox(width: 3),
        Text(label, style: AppFonts.outfit(fontSize: 9, color: AppColors.textMuted)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MANUAL DRUM PADS — tap to trigger + beat-synced glow
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDrumPads(Map<String, List<int>> pattern, int drumStep, bool playing) {
    final volumes = ref.watch(drumVolumesProvider);
    final mutes = ref.watch(drumMuteProvider);
    final solos = ref.watch(drumSoloProvider);
    final effectiveVols = computeEffectiveDrumVolumes(
      volumes: volumes, mutes: mutes, solos: solos,
    );

    final instruments = [
      {'key': 'kick',  'label': 'KICK',  'short': 'KI', 'icon': Icons.circle,                'color': AppColors.kick},
      {'key': 'snare', 'label': 'SNR',   'short': 'SN', 'icon': Icons.radio_button_unchecked, 'color': AppColors.snare},
      {'key': 'hihat', 'label': 'HAT',   'short': 'HH', 'icon': Icons.change_history,         'color': AppColors.hihat},
      {'key': 'ride',  'label': 'RIDE',  'short': 'RI', 'icon': Icons.album_outlined,         'color': AppColors.ride},
    ];

    return SizedBox(
      height: 44,
      child: Row(
        children: instruments.map((inst) {
          final key = inst['key'] as String;
          final label = inst['label'] as String;
          final icon = inst['icon'] as IconData;
          final color = inst['color'] as Color;
          final row = pattern[key] ?? [];
          final isSeqActive = playing && drumStep >= 0 && drumStep < row.length && row[drumStep] == 1;
          final padVol = effectiveVols[key] ?? 1.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _DrumPad(
                label: label,
                icon: icon,
                color: color,
                isSeqActive: isSeqActive,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref.read(audioServiceProvider).playDrumHit(key, volume: padVol);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DRUM PAD WIDGET — compact with LED glow on beat
// ═══════════════════════════════════════════════════════════════════

class _DrumPad extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSeqActive;
  final VoidCallback onTap;

  const _DrumPad({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSeqActive,
    required this.onTap,
  });

  @override
  State<_DrumPad> createState() => _DrumPadState();
}

class _DrumPadState extends State<_DrumPad> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _hitCtrl;

  @override
  void initState() {
    super.initState();
    _hitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void didUpdateWidget(_DrumPad old) {
    super.didUpdateWidget(old);
    if (widget.isSeqActive && !old.isSeqActive) {
      _hitCtrl.forward(from: 0).then((_) => _hitCtrl.reverse());
    }
  }

  @override
  void dispose() {
    _hitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final isLit = _pressed || widget.isSeqActive;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onTap();
        _hitCtrl.forward(from: 0).then((_) => _hitCtrl.reverse());
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _hitCtrl,
        builder: (_, __) {
          final hitVal = _hitCtrl.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            height: 44,
            transform: Matrix4.identity()
              ..translate(0.0, isLit ? 1.0 : 0.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLit
                    ? [
                        Color.lerp(c, const Color(0xFF1A1A1A), 0.3)!,
                        Color.lerp(c, const Color(0xFF111111), 0.5)!,
                      ]
                    : [
                        const Color(0xFF222222),
                        const Color(0xFF161616),
                      ],
              ),
              border: Border(
                top: BorderSide(
                  color: isLit ? c.withValues(alpha: 0.60) : const Color(0xFF2A2A2A),
                  width: 1,
                ),
                left: BorderSide(
                  color: isLit ? c.withValues(alpha: 0.40) : const Color(0xFF252525),
                  width: 1,
                ),
                right: BorderSide(color: Colors.black.withValues(alpha: 0.4), width: 1),
                bottom: BorderSide(
                  color: isLit ? Colors.black.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              boxShadow: isLit
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.50 + hitVal * 0.3),
                        blurRadius: 12 + hitVal * 8,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 3, offset: const Offset(1, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 0, offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 4, offset: const Offset(1, 3),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LED indicator dot
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLit ? c : c.withValues(alpha: 0.20),
                    boxShadow: isLit ? [
                      BoxShadow(color: c.withValues(alpha: 0.8), blurRadius: 6),
                    ] : null,
                  ),
                ),
                const SizedBox(width: 6),
                // Icon
                Icon(widget.icon, size: 12,
                  color: isLit ? Colors.white.withValues(alpha: 0.9) : c.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                // Label
                Flexible(
                  child: Text(
                    widget.label,
                    style: AppFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isLit
                          ? Colors.white.withValues(alpha: 0.95)
                          : c.withValues(alpha: 0.70),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
