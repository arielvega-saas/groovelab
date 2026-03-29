import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
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
//  TUNER TAB
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

  // Input mode: 'mic' or 'direct'
  String _inputMode = 'mic';
  List<Map<String, String>> _devices = [];
  String? _selectedDeviceId;
  bool _loadingDevices = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _stopListening(); _pulseController.dispose(); super.dispose(); }

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

  /// Find which string index matches the detected note
  int get _activeStringIdx {
    if (_frequency == 0) return -1;
    for (int i = 0; i < _preset.strings.length; i++) {
      final s = _preset.strings[i];
      if (s.note == _detectedNote && s.octave == _detectedOctave) return i;
    }
    return -1;
  }

  // Returns a per-instrument highlight color for active glow
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

  /// Icon for each instrument type (used in dropdown and picker)
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

    return Column(
      children: [
        // ── Header ──
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
              Text(tr(lang, 'tunerTitle').toUpperCase(), style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: _isListening ? AppColors.warm : AppColors.textMuted,
                letterSpacing: 2.0,
              )),
              const Spacer(),
              if (_frequency > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.accent.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text('${_frequency.toStringAsFixed(1)} Hz', style: AppTheme.monoStyle(size: 10, weight: FontWeight.w600, color: AppColors.accent)),
                ),
            ],
          ),
        ),

        // ── All content ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Column(
              children: [
                // ── Instrument dropdown button ──
                _buildInstrumentDropdown(lang),
                const SizedBox(height: 8),

                // ── Gauge (BIG) + Note Display ── fills available space
                Expanded(
                  child: _buildGaugeSection(lang, noteColor),
                ),
                const SizedBox(height: 8),

                // ── String pills BELOW gauge ──
                _buildStringPills(),
                const SizedBox(height: 8),

                // ── Mic button + Input mode + Level ──
                _buildControlSection(lang),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  INSTRUMENT DROPDOWN BUTTON
  // ═══════════════════════════════════════

  Widget _buildInstrumentDropdown(String lang) {
    final preset = _preset;
    final glowCol = _instrumentGlowColor(preset.id);

    return GestureDetector(
      onTap: () => _showInstrumentPicker(lang),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Color.lerp(AppColors.bgPanel, glowCol, 0.05),
          border: Border.all(color: glowCol.withValues(alpha: 0.35), width: 1.0),
          boxShadow: AppColors.neumorphicRaised(glowColor: glowCol, scale: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_instrumentIcon(preset.id), size: 18, color: glowCol),
            const SizedBox(width: 8),
            Text(
              tr(lang, preset.nameKey),
              style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: glowCol,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: glowCol.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  INSTRUMENT PICKER BOTTOM SHEET
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

  // ═══════════════════════════════════════
  //  GAUGE + NOTE DISPLAY (BIG)
  // ═══════════════════════════════════════

  Widget _buildGaugeSection(String lang, Color noteColor) {
    final statusText = _frequency == 0
      ? tr(lang, 'tunerTapString')
      : _inTune ? tr(lang, 'tunerInTune')
        : _cents < 0 ? tr(lang, 'tunerFlat') : tr(lang, 'tunerSharp');
    final statusColor = noteColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: AppTheme.glassCard(
        glowColor: _inTune && _frequency > 0 ? AppColors.accent2 : null,
        borderColor: _inTune && _frequency > 0 ? AppColors.accent2.withValues(alpha: 0.3) : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Gauge takes as much space as possible
          final gaugeWidth = (constraints.maxWidth - 24).clamp(200.0, 400.0);
          final gaugeHeight = (gaugeWidth * 0.48).clamp(90.0, 200.0);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 1),

              // ── Semicircular gauge — BIG ──
              Container(
                width: gaugeWidth + 8,
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                decoration: AppTheme.insetPanel(
                  radius: 16,
                  glowColor: _inTune && _frequency > 0 ? AppColors.accent2 : null,
                ),
                child: CustomPaint(
                  size: Size(gaugeWidth, gaugeHeight),
                  painter: _TunerGaugePainter(
                    cents: _smoothCents, noteColor: noteColor, isActive: _frequency > 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Note display + cents + status ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Note letter — large LCD style
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: AppTheme.insetPanel(
                      radius: 12,
                      glowColor: _frequency > 0 ? noteColor : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _detectedNote == '-' ? '—' : _detectedNote,
                          style: _frequency > 0
                              ? AppTheme.lcdStyle(
                                  size: 44,
                                  weight: FontWeight.w800,
                                  color: noteColor,
                                  glow: true,
                                  glowAlpha: 0.55,
                                )
                              : AppTheme.monoStyle(
                                  size: 44,
                                  weight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                ),
                        ),
                        if (_frequency > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$_detectedOctave',
                            style: AppTheme.lcdStyle(
                              size: 18,
                              color: noteColor.withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_frequency > 0) ...[
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_cents > 0 ? "+" : ""}$_cents\u00A2',
                          style: AppTheme.lcdStyle(
                            size: 16,
                            color: noteColor.withValues(alpha: 0.70),
                            glow: _inTune,
                            glowAlpha: 0.40,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: AppTheme.insetPanel(radius: 10),
                          child: Text(statusText, style: GoogleFonts.outfit(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: statusColor,
                            letterSpacing: 0.8,
                            shadows: [Shadow(color: statusColor.withValues(alpha: 0.50), blurRadius: 6)],
                          )),
                        ),
                      ],
                    ),
                  ],
                  if (_frequency == 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        decoration: AppTheme.insetPanel(radius: 10),
                        child: Text(statusText, style: GoogleFonts.outfit(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: statusColor,
                          letterSpacing: 0.8,
                        )),
                      ),
                    ),
                ],
              ),

              const Spacer(flex: 1),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════
  //  COMPACT STRING PILLS
  // ═══════════════════════════════════════

  Widget _buildStringPills() {
    final strings = _preset.strings;
    final activeIdx = _activeStringIdx;

    return SizedBox(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(strings.length, (i) {
          final s = strings[i];
          final isDetected = i == activeIdx;
          final isSelected = _selectedString == i;
          final isTuned = isDetected && _inTune;

          Color accent;
          if (isTuned) accent = AppColors.accent2;
          else if (isDetected) accent = AppColors.warning;
          else if (isSelected) accent = AppColors.accent;
          else accent = AppColors.textMuted;

          final isHighlighted = isTuned || isDetected || isSelected;

          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() { _selectedString = _selectedString == i ? -1 : i; }); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isHighlighted ? accent.withValues(alpha: 0.12) : AppColors.bgPanel,
                border: Border.all(
                  color: isHighlighted ? accent.withValues(alpha: 0.55) : AppColors.border,
                  width: isTuned ? 1.5 : 0.5,
                ),
                boxShadow: isHighlighted
                    ? [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 10, spreadRadius: -1)]
                    : AppColors.neumorphicRaised(scale: 0.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTuned) Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(Icons.check_circle, size: 12, color: AppColors.accent2),
                  ),
                  Text(s.note, style: AppTheme.monoStyle(size: 14, weight: FontWeight.w700, color: accent)),
                  Text(s.octave.toString(), style: AppTheme.monoStyle(size: 10, color: accent.withValues(alpha: 0.6))),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  CONTROL SECTION (Mode + Mic + Level)
  // ═══════════════════════════════════════

  Widget _buildControlSection(String lang) {
    return Row(
      children: [
        // Listen / Stop button — compact
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (_isListening) _stopListening(); else _startListening();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40, height: 40,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
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
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Input mode toggle — compact pills
        _inputModePill(lang, 'mic', Icons.mic_rounded),
        const SizedBox(width: 4),
        _inputModePill(lang, 'direct', Icons.cable_rounded),
        // Device picker for direct mode
        if (_inputMode == 'direct' && _devices.isNotEmpty) ...[
          const SizedBox(width: 4),
          _buildCompactDevicePicker(lang),
        ],
      ],
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
        child: Text(d['name'] ?? 'Audio Input', style: GoogleFonts.outfit(fontSize: 11)),
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
          // ── Handle ──
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: AppColors.textMuted.withValues(alpha: 0.35),
            ),
          ),
          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              tr(lang, 'tunerTitle').toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // ── Instrument grid ──
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
                        // SVG illustration
                        SizedBox(
                          width: 40, height: 52,
                          child: _InstrumentSvg(id: p.id, isActive: active),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            tr(lang, p.nameKey),
                            style: GoogleFonts.outfit(
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
                              style: GoogleFonts.outfit(
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
//  INSTRUMENT SVG WIDGET  (Premium local SVG assets)
// ═══════════════════════════════════════════════════════════════

/// Maps preset IDs to their SVG asset paths.
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
        // Active glow behind the SVG
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
            ? null // show full color when active
            : const ColorFilter.matrix(<double>[
                0.35, 0, 0, 0, 0,
                0, 0.35, 0, 0, 0,
                0, 0, 0.35, 0, 0,
                0, 0, 0, 0.7, 0,
              ]), // desaturate + dim when inactive
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
    return const Color(0xFFD4924A); // guitar amber
  }
}

// ═══════════════════════════════════════════════════════════════
//  INSTRUMENT ICON PAINTER  (kept for backward-compat, unused)
// ═══════════════════════════════════════════════════════════════

class _InstrumentIconPainter extends CustomPainter {
  final String type;
  final bool isActive;
  _InstrumentIconPainter({required this.type, required this.isActive});

  // ── Color palette ──────────────────────────────────────────────
  static const _bodyAmber    = Color(0xFFC8883A); // acoustic top
  static const _bodyDark     = Color(0xFF7A4A1A); // acoustic shadow
  static const _bodyMid      = Color(0xFFA06828); // acoustic mid
  static const _bassBody1    = Color(0xFF1A3050); // bass midnight
  static const _bassBody2    = Color(0xFF0A1828); // bass deep
  static const _ukeBody1     = Color(0xFFD4A030); // koa light
  static const _ukeBody2     = Color(0xFF8C6018); // koa dark
  static const _neckColor    = Color(0xFFB8925A); // maple neck
  static const _neckShadow   = Color(0xFF7A5E32); // neck shadow
  static const _headstock    = Color(0xFF2C1808); // dark headstock
  static const _headLight    = Color(0xFF4A2C10); // headstock edge
  static const _pegGold      = Color(0xFFD4AF37); // gold tuner
  static const _pegSilver    = Color(0xFF9E9E9E); // silver tuner
  static const _binding      = Color(0xFFF0E8D0); // binding/nut
  static const _fretmetal    = Color(0xFFB0A080); // fret wire

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (type == 'ukulele') {
      _drawUkulele(canvas, w, h);
    } else if (type.startsWith('bass')) {
      _drawBass(canvas, w, h);
    } else {
      _drawAcousticGuitar(canvas, w, h);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  ACOUSTIC GUITAR  (dreadnought silhouette, neck at top)
  // ══════════════════════════════════════════════════════════════
  void _drawAcousticGuitar(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final neckW = w * 0.18;
    final headW = w * 0.42;
    final headH = h * 0.12;
    final bodyTop = h * 0.36;

    // ── Headstock ──
    final headPath = Path()
      ..moveTo(cx - headW / 2, headH)
      ..lineTo(cx - headW / 2, h * 0.02)
      ..quadraticBezierTo(cx - headW / 2, 0, cx - headW / 2 + h * 0.02, 0)
      ..lineTo(cx + headW / 2 - h * 0.02, 0)
      ..quadraticBezierTo(cx + headW / 2, 0, cx + headW / 2, h * 0.02)
      ..lineTo(cx + headW / 2, headH)
      ..close();
    canvas.drawPath(headPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_headLight, _headstock],
      ).createShader(Rect.fromLTWH(cx - headW / 2, 0, headW, headH)));
    canvas.drawPath(headPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke..strokeWidth = 0.6);

    // ── Tuning pegs (3 per side) ──
    final pegColor = isActive ? _pegGold : _pegSilver;
    for (int i = 0; i < 3; i++) {
      final py = h * 0.014 + i * (headH - h * 0.02) / 3.2;
      // Left peg shaft
      canvas.drawLine(Offset(cx - headW / 2, py + headH / 7),
          Offset(cx - headW / 2 - w * 0.06, py + headH / 7),
          Paint()..color = pegColor..strokeWidth = 1.2..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(cx - headW / 2 - w * 0.06, py + headH / 7), 2.8,
          Paint()..color = pegColor);
      canvas.drawCircle(Offset(cx - headW / 2 - w * 0.06, py + headH / 7), 1.2,
          Paint()..color = Colors.white.withValues(alpha: 0.4));
      // Right peg shaft
      canvas.drawLine(Offset(cx + headW / 2, py + headH / 7),
          Offset(cx + headW / 2 + w * 0.06, py + headH / 7),
          Paint()..color = pegColor..strokeWidth = 1.2..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(cx + headW / 2 + w * 0.06, py + headH / 7), 2.8,
          Paint()..color = pegColor);
      canvas.drawCircle(Offset(cx + headW / 2 + w * 0.06, py + headH / 7), 1.2,
          Paint()..color = Colors.white.withValues(alpha: 0.4));
    }

    // ── Nut ──
    canvas.drawLine(Offset(cx - neckW / 2, headH + 1),
        Offset(cx + neckW / 2, headH + 1),
        Paint()..color = _binding..strokeWidth = 2.2..strokeCap = StrokeCap.round);

    // ── Neck ──
    final neckPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - neckW / 2, headH, neckW, bodyTop - headH),
        const Radius.circular(2)));
    canvas.drawPath(neckPath, Paint()
      ..shader = LinearGradient(
        colors: [_neckColor, _neckShadow, _neckColor],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - neckW / 2, headH, neckW, bodyTop - headH)));
    canvas.drawPath(neckPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // Fret lines
    for (int f = 1; f <= 4; f++) {
      final fy = headH + (bodyTop - headH) * f / 5.0;
      canvas.drawLine(Offset(cx - neckW / 2 + 1, fy), Offset(cx + neckW / 2 - 1, fy),
          Paint()..color = _fretmetal.withValues(alpha: 0.6)..strokeWidth = 0.7);
    }

    // Strings on neck (6)
    final stringSpacing = (neckW - 3) / 5;
    for (int s = 0; s < 6; s++) {
      final sx = cx - neckW / 2 + 1.5 + s * stringSpacing;
      canvas.drawLine(Offset(sx, headH + 2), Offset(sx, bodyTop),
          Paint()
            ..color = (isActive ? AppColors.accent : AppColors.textSecondary).withValues(alpha: 0.28 + s * 0.04)
            ..strokeWidth = 0.3 + s * 0.06);
    }

    // ── Guitar body (dreadnought bezier) ──
    final bodyPath = _guitarBodyPath(cx, w, h, bodyTop);
    canvas.drawPath(bodyPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isActive
            ? [_bodyAmber, _bodyMid, _bodyDark]
            : [const Color(0xFF5A3A18), const Color(0xFF3A2210), const Color(0xFF261608)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, bodyTop, w, h - bodyTop)));

    // Body binding (edge highlight)
    canvas.drawPath(bodyPath, Paint()
      ..color = _binding.withValues(alpha: isActive ? 0.25 : 0.12)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);
    canvas.drawPath(bodyPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // ── Sound hole ──
    final holeCenter = Offset(cx, bodyTop + (h - bodyTop) * 0.40);
    final holeR = w * 0.14;
    // Rosette ring
    canvas.drawCircle(holeCenter, holeR + 2.5,
        Paint()..color = isActive ? _pegGold : _pegSilver.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke..strokeWidth = 1.0);
    canvas.drawCircle(holeCenter, holeR + 1.0,
        Paint()..color = _binding.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke..strokeWidth = 0.5);
    canvas.drawCircle(holeCenter, holeR, Paint()..color = const Color(0xFF080810));

    // ── Bridge ──
    final bridgeY = bodyTop + (h - bodyTop) * 0.70;
    final bridgePath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.15, bridgeY, w * 0.30, h * 0.04),
        const Radius.circular(1.5)));
    canvas.drawPath(bridgePath, Paint()..color = _headstock);
    // Saddle
    canvas.drawLine(Offset(cx - w * 0.12, bridgeY + h * 0.012),
        Offset(cx + w * 0.12, bridgeY + h * 0.012),
        Paint()..color = _binding..strokeWidth = 1.5..strokeCap = StrokeCap.round);

    // Strings on body (to bridge)
    for (int s = 0; s < 6; s++) {
      final sx = cx - neckW / 2 + 1.5 + s * stringSpacing;
      canvas.drawLine(Offset(sx, bodyTop), Offset(cx - w * 0.12 + s * w * 0.048, bridgeY + h * 0.012),
          Paint()
            ..color = (isActive ? AppColors.accent : AppColors.textSecondary).withValues(alpha: 0.20)
            ..strokeWidth = 0.3 + s * 0.06);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  BASS GUITAR  (solid body J-bass silhouette)
  // ══════════════════════════════════════════════════════════════
  void _drawBass(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final headW = w * 0.36;
    final headH = h * 0.11;
    final neckW = w * 0.20;
    final bodyTop = h * 0.40;

    // ── Headstock (4-in-line style) ──
    final headPath = Path()
      ..moveTo(cx - headW / 2, headH)
      ..lineTo(cx - headW / 2, h * 0.018)
      ..quadraticBezierTo(cx - headW / 2, 0, cx - headW / 2 + h * 0.018, 0)
      ..lineTo(cx + headW / 4, 0)
      ..quadraticBezierTo(cx + headW / 2, h * 0.03, cx + headW / 2, headH * 0.6)
      ..lineTo(cx + headW * 0.2, headH)
      ..close();
    canvas.drawPath(headPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: isActive
            ? [const Color(0xFF223050), const Color(0xFF0E1828)]
            : [_headLight, _headstock],
      ).createShader(Rect.fromLTWH(cx - headW / 2, 0, headW, headH)));
    canvas.drawPath(headPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke..strokeWidth = 0.6);

    // Tuning pegs (4, all on left for J-bass look)
    final pegColor = isActive ? AppColors.accent : _pegSilver;
    final bassStrings = type == 'bass4' ? 4 : type == 'bass5' ? 5 : 6;
    final leftPegs = (bassStrings / 2).ceil();
    final rightPegs = bassStrings - leftPegs;
    for (int i = 0; i < leftPegs; i++) {
      final py = h * 0.01 + i * headH / leftPegs + headH / (leftPegs * 2);
      canvas.drawLine(Offset(cx - headW / 2, py),
          Offset(cx - headW / 2 - w * 0.05, py),
          Paint()..color = pegColor..strokeWidth = 1.2..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(cx - headW / 2 - w * 0.05, py), 2.5, Paint()..color = pegColor);
      canvas.drawCircle(Offset(cx - headW / 2 - w * 0.05, py), 1.0, Paint()..color = Colors.white.withValues(alpha: 0.35));
    }
    for (int i = 0; i < rightPegs; i++) {
      final py = h * 0.01 + i * headH / rightPegs + headH / (rightPegs * 2);
      canvas.drawLine(Offset(cx + headW * 0.2, py),
          Offset(cx + headW * 0.2 + w * 0.05, py),
          Paint()..color = pegColor..strokeWidth = 1.2..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(cx + headW * 0.2 + w * 0.05, py), 2.5, Paint()..color = pegColor);
      canvas.drawCircle(Offset(cx + headW * 0.2 + w * 0.05, py), 1.0, Paint()..color = Colors.white.withValues(alpha: 0.35));
    }

    // Nut
    canvas.drawLine(Offset(cx - neckW / 2, headH + 0.5),
        Offset(cx + neckW / 2, headH + 0.5),
        Paint()..color = _binding..strokeWidth = 2.0..strokeCap = StrokeCap.round);

    // ── Neck ──
    final neckPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - neckW / 2, headH, neckW, bodyTop - headH),
        const Radius.circular(2)));
    canvas.drawPath(neckPath, Paint()
      ..shader = LinearGradient(
        colors: [_neckColor, _neckShadow, _neckColor],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - neckW / 2, headH, neckW, bodyTop - headH)));
    canvas.drawPath(neckPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // Frets
    for (int f = 1; f <= 5; f++) {
      final fy = headH + (bodyTop - headH) * f / 6.0;
      canvas.drawLine(Offset(cx - neckW / 2 + 1, fy), Offset(cx + neckW / 2 - 1, fy),
          Paint()..color = _fretmetal.withValues(alpha: 0.55)..strokeWidth = 0.7);
    }

    // Strings on neck
    final strSpacing = (neckW - 3) / (bassStrings - 1).clamp(1, 5).toDouble();
    for (int s = 0; s < bassStrings; s++) {
      final sx = cx - neckW / 2 + 1.5 + s * strSpacing;
      canvas.drawLine(Offset(sx, headH + 2), Offset(sx, bodyTop),
          Paint()
            ..color = (isActive ? AppColors.accent : AppColors.textSecondary).withValues(alpha: 0.28)
            ..strokeWidth = 0.4 + s * 0.12);
    }

    // ── Body (offset/asymmetric J-bass style) ──
    final bodyPath = _bassBodyPath(cx, w, h, bodyTop);
    canvas.drawPath(bodyPath, Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.1,
        colors: isActive
            ? [const Color(0xFF2A4870), _bassBody1, _bassBody2]
            : [const Color(0xFF223040), const Color(0xFF142030), const Color(0xFF080E18)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, bodyTop, w, h - bodyTop)));

    // Binding
    canvas.drawPath(bodyPath, Paint()
      ..color = (isActive ? AppColors.accent : _binding).withValues(alpha: isActive ? 0.20 : 0.10)
      ..style = PaintingStyle.stroke..strokeWidth = 1.0);
    canvas.drawPath(bodyPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // ── Pickups ──
    final pu1Y = bodyTop + (h - bodyTop) * 0.38;
    final pu2Y = bodyTop + (h - bodyTop) * 0.58;
    _drawPickup(canvas, cx, pu1Y, w * 0.36, h * 0.045, isActive);
    _drawPickup(canvas, cx + w * 0.04, pu2Y, w * 0.32, h * 0.04, isActive);

    // ── Bridge ──
    final bridgeY = bodyTop + (h - bodyTop) * 0.74;
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w * 0.14, bridgeY, w * 0.28, h * 0.05),
      const Radius.circular(2)),
      Paint()..color = isActive ? const Color(0xFF446688) : const Color(0xFF2A3540));
    canvas.drawLine(Offset(cx - w * 0.12, bridgeY + h * 0.015),
        Offset(cx + w * 0.12, bridgeY + h * 0.015),
        Paint()..color = _binding.withValues(alpha: 0.5)..strokeWidth = 1.2..strokeCap = StrokeCap.round);

    // Strings to bridge
    for (int s = 0; s < bassStrings; s++) {
      final sx = cx - neckW / 2 + 1.5 + s * strSpacing;
      canvas.drawLine(Offset(sx, bodyTop), Offset(cx - w * 0.10 + s * w * 0.065, bridgeY + h * 0.015),
          Paint()
            ..color = (isActive ? AppColors.accent : AppColors.textSecondary).withValues(alpha: 0.18)
            ..strokeWidth = 0.4 + s * 0.12);
    }

    // Strap pin
    canvas.drawCircle(Offset(cx - w * 0.32, bodyTop + (h - bodyTop) * 0.18), 2.5,
        Paint()..color = _pegSilver);
    canvas.drawCircle(Offset(cx + w * 0.10, h - h * 0.02), 2.5,
        Paint()..color = _pegSilver);
  }

  void _drawPickup(Canvas canvas, double cx, double py, double pw, double ph, bool active) {
    final pu = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - pw / 2, py, pw, ph), const Radius.circular(2));
    canvas.drawRRect(pu, Paint()
      ..color = active ? const Color(0xFF334466) : const Color(0xFF1A2030));
    canvas.drawRRect(pu, Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);
    // Pole pieces
    final poleSpacing = pw / 5;
    for (int p = 0; p < 4; p++) {
      canvas.drawCircle(Offset(cx - pw * 0.3 + p * poleSpacing, py + ph / 2), 1.2,
          Paint()..color = active ? AppColors.accent.withValues(alpha: 0.5) : _pegSilver.withValues(alpha: 0.4));
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  UKULELE  (soprano silhouette)
  // ══════════════════════════════════════════════════════════════
  void _drawUkulele(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final headW = w * 0.38;
    final headH = h * 0.10;
    final neckW = w * 0.16;
    final bodyTop = h * 0.34;

    // ── Headstock ──
    final headPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - headW / 2, 0, headW, headH),
        const Radius.circular(4)));
    canvas.drawPath(headPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: isActive
            ? [const Color(0xFF3C2808), const Color(0xFF1E1004)]
            : [_headLight, _headstock],
      ).createShader(Rect.fromLTWH(cx - headW / 2, 0, headW, headH)));
    canvas.drawPath(headPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // Tuning pegs (4 — 2 per side)
    final pegColor = isActive ? _pegGold : _pegSilver;
    for (int i = 0; i < 2; i++) {
      final py = h * 0.015 + i * headH / 2.2 + headH / 5;
      canvas.drawLine(Offset(cx - headW / 2, py),
          Offset(cx - headW / 2 - w * 0.055, py),
          Paint()..color = pegColor..strokeWidth = 1.1..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(cx - headW / 2 - w * 0.055, py), 2.4, Paint()..color = pegColor);
      canvas.drawLine(Offset(cx + headW / 2, py),
          Offset(cx + headW / 2 + w * 0.055, py),
          Paint()..color = pegColor..strokeWidth = 1.1..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(cx + headW / 2 + w * 0.055, py), 2.4, Paint()..color = pegColor);
    }

    // Nut
    canvas.drawLine(Offset(cx - neckW / 2, headH + 0.5),
        Offset(cx + neckW / 2, headH + 0.5),
        Paint()..color = _binding..strokeWidth = 2.0..strokeCap = StrokeCap.round);

    // ── Neck ──
    final neckPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - neckW / 2, headH, neckW, bodyTop - headH),
        const Radius.circular(2)));
    canvas.drawPath(neckPath, Paint()
      ..shader = LinearGradient(
        colors: [_neckColor, _neckShadow, _neckColor],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - neckW / 2, headH, neckW, bodyTop - headH)));
    canvas.drawPath(neckPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // Frets
    for (int f = 1; f <= 3; f++) {
      final fy = headH + (bodyTop - headH) * f / 4.0;
      canvas.drawLine(Offset(cx - neckW / 2 + 1, fy), Offset(cx + neckW / 2 - 1, fy),
          Paint()..color = _fretmetal.withValues(alpha: 0.5)..strokeWidth = 0.7);
    }

    // 4 Strings on neck
    final strSpacing = (neckW - 2) / 3;
    for (int s = 0; s < 4; s++) {
      final sx = cx - neckW / 2 + 1 + s * strSpacing;
      canvas.drawLine(Offset(sx, headH + 2), Offset(sx, bodyTop),
          Paint()
            ..color = (isActive ? _ukeBody1 : AppColors.textSecondary).withValues(alpha: 0.35)
            ..strokeWidth = 0.4 + s * 0.07);
    }

    // ── Body (compact figure-8) ──
    final bodyPath = _ukuleleBodyPath(cx, w, h, bodyTop);
    canvas.drawPath(bodyPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isActive
            ? [_ukeBody1, const Color(0xFFB07828), _ukeBody2]
            : [const Color(0xFF6A4018), const Color(0xFF4A2808), const Color(0xFF301808)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, bodyTop, w, h - bodyTop)));
    canvas.drawPath(bodyPath, Paint()
      ..color = _binding.withValues(alpha: isActive ? 0.3 : 0.12)
      ..style = PaintingStyle.stroke..strokeWidth = 1.0);
    canvas.drawPath(bodyPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // Sound hole with rosette
    final holeCenter = Offset(cx, bodyTop + (h - bodyTop) * 0.44);
    final holeR = w * 0.13;
    canvas.drawCircle(holeCenter, holeR + 2.5,
        Paint()..color = isActive ? _pegGold : _pegSilver.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke..strokeWidth = 1.0);
    canvas.drawCircle(holeCenter, holeR + 1.0,
        Paint()..color = _binding.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke..strokeWidth = 0.5);
    canvas.drawCircle(holeCenter, holeR, Paint()..color = const Color(0xFF080810));

    // Bridge saddle
    final bridgeY = bodyTop + (h - bodyTop) * 0.70;
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w * 0.10, bridgeY, w * 0.20, h * 0.035),
      const Radius.circular(1.5)),
      Paint()..color = _headstock);
    canvas.drawLine(Offset(cx - w * 0.08, bridgeY + h * 0.010),
        Offset(cx + w * 0.08, bridgeY + h * 0.010),
        Paint()..color = _binding..strokeWidth = 1.2..strokeCap = StrokeCap.round);

    // Strings to bridge
    for (int s = 0; s < 4; s++) {
      final sx = cx - neckW / 2 + 1 + s * strSpacing;
      canvas.drawLine(Offset(sx, bodyTop), Offset(cx - w * 0.06 + s * w * 0.04, bridgeY + h * 0.01),
          Paint()
            ..color = (isActive ? _ukeBody1 : AppColors.textSecondary).withValues(alpha: 0.22)
            ..strokeWidth = 0.35 + s * 0.07);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  PATH HELPERS
  // ══════════════════════════════════════════════════════════════

  /// Classic dreadnought guitar body — bezier figure-8 silhouette.
  Path _guitarBodyPath(double cx, double w, double h, double bodyTop) {
    final bh = h - bodyTop;
    final ub = w * 0.42;   // upper bout half-width
    final wa = w * 0.26;   // waist half-width
    final lb = w * 0.49;   // lower bout half-width
    final ubY = bodyTop + bh * 0.28;
    final waY = bodyTop + bh * 0.46;
    final lbY = bodyTop + bh * 0.66;

    final path = Path()..moveTo(cx, bodyTop);
    // Right side
    path.cubicTo(cx + ub, bodyTop, cx + ub, ubY, cx + wa, waY);
    path.cubicTo(cx + wa, waY, cx + lb, waY + bh * 0.10, cx + lb, lbY);
    path.cubicTo(cx + lb, lbY, cx + lb * 0.65, h, cx, h);
    // Left side
    path.cubicTo(cx - lb * 0.65, h, cx - lb, lbY, cx - lb, lbY);
    path.cubicTo(cx - lb, waY + bh * 0.10, cx - wa, waY, cx - wa, waY);
    path.cubicTo(cx - ub, ubY, cx - ub, bodyTop, cx, bodyTop);
    path.close();
    return path;
  }

  /// Offset J-bass body — asymmetric curved silhouette.
  Path _bassBodyPath(double cx, double w, double h, double bodyTop) {
    final bh = h - bodyTop;
    final path = Path()..moveTo(cx, bodyTop);
    // Upper horn (right — longer)
    path.cubicTo(cx + w * 0.50, bodyTop, cx + w * 0.50, bodyTop + bh * 0.18,
        cx + w * 0.42, bodyTop + bh * 0.25);
    // Lower right bout
    path.cubicTo(cx + w * 0.48, bodyTop + bh * 0.45,
        cx + w * 0.50, bodyTop + bh * 0.70, cx + w * 0.25, h);
    // Bottom curve
    path.cubicTo(cx + w * 0.10, h + h * 0.02, cx - w * 0.10, h + h * 0.02, cx - w * 0.25, h);
    // Lower left
    path.cubicTo(cx - w * 0.48, bodyTop + bh * 0.65,
        cx - w * 0.45, bodyTop + bh * 0.40, cx - w * 0.35, bodyTop + bh * 0.28);
    // Upper horn (left — shorter stub)
    path.cubicTo(cx - w * 0.42, bodyTop + bh * 0.18,
        cx - w * 0.28, bodyTop + bh * 0.04, cx, bodyTop);
    path.close();
    return path;
  }

  /// Compact soprano ukulele body — tighter figure-8.
  Path _ukuleleBodyPath(double cx, double w, double h, double bodyTop) {
    final bh = h - bodyTop;
    final ub = w * 0.35;
    final wa = w * 0.22;
    final lb = w * 0.42;
    final ubY = bodyTop + bh * 0.26;
    final waY = bodyTop + bh * 0.44;
    final lbY = bodyTop + bh * 0.64;

    final path = Path()..moveTo(cx, bodyTop);
    path.cubicTo(cx + ub, bodyTop, cx + ub, ubY, cx + wa, waY);
    path.cubicTo(cx + wa, waY, cx + lb, waY + bh * 0.10, cx + lb, lbY);
    path.cubicTo(cx + lb, lbY, cx + lb * 0.60, h, cx, h);
    path.cubicTo(cx - lb * 0.60, h, cx - lb, lbY, cx - lb, lbY);
    path.cubicTo(cx - lb, waY + bh * 0.10, cx - wa, waY, cx - wa, waY);
    path.cubicTo(cx - ub, ubY, cx - ub, bodyTop, cx, bodyTop);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _InstrumentIconPainter old) =>
      old.type != type || old.isActive != isActive;
}

