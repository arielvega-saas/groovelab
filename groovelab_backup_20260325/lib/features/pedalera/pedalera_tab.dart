import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../core/widgets/signal_flow_widget.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';
import 'pedalera_models.dart';
import 'pedalera_providers.dart';

class PedaleraTab extends ConsumerStatefulWidget {
  const PedaleraTab({super.key});

  @override
  ConsumerState<PedaleraTab> createState() => _PedaleraTabState();
}

class _PedaleraTabState extends ConsumerState<PedaleraTab> {
  bool _inputActive = false;
  int? _selectedPedalIndex;
  bool _liveMode = false;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final chain = ref.watch(pedalChainProvider);
    final activePreset = ref.watch(activePresetProvider);
    final presets = ref.watch(pedalPresetsProvider);

    if (_liveMode) return _buildLiveMode(chain);

    return Column(
      children: [
        // ── Preset Bar ──
        _buildPresetBar(activePreset, presets),

        // ── Signal Chain ──
        Expanded(
          flex: _selectedPedalIndex != null ? 1 : 2,
          child: _buildSignalChain(chain),
        ),

        // ── Pedal Detail Panel ──
        if (_selectedPedalIndex != null && _selectedPedalIndex! < chain.length)
          Expanded(
            flex: 2,
            child: _buildPedalDetail(chain[_selectedPedalIndex!], _selectedPedalIndex!),
          ),

        // ── Bottom Controls ──
        _buildBottomControls(chain),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PRESET BAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPresetBar(PedalPreset? active, List<PedalPreset> presets) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.bgDeepest,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            active?.name ?? 'No Preset',
            style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          if (active != null)
            Text(
              active.category,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
            ),
          const Spacer(),
          // Preset browser button
          GestureDetector(
            onTap: () => _showPresetBrowser(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgPanel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.folder_open, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Presets', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Live mode toggle
          GestureDetector(
            onTap: () => setState(() => _liveMode = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warm.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warm.withValues(alpha: 0.4)),
              ),
              child: Text('LIVE', style: GoogleFonts.jetBrainsMono(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warm,
              )),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SIGNAL CHAIN VIEW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSignalChain(List<PedalState> chain) {
    if (chain.isEmpty) return _buildEmptyState();

    return Container(
      color: AppColors.bgDark,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text('SIGNAL CHAIN', style: GoogleFonts.jetBrainsMono(
            fontSize: 10, color: AppColors.textMuted, letterSpacing: 1.5,
          )),
          const SizedBox(height: 4),
          // ── Visual signal flow diagram (premium UX) ──
          SignalFlowWidget(
            chain: chain.map((p) => {
              'type': p.type.name,
              'enabled': p.enabled,
            }).toList(),
            selectedIndex: _selectedPedalIndex,
            onPedalTap: (idx) {
              HapticFeedback.selectionClick();
              setState(() => _selectedPedalIndex = _selectedPedalIndex == idx ? null : idx);
            },
            onBypassToggle: (idx) => _toggleBypass(idx, chain),
          ),
          const SizedBox(height: 4),
          // ── Detailed pedal cards (scrollable) ──
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: chain.length + 1, // +1 for "add" button
              separatorBuilder: (_, __) => _chainConnector(),
              itemBuilder: (context, index) {
                if (index == chain.length) return _addPedalButton();
                return _pedalCard(chain[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleBypass(int index, List<PedalState> chain) {
    if (index < 0 || index >= chain.length) return;
    final pedal = chain[index];
    final newEnabled = !pedal.enabled;
    ref.read(pedalChainProvider.notifier).state = [
      for (int i = 0; i < chain.length; i++)
        if (i == index) pedal.copyWith(enabled: newEnabled) else chain[i],
    ];
    ref.read(audioServiceProvider).setPedalBypass(index, !newEnabled);
    HapticFeedback.mediumImpact();
  }

  Widget _pedalCard(PedalState pedal, int index) {
    final isSelected = _selectedPedalIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPedalIndex = isSelected ? null : index);
      },
      onLongPress: () => _showPedalMenu(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [pedal.color.withValues(alpha: 0.18), pedal.color.withValues(alpha: 0.08)]
                : [AppColors.bgPanel, const Color(0xFF1C1C1C)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? pedal.color : (pedal.enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.3)),
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(3, 3)),
            const BoxShadow(color: Color(0xFF2A2A2A), blurRadius: 6, offset: Offset(-2, -2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LED indicator
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pedal.enabled ? pedal.color : AppColors.textMuted,
                boxShadow: pedal.enabled ? [
                  BoxShadow(color: pedal.color.withValues(alpha: 0.6), blurRadius: 6),
                ] : null,
              ),
            ),
            const SizedBox(height: 8),
            Icon(pedal.icon, size: 28, color: pedal.enabled ? pedal.color : AppColors.textMuted),
            const SizedBox(height: 6),
            Text(
              pedal.name,
              style: GoogleFonts.outfit(
                fontSize: 10, color: pedal.enabled ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chainConnector() {
    return Center(
      child: SizedBox(
        width: 24, height: 12,
        child: CustomPaint(
          painter: _ChainConnectorPainter(),
        ),
      ),
    );
  }

  Widget _addPedalButton() {
    return GestureDetector(
      onTap: _showAddPedalSheet,
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          color: AppColors.bgInset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 24, color: AppColors.accent),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cable, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Build Your Signal Chain',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Tap a preset or add effects manually',
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showPresetBrowser,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Browse Presets'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PEDAL DETAIL PANEL
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPedalDetail(PedalState pedal, int index) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        border: Border(top: BorderSide(color: pedal.color.withValues(alpha: 0.6), width: 2.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, -3)),
          const BoxShadow(color: Color(0xFF2A2A2A), blurRadius: 6, offset: Offset(0, -1)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(pedal.icon, size: 20, color: pedal.color),
                const SizedBox(width: 8),
                Text(pedal.name, style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                )),
                const Spacer(),
                // Bypass toggle
                GestureDetector(
                  onTap: () {
                    final chain = List<PedalState>.from(ref.read(pedalChainProvider));
                    chain[index] = pedal.copyWith(enabled: !pedal.enabled);
                    ref.read(pedalChainProvider.notifier).state = chain;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: pedal.enabled
                          ? const Color(0xFF32D74B).withValues(alpha: 0.15)
                          : AppColors.bgInset,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: pedal.enabled ? const Color(0xFF32D74B) : AppColors.border,
                      ),
                    ),
                    child: Text(
                      pedal.enabled ? 'ON' : 'OFF',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: pedal.enabled ? const Color(0xFF32D74B) : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Knobs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: pedal.params.entries.map((entry) {
                  return _buildKnob(
                    label: entry.key,
                    value: entry.value,
                    min: _minForParam(pedal.type, entry.key),
                    max: _maxForParam(pedal.type, entry.key),
                    onChanged: (val) {
                      final chain = List<PedalState>.from(ref.read(pedalChainProvider));
                      final newParams = Map<String, double>.from(pedal.params);
                      newParams[entry.key] = val;
                      chain[index] = pedal.copyWith(params: newParams);
                      ref.read(pedalChainProvider.notifier).state = chain;
                    },
                    color: pedal.color,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnob({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required Color color,
  }) {
    final normalized = (value - min) / (max - min);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Knob (simplified as a radial slider)
          GestureDetector(
            onPanUpdate: (details) {
              final delta = -details.delta.dy / 150.0;
              final newNorm = (normalized + delta).clamp(0.0, 1.0);
              onChanged(min + newNorm * (max - min));
            },
            child: SizedBox(
              width: 56, height: 56,
              child: CustomPaint(
                painter: _KnobPainter(value: normalized, color: color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          Text(
            _unitForParam(label),
            style: GoogleFonts.outfit(fontSize: 8, color: AppColors.textMuted.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  double _minForParam(EffectType type, String param) {
    if (param == 'threshold') return -60;
    if (param == 'time') return 10;
    if (param == 'release' || param == 'attack') return 1;
    return 0;
  }

  double _maxForParam(EffectType type, String param) {
    if (param == 'threshold') return 0;
    if (param == 'ratio') return 20;
    if (param == 'time') return 2000;
    if (param == 'release') return 500;
    if (param == 'attack') return 100;
    return 100;
  }

  String _unitForParam(String param) {
    final p = param.toLowerCase();
    if (p.contains('gain') || p.contains('threshold') || p.contains('volume') || p.contains('level')) return 'dB';
    if (p.contains('time') || p.contains('delay') || p.contains('attack') || p.contains('release') || p.contains('decay')) return 'ms';
    if (p.contains('mix') || p.contains('blend') || p.contains('depth') || p.contains('ratio')) return '%';
    if (p.contains('freq') || p.contains('tone') || p.contains('rate')) return 'Hz';
    return '';
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BOTTOM CONTROLS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBottomControls(List<PedalState> chain) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.bgDeepest,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Input toggle
          GestureDetector(
            onTap: () => setState(() => _inputActive = !_inputActive),
            child: Container(
              width: 48, height: 40,
              decoration: BoxDecoration(
                color: _inputActive ? AppColors.danger.withValues(alpha: 0.15) : AppColors.bgPanel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _inputActive ? AppColors.danger : AppColors.border),
              ),
              child: Icon(
                _inputActive ? Icons.mic : Icons.mic_off,
                size: 20,
                color: _inputActive ? AppColors.danger : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Latency display
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LATENCY', style: GoogleFonts.outfit(fontSize: 8, color: AppColors.textMuted, letterSpacing: 1)),
              Text(
                '${ref.watch(pedalLatencyMsProvider).toStringAsFixed(1)} ms',
                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          // Quick toggles for main effect types
          ...chain.where((p) => [EffectType.drive, EffectType.chorus, EffectType.delay, EffectType.reverb].contains(p.type))
            .map((pedal) {
              final idx = chain.indexOf(pedal);
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () {
                    final newChain = List<PedalState>.from(chain);
                    newChain[idx] = pedal.copyWith(enabled: !pedal.enabled);
                    ref.read(pedalChainProvider.notifier).state = newChain;
                  },
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: pedal.enabled ? pedal.color.withValues(alpha: 0.15) : AppColors.bgPanel,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pedal.enabled ? pedal.color : AppColors.border),
                      boxShadow: pedal.enabled ? [
                        BoxShadow(color: pedal.color.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 0),
                      ] : null,
                    ),
                    child: Icon(pedal.icon, size: 20, color: pedal.enabled ? pedal.color : AppColors.textMuted),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  LIVE MODE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildLiveMode(List<PedalState> chain) {
    final presets = ref.watch(pedalPresetsProvider);
    final quickPresets = presets.take(4).toList();

    return Container(
      color: AppColors.bgDark,
      child: Column(
        children: [
          // Exit button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _liveMode = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgPanel,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.arrow_back, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('EXIT LIVE', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ),
                ),
                const Spacer(),
                Text('LIVE MODE', style: GoogleFonts.jetBrainsMono(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warm, letterSpacing: 1,
                )),
              ],
            ),
          ),
          // 4 large preset buttons
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: quickPresets.asMap().entries.map((e) {
                  final preset = e.value;
                  final isActive = ref.watch(activePresetProvider)?.id == preset.id;
                  return GestureDetector(
                    onTap: () => _loadPreset(preset),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isActive ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.accent.withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0.08)],
                        ) : null,
                        color: isActive ? null : AppColors.bgPanel,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive ? AppColors.accent : AppColors.border,
                          width: isActive ? 2 : 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(2, 2)),
                          const BoxShadow(color: Color(0xFF2A2A2A), blurRadius: 4, offset: Offset(-1, -1)),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(preset.name, style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: isActive ? AppColors.accent : AppColors.textPrimary,
                            )),
                            const SizedBox(height: 4),
                            Text(preset.category, style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.textMuted,
                            )),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Effect toggles
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: chain.where((p) => [EffectType.drive, EffectType.chorus, EffectType.delay, EffectType.reverb].contains(p.type))
                .map((pedal) {
                  final idx = chain.indexOf(pedal);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          final newChain = List<PedalState>.from(chain);
                          newChain[idx] = pedal.copyWith(enabled: !pedal.enabled);
                          ref.read(pedalChainProvider.notifier).state = newChain;
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: pedal.enabled ? pedal.color.withValues(alpha: 0.2) : AppColors.bgPanel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: pedal.enabled ? pedal.color : AppColors.border, width: pedal.enabled ? 2 : 0.5),
                          ),
                          child: Center(
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(pedal.icon, size: 20, color: pedal.enabled ? pedal.color : AppColors.textMuted),
                              const SizedBox(height: 2),
                              Text(pedal.name, style: GoogleFonts.outfit(
                                fontSize: 9, color: pedal.enabled ? pedal.color : AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              )),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DIALOGS
  // ═══════════════════════════════════════════════════════════════════

  void _showPresetBrowser() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final presets = ref.watch(pedalPresetsProvider);
        final categories = ['All', ...{...presets.map((p) => p.category)}];
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filter = ref.watch(pedalCategoryFilterProvider);
            final filtered = filter == 'All' ? presets : presets.where((p) => p.category == filter).toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text('Presets', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    // Category chips
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final cat = categories.elementAt(i);
                          final isActive = filter == cat;
                          return GestureDetector(
                            onTap: () => ref.read(pedalCategoryFilterProvider.notifier).state = cat,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgInset,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isActive ? AppColors.accent : AppColors.border),
                              ),
                              child: Text(cat, style: GoogleFonts.outfit(
                                fontSize: 12, color: isActive ? AppColors.accent : AppColors.textSecondary,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              )),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final preset = filtered[i];
                          final catColor = _categoryColor(preset.category);
                          return GestureDetector(
                            onTap: () {
                              _loadPreset(preset);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.bgInset,
                                borderRadius: BorderRadius.circular(10),
                                border: Border(
                                  left: BorderSide(color: catColor, width: 3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(preset.name, style: GoogleFonts.outfit(
                                          fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500,
                                        )),
                                        const SizedBox(height: 3),
                                        Text(preset.category, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${preset.chain.length}',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: catColor),
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
                );
              },
            );
          },
        );
      },
    );
  }

  void _loadPreset(PedalPreset preset) {
    ref.read(activePresetProvider.notifier).state = preset;
    ref.read(pedalChainProvider.notifier).state = List.from(preset.chain);
    setState(() => _selectedPedalIndex = null);
  }

  void _showAddPedalSheet() {
    final types = EffectType.values;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Effect', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: types.map((type) {
                final pedal = createDefaultPedal(type);
                return GestureDetector(
                  onTap: () {
                    final chain = List<PedalState>.from(ref.read(pedalChainProvider));
                    chain.add(pedal);
                    ref.read(pedalChainProvider.notifier).state = chain;
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 80, height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.bgInset,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: pedal.color.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(pedal.icon, size: 22, color: pedal.color),
                        const SizedBox(height: 4),
                        Text(pedal.name, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'clean': return AppColors.accent;
      case 'rock': return AppColors.warm;
      case 'ambient': return const Color(0xFF8B5CF6);
      case 'blues': return const Color(0xFF4FC3F7);
      case 'metal': return AppColors.danger;
      case 'funk': return const Color(0xFFE040FB);
      default: return AppColors.accent;
    }
  }

  void _showPedalMenu(int index) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgPanel,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.danger),
              title: Text('Remove', style: GoogleFonts.outfit(color: AppColors.danger)),
              onTap: () {
                final chain = List<PedalState>.from(ref.read(pedalChainProvider));
                chain.removeAt(index);
                ref.read(pedalChainProvider.notifier).state = chain;
                if (_selectedPedalIndex == index) setState(() => _selectedPedalIndex = null);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CHAIN CONNECTOR PAINTER
// ═══════════════════════════════════════════════════════════════════

class _ChainConnectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final midY = size.height / 2;

    // Main bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, midY - 1.5, size.width - 5, 3),
        const Radius.circular(1.5),
      ),
      paint,
    );

    // Arrowhead
    final path = Path()
      ..moveTo(size.width - 7, midY - 5)
      ..lineTo(size.width, midY)
      ..lineTo(size.width - 7, midY + 5)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
//  KNOB PAINTER
// ═══════════════════════════════════════════════════════════════════

class _KnobPainter extends CustomPainter {
  final double value; // 0.0 - 1.0
  final Color color;

  _KnobPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.bgInset
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const startAngle = 2.356; // 135 degrees
    const sweepAngle = 4.712; // 270 degrees

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false, bgPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle * value, false, valuePaint,
    );

    // Center dot
    canvas.drawCircle(center, 3, Paint()..color = AppColors.textPrimary);

    // Indicator line
    final angle = startAngle + sweepAngle * value;
    final lineEnd = Offset(
      center.dx + (radius - 8) * math.cos(angle),
      center.dy + (radius - 8) * math.sin(angle),
    );
    canvas.drawLine(
      center,
      lineEnd,
      Paint()..color = AppColors.textPrimary..strokeWidth = 2..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.value != value || old.color != color;
}
