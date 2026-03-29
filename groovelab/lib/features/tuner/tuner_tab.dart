import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_fonts.dart';
import '../../core/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';

// ═══════════════════════════════════════════════════════════════
//  TUNING PRESETS
// ═══════════════════════════════════════════════════════════════

class TuningPreset {
  final String id;
  final String nameKey;
  final List<StringNote> strings;
  final int stringCount;
  const TuningPreset(this.id, this.nameKey, this.strings) : stringCount = strings.length;
}

class StringNote {
  final String note;
  final int octave;
  final double frequency;
  const StringNote(this.note, this.octave, this.frequency);
  String get label => '$note$octave';
}

final _tuningPresets = [
  TuningPreset('guitar', 'tunerGuitar', const [
    StringNote('E', 2, 82.41), StringNote('A', 2, 110.0),
    StringNote('D', 3, 146.83), StringNote('G', 3, 196.0),
    StringNote('B', 3, 246.94), StringNote('E', 4, 329.63),
  ]),
  TuningPreset('dropd', 'tunerDropD', const [
    StringNote('D', 2, 73.42), StringNote('A', 2, 110.0),
    StringNote('D', 3, 146.83), StringNote('G', 3, 196.0),
    StringNote('B', 3, 246.94), StringNote('E', 4, 329.63),
  ]),
  TuningPreset('bass4', 'tunerBass4', const [
    StringNote('E', 1, 41.20), StringNote('A', 1, 55.0),
    StringNote('D', 2, 73.42), StringNote('G', 2, 98.0),
  ]),
  TuningPreset('bass5', 'tunerBass5', const [
    StringNote('B', 0, 30.87), StringNote('E', 1, 41.20),
    StringNote('A', 1, 55.0), StringNote('D', 2, 73.42),
    StringNote('G', 2, 98.0),
  ]),
  TuningPreset('bass6', 'tunerBass6', const [
    StringNote('B', 0, 30.87), StringNote('E', 1, 41.20),
    StringNote('A', 1, 55.0), StringNote('D', 2, 73.42),
    StringNote('G', 2, 98.0), StringNote('C', 3, 130.81),
  ]),
  TuningPreset('ukulele', 'tunerUkulele', const [
    StringNote('G', 4, 392.0), StringNote('C', 4, 261.63),
    StringNote('E', 4, 329.63), StringNote('A', 4, 440.0),
  ]),
  TuningPreset('violin', 'tunerViolin', const [
    StringNote('G', 3, 196.0), StringNote('D', 4, 293.66),
    StringNote('A', 4, 440.0), StringNote('E', 5, 659.25),
  ]),
  TuningPreset('saxophone', 'tunerSaxophone', const [
    StringNote('A', 4, 440.0),
  ]),
  TuningPreset('trumpet', 'tunerTrumpet', const [
    StringNote('A', 4, 440.0),
  ]),
  TuningPreset('piano', 'tunerPiano', const [
    StringNote('A', 4, 440.0),
  ]),
];

// ═══════════════════════════════════════════════════════════════
//  TUNER TAB — BIAS FX 2 style vertical LED bar meter
// ═══════════════════════════════════════════════════════════════

class TunerTab extends ConsumerStatefulWidget {
  const TunerTab({super.key});
  @override
  ConsumerState<TunerTab> createState() => _TunerTabState();
}

class _TunerTabState extends ConsumerState<TunerTab> with TickerProviderStateMixin {
  late AudioService _audio;
  bool _isListening = false;
  int _presetIndex = 0;
  int _selectedString = -1;

  String _detectedNote = '-';
  int _detectedOctave = 0;
  int _cents = 0;
  double _frequency = 0;
  bool _inTune = false;
  double _level = 0;
  double _smoothCents = 0;

  // Reference pitch
  int _refPitch = 440;

  // Input mode: 'mic' or 'direct'
  String _inputMode = 'mic';
  List<Map<String, String>> _devices = [];
  String? _selectedDeviceId;
  bool _loadingDevices = false;