// ═══════════════════════════════════════════════════════════════
//  HEADSTOCK PAINTER (Top-down view with strings and tuners)
// ═══════════════════════════════════════════════════════════════

class _HeadstockPainter extends CustomPainter {
  final int stringCount;
  final int activeStringIdx;
  final bool isTuned;
  final bool isBass;

  _HeadstockPainter({required this.stringCount, required this.activeStringIdx, required this.isTuned, required this.isBass});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ── Neck (vertical from bottom to middle) ──
    final neckW = isBass ? 42.0 : 36.0;
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - neckW / 2, h * 0.35, neckW, h * 0.65),
      const Radius.circular(4),
    );
    canvas.drawRRect(neckRect, Paint()..color = const Color(0xFF3E2723)); // dark wood
    canvas.drawRRect(neckRect, Paint()..color = const Color(0xFF5D4037)..style = PaintingStyle.stroke..strokeWidth = 1);

    // ── Headstock ──
    final headW = isBass ? 56.0 : 48.0;
    final headH = h * 0.42;
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - headW / 2, 0, headW, headH),
      const Radius.circular(8),
    );
    canvas.drawRRect(headRect, Paint()..color = const Color(0xFF2E1B0E));
    canvas.drawRRect(headRect, Paint()..color = const Color(0xFF4E3524)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // ── Nut (white line between headstock and neck) ──
    canvas.drawLine(
      Offset(cx - neckW / 2 + 2, headH), Offset(cx + neckW / 2 - 2, headH),
      Paint()..color = const Color(0xFFE8E0D0)..strokeWidth = 3..strokeCap = StrokeCap.round,
    );

    // ── Strings ──
    final stringArea = neckW - 10;
    final gap = stringCount > 1 ? stringArea / (stringCount - 1) : 0.0;
    final startX = cx - stringArea / 2;

    for (int i = 0; i < stringCount; i++) {
      final x = startX + i * gap;
      final isActive = i == activeStringIdx;
      final thickness = isBass
        ? 2.5 - i * 0.3
        : 2.0 - i * 0.2;

      Color stringColor;
      if (isActive && isTuned) stringColor = AppColors.accent2;
      else if (isActive) stringColor = AppColors.warning;
      else stringColor = const Color(0xFF9E9E9E);

      // String line
      canvas.drawLine(
        Offset(x, headH + 3), Offset(x, h),
        Paint()..color = stringColor..strokeWidth = thickness.clamp(0.8, 2.5)..strokeCap = StrokeCap.round,
      );

      // Glow on active string
      if (isActive) {
        canvas.drawLine(
          Offset(x, headH + 3), Offset(x, h),
          Paint()..color = stringColor.withValues(alpha: 0.3)..strokeWidth = (thickness + 4).clamp(3, 8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }

      // ── Tuning pegs (circles on sides of headstock) ──
      final isLeft = i < (stringCount / 2).ceil();
      final pegIdx = isLeft ? i : i - (stringCount / 2).ceil();
      final pegY = 10.0 + pegIdx * (headH - 20) / ((stringCount / 2).ceil());
      final pegX = isLeft ? cx - headW / 2 - 6 : cx + headW / 2 + 6;

      // Peg shaft (line from peg to headstock)
      canvas.drawLine(
        Offset(pegX, pegY), Offset(isLeft ? cx - headW / 2 + 4 : cx + headW / 2 - 4, pegY),
        Paint()..color = const Color(0xFF757575)..strokeWidth = 2,
      );
      // Peg button
      canvas.drawCircle(Offset(pegX, pegY), 5, Paint()..color = isActive ? stringColor : const Color(0xFF9E9E9E));
      canvas.drawCircle(Offset(pegX, pegY), 5, Paint()..color = const Color(0xFF616161)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawCircle(Offset(pegX, pegY), 2, Paint()..color = Colors.white.withValues(alpha: 0.3));
    }

    // ── Fret markers on neck ──
    final fretY1 = headH + (h - headH) * 0.35;
    final fretY2 = headH + (h - headH) * 0.7;
    canvas.drawCircle(Offset(cx, fretY1), 3, Paint()..color = const Color(0xFFE8E0D0).withValues(alpha: 0.4));
    canvas.drawCircle(Offset(cx, fretY2), 3, Paint()..color = const Color(0xFFE8E0D0).withValues(alpha: 0.4));

    // ── Fret lines ──
    for (int f = 1; f <= 3; f++) {
      final fy = headH + (h - headH) * (f / 4);
      canvas.drawLine(
        Offset(cx - neckW / 2 + 3, fy), Offset(cx + neckW / 2 - 3, fy),
        Paint()..color = const Color(0xFF9E9E9E).withValues(alpha: 0.3)..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeadstockPainter old) =>
    old.stringCount != stringCount || old.activeStringIdx != activeStringIdx || old.isTuned != isTuned;
}

// ═══════════════════════════════════════════════════════════════
//  TUNER GAUGE PAINTER (Premium semicircular with ticks)
// ═══════════════════════════════════════════════════════════════

class _TunerGaugePainter extends CustomPainter {
  final double cents;
  final Color noteColor;
  final bool isActive;

  _TunerGaugePainter({required this.cents, required this.noteColor, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 8);
    final radius = size.width / 2 - 16;

    // ── Background arc — neumorphic inset track ──
    // Outer dark shadow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 2),
      pi, pi, false,
      Paint()..color = Colors.black.withValues(alpha: 0.55)..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round,
    );
    // Lighter top highlight
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      pi, pi, false,
      Paint()..color = const Color(0xFF2A2A2A).withValues(alpha: 0.45)..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round,
    );
    // Track fill
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, pi, false,
      Paint()..color = AppColors.bgInset..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round,
    );

    // ── Colored zones (red-yellow-green-yellow-red) ──
    const zones = 20;
    for (int i = 0; i < zones; i++) {
      final frac = i / zones;
      final angle = pi + pi * frac;
      final distFromCenter = (frac - 0.5).abs();
      Color zoneColor;
      if (distFromCenter < 0.05)       zoneColor = AppColors.accent2.withValues(alpha: 0.35);
      else if (distFromCenter < 0.2)   zoneColor = AppColors.warning.withValues(alpha: 0.14);
      else                              zoneColor = AppColors.danger.withValues(alpha: 0.09);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle, pi / zones, false,
        Paint()..color = zoneColor..style = PaintingStyle.stroke..strokeWidth = 10,
      );
    }

    // ── Tick marks — neon green center tick ──
    for (int i = 0; i <= 20; i++) {
      final frac = i / 20;
      final angle = pi + pi * frac;
      final isMajor = i % 5 == 0;
      final isCenter = i == 10;
      final inner = radius - (isCenter ? 22 : isMajor ? 14 : 8);
      final outer = radius + 7;

      if (isCenter) {
        // Neon green center tick with glow
        canvas.drawLine(
          Offset(center.dx + inner * cos(angle), center.dy + inner * sin(angle)),
          Offset(center.dx + outer * cos(angle), center.dy + outer * sin(angle)),
          Paint()
            ..color = AppColors.accent2.withValues(alpha: 0.30)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawLine(
          Offset(center.dx + inner * cos(angle), center.dy + inner * sin(angle)),
          Offset(center.dx + outer * cos(angle), center.dy + outer * sin(angle)),
          Paint()
            ..color = AppColors.accent2
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawLine(
          Offset(center.dx + inner * cos(angle), center.dy + inner * sin(angle)),
          Offset(center.dx + outer * cos(angle), center.dy + outer * sin(angle)),
          Paint()
            ..color = isMajor ? AppColors.textMuted : AppColors.border
            ..strokeWidth = isMajor ? 1.4 : 0.7
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── Note labels at edges ──
    _drawTextAt(canvas, '\u266D', Offset(center.dx + (radius + 16) * cos(pi + pi * 0.08), center.dy + (radius + 16) * sin(pi + pi * 0.08)),
      AppColors.danger.withValues(alpha: 0.6), 11);
    _drawTextAt(canvas, '\u266F', Offset(center.dx + (radius + 16) * cos(pi + pi * 0.92), center.dy + (radius + 16) * sin(pi + pi * 0.92)),
      AppColors.danger.withValues(alpha: 0.6), 11);

    if (!isActive) return;

    // ── Needle ──
    final clamped = cents.clamp(-50.0, 50.0);
    final needleAngle = pi + (pi * (clamped + 50) / 100);
    final needleLen = radius - 6;

    // Needle shadow
    canvas.drawLine(
      Offset(center.dx + 1, center.dy + 1),
      Offset(center.dx + needleLen * cos(needleAngle) + 1, center.dy + needleLen * sin(needleAngle) + 1),
      Paint()..color = Colors.black.withValues(alpha: 0.3)..strokeWidth = 4..strokeCap = StrokeCap.round,
    );
    // Needle body
    canvas.drawLine(
      center,
      Offset(center.dx + needleLen * cos(needleAngle), center.dy + needleLen * sin(needleAngle)),
      Paint()..color = noteColor..strokeWidth = 3..strokeCap = StrokeCap.round,
    );
    // Needle tip glow
    final tipPos = Offset(center.dx + needleLen * cos(needleAngle), center.dy + needleLen * sin(needleAngle));
    canvas.drawCircle(tipPos, 4, Paint()..color = noteColor.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(tipPos, 2, Paint()..color = noteColor);

    // Center pivot — neumorphic raised dot
    canvas.drawCircle(center, 9, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawCircle(center, 7, Paint()..color = AppColors.bgPanel);
    // LED glow
    if (noteColor == AppColors.accent2) {
      canvas.drawCircle(center, 8, Paint()
        ..color = noteColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    canvas.drawCircle(center, 4.5, Paint()..color = noteColor);
    canvas.drawCircle(center, 2, Paint()..color = Colors.white.withValues(alpha: 0.55));
  }

  void _drawTextAt(Canvas canvas, String text, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TunerGaugePainter old) =>
    old.cents != cents || old.noteColor != noteColor || old.isActive != isActive;
}
