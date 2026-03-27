import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';
import '../../core/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../core/widgets/signal_flow_widget.dart';

import '../../providers/app_providers.dart';
import 'pedalera_models.dart';
import 'pedalera_providers.dart';

// ═══════════════════════════════════════════════════════════════════════
//  PEDALERA TAB  —  Premium Pedalboard UI
// ═══════════════════════════════════════════════════════════════════════

class PedaleraTab extends ConsumerStatefulWidget {
  const PedaleraTab({super.key});

  @override
  ConsumerState<PedaleraTab> createState() => _PedaleraTabState();
}

class _PedaleraTabState extends ConsumerState<PedaleraTab>
    with TickerProviderStateMixin {
  bool _inputActive = false;
  int? _selectedPedalIndex;
  bool _liveMode = false;

  // LED pulse animation
  late AnimationController _ledPulseController;
  late Animation<double> _ledPulseAnim;

  // Cable flow animation
  late AnimationController _cableFlowController;

  @override
  void initState() {
    super.initState();
    _ledPulseController = AnimationController(
      vsync: this,
      duration: AppAnimations.breathe,
    )..repeat(reverse: true);
    _ledPulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ledPulseController, curve: Curves.easeInOut),
    );

    _cableFlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ledPulseController.dispose();
    _cableFlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chain = ref.watch(pedalChainProvider);
    final activePreset = ref.watch(activePresetProvider);
    final presets = ref.watch(pedalPresetsProvider);

    if (_liveMode) return _buildLiveMode(chain);

    return Column(
      children: [
        _buildPresetBar(activePreset, presets),
        Expanded(
          flex: _selectedPedalIndex != null ? 1 : 2,
          child: _buildSignalChain(chain),
        ),
        if (_selectedPedalIndex != null && _selectedPedalIndex! < chain.length)
          Expanded(
            flex: 2,
            child: _buildPedalDetail(chain[_selectedPedalIndex!], _selectedPedalIndex!),
          ),
        _buildBottomControls(chain),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PRESET BAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPresetBar(PedalPreset? active, List<PedalPreset> presets) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), Color(0xFF0E0E0E)],
        ),
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Preset name with LED dot
          AnimatedBuilder(
            animation: _ledPulseAnim,
            builder: (_, __) => Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active != null
                    ? AppColors.accent.withValues(alpha: 0.6 + 0.4 * _ledPulseAnim.value)
                    : const Color(0xFF333333),
                boxShadow: active != null ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4 * _ledPulseAnim.value),
                    blurRadius: 8, spreadRadius: 1,
                  ),
                ] : null,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active?.name ?? 'No Preset',
                  style: AppFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (active != null)
                  Text(
                    active.category.toUpperCase(),
                    style: AppFonts.jetBrainsMono(
                      fontSize: 9, color: AppColors.textMuted, letterSpacing: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showPresetBrowser(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A2A2A), Color(0xFF1E1E1E)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3A3A3A), width: 0.8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 2)),
                  const BoxShadow(color: Color(0xFF2A2A2A), blurRadius: 2, offset: Offset(0, -1)),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.folder_open, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Presets', style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _liveMode = true),
            child: AnimatedBuilder(
              animation: _ledPulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.warm.withValues(alpha: 0.25),
                      AppColors.warm.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warm.withValues(alpha: 0.6), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warm.withValues(alpha: 0.15 + 0.1 * _ledPulseAnim.value),
                      blurRadius: 12, spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.warm,
                      boxShadow: [BoxShadow(color: AppColors.warm.withValues(alpha: 0.6), blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('LIVE', style: AppFonts.jetBrainsMono(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warm,
                    letterSpacing: 1,
                  )),
                ]),
              ),
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141414), Color(0xFF0D0D0D), Color(0xFF080808)],
          stops: [0.0, 0.6, 1.0],
        ),
        border: Border(
          top: BorderSide(color: AppColors.accent.withValues(alpha: 0.08), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Signal chain header with input/output indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Input indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _inputActive ? AppColors.accent2.withValues(alpha: 0.15) : AppColors.bgInset,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _inputActive ? AppColors.accent2.withValues(alpha: 0.4) : AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _inputActive ? AppColors.accent2 : const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('IN', style: AppFonts.jetBrainsMono(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: _inputActive ? AppColors.accent2 : AppColors.textMuted,
                      letterSpacing: 1,
                    )),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: Text('SIGNAL CHAIN', style: AppTheme.lcdStyle(
                      size: 10, color: AppColors.accent, glowAlpha: 0.5,
                    ).copyWith(letterSpacing: 2.5)),
                  ),
                ),
                const SizedBox(width: 8),
                // Output indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgInset,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('OUT', style: AppFonts.jetBrainsMono(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 1,
                    )),
                    const SizedBox(width: 4),
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: chain.any((p) => p.enabled) ? AppColors.accent : const Color(0xFF333333),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
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
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: chain.length * 2 + 1, // pedals + connectors + add btn
              itemBuilder: (context, index) {
                // Last item is the add button
                if (index == chain.length * 2) return _addPedalButton();
                // Even indices = pedals, odd = connectors
                if (index.isEven) {
                  final pedalIdx = index ~/ 2;
                  return _pedalCard(chain[pedalIdx], pedalIdx);
                } else {
                  final fromIdx = index ~/ 2;
                  final fromEnabled = chain[fromIdx].enabled;
                  final toEnabled = (fromIdx + 1 < chain.length) ? chain[fromIdx + 1].enabled : true;
                  return _animatedCableConnector(fromEnabled && toEnabled);
                }
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

  // ── Premium Pedal Card (Stompbox Style — BIAS FX quality) ──

  Widget _pedalCard(PedalState pedal, int index) {
    final isSelected = _selectedPedalIndex == index;
    final isBypassed = !pedal.enabled;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPedalIndex = isSelected ? null : index);
      },
      onLongPress: () => _showPedalMenu(index),
      child: AnimatedContainer(
        duration: AppAnimations.medium,
        curve: AppAnimations.snapCurve,
        width: 130,
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // Premium metallic gradient with color tint
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.08, 0.2, 0.5, 0.85, 1.0],
            colors: isBypassed
                ? [
                    const Color(0xFF1E1E1E),
                    const Color(0xFF1C1C1C),
                    const Color(0xFF1A1A1A),
                    const Color(0xFF181818),
                    const Color(0xFF151515),
                    const Color(0xFF111111),
                  ]
                : isSelected
                    ? [
                        Color.lerp(const Color(0xFF333333), pedal.color, 0.18)!,
                        Color.lerp(const Color(0xFF2E2E2E), pedal.color, 0.12)!,
                        Color.lerp(const Color(0xFF3A3A3A), pedal.color, 0.10)!,
                        Color.lerp(const Color(0xFF2E2E2E), pedal.color, 0.08)!,
                        Color.lerp(const Color(0xFF242424), pedal.color, 0.05)!,
                        Color.lerp(const Color(0xFF1A1A1A), pedal.color, 0.03)!,
                      ]
                    : [
                        const Color(0xFF2E2E2E),
                        const Color(0xFF2A2A2A),
                        const Color(0xFF383838),
                        const Color(0xFF2E2E2E),
                        const Color(0xFF242424),
                        const Color(0xFF1A1A1A),
                      ],
          ),
          borderRadius: BorderRadius.circular(16),
          // Metallic border effect
          border: Border.all(
            color: isSelected
                ? pedal.color.withValues(alpha: 0.9)
                : isBypassed
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFF444444),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            // Deep neumorphic shadows
            ...AppColors.neumorphicRaised(
              scale: isBypassed ? 0.6 : 1.2,
              glowColor: isSelected ? pedal.color : null,
            ),
            // Extra depth shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: isBypassed ? 0.2 : 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AnimatedOpacity(
          duration: AppAnimations.medium,
          opacity: isBypassed ? 0.40 : 1.0,
          child: Stack(
            children: [
              // Premium top-edge metallic highlight
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: isBypassed ? 0.04 : 0.18),
                        Colors.white.withValues(alpha: isBypassed ? 0.04 : 0.12),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // Subtle texture overlay
              if (!isBypassed)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.3),
                        radius: 1.2,
                        colors: [
                          Colors.white.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ── Top: LED + Name + Type ──
                    Column(
                      children: [
                        _ledIndicator(pedal.color, pedal.enabled),
                        const SizedBox(height: 6),
                        Text(
                          pedal.name.toUpperCase(),
                          style: AppFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: pedal.enabled ? AppColors.textPrimary : AppColors.textMuted,
                            letterSpacing: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: pedal.color.withValues(alpha: pedal.enabled ? 0.12 : 0.05),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: pedal.color.withValues(alpha: pedal.enabled ? 0.25 : 0.1),
                            ),
                          ),
                          child: Text(
                            pedal.type.name.toUpperCase(),
                            style: AppFonts.jetBrainsMono(
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                              color: pedal.color.withValues(alpha: pedal.enabled ? 0.7 : 0.3),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Middle: Effect Icon with metallic ring ──
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.2, -0.2),
                          colors: [
                            pedal.color.withValues(alpha: pedal.enabled ? 0.25 : 0.05),
                            pedal.color.withValues(alpha: pedal.enabled ? 0.08 : 0.02),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        border: Border.all(
                          color: pedal.color.withValues(alpha: pedal.enabled ? 0.2 : 0.05),
                          width: 1.0,
                        ),
                        boxShadow: pedal.enabled ? [
                          BoxShadow(
                            color: pedal.color.withValues(alpha: 0.15),
                            blurRadius: 12, spreadRadius: -2,
                          ),
                        ] : null,
                      ),
                      child: Icon(
                        pedal.icon,
                        size: 28,
                        color: pedal.enabled ? pedal.color : AppColors.textMuted,
                      ),
                    ),

                    // ── Bottom: Premium 3D Footswitch Button ──
                    GestureDetector(
                      onTap: () => _toggleBypass(index, ref.read(pedalChainProvider)),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Brushed metal gradient
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF4A4A4A),
                              Color(0xFF3A3A3A),
                              Color(0xFF2A2A2A),
                              Color(0xFF1E1E1E),
                            ],
                            stops: [0.0, 0.3, 0.6, 1.0],
                          ),
                          border: Border.all(color: const Color(0xFF555555), width: 1.8),
                          boxShadow: [
                            // Deep 3D shadow
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 8,
                              offset: const Offset(1, 4),
                            ),
                            // Ambient light from top
                            BoxShadow(
                              color: const Color(0xFF444444).withValues(alpha: 0.5),
                              blurRadius: 3,
                              offset: const Offset(-1, -1),
                            ),
                            // Inner white catch
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.06),
                              blurRadius: 2,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: pedal.enabled
                                  ? pedal.color.withValues(alpha: 0.8)
                                  : const Color(0xFF222222),
                              border: Border.all(
                                color: pedal.enabled
                                    ? pedal.color.withValues(alpha: 0.4)
                                    : const Color(0xFF333333),
                                width: 0.5,
                              ),
                              boxShadow: pedal.enabled
                                  ? [
                                      BoxShadow(color: pedal.color.withValues(alpha: 0.5), blurRadius: 6),
                                      BoxShadow(color: pedal.color.withValues(alpha: 0.2), blurRadius: 12),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Premium LED Indicator with Glow + Pulse ──

  Widget _ledIndicator(Color color, bool active) {
    return AnimatedBuilder(
      animation: _ledPulseAnim,
      builder: (context, child) {
        final glowIntensity = active ? _ledPulseAnim.value : 0.0;
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // LED lens gradient - simulates real LED dome
            gradient: active
                ? RadialGradient(
                    center: const Alignment(-0.2, -0.3),
                    radius: 0.8,
                    colors: [
                      Color.lerp(Colors.white, color, 0.3)!,
                      color,
                      color.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  )
                : const RadialGradient(
                    colors: [Color(0xFF3A3A3A), Color(0xFF2A2A2A)],
                  ),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.5) : const Color(0xFF444444),
              width: 1.0,
            ),
            boxShadow: active
                ? [
                    // Inner glow
                    BoxShadow(
                      color: color.withValues(alpha: 0.7 * glowIntensity),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                    // Mid glow
                    BoxShadow(
                      color: color.withValues(alpha: 0.4 * glowIntensity),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                    // Wide ambient glow
                    BoxShadow(
                      color: color.withValues(alpha: 0.15 * glowIntensity),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ]
                : [
                    // Subtle inset shadow when off
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
        );
      },
    );
  }

  // ── Premium Animated Cable Connector ──

  Widget _animatedCableConnector(bool active) {
    return Center(
      child: SizedBox(
        width: 48,
        height: 32,
        child: AnimatedBuilder(
          animation: _cableFlowController,
          builder: (context, child) {
            return CustomPaint(
              painter: _CatenaryCablePainter(
                progress: _cableFlowController.value,
                active: active,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _addPedalButton() {
    return GestureDetector(
      onTap: _showAddPedalSheet,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgInset,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.15),
            width: 1.0,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(2, 3)),
            const BoxShadow(color: Color(0xFF2A2A2A), blurRadius: 4, offset: Offset(-1, -1)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.1), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.add_rounded, size: 22, color: AppColors.accent),
            ),
            const SizedBox(height: 8),
            Text('ADD', style: AppFonts.jetBrainsMono(
              fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.accent.withValues(alpha: 0.6), letterSpacing: 1.5,
            )),
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
            style: AppFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Tap a preset or add effects manually',
            style: AppFonts.outfit(fontSize: 13, color: AppColors.textMuted)),
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
    // Group parameters into categories for visual organization
    final paramGroups = _groupParams(pedal.type, pedal.params);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF1E1E1E), pedal.color, 0.06)!,
            Color.lerp(AppColors.bgPanel, pedal.color, 0.02)!,
            AppColors.bgPanel,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
        border: Border(top: BorderSide(color: pedal.color.withValues(alpha: 0.8), width: 3.0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 12, offset: const Offset(0, -4)),
          const BoxShadow(color: Color(0xFF2A2A2A), blurRadius: 6, offset: Offset(0, -1)),
          BoxShadow(color: pedal.color.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -6)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _ledIndicator(pedal.color, pedal.enabled),
                const SizedBox(width: 10),
                Icon(pedal.icon, size: 20, color: pedal.color),
                const SizedBox(width: 8),
                Text(pedal.name, style: AppFonts.outfit(
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: pedal.enabled
                          ? LinearGradient(
                              colors: [
                                const Color(0xFF32D74B).withValues(alpha: 0.2),
                                const Color(0xFF32D74B).withValues(alpha: 0.08),
                              ],
                            )
                          : null,
                      color: pedal.enabled ? null : AppColors.bgInset,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: pedal.enabled ? const Color(0xFF32D74B) : AppColors.border,
                      ),
                      boxShadow: pedal.enabled
                          ? [
                              BoxShadow(
                                color: const Color(0xFF32D74B).withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      pedal.enabled ? 'ON' : 'OFF',
                      style: AppFonts.jetBrainsMono(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: pedal.enabled ? const Color(0xFF32D74B) : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Knobs in grouped layout
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: paramGroups.entries.map((group) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group label
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
                        child: Text(
                          group.key.toUpperCase(),
                          style: AppFonts.jetBrainsMono(
                            fontSize: 9,
                            color: pedal.color.withValues(alpha: 0.6),
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Knobs in a wrapping row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: group.value.map((paramKey) {
                          final val = pedal.params[paramKey] ?? 0;
                          return _buildPremiumKnob(
                            label: paramKey,
                            value: val,
                            min: _minForParam(pedal.type, paramKey),
                            max: _maxForParam(pedal.type, paramKey),
                            onChanged: (newVal) {
                              final chain = List<PedalState>.from(ref.read(pedalChainProvider));
                              final newParams = Map<String, double>.from(pedal.params);
                              newParams[paramKey] = newVal;
                              chain[index] = pedal.copyWith(params: newParams);
                              ref.read(pedalChainProvider.notifier).state = chain;
                            },
                            color: pedal.color,
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Group parameters by logical category for visual layout
  Map<String, List<String>> _groupParams(EffectType type, Map<String, double> params) {
    final keys = params.keys.toList();
    return switch (type) {
      EffectType.compressor => {
        'Dynamics': keys.where((k) => ['threshold', 'ratio'].contains(k)).toList(),
        'Envelope': keys.where((k) => ['attack', 'release'].contains(k)).toList(),
      },
      EffectType.drive => {
        'Drive': keys.where((k) => ['gain'].contains(k)).toList(),
        'Tone': keys.where((k) => ['tone', 'level'].contains(k)).toList(),
      },
      EffectType.eq => {
        'Equalizer': keys,
      },
      EffectType.amp => {
        'Gain': keys.where((k) => ['gain', 'volume'].contains(k)).toList(),
        'Tone': keys.where((k) => ['bass', 'mid', 'treble'].contains(k)).toList(),
      },
      EffectType.delay => {
        'Time': keys.where((k) => ['time', 'feedback'].contains(k)).toList(),
        'Mix': keys.where((k) => ['mix'].contains(k)).toList(),
      },
      EffectType.chorus => {
        'Modulation': keys.where((k) => ['rate', 'depth'].contains(k)).toList(),
        'Mix': keys.where((k) => ['mix'].contains(k)).toList(),
      },
      EffectType.reverb => {
        'Space': keys.where((k) => ['decay'].contains(k)).toList(),
        'Mix': keys.where((k) => ['mix'].contains(k)).toList(),
      },
      _ => {'Parameters': keys},
    };
  }

  // ── Premium 3D Knob (BOSS / Line 6 quality) ──

  Widget _buildPremiumKnob({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required Color color,
  }) {
    final normalized = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return StatefulBuilder(
      builder: (context, setKnobState) {
        return SizedBox(
          width: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Knob with GestureDetector for rotation feel
              GestureDetector(
                onPanUpdate: (details) {
                  final delta = -details.delta.dy / 100.0;
                  final newNorm = (normalized + delta).clamp(0.0, 1.0);
                  final newVal = min + newNorm * (max - min);
                  onChanged(newVal);
                },
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: CustomPaint(
                    painter: _PremiumKnobPainter(
                      value: normalized,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Value display in LCD-style inset
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgInset,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF1A1A1A)),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF121212), blurRadius: 2, offset: Offset(1, 1), spreadRadius: -1),
                  ],
                ),
                child: Text(
                  value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
                  style: AppFonts.jetBrainsMono(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Unit
              Text(
                _unitForParam(label),
                style: AppFonts.outfit(
                  fontSize: 8,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              // Label
              Text(
                label.toUpperCase(),
                style: AppFonts.outfit(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
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
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141414), Color(0xFF0A0A0A)],
        ),
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          // Input toggle — premium neumorphic
          GestureDetector(
            onTap: () => setState(() => _inputActive = !_inputActive),
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              width: 52, height: 44,
              decoration: BoxDecoration(
                gradient: _inputActive
                    ? LinearGradient(colors: [
                        AppColors.danger.withValues(alpha: 0.25),
                        AppColors.danger.withValues(alpha: 0.12),
                      ])
                    : const LinearGradient(colors: [Color(0xFF242424), Color(0xFF1C1C1C)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _inputActive ? AppColors.danger.withValues(alpha: 0.7) : const Color(0xFF3A3A3A),
                  width: _inputActive ? 1.5 : 1.0,
                ),
                boxShadow: [
                  if (_inputActive)
                    BoxShadow(color: AppColors.danger.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: -2)
                  else
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(
                _inputActive ? Icons.mic : Icons.mic_off,
                size: 22,
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
              Text('LATENCY', style: AppFonts.outfit(fontSize: 8, color: AppColors.textMuted, letterSpacing: 1)),
              Text(
                '${ref.watch(pedalLatencyMsProvider).toStringAsFixed(1)} ms',
                style: AppFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          // Quick toggles — premium neumorphic stomp style
          ...chain.where((p) => [EffectType.drive, EffectType.chorus, EffectType.delay, EffectType.reverb].contains(p.type))
            .map((pedal) {
              final idx = chain.indexOf(pedal);
              return Padding(
                padding: const EdgeInsets.only(left: 10),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final newChain = List<PedalState>.from(chain);
                    newChain[idx] = pedal.copyWith(enabled: !pedal.enabled);
                    ref.read(pedalChainProvider.notifier).state = newChain;
                  },
                  child: AnimatedContainer(
                    duration: AppAnimations.fast,
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      gradient: pedal.enabled
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                pedal.color.withValues(alpha: 0.25),
                                pedal.color.withValues(alpha: 0.10),
                              ],
                            )
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF242424), Color(0xFF1A1A1A)],
                            ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pedal.enabled ? pedal.color.withValues(alpha: 0.7) : const Color(0xFF3A3A3A),
                        width: pedal.enabled ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        if (pedal.enabled) ...[
                          BoxShadow(color: pedal.color.withValues(alpha: 0.25), blurRadius: 10, spreadRadius: -1),
                        ] else
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(pedal.icon, size: 20, color: pedal.enabled ? pedal.color : AppColors.textMuted),
                        const SizedBox(height: 2),
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pedal.enabled ? pedal.color : const Color(0xFF333333),
                            boxShadow: pedal.enabled ? [
                              BoxShadow(color: pedal.color.withValues(alpha: 0.5), blurRadius: 4),
                            ] : null,
                          ),
                        ),
                      ],
                    ),
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
    return Container(
      // Very dark background for stage visibility
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF080808), Color(0xFF030303)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header bar - more prominent
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0E0E0E), Color(0xFF060606)],
                ),
                border: Border(
                  bottom: BorderSide(color: AppColors.warm.withValues(alpha: 0.15), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _liveMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF222222), Color(0xFF1A1A1A)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3A3A3A)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.arrow_back, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('EXIT', style: AppFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _ledPulseAnim,
                    builder: (context, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.warm.withValues(alpha: 0.6 + 0.4 * _ledPulseAnim.value),
                              boxShadow: [
                                BoxShadow(color: AppColors.warm.withValues(alpha: 0.5 * _ledPulseAnim.value), blurRadius: 10, spreadRadius: 2),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('LIVE MODE', style: AppTheme.lcdStyle(
                            size: 18, color: AppColors.warm, glowAlpha: 0.3 + 0.3 * _ledPulseAnim.value,
                          ).copyWith(letterSpacing: 3)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            // Full-screen stomp buttons for each pedal — 96px min
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: chain.length,
                      itemBuilder: (context, index) {
                        final pedal = chain[index];
                        return _liveStompButton(pedal, index, chain);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Large stomp button for Live Mode - 96x96 min, foot-tap friendly, BOSS quality
  Widget _liveStompButton(PedalState pedal, int index, List<PedalState> chain) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        _toggleBypass(index, chain);
      },
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.snapCurve,
        constraints: const BoxConstraints(minWidth: 96, minHeight: 96),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.1, 0.25, 0.5, 0.85, 1.0],
            colors: pedal.enabled
                ? [
                    Color.lerp(const Color(0xFF333333), pedal.color, 0.20)!,
                    Color.lerp(const Color(0xFF2E2E2E), pedal.color, 0.14)!,
                    Color.lerp(const Color(0xFF3A3A3A), pedal.color, 0.12)!,
                    Color.lerp(const Color(0xFF2E2E2E), pedal.color, 0.08)!,
                    Color.lerp(const Color(0xFF222222), pedal.color, 0.05)!,
                    Color.lerp(const Color(0xFF181818), pedal.color, 0.03)!,
                  ]
                : [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF1C1C1C),
                    const Color(0xFF1E1E1E),
                    const Color(0xFF1B1B1B),
                    const Color(0xFF161616),
                    const Color(0xFF111111),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: pedal.enabled ? pedal.color.withValues(alpha: 0.75) : const Color(0xFF2E2E2E),
            width: pedal.enabled ? 2.5 : 1.2,
          ),
          boxShadow: [
            // Deep neumorphic shadows
            ...AppColors.neumorphicRaised(
              scale: 1.5,
              glowColor: pedal.enabled ? pedal.color : null,
            ),
            // Extra stage shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top metallic edge
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: pedal.enabled ? 0.15 : 0.05),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // BYPASS overlay stripe
            if (!pedal.enabled)
              Positioned(
                bottom: 8, left: 16, right: 16,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.15), blurRadius: 6)],
                  ),
                ),
              ),
            Center(
              child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LED indicator - large and bright
            AnimatedBuilder(
              animation: _ledPulseAnim,
              builder: (context, child) {
                final glow = pedal.enabled ? _ledPulseAnim.value : 0.0;
                return Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: pedal.enabled
                        ? RadialGradient(
                            center: const Alignment(-0.2, -0.2),
                            colors: [
                              Color.lerp(Colors.white, pedal.color, 0.3)!,
                              pedal.color,
                              pedal.color.withValues(alpha: 0.7),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          )
                        : const RadialGradient(colors: [Color(0xFF2E2E2E), Color(0xFF1E1E1E)]),
                    border: Border.all(
                      color: pedal.enabled ? pedal.color.withValues(alpha: 0.5) : const Color(0xFF3A3A3A),
                      width: 1.2,
                    ),
                    boxShadow: pedal.enabled
                        ? [
                            BoxShadow(color: pedal.color.withValues(alpha: 0.7 * glow), blurRadius: 14, spreadRadius: 2),
                            BoxShadow(color: pedal.color.withValues(alpha: 0.35 * glow), blurRadius: 28, spreadRadius: 4),
                            BoxShadow(color: pedal.color.withValues(alpha: 0.15 * glow), blurRadius: 40, spreadRadius: 6),
                          ]
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2, offset: const Offset(0, 1))],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Pedal name
            Text(
              pedal.name.toUpperCase(),
              style: AppFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: pedal.enabled ? AppColors.textPrimary : AppColors.textMuted,
                letterSpacing: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // ON/OFF badge — clearer bypass indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: pedal.enabled
                    ? pedal.color.withValues(alpha: 0.2)
                    : AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: pedal.enabled
                      ? pedal.color.withValues(alpha: 0.4)
                      : AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
              pedal.enabled ? 'ON' : 'BYPASS',
              style: AppFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pedal.enabled ? pedal.color : AppColors.danger.withValues(alpha: 0.6),
                letterSpacing: 1.5,
              ),
            ),
            ),
          ],
        ),
            ),
          ],
        ),
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
                    Text('Presets', style: AppFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
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
                              child: Text(cat, style: AppFonts.outfit(
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
                                        Text(preset.name, style: AppFonts.outfit(
                                          fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500,
                                        )),
                                        const SizedBox(height: 3),
                                        Text(preset.category, style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
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
                                      style: AppFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: catColor),
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
            Text('Add Effect', style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                        Text(pedal.name, style: AppFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
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
              title: Text('Remove', style: AppFonts.outfit(color: AppColors.danger)),
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

// ═══════════════════════════════════════════════════════════════════════
//  ANIMATED CABLE PAINTER  —  Flowing signal dots between pedals
// ═══════════════════════════════════════════════════════════════════════

class _CatenaryCablePainter extends CustomPainter {
  final double progress; // 0.0 - 1.0 (animation cycle)
  final bool active;

  _CatenaryCablePainter({required this.progress, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height * 0.30;
    final droopY = size.height * 0.80;
    const jackRadius = 4.5;
    const jackPadding = 5.0;

    final startX = jackPadding;
    final endX = size.width - jackPadding;

    // ── 1. Jack plug endpoints — metallic ring style ──
    // Left jack — outer ring
    final jackGrad = const RadialGradient(
      center: Alignment(-0.3, -0.3),
      colors: [Color(0xFF999999), Color(0xFF666666), Color(0xFF444444)],
      stops: [0.0, 0.5, 1.0],
    );
    final activeJackGrad = const RadialGradient(
      center: Alignment(-0.3, -0.3),
      colors: [Color(0xFFBBBBBB), Color(0xFF888888), Color(0xFF555555)],
      stops: [0.0, 0.5, 1.0],
    );

    final leftJackRect = Rect.fromCircle(center: Offset(startX, midY), radius: jackRadius);
    final rightJackRect = Rect.fromCircle(center: Offset(endX, midY), radius: jackRadius);

    canvas.drawCircle(Offset(startX, midY), jackRadius,
      Paint()..shader = (active ? activeJackGrad : jackGrad).createShader(leftJackRect));
    canvas.drawCircle(Offset(startX, midY), jackRadius,
      Paint()..color = const Color(0xFF555555)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    canvas.drawCircle(Offset(startX, midY), 2.0,
      Paint()..color = active ? const Color(0xFFDDDDDD) : const Color(0xFF888888));

    canvas.drawCircle(Offset(endX, midY), jackRadius,
      Paint()..shader = (active ? activeJackGrad : jackGrad).createShader(rightJackRect));
    canvas.drawCircle(Offset(endX, midY), jackRadius,
      Paint()..color = const Color(0xFF555555)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    canvas.drawCircle(Offset(endX, midY), 2.0,
      Paint()..color = active ? const Color(0xFFDDDDDD) : const Color(0xFF888888));

    // ── 2. Bezier cable with catenary droop — thicker with glow ──
    final cablePath = Path()
      ..moveTo(startX, midY)
      ..cubicTo(
        startX + (endX - startX) * 0.25, droopY,
        startX + (endX - startX) * 0.75, droopY,
        endX, midY,
      );

    // Cable shadow (deeper)
    canvas.drawPath(
      cablePath.shift(const Offset(0.8, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: active ? 0.4 : 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );

    // Cable glow (when active)
    if (active) {
      canvas.drawPath(
        cablePath,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Main cable
    canvas.drawPath(cablePath, Paint()
      ..color = active
          ? AppColors.accent.withValues(alpha: 0.45)
          : AppColors.textMuted.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round,
    );

    // Cable highlight (thin white line on top for 3D effect)
    canvas.drawPath(
      cablePath.shift(const Offset(-0.3, -0.5)),
      Paint()
        ..color = Colors.white.withValues(alpha: active ? 0.08 : 0.03)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );

    if (!active) return;

    // ── 3. Flowing signal dots along bezier path ──
    const dotCount = 5;
    for (int i = 0; i < dotCount; i++) {
      final t = (progress + i / dotCount) % 1.0;
      final pt = _evalCubic(
        Offset(startX, midY),
        Offset(startX + (endX - startX) * 0.25, droopY),
        Offset(startX + (endX - startX) * 0.75, droopY),
        Offset(endX, midY),
        t,
      );
      final alpha = (1.0 - (t - 0.5).abs() * 2.0).clamp(0.3, 1.0);
      // Dot glow
      canvas.drawCircle(pt, 3.5,
        Paint()..color = AppColors.accent.withValues(alpha: alpha * 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      // Dot core
      canvas.drawCircle(pt, 2.0,
        Paint()..color = AppColors.accent.withValues(alpha: alpha * 0.95));
    }
  }

  /// Evaluate a cubic bezier at parameter t
  Offset _evalCubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1.0 - t;
    final mt2 = mt * mt;
    final t2 = t * t;
    return Offset(
      mt2 * mt * p0.dx + 3 * mt2 * t * p1.dx + 3 * mt * t2 * p2.dx + t2 * t * p3.dx,
      mt2 * mt * p0.dy + 3 * mt2 * t * p1.dy + 3 * mt * t2 * p2.dy + t2 * t * p3.dy,
    );
  }

  @override
  bool shouldRepaint(_CatenaryCablePainter old) =>
      old.progress != progress || old.active != active;
}

// ═══════════════════════════════════════════════════════════════════════
//  PREMIUM 3D KNOB PAINTER  —  Brushed metal with tick marks
// ═══════════════════════════════════════════════════════════════════════

class _PremiumKnobPainter extends CustomPainter {
  final double value; // 0.0 - 1.0
  final Color color;

  _PremiumKnobPainter({required this.value, required this.color});

  static const double _startAngle = 2.356; // 135 degrees in radians
  static const double _sweepAngle = 4.712; // 270 degrees in radians
  static const int _tickCount = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 2;
    final knobRadius = outerRadius - 8;

    // ── 1. Tick marks around perimeter ──
    _drawTicks(canvas, center, outerRadius, knobRadius);

    // ── 2. Value arc (background track) ──
    final trackPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius - 4),
      _startAngle,
      _sweepAngle,
      false,
      trackPaint,
    );

    // ── 3. Value arc (filled portion) ──
    if (value > 0.005) {
      final valuePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius - 4),
        _startAngle,
        _sweepAngle * value,
        false,
        valuePaint,
      );

      // Glow behind value arc
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius - 4),
        _startAngle,
        _sweepAngle * value,
        false,
        glowPaint,
      );
    }

    // ── 4. Knob body — radial gradient for brushed metal look ──
    final knobGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3), // Light source top-left
      radius: 1.0,
      colors: [
        const Color(0xFF484848), // highlight
        const Color(0xFF363636), // mid
        const Color(0xFF2A2A2A), // base
        const Color(0xFF222222), // shadow edge
      ],
      stops: const [0.0, 0.35, 0.7, 1.0],
    );

    final knobPaint = Paint()
      ..shader = knobGradient.createShader(
        Rect.fromCircle(center: center, radius: knobRadius),
      );

    canvas.drawCircle(center, knobRadius, knobPaint);

    // Knob edge ring (subtle bevel)
    final edgePaint = Paint()
      ..color = const Color(0xFF555555).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, knobRadius, edgePaint);

    // Inner shadow for depth
    final innerShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center, knobRadius - 1, innerShadow);

    // ── 5. Indicator line (thick, from center outward) ──
    final angle = _startAngle + _sweepAngle * value;
    final lineStart = Offset(
      center.dx + 4 * math.cos(angle),
      center.dy + 4 * math.sin(angle),
    );
    final lineEnd = Offset(
      center.dx + (knobRadius - 3) * math.cos(angle),
      center.dy + (knobRadius - 3) * math.sin(angle),
    );

    // Indicator shadow
    canvas.drawLine(
      lineStart,
      lineEnd,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Indicator line
    canvas.drawLine(
      lineStart,
      lineEnd,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Bright dot at indicator tip
    canvas.drawCircle(
      lineEnd,
      2.0,
      Paint()..color = color.withValues(alpha: 0.9),
    );

    // ── 6. Center cap (small reflective dot) ──
    final capGrad = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: [
        const Color(0xFF555555),
        const Color(0xFF333333),
      ],
    );
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..shader = capGrad.createShader(Rect.fromCircle(center: center, radius: 4)),
    );
  }

  void _drawTicks(Canvas canvas, Offset center, double outerR, double knobR) {
    final tickOuterR = outerR - 1;
    final tickInnerR = knobR + 4;

    for (int i = 0; i <= _tickCount; i++) {
      final t = i / _tickCount;
      final angle = _startAngle + _sweepAngle * t;

      final isActive = t <= value;
      final isMajor = i % 3 == 0; // every 3rd tick is major

      final paint = Paint()
        ..color = isActive
            ? color.withValues(alpha: isMajor ? 0.7 : 0.4)
            : const Color(0xFF444444).withValues(alpha: isMajor ? 0.6 : 0.3)
        ..strokeWidth = isMajor ? 1.5 : 0.8
        ..strokeCap = StrokeCap.round;

      final inner = isMajor ? tickInnerR : tickInnerR + 2;

      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle), center.dy + inner * math.sin(angle)),
        Offset(center.dx + tickOuterR * math.cos(angle), center.dy + tickOuterR * math.sin(angle)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PremiumKnobPainter old) =>
      old.value != value || old.color != color;
}