  late AnimationController _pulseController;
  late AnimationController _inTunePulseController;
  late AnimationController _inTuneBurstController;
  late Animation<double> _inTuneScaleAnim;
  bool _wasInTune = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _inTunePulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _inTuneScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _inTunePulseController, curve: Curves.easeOutCubic));
    _inTuneBurstController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() { _stopListening(); _pulseController.dispose(); _inTunePulseController.dispose(); _inTuneBurstController.dispose(); super.dispose(); }

  TuningPreset get _preset => _tuningPresets[_presetIndex];

  void _startListening({String? deviceId}) async {
    _audio = ref.read(audioServiceProvider);
    await _audio.startTuner((data) {
      if (!mounted) return;
      setState(() {
        _frequency = (data['frequency'] as double?) ?? 0;
        _detectedNote = (data['note'] as String?) ?? '-';
        _detectedOctave = (data['octave'] as int?) ?? 0;
        _cents = (data['cents'] as int?) ?? 0;
        _inTune = (data['inTune'] as bool?) ?? false;
        _level = (data['level'] as double?) ?? 0;
        _smoothCents = _smoothCents * 0.55 + _cents * 0.45;
        if (_inTune && !_wasInTune) {
          _inTunePulseController.forward(from: 0);
          _inTuneBurstController.forward(from: 0);
        }
        _wasInTune = _inTune;
      });
    }, deviceId: deviceId ?? (_inputMode == 'direct' ? _selectedDeviceId : null));
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    if (!_isListening) return;
    await ref.read(audioServiceProvider).stopTuner();
    if (mounted) setState(() { _isListening = false; _detectedNote = '-'; _cents = 0; _frequency = 0; _smoothCents = 0; });
  }

  Future<void> _loadDevices() async {
    setState(() => _loadingDevices = true);
    try {
      final audio = ref.read(audioServiceProvider);
      final devices = await audio.getAudioInputDevices();
      if (mounted) setState(() { _devices = devices; _loadingDevices = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  void _selectInputMode(String mode) async {
    if (_inputMode == mode) return;
    final wasListening = _isListening;
    if (wasListening) await ref.read(audioServiceProvider).stopTuner();
    setState(() {
      _inputMode = mode;
      _isListening = false;
      _detectedNote = '-'; _cents = 0; _frequency = 0; _smoothCents = 0;
    });
    if (mode == 'direct' && _devices.isEmpty) {
      await _loadDevices();
    }
    if (wasListening) {
      _startListening();
    }
  }

  int get _activeStringIdx {
    if (_frequency == 0) return -1;
    for (int i = 0; i < _preset.strings.length; i++) {
      final s = _preset.strings[i];
      if (s.note == _detectedNote && s.octave == _detectedOctave) return i;
    }
    return -1;
  }

  Color _instrumentGlowColor(String id) {
    switch (id) {
      case 'ukulele':   return const Color(0xFFE0B840);
      case 'bass4':     return const Color(0xFF4488AA);
      case 'bass5':     return const Color(0xFF3898B0);
      case 'bass6':     return const Color(0xFFA070C0);
      case 'dropd':     return const Color(0xFFB89020);
      case 'violin':    return const Color(0xFFCC4422);
      case 'saxophone': return const Color(0xFFD4A020);
      case 'trumpet':   return const Color(0xFFE0B828);
      case 'piano':     return const Color(0xFFCCCCC8);
      default:          return const Color(0xFFD4924A);
    }
  }

  IconData _instrumentIcon(String id) {
    switch (id) {
      case 'guitar':
      case 'dropd':     return Icons.music_note_rounded;
      case 'bass4':
      case 'bass5':
      case 'bass6':     return Icons.graphic_eq_rounded;
      case 'ukulele':   return Icons.music_note_rounded;
      case 'violin':    return Icons.queue_music_rounded;
      case 'saxophone': return Icons.air_rounded;
      case 'trumpet':   return Icons.campaign_rounded;
      case 'piano':     return Icons.piano_rounded;
      default:          return Icons.music_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final noteColor = _frequency == 0
      ? AppColors.textMuted
      : _inTune ? AppColors.accent2 : (_cents.abs() > 20 ? AppColors.danger : AppColors.warning);
    final isInTuneActive = _inTune && _frequency > 0;

    return Container(
      color: AppColors.bgDark,
      child: Column(
        children: [
          // ── Header bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgDeepest,
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 0.5)),
            ),
            child: Row(
              children: [
                if (_isListening)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.warm,
                        boxShadow: [BoxShadow(color: AppColors.warm.withValues(alpha: _pulseController.value * 0.75), blurRadius: 8)],
                      ),
                    ),
                  ),
                Text(tr(lang, 'tunerTitle').toUpperCase(), style: AppFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _isListening ? AppColors.warm : AppColors.textMuted,
                  letterSpacing: 2.0,
                )),
                const Spacer(),
                // Instrument selector compact
                GestureDetector(
                  onTap: () => _showInstrumentPicker(lang),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _instrumentGlowColor(_preset.id).withValues(alpha: 0.10),
                      border: Border.all(color: _instrumentGlowColor(_preset.id).withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_instrumentIcon(_preset.id), size: 14, color: _instrumentGlowColor(_preset.id)),
                        const SizedBox(width: 4),
                        Text(
                          tr(lang, _preset.nameKey),
                          style: AppFonts.outfit(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: _instrumentGlowColor(_preset.id),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _instrumentGlowColor(_preset.id).withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main content ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                children: [
                  // ── Vertical LED Bar Meter (BIAS FX 2 style) ──
                  Expanded(
                    child: _buildLedBarMeter(noteColor, isInTuneActive),
                  ),
                  const SizedBox(height: 8),

                  // ── String pills ──
                  _buildStringPills(),
                  const SizedBox(height: 8),

                  // ── Reference pitch + controls ──
                  _buildBottomControls(lang),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  VERTICAL LED BAR METER (BIAS FX 2 style)
  // ═══════════════════════════════════════

  Widget _buildLedBarMeter(Color noteColor, bool isInTuneActive) {
    final statusText = _frequency == 0
      ? ''
      : _inTune ? 'IN TUNE'
        : _cents < 0 ? 'FLAT' : 'SHARP';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: AppTheme.glassCard(
        glowColor: isInTuneActive ? AppColors.accent2 : null,
        borderColor: isInTuneActive ? AppColors.accent2.withValues(alpha: 0.3) : null,
      ),
      child: Column(
        children: [
          // ── LED bar meter row ──
          SizedBox(
            height: 48,
            child: _LedBarWidget(
              cents: _smoothCents,
              isActive: _frequency > 0,
              inTune: _inTune,
            ),
          ),
          const SizedBox(height: 4),
          // ── -50 / 0 / +50 labels ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('-50', style: AppFonts.jetBrainsMono(
                  fontSize: 8, color: AppColors.textMuted.withValues(alpha: 0.5),
                )),
                Text('0', style: AppFonts.jetBrainsMono(
                  fontSize: 8, color: AppColors.accent2.withValues(alpha: 0.6),
                )),
                Text('+50', style: AppFonts.jetBrainsMono(
                  fontSize: 8, color: AppColors.textMuted.withValues(alpha: 0.5),
                )),
              ],
            ),
          ),

          const Spacer(),

          // ── Note name (large, center) ──
          AnimatedBuilder(
            animation: _inTuneScaleAnim,
            builder: (_, child) => Transform.scale(
              scale: isInTuneActive ? _inTuneScaleAnim.value : 1.0,
              child: child,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _detectedNote == '-' ? '\u2014' : _detectedNote,
                  style: _frequency > 0
                      ? AppTheme.lcdStyle(
                          size: 64,
                          weight: FontWeight.w800,
                          color: noteColor,
                          glow: true,
                          glowAlpha: _inTune ? 0.75 : 0.50,
                        )
                      : AppFonts.jetBrainsMono(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted.withValues(alpha: 0.3),
                        ),
                ),
                if (_frequency > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '$_detectedOctave',
                      style: AppTheme.lcdStyle(
                        size: 24,
                        color: noteColor.withValues(alpha: 0.60),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Cents display ──
          if (_frequency > 0)
            Text(
              '${_cents > 0 ? "+" : ""}$_cents cent',
              style: AppFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: noteColor.withValues(alpha: 0.80),
                shadows: _inTune ? [
                  Shadow(color: noteColor.withValues(alpha: 0.40), blurRadius: 8),
                ] : null,
              ),
            )
          else
            Text(
              'Play a note',
              style: AppFonts.outfit(
                fontSize: 13,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ),

          const SizedBox(height: 4),

          // ── Status badge ──
          if (statusText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: noteColor.withValues(alpha: 0.10),
                border: Border.all(color: noteColor.withValues(alpha: 0.25)),
              ),
              child: Text(statusText, style: AppFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: noteColor,
                letterSpacing: 1.2,
                shadows: _inTune ? [Shadow(color: noteColor.withValues(alpha: 0.50), blurRadius: 6)] : null,
              )),
            ),

          const SizedBox(height: 4),

          // ── Frequency display ──
          if (_frequency > 0)
            Text(
              '${_frequency.toStringAsFixed(1)} Hz',
              style: AppFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accent.withValues(alpha: 0.70),
              ),
            ),

          const Spacer(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  STRING PILLS
  // ═══════════════════════════════════════

  Widget _buildStringPills() {
    final strings = _preset.strings;
    final activeIdx = _activeStringIdx;

    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(strings.length, (i) {
          final s = strings[i];
          final isDetected = i == activeIdx;
          final isSelected = _selectedString == i;
          final isTuned = isDetected && _inTune;

          final Color accent;
          if (isTuned) {
            accent = AppColors.accent2;
          } else if (isDetected) {
            accent = AppColors.warning;
          } else if (isSelected) {
            accent = AppColors.accent;
          } else {
            accent = AppColors.textMuted;
          }

          final isHighlighted = isTuned || isDetected || isSelected;

          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() { _selectedString = _selectedString == i ? -1 : i; }); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isHighlighted
                    ? Color.lerp(AppColors.bgPanel, accent, 0.10)!
                    : AppColors.bgPanel,
                border: Border.all(
                  color: isHighlighted ? accent.withValues(alpha: 0.60) : const Color(0x08FFFFFF),
                  width: isTuned ? 1.6 : 1.0,
                ),
                boxShadow: isHighlighted
                    ? [
                        ...AppColors.neumorphicRaised(scale: 0.5, glowColor: accent),
                        if (isTuned) BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: -2,
                        ),
                      ]
                    : AppColors.neumorphicRaised(scale: 0.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTuned) Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(Icons.check_circle, size: 12, color: AppColors.accent2),
                  ),
                  Text(s.note, style: AppFonts.jetBrainsMono(
                    fontSize: 14, fontWeight: FontWeight.w700, color: accent,
                    shadows: isHighlighted ? [Shadow(color: accent.withValues(alpha: 0.40), blurRadius: 6)] : null,
                  )),
                  Text(s.octave.toString(), style: AppFonts.jetBrainsMono(
                    fontSize: 10, color: accent.withValues(alpha: 0.6),
                  )),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  BOTTOM CONTROLS (Ref pitch + Mic + Level)
  // ═══════════════════════════════════════

  Widget _buildBottomControls(String lang) {
    return Row(
      children: [
        // Listen / Stop button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (_isListening) {
              _stopListening();
            } else {
              _startListening();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgPanel,
              border: Border.all(
                color: _isListening
                    ? AppColors.warm.withValues(alpha: 0.65)
                    : AppColors.accent.withValues(alpha: 0.35),
                width: _isListening ? 1.8 : 0.8,
              ),
              boxShadow: AppColors.neumorphicRaised(
                glowColor: _isListening ? AppColors.warm : AppColors.accent,
              ),
            ),
            child: Icon(
              _isListening ? Icons.stop_rounded
                  : (_inputMode == 'direct' ? Icons.cable_rounded : Icons.mic_rounded),
              size: 18,
              color: _isListening ? AppColors.warm : AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Level meter
        Expanded(
          child: Container(
            height: 4, width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: AppColors.bgInput),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_level * 3).clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(colors: [AppColors.accent2, AppColors.accent, AppColors.warning]),
              )),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Reference pitch control
        _buildRefPitchControl(),
        const SizedBox(width: 4),

        // Input mode toggle
        _inputModePill(lang, 'mic', Icons.mic_rounded),
        const SizedBox(width: 4),
        _inputModePill(lang, 'direct', Icons.cable_rounded),
        if (_inputMode == 'direct' && _devices.isNotEmpty) ...[
          const SizedBox(width: 4),
          _buildCompactDevicePicker(lang),
        ],
      ],
    );
  }

  Widget _buildRefPitchControl() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.bgPanel,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _refPitch = (_refPitch - 1).clamp(415, 465)),
            child: const SizedBox(
              width: 28, height: 36,
              child: Icon(Icons.remove, size: 14, color: AppColors.textMuted),
            ),
          ),
          Text(
            '$_refPitch',
            style: AppFonts.jetBrainsMono(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _refPitch = (_refPitch + 1).clamp(415, 465)),
            child: const SizedBox(
              width: 28, height: 36,
              child: Icon(Icons.add, size: 14, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputModePill(String lang, String mode, IconData icon) {
    final active = _inputMode == mode;
    return GestureDetector(
      onTap: () => _selectInputMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active ? AppColors.accent.withValues(alpha: 0.12) : AppColors.bgInput,
          border: Border.all(
            color: active ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
            width: active ? 1.2 : 0.6,
          ),
        ),
        child: Icon(icon, size: 14,
          color: active ? AppColors.accent : AppColors.textMuted),
      ),
    );
  }

  Widget _buildCompactDevicePicker(String lang) {
    return PopupMenuButton<String>(
      onSelected: (id) async {
        final wasListening = _isListening;
        if (wasListening) await ref.read(audioServiceProvider).stopTuner();
        setState(() {
          _selectedDeviceId = id;
          _isListening = false;
          _detectedNote = '-'; _cents = 0; _frequency = 0; _smoothCents = 0;
        });
        if (wasListening) _startListening(deviceId: id);
      },
      itemBuilder: (_) => _devices.map((d) => PopupMenuItem<String>(
        value: d['id'],
        child: Text(d['name'] ?? 'Audio Input', style: AppFonts.outfit(fontSize: 11)),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.bgInput,
          border: Border.all(color: AppColors.border, width: 0.6),
        ),
        child: const Icon(Icons.settings_input_hdmi, size: 14, color: AppColors.textMuted),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  INSTRUMENT PICKER
  // ═══════════════════════════════════════

  void _showInstrumentPicker(String lang) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _InstrumentPickerSheet(
        lang: lang,
        currentIndex: _presetIndex,
        onSelect: (index) {
          setState(() { _presetIndex = index; _selectedString = -1; });
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  LED BAR WIDGET — Vertical bars like BIAS FX 2 tuner
//  Center bars = green (in tune)
//  Left bars = red (flat), Right bars = red (sharp)
// ═══════════════════════════════════════════════════════════════

class _LedBarWidget extends StatelessWidget {
  final double cents;
  final bool isActive;
  final bool inTune;

  const _LedBarWidget({
    required this.cents,
    required this.isActive,
    required this.inTune,
  });

  @override
  Widget build(BuildContext context) {
    // 21 bars: index 0..20, center is 10
    const totalBars = 21;
    const centerIdx = 10;

    // Map cents (-50..+50) to bar position (0..20)
    final clamped = cents.clamp(-50.0, 50.0);
    final barPos = ((clamped + 50) / 100 * (totalBars - 1));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalBars, (i) {
        // Determine base color for this bar position
        final distFromCenter = (i - centerIdx).abs();
        Color barBaseColor;
        if (distFromCenter <= 1) {
          barBaseColor = AppColors.accent2; // green center
        } else if (distFromCenter <= 4) {
          barBaseColor = Color.lerp(AppColors.accent2, AppColors.warning, (distFromCenter - 1) / 3)!;
        } else {
          barBaseColor = Color.lerp(AppColors.warning, AppColors.danger, ((distFromCenter - 4) / 6).clamp(0, 1))!;
        }

        // Determine if this bar is "lit"
        bool isLit = false;
        if (isActive) {
          // Light up bars from center toward the detected position
          final rounded = barPos.round();
          if (clamped >= 0) {
            // Sharp: light from center to right
            isLit = i >= centerIdx && i <= rounded;
          } else {
            // Flat: light from center to left
            isLit = i <= centerIdx && i >= rounded;
          }
          // Always light center bar when active
          if (i == centerIdx) isLit = true;
        }

        final dimColor = barBaseColor.withValues(alpha: 0.10);
        final litColor = barBaseColor;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              height: distFromCenter <= 1 ? 44 : 36.0 + (10 - distFromCenter).clamp(0, 10) * 0.8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isLit ? litColor : dimColor,
                boxShadow: isLit ? [
                  BoxShadow(
                    color: litColor.withValues(alpha: 0.50),
                    blurRadius: 8,
                    spreadRadius: -1,
                  ),
                ] : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  INSTRUMENT PICKER BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════

class _InstrumentPickerSheet extends StatelessWidget {
  final String lang;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _InstrumentPickerSheet({
    required this.lang,
    required this.currentIndex,
    required this.onSelect,
  });

  Color _instrumentGlowColor(String id) {
    switch (id) {
      case 'ukulele':   return const Color(0xFFE0B840);
      case 'bass4':     return const Color(0xFF4488AA);
      case 'bass5':     return const Color(0xFF3898B0);
      case 'bass6':     return const Color(0xFFA070C0);
      case 'dropd':     return const Color(0xFFB89020);
      case 'violin':    return const Color(0xFFCC4422);
      case 'saxophone': return const Color(0xFFD4A020);
      case 'trumpet':   return const Color(0xFFE0B828);
      case 'piano':     return const Color(0xFFCCCCC8);
      default:          return const Color(0xFFD4924A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      decoration: BoxDecoration(
        color: AppColors.bgDeepest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.6), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: AppColors.textMuted.withValues(alpha: 0.35),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              tr(lang, 'tunerTitle').toUpperCase(),
              style: AppFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _tuningPresets.length,
              itemBuilder: (_, i) {
                final p = _tuningPresets[i];
                final active = i == currentIndex;
                final glowCol = _instrumentGlowColor(p.id);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: active
                          ? Color.lerp(AppColors.bgPanel, glowCol, 0.10)
                          : AppColors.bgPanel,
                      border: Border.all(
                        color: active ? glowCol.withValues(alpha: 0.60) : AppColors.border,
                        width: active ? 1.6 : 0.5,
                      ),
                      boxShadow: active
                          ? AppColors.neumorphicRaised(glowColor: glowCol)
                          : AppColors.neumorphicRaised(scale: 0.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40, height: 52,
                          child: _InstrumentSvg(id: p.id, isActive: active),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            tr(lang, p.nameKey),
                            style: AppFonts.outfit(
                              fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                              color: active ? glowCol : AppColors.textMuted,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (active)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              p.strings.map((s) => s.label).join(' '),
                              style: AppFonts.outfit(
                                fontSize: 7, fontWeight: FontWeight.w500,
                                color: glowCol.withValues(alpha: 0.6),
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  INSTRUMENT SVG WIDGET
// ═══════════════════════════════════════════════════════════════

const _instrumentAssets = {
  'guitar':    'assets/images/instruments/guitar.svg',
  'dropd':     'assets/images/instruments/dropd.svg',
  'bass4':     'assets/images/instruments/bass4.svg',
  'bass5':     'assets/images/instruments/bass5.svg',
  'bass6':     'assets/images/instruments/bass6.svg',
  'ukulele':   'assets/images/instruments/ukulele.svg',
  'violin':    'assets/images/instruments/violin.svg',
  'saxophone': 'assets/images/instruments/saxophone.svg',
  'trumpet':   'assets/images/instruments/trumpet.svg',
  'piano':     'assets/images/instruments/piano.svg',
};

class _InstrumentSvg extends StatelessWidget {
  final String id;
  final bool isActive;
  const _InstrumentSvg({required this.id, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final path = _instrumentAssets[id] ?? _instrumentAssets['guitar']!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: isActive ? [
          BoxShadow(
            color: _glowColor(id).withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: SvgPicture.asset(
        path,
        fit: BoxFit.contain,
        colorFilter: isActive
            ? null
            : const ColorFilter.matrix(<double>[
                0.35, 0, 0, 0, 0,
                0, 0.35, 0, 0, 0,
                0, 0, 0.35, 0, 0,
                0, 0, 0, 0.7, 0,
              ]),
      ),
    );
  }

  Color _glowColor(String id) {
    if (id == 'ukulele') return const Color(0xFFE0B840);
    if (id.startsWith('bass')) {
      if (id == 'bass5') return const Color(0xFF3898B0);
      if (id == 'bass6') return const Color(0xFFA070C0);
      return const Color(0xFF4488AA);
    }
    if (id == 'dropd') return const Color(0xFFB89020);
    if (id == 'violin') return const Color(0xFFCC4422);
    if (id == 'saxophone') return const Color(0xFFD4A020);
    if (id == 'trumpet') return const Color(0xFFE0B828);
    if (id == 'piano') return const Color(0xFFCCCCC8);
    return const Color(0xFFD4924A);
  }
}
