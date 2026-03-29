import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';
import '../../core/theme.dart';
import '../../core/audio/audio_service.dart';
import 'pedalera_models.dart';
import 'pedalera_providers.dart';

// ═══════════════════════════════════════════════════════════════════════
//  PEDALERA TAB  —  Professional Live Rig (HTML design replica)
// ═══════════════════════════════════════════════════════════════════════

// ── Rich color palette per pedal type (from HTML design) ──
class _PedalColors {
  // Body gradients: 160deg linear-gradient per pedal type
  static const Map<EffectType, List<Color>> bodyGradients = {
    EffectType.noiseGate: [Color(0xFF222222), Color(0xFF111111), Color(0xFF050505)],
    EffectType.compressor: [Color(0xFFCC5500), Color(0xFFAA3300), Color(0xFF882200)],
    EffectType.drive: [Color(0xFF2A6622), Color(0xFF1A4416), Color(0xFF0F2E0D)],
    EffectType.eq: [Color(0xFF1A1A1A), Color(0xFF111111), Color(0xFF0A0A0A)],
    EffectType.amp: [Color(0xFF2A2A2A), Color(0xFF222222), Color(0xFF1A1A1A)],
    EffectType.cabinet: [Color(0xFF2C2218), Color(0xFF241C14), Color(0xFF1A1410)],
    EffectType.chorus: [Color(0xFF006655), Color(0xFF004433), Color(0xFF002A22)],
    EffectType.delay: [Color(0xFF1A1A2E), Color(0xFF111122), Color(0xFF080810)],
    EffectType.reverb: [Color(0xFF0A1A2A), Color(0xFF061015), Color(0xFF030810)],
    EffectType.volume: [Color(0xFF2A1A3A), Color(0xFF1A1028), Color(0xFF110A1E)],
  };

  // Faceplate accent per type (LED / text highlight color)
  static const Map<EffectType, Color> faceplate = {
    EffectType.noiseGate: Color(0xFFAAAAAA),
    EffectType.compressor: Color(0xFFFF6600),
    EffectType.drive: Color(0xFF88DD66),
    EffectType.eq: Color(0xFFCCCCCC),
    EffectType.amp: Color(0xFF888888),
    EffectType.cabinet: Color(0xFF8B7355),
    EffectType.chorus: Color(0xFF00FFCC),
    EffectType.delay: Color(0xFF4466FF),
    EffectType.reverb: Color(0xFF2255FF),
    EffectType.volume: Color(0xFFBB88FF),
  };

  // Knob style per type
  static const Map<EffectType, Color> knobColor = {
    EffectType.noiseGate: Color(0xFF333333),
    EffectType.compressor: Color(0xFFCCCCCC),
    EffectType.drive: Color(0xFFCCCCCC),
    EffectType.eq: Color(0xFFAAAAAA),
    EffectType.amp: Color(0xFF333333),
    EffectType.cabinet: Color(0xFF555555),
    EffectType.chorus: Color(0xFF44CC44),
    EffectType.delay: Color(0xFFCCCCCC),
    EffectType.reverb: Color(0xFF4499FF),
    EffectType.volume: Color(0xFF9966DD),
  };

  // Name text color per type
  static const Map<EffectType, Color> nameColor = {
    EffectType.noiseGate: Color(0xFFAAAAAA),
    EffectType.compressor: Color(0xFFFFCC88),
    EffectType.drive: Color(0xFF88DD66),
    EffectType.eq: Color(0xFFCCCCCC),
    EffectType.amp: Color(0xFFFFAA22),
    EffectType.cabinet: Color(0xFF8B7355),
    EffectType.chorus: Color(0xFF55FFCC),
    EffectType.delay: Color(0xFF8888FF),
    EffectType.reverb: Color(0xFF66AADD),
    EffectType.volume: Color(0xFFCC99FF),
  };
}

// ── Factory preset chips (matching HTML) ──
const _factoryPresetChipNames = [
  'CLEAN JAZZ', 'BLUES CRUNCH', 'CLASSIC ROCK', 'MODERN METAL',
  'AMBIENT CLEAN', 'FUNK RHYTHM', 'LEAD SOLO',
];

// ── Section tabs (matching HTML nav-tabs) ──
const _sectionTabs = [
  '🎸 Pedalboard', '🔊 Amplifiers', '📦 Cabinets',
  '🎤 Microphones', '⚙ Rack & FX', '🎫 Master Output',
];

// ═══════════════════════════════════════════════════════════════════════

class PedaleraTab extends ConsumerStatefulWidget {
  const PedaleraTab({super.key});

  @override
  ConsumerState<PedaleraTab> createState() => _PedaleraTabState();
}

class _PedaleraTabState extends ConsumerState<PedaleraTab>
    with TickerProviderStateMixin {
  // ignore: prefer_final_fields
  bool _inputActive = false;
  int? _selectedPedalIndex;
  bool _liveMode = false;
  int _activeSection = 0;
  int _activePresetChip = 2; // CLASSIC ROCK default
  bool _compactView = false;
  bool _globalBypass = false;
  bool _isLocked = false;
  bool _dragMode = false;

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
        // 1. App header bar
        _buildAppHeader(),
        // 2. Factory presets mini strip (FIX 1: presets BEFORE scenes)
        _buildFactoryPresetsStrip(activePreset, presets),
        // 3. Scenes bar
        _buildScenesBar(),
        // 4. Section tabs (FIX 2: expandable)
        _buildSectionTabs(),
        // 5. Section content area (FIX 2: show content based on active section)
        if (_activeSection == 1)
          _buildAmpSelector()
        else if (_activeSection == 2)
          _buildCabinetSelector()
        else if (_activeSection == 3)
          _buildMicSelector()
        else if (_activeSection == 4)
          _buildPlaceholderSection('Rack & FX', 'Coming soon...')
        else if (_activeSection == 5)
          _buildPlaceholderSection('Master Output', 'Coming soon...')
        else ...[
          // 6. Chain toolbar (only for pedalboard section)
          _buildChainToolbar(),
          // 7. Main pedalboard area
          Expanded(
            flex: _selectedPedalIndex != null ? 1 : 2,
            child: _buildPedalBoard(chain),
          ),
          // 8. Detail panel (when pedal selected)
          if (_selectedPedalIndex != null && _selectedPedalIndex! < chain.length)
            Expanded(
              flex: 2,
              child: _buildPedalDetail(chain[_selectedPedalIndex!], _selectedPedalIndex!),
            ),
        ],
        // 9. Bottom status bar (FIX 13: no scene info)
        _buildBottomStatusBar(chain),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  1. APP HEADER  —  GROOVELAB Professional Live Rig
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAppHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141418), Color(0xFF0D0D0F)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A30), width: 1)),
      ),
      child: Row(
        children: [
          // Logo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('GROOVELAB', style: AppFonts.jetBrainsMono(
                fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFFF8C00),
                letterSpacing: 3,
              )),
              Text('PROFESSIONAL LIVE RIG', style: AppFonts.jetBrainsMono(
                fontSize: 8, color: const Color(0xFF555555), letterSpacing: 6,
              )),
            ],
          ),
          const SizedBox(width: 16),
          // Signal chain indicator (FIX 14: tappable for linear view)
          Expanded(
            child: GestureDetector(
              onTap: () => _showSignalChainOverlay(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: const Color(0xFF00FF11),
                    boxShadow: [BoxShadow(color: const Color(0xFF00FF11).withValues(alpha: 0.5), blurRadius: 6)],
                  )),
                  const SizedBox(width: 8),
                  Flexible(child: Text(
                    'GUITAR → PEDALBOARD → AMP → CAB → MIC → FOH',
                    style: AppFonts.jetBrainsMono(fontSize: 8, color: const Color(0xFF444444), letterSpacing: 2),
                    overflow: TextOverflow.ellipsis,
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Header controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // EDIT / LIVE toggle
              _buildModeToggle(),
              const SizedBox(width: 6),
              // FIX 12: BYPASS connected to _globalBypass with visual feedback
              _headerBtn('BYPASS', _globalBypass, onTap: () {
                setState(() => _globalBypass = !_globalBypass);
                _applyGlobalBypass();
              }),
              const SizedBox(width: 4),
              // FIX 9: TAP button connected to tap tempo
              _headerBtn('TAP', false, onTap: () => _handleTapTempo()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _liveMode = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !_liveMode ? const Color(0xFF333333) : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('✏ EDIT', style: AppFonts.jetBrainsMono(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: !_liveMode ? Colors.white : const Color(0xFF555555),
                letterSpacing: 1,
              )),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _liveMode = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _liveMode ? const Color(0xFF00AA44) : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('▶ LIVE', style: AppFonts.jetBrainsMono(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: _liveMode ? Colors.white : const Color(0xFF555555),
                letterSpacing: 1,
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerBtn(String label, bool active, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFF8C00) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? const Color(0xFFFF8C00) : const Color(0xFF333333), width: 1),
        ),
        child: Text(label, style: AppFonts.jetBrainsMono(
          fontSize: 9, fontWeight: FontWeight.w600,
          color: active ? Colors.black : const Color(0xFF666666),
          letterSpacing: 1,
        )),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  2. SECTION TABS  —  Pedalboard | Amplifiers | Cabinets | ...
  //  FIX 2: Pressing a tab shows expandable content below it
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSectionTabs() {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0F),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1E), width: 2)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _sectionTabs.length,
        itemBuilder: (context, i) {
          final isActive = i == _activeSection;
          return GestureDetector(
            onTap: () => setState(() {
              // Toggle: tap same tab to collapse back to pedalboard
              if (_activeSection == i && i != 0) {
                _activeSection = 0;
              } else {
                _activeSection = i;
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? const Color(0xFFFF8C00) : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_sectionTabs[i], style: AppFonts.jetBrainsMono(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFFFF8C00) : const Color(0xFF555555),
                    letterSpacing: 1,
                  )),
                  if (isActive && i != 0) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, size: 14, color: const Color(0xFFFF8C00)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  3. SCENES BAR  —  FIX 6: Use scenes from active preset
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildScenesBar() {
    final activePreset = ref.watch(activePresetProvider);
    final activeSceneIdx = ref.watch(activeSceneIndexProvider);

    // FIX 6: Use scenes from active preset if available
    final List<PresetScene> scenes;
    if (activePreset != null && activePreset.scenes.isNotEmpty) {
      scenes = activePreset.scenes;
    } else {
      scenes = _defaultPresetScenes;
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E0E12), Color(0xFF0A0A0D)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1E), width: 1)),
      ),
      child: Row(
        children: [
          Text('SCENES ▸', style: AppFonts.jetBrainsMono(
            fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF555555), letterSpacing: 2,
          )),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: scenes.length,
              itemBuilder: (context, i) {
                final scene = scenes[i];
                final isActive = i == activeSceneIdx;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(activeSceneIndexProvider.notifier).state = i;
                    // FIX 6 & 10: Apply scene pedal states & overrides
                    _applyScene(scene);
                  },
                  child: AnimatedContainer(
                    duration: AppAnimations.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? scene.color.withValues(alpha: 0.15)
                          : const Color(0xFF111115),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive ? scene.color.withValues(alpha: 0.6) : const Color(0xFF222228),
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(color: scene.color.withValues(alpha: 0.15), blurRadius: 8),
                      ] : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(scene.icon, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(scene.name.toUpperCase(), style: AppFonts.jetBrainsMono(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: isActive ? scene.color : const Color(0xFF555555),
                          letterSpacing: 1,
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          // Scene actions
          _sceneActionBtn('💾 SAVE', const Color(0xFF4CAF50)),
          const SizedBox(width: 4),
          _sceneActionBtn('✏️ EDIT', const Color(0xFF888888)),
          const SizedBox(width: 4),
          _sceneActionBtn('✕ CLEAR', const Color(0xFFFF5252)),
        ],
      ),
    );
  }

  // Default scenes when no preset is loaded
  static final _defaultPresetScenes = [
    const PresetScene(name: 'Intro', icon: '🎬', color: Color(0xFF4CAF50)),
    const PresetScene(name: 'Verso', icon: '🎵', color: Color(0xFF2196F3)),
    const PresetScene(name: 'Coro', icon: '🔥', color: Color(0xFFFF9800)),
    const PresetScene(name: 'Solo', icon: '⚡', color: Color(0xFFE91E63)),
    const PresetScene(name: 'Ambient', icon: '🌊', color: Color(0xFF9C27B0)),
    const PresetScene(name: 'Outro', icon: '🎥', color: Color(0xFF607D8B)),
  ];

  /// FIX 6 & 10: Apply a scene's pedal states and parameter overrides to the chain
  void _applyScene(PresetScene scene) {
    final chain = List<PedalState>.from(ref.read(pedalChainProvider));
    if (chain.isEmpty) return;

    for (final entry in scene.pedalStates.entries) {
      if (entry.key >= 0 && entry.key < chain.length) {
        chain[entry.key] = chain[entry.key].copyWith(enabled: entry.value);
      }
    }

    for (final entry in scene.pedalParamOverrides.entries) {
      if (entry.key >= 0 && entry.key < chain.length) {
        final currentParams = Map<String, double>.from(chain[entry.key].params);
        currentParams.addAll(entry.value);
        chain[entry.key] = chain[entry.key].copyWith(params: currentParams);
      }
    }

    ref.read(pedalChainProvider.notifier).state = chain;
  }

  Widget _sceneActionBtn(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(label, style: AppFonts.jetBrainsMono(
        fontSize: 8, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7), letterSpacing: 0.5,
      )),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  4. FACTORY PRESETS STRIP
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildFactoryPresetsStrip(PedalPreset? active, List<PedalPreset> presets) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0F),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1E), width: 1)),
      ),
      child: Row(
        children: [
          Text('FACTORY PRESETS', style: AppFonts.jetBrainsMono(
            fontSize: 9, color: const Color(0xFF444444), letterSpacing: 2,
          )),
          const SizedBox(width: 8),
          Container(width: 1, height: 16, color: const Color(0xFF222222)),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _factoryPresetChipNames.length,
              itemBuilder: (context, i) {
                final isActive = i == _activePresetChip;
                return GestureDetector(
                  onTap: () {
                    setState(() => _activePresetChip = i);
                    // Load matching preset if available
                    final matchName = _factoryPresetChipNames[i].toLowerCase().replaceAll(' ', '_');
                    final match = presets.where((p) =>
                      p.name.toLowerCase().replaceAll(' ', '_').contains(matchName) ||
                      matchName.contains(p.name.toLowerCase().replaceAll(' ', '_'))
                    ).toList();
                    if (match.isNotEmpty) _loadPreset(match.first);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1A1008) : const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isActive ? const Color(0xFFFF8C00) : const Color(0xFF222222),
                        width: 1,
                      ),
                    ),
                    child: Text(_factoryPresetChipNames[i], style: AppFonts.jetBrainsMono(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: isActive ? const Color(0xFFFF8C00) : const Color(0xFF555555),
                      letterSpacing: 1,
                    )),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  5. CHAIN TOOLBAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildChainToolbar() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF111115), Color(0xFF0D0D0F)]),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1E), width: 1)),
      ),
      child: Row(
        children: [
          Text('CHAIN ▸', style: AppFonts.jetBrainsMono(
            fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF555555), letterSpacing: 2,
          )),
          const SizedBox(width: 8),
          // FIX 12: DRAG button shows snackbar
          _chainToolBtn('↕ DRAG', _dragMode, onTap: () {
            setState(() => _dragMode = !_dragMode);
            if (_dragMode) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Drag mode: long-press and drag to reorder pedals',
                    style: AppFonts.outfit(fontSize: 13, color: Colors.white)),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF333333),
                ),
              );
            }
          }),
          // FIX 12: UNLOCK button toggles lock state
          _chainToolBtn(_isLocked ? '🔒 LOCKED' : '🔓 UNLOCK', _isLocked, onTap: () {
            setState(() => _isLocked = !_isLocked);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isLocked ? 'Pedalboard locked: changes prevented' : 'Pedalboard unlocked',
                  style: AppFonts.outfit(fontSize: 13, color: Colors.white)),
                duration: const Duration(seconds: 2),
                backgroundColor: _isLocked ? const Color(0xFFFF5252) : const Color(0xFF4CAF50),
              ),
            );
          }),
          Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 6), color: const Color(0xFF222222)),
          _chainToolBtn('◧ COMPACT', _compactView, onTap: () => setState(() => _compactView = true)),
          _chainToolBtn('◣ DETAILED', !_compactView, onTap: () => setState(() => _compactView = false)),
          Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 6), color: const Color(0xFF222222)),
          // FIX 12: GLOBAL BYPASS connected and applies visually
          _chainToolBtn('⊘ GLOBAL BYPASS', _globalBypass,
            color: _globalBypass ? const Color(0xFFF44336) : null,
            onTap: () {
              setState(() => _globalBypass = !_globalBypass);
              _applyGlobalBypass();
            },
          ),
          const Spacer(),
          // FIX 14: Signal chain view button
          GestureDetector(
            onTap: () => _showSignalChainOverlay(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF444444), width: 1),
              ),
              child: Text('⫏ CHAIN VIEW', style: AppFonts.jetBrainsMono(
                fontSize: 8, fontWeight: FontWeight.w600, color: const Color(0xFF888888), letterSpacing: 0.5,
              )),
            ),
          ),
          GestureDetector(
            onTap: _isLocked ? null : _showAddPedalSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isLocked ? const Color(0xFF111111) : const Color(0xFF1A1008),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _isLocked ? const Color(0xFF333333) : const Color(0xFFFF8C00), width: 1),
              ),
              child: Text('+ ADD PEDAL', style: AppFonts.jetBrainsMono(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _isLocked ? const Color(0xFF555555) : const Color(0xFFFF8C00), letterSpacing: 1,
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chainToolBtn(String label, bool active, {VoidCallback? onTap, Color? color}) {
    final btnColor = color ?? (active ? const Color(0xFFFF6B35) : const Color(0xFF888888));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? btnColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? btnColor : const Color(0xFF333333),
            width: 1,
          ),
        ),
        child: Text(label, style: AppFonts.jetBrainsMono(
          fontSize: 8, fontWeight: FontWeight.w600,
          color: active ? btnColor : const Color(0xFF888888),
          letterSpacing: 0.5,
        )),
      ),
    );
  }

  // FIX 12: Apply global bypass to all pedals
  void _applyGlobalBypass() {
    final chain = List<PedalState>.from(ref.read(pedalChainProvider));
    if (chain.isEmpty) return;
    ref.read(pedalChainProvider.notifier).state = [
      for (final pedal in chain) pedal.copyWith(enabled: !_globalBypass),
    ];
    HapticFeedback.mediumImpact();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  FIX 5: AMP / CABINET / MIC SELECTORS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAmpSelector() {
    final activeIdx = ref.watch(activeAmpModelProvider);
    return _buildModelSelectorSection(
      title: 'AMPLIFIER MODELS',
      itemCount: ampModels.length,
      activeIndex: activeIdx,
      itemBuilder: (i) {
        final amp = ampModels[i];
        final isActive = i == activeIdx;
        return _modelCard(
          name: amp.name,
          subtitle: amp.category,
          isActive: isActive,
          color: const Color(0xFFFF8C00),
          icon: Icons.amp_stories,
          onTap: () => ref.read(activeAmpModelProvider.notifier).state = i,
        );
      },
    );
  }

  Widget _buildCabinetSelector() {
    final activeIdx = ref.watch(activeCabinetModelProvider);
    return _buildModelSelectorSection(
      title: 'CABINET MODELS',
      itemCount: cabinetModels.length,
      activeIndex: activeIdx,
      itemBuilder: (i) {
        final cab = cabinetModels[i];
        final isActive = i == activeIdx;
        return _modelCard(
          name: cab.name,
          subtitle: '${cab.speakerConfig} - ${cab.description}',
          isActive: isActive,
          color: const Color(0xFF8B7355),
          icon: Icons.speaker,
          onTap: () => ref.read(activeCabinetModelProvider.notifier).state = i,
        );
      },
    );
  }

  Widget _buildMicSelector() {
    final activeIdx = ref.watch(activeMicModelProvider);
    return _buildModelSelectorSection(
      title: 'MICROPHONE MODELS',
      itemCount: micModels.length,
      activeIndex: activeIdx,
      itemBuilder: (i) {
        final mic = micModels[i];
        final isActive = i == activeIdx;
        return _modelCard(
          name: mic.name,
          subtitle: '${mic.type} - ${mic.description}',
          isActive: isActive,
          color: const Color(0xFF4FC3F7),
          icon: Icons.mic,
          onTap: () => ref.read(activeMicModelProvider.notifier).state = i,
        );
      },
    );
  }

  Widget _buildModelSelectorSection({
    required String title,
    required int itemCount,
    required int activeIndex,
    required Widget Function(int) itemBuilder,
  }) {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E0E12), Color(0xFF0A0A0D)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(title, style: AppFonts.jetBrainsMono(
                fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFFF8C00), letterSpacing: 3,
              )),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                ),
                itemCount: itemCount,
                itemBuilder: (context, i) => itemBuilder(i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelCard({
    required String name,
    required String subtitle,
    required bool isActive,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isActive
                ? [color.withValues(alpha: 0.12), color.withValues(alpha: 0.05)]
                : [const Color(0xFF181818), const Color(0xFF111111)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.7) : const Color(0xFF2A2A2A),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: -2),
          ] : null,
        ),
        child: Stack(
          children: [
            if (isActive)
              Positioned(top: 6, right: 6, child: Icon(Icons.check_circle, size: 16, color: color)),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 22, color: isActive ? color : const Color(0xFF555555)),
                    const SizedBox(height: 4),
                    Text(name.toUpperCase(), style: AppFonts.jetBrainsMono(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: isActive ? color : const Color(0xFF888888), letterSpacing: 1,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppFonts.outfit(
                      fontSize: 8, color: const Color(0xFF555555),
                    ), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderSection(String title, String message) {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E0E12), Color(0xFF0A0A0D)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 40, color: const Color(0xFF444444)),
              const SizedBox(height: 12),
              Text(title, style: AppFonts.jetBrainsMono(
                fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF555555), letterSpacing: 2,
              )),
              const SizedBox(height: 8),
              Text(message, style: AppFonts.outfit(fontSize: 13, color: const Color(0xFF444444))),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  6. PEDALBOARD AREA  —  Wood grain board with organized sections
  //  FIX 3: Empty "+" slots after each section
  //  FIX 4: Proper spacing with Wrap/constrained layout
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPedalBoard(List<PedalState> chain) {
    if (chain.isEmpty) return _buildEmptyState();

    // Group pedals by category
    final dynamics = chain.where((p) => [EffectType.noiseGate, EffectType.compressor, EffectType.eq].contains(p.type)).toList();
    final gain = chain.where((p) => [EffectType.drive, EffectType.amp].contains(p.type)).toList();
    final modTime = chain.where((p) => [EffectType.chorus, EffectType.delay, EffectType.reverb, EffectType.cabinet, EffectType.volume].contains(p.type)).toList();

    return Container(
      decoration: BoxDecoration(
        // Pedalboard wood grain background
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1A06), Color(0xFF1A1008), Color(0xFF120C05), Color(0xFF1A1008)],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
        border: Border.all(color: const Color(0xFF8B6914), width: 3),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          const BoxShadow(color: Color(0xFF4A3800), blurRadius: 0, spreadRadius: 1),
          BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Metal rail top
          Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5A5A60), Color(0xFF3A3A40), Color(0xFF888890), Color(0xFF4A4A50)],
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2))],
            ),
          ),
          // Signal path header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 40, height: 1, decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.transparent, const Color(0xFF333333)]))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('🎸 INPUT', style: AppFonts.jetBrainsMono(
                    fontSize: 9, color: const Color(0xFF444444), letterSpacing: 3,
                  )),
                ),
                Container(width: 40, height: 1, color: const Color(0xFF333333)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('SIGNAL CHAIN', style: AppFonts.jetBrainsMono(
                    fontSize: 9, color: const Color(0xFF444444), letterSpacing: 3,
                  )),
                ),
                Container(width: 40, height: 1, color: const Color(0xFF333333)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('AMP OUT 🔊', style: AppFonts.jetBrainsMono(
                    fontSize: 9, color: const Color(0xFF444444), letterSpacing: 3,
                  )),
                ),
                Container(width: 40, height: 1, decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF333333), Colors.transparent]))),
              ],
            ),
          ),
          // Pedal rows by section
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (dynamics.isNotEmpty) ...[
                    _sectionLabel('· dynamics · filters · pitch ·'),
                    _buildPedalsRow(dynamics, chain),
                  ],
                  if (gain.isNotEmpty) ...[
                    _sectionLabel('· gain staging · overdrive · distortion · fuzz ·'),
                    _buildPedalsRow(gain, chain),
                  ],
                  if (modTime.isNotEmpty) ...[
                    _sectionLabel('· modulation · time · ambience ·'),
                    _buildPedalsRow(modTime, chain),
                  ],
                  // If categories are empty, show all pedals in a single row
                  if (dynamics.isEmpty && gain.isEmpty && modTime.isEmpty)
                    _buildPedalsRow(chain, chain),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Metal rail bottom
          Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5A5A60), Color(0xFF3A3A40), Color(0xFF888890), Color(0xFF4A4A50)],
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2))],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text, style: AppFonts.jetBrainsMono(
        fontSize: 9, color: const Color(0xFF444444), letterSpacing: 3,
      )),
    );
  }

  // FIX 3: Add empty "+" slots after pedals
  // FIX 4: Proper spacing with constrained layout
  Widget _buildPedalsRow(List<PedalState> sectionPedals, List<PedalState> fullChain) {
    final rowHeight = _compactView ? 100.0 : 180.0;
    // Total items = pedals + 2 empty slots (FIX 3)
    final totalItems = sectionPedals.length + 2;
    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: totalItems,
        separatorBuilder: (_, i) {
          if (i < sectionPedals.length) return _copperCableConnector(true);
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, i) {
          if (i >= sectionPedals.length) {
            // FIX 3: Empty "+" slot
            return _emptyPedalSlot();
          }
          final pedal = sectionPedals[i];
          final idx = fullChain.indexOf(pedal);
          if (pedal.type == EffectType.amp) return _ampHeadCard(pedal, idx);
          if (pedal.type == EffectType.cabinet) return _cabinetCard(pedal, idx);
          if (pedal.type == EffectType.volume) return _volumePedalCard(pedal, idx);
          return _pedalCard(pedal, idx);
        },
      ),
    );
  }

  // FIX 3: Empty slot widget with dotted border
  Widget _emptyPedalSlot() {
    final cardWidth = _compactView ? 68.0 : 100.0;
    final cardHeight = _compactView ? 90.0 : 165.0;
    return GestureDetector(
      onTap: _isLocked ? null : _showAddPedalSheet,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3A3A3A), width: 1),
        ),
        child: CustomPaint(
          painter: _DottedBorderPainter(color: const Color(0xFF444444)),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: _compactView ? 22 : 30, color: const Color(0xFF444444)),
                if (!_compactView) ...[
                  const SizedBox(height: 6),
                  Text('ADD', style: AppFonts.jetBrainsMono(
                    fontSize: 8, color: const Color(0xFF444444), letterSpacing: 2,
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PEDAL CARD  —  Realistic stompbox (HTML design quality)
  // ═══════════════════════════════════════════════════════════════════

  Widget _pedalCard(PedalState pedal, int index) {
    final isSelected = _selectedPedalIndex == index;
    final isBypassed = !pedal.enabled || _globalBypass;
    final bodyColors = _PedalColors.bodyGradients[pedal.type] ?? [const Color(0xFF2E2E2E), const Color(0xFF222222), const Color(0xFF1A1A1A)];
    final faceplateColor = _PedalColors.faceplate[pedal.type] ?? pedal.color;
    final nameColor = _PedalColors.nameColor[pedal.type] ?? pedal.color;
    final knobCol = _PedalColors.knobColor[pedal.type] ?? const Color(0xFFCCCCCC);
    final cardWidth = _compactView ? 68.0 : 100.0;
    final cardHeight = _compactView ? 90.0 : 165.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPedalIndex = isSelected ? null : index);
      },
      onLongPress: () => _showPedalMenu(index),
      child: AnimatedContainer(
        duration: AppAnimations.medium,
        curve: AppAnimations.snapCurve,
        width: cardWidth,
        height: cardHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.5, -1),
            end: const Alignment(0.5, 1),
            colors: isBypassed
                ? bodyColors.map((c) => Color.lerp(c, const Color(0xFF111111), 0.6)!).toList()
                : bodyColors,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? faceplateColor.withValues(alpha: 0.8)
                : isBypassed ? const Color(0xFF222222) : const Color(0xFF3A3A3A),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 16, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 0, offset: const Offset(0, -1)),
            if (isSelected) BoxShadow(color: faceplateColor.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: -2),
          ],
        ),
        child: AnimatedOpacity(
          duration: AppAnimations.medium,
          opacity: isBypassed ? 0.4 : 1.0,
          child: Stack(
            children: [
              // Corner screws
              ..._buildScrews(cardWidth, cardHeight),
              // LED
              Positioned(
                top: 4, left: 0, right: 0,
                child: Center(child: _ledIndicator(faceplateColor, pedal.enabled && !_globalBypass, size: 7)),
              ),
              // Pedal content
              Padding(
                padding: EdgeInsets.fromLTRB(6, _compactView ? 12 : 18, 6, 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (!_compactView) ...[
                      // Brand label
                      Text(
                        pedal.type.name.toUpperCase(),
                        style: AppFonts.jetBrainsMono(
                          fontSize: 5, color: faceplateColor.withValues(alpha: 0.5), letterSpacing: 3,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                    ],
                    // Pedal name
                    Text(
                      pedal.name.toUpperCase(),
                      style: AppFonts.jetBrainsMono(
                        fontSize: _compactView ? 6 : 8,
                        fontWeight: FontWeight.w800,
                        color: pedal.enabled && !_globalBypass ? nameColor : AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (!_compactView) ...[
                      const SizedBox(height: 6),
                      // Knobs row
                      _miniKnobsRow(pedal, knobCol),
                      const Spacer(),
                      // Footswitch + jacks
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _jackDot(),
                          _chromeFootswitch(
                            onTap: () => _toggleBypass(index, ref.read(pedalChainProvider)),
                            enabled: pedal.enabled,
                            color: faceplateColor,
                            size: 30,
                          ),
                          _jackDot(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  FIX 15: VOLUME PEDAL CARD — Expression pedal treadle shape
  // ═══════════════════════════════════════════════════════════════════

  Widget _volumePedalCard(PedalState pedal, int index) {
    final isSelected = _selectedPedalIndex == index;
    final isBypassed = !pedal.enabled || _globalBypass;
    final faceplateColor = _PedalColors.faceplate[EffectType.volume]!;
    final nameColor = _PedalColors.nameColor[EffectType.volume]!;
    final cardWidth = _compactView ? 90.0 : 120.0;
    final cardHeight = _compactView ? 90.0 : 165.0;
    final level = (pedal.params['level'] ?? 100) / 100.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPedalIndex = isSelected ? null : index);
      },
      onLongPress: () => _showPedalMenu(index),
      child: AnimatedContainer(
        duration: AppAnimations.medium,
        curve: AppAnimations.snapCurve,
        width: cardWidth,
        height: cardHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isBypassed
                ? [const Color(0xFF151515), const Color(0xFF101010), const Color(0xFF0A0A0A)]
                : [const Color(0xFF2A1A3A), const Color(0xFF1A1028), const Color(0xFF110A1E)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? faceplateColor.withValues(alpha: 0.8) : const Color(0xFF3A3A3A),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 16, offset: const Offset(0, 8)),
            if (isSelected) BoxShadow(color: faceplateColor.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: -2),
          ],
        ),
        child: AnimatedOpacity(
          duration: AppAnimations.medium,
          opacity: isBypassed ? 0.45 : 1.0,
          child: Stack(
            children: [
              // Treadle shape
              Positioned.fill(
                child: CustomPaint(
                  painter: _ExpressionPedalPainter(
                    level: level,
                    color: faceplateColor,
                    enabled: pedal.enabled && !_globalBypass,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      _ledIndicator(faceplateColor, pedal.enabled && !_globalBypass),
                      const SizedBox(width: 6),
                      Expanded(child: Text('VOL PEDAL', style: AppFonts.jetBrainsMono(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: pedal.enabled && !_globalBypass ? Colors.white : AppColors.textMuted,
                        letterSpacing: 1.5,
                      ))),
                    ]),
                    if (!_compactView) ...[
                      const SizedBox(height: 8),
                      // Level display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            faceplateColor.withValues(alpha: 0.15),
                            faceplateColor.withValues(alpha: 0.05),
                          ]),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: faceplateColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '${(level * 100).toInt()}%',
                          style: AppFonts.jetBrainsMono(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: pedal.enabled && !_globalBypass ? nameColor : AppColors.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Treadle indicator
                      Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: const Color(0xFF1A1A1A),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: level,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(colors: [
                                faceplateColor.withValues(alpha: 0.8),
                                faceplateColor,
                              ]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _chromeFootswitch(
                        onTap: () => _toggleBypass(index, ref.read(pedalChainProvider)),
                        enabled: pedal.enabled, color: faceplateColor,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScrews(double w, double h) {
    return [
      for (final pos in [
        const Offset(5, 5), Offset(w - 14, 5),
        Offset(5, h - 14), Offset(w - 14, h - 14),
      ])
        Positioned(
          left: pos.dx, top: pos.dy,
          child: Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                colors: [Color(0xFF666666), Color(0xFF222222)],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 2),
                BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 0, offset: const Offset(0, 1)),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _jackDot() {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFF444444), Color(0xFF111111)]),
        border: Border.all(color: const Color(0xFF555555), width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 2)],
      ),
    );
  }

  // ── Miniature knobs row on pedal face ──
  Widget _miniKnobsRow(PedalState pedal, Color knobColor) {
    final paramKeys = pedal.params.keys.take(_compactView ? 2 : 3).toList();
    if (paramKeys.isEmpty) return const SizedBox(height: 24);

    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: paramKeys.map((key) {
          final val = pedal.params[key] ?? 0;
          final max = _maxForParam(pedal.type, key);
          final min = _minForParam(pedal.type, key);
          final norm = ((val - min) / (max - min)).clamp(0.0, 1.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22, height: 22,
                child: CustomPaint(
                  painter: _MiniKnobPainter(value: norm, color: knobColor),
                ),
              ),
              const SizedBox(height: 2),
              Text(key.toUpperCase(), style: AppFonts.jetBrainsMono(
                fontSize: 6, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 0.5,
              )),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Chrome footswitch button ──
  Widget _chromeFootswitch({required VoidCallback onTap, required bool enabled, required Color color, double size = 40}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.3),
            colors: [Color(0xFF4A4A50), Color(0xFF1A1A1E), Color(0xFF0A0A0E)],
            stops: [0.0, 0.6, 1.0],
          ),
          border: Border.all(color: const Color(0xFF333333), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 8, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 0, offset: const Offset(0, -1)),
          ],
        ),
      ),
    );
  }

  // ── LED Indicator with Glow + Pulse ──
  Widget _ledIndicator(Color color, bool active, {double size = 12}) {
    return AnimatedBuilder(
      animation: _ledPulseAnim,
      builder: (context, child) {
        final glowIntensity = active ? _ledPulseAnim.value : 0.0;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : color.withValues(alpha: 0.25),
            boxShadow: active
                ? [
                    BoxShadow(color: color.withValues(alpha: 0.7 * glowIntensity), blurRadius: 6, spreadRadius: 3),
                    BoxShadow(color: color.withValues(alpha: 0.4 * glowIntensity), blurRadius: 12, spreadRadius: 0),
                  ]
                : null,
          ),
        );
      },
    );
  }

  // ── Copper Cable Connector ──
  Widget _copperCableConnector(bool active) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 32,
        child: AnimatedBuilder(
          animation: _cableFlowController,
          builder: (context, child) {
            return CustomPaint(
              painter: _CopperCablePainter(
                progress: _cableFlowController.value,
                active: active,
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  AMP HEAD CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _ampHeadCard(PedalState pedal, int index) {
    final isSelected = _selectedPedalIndex == index;
    final isBypassed = !pedal.enabled || _globalBypass;

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
        height: _compactView ? 90 : 165,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isBypassed
                ? [const Color(0xFF181818), const Color(0xFF131313), const Color(0xFF0E0E0E)]
                : [const Color(0xFF2A2A2A), const Color(0xFF222222), const Color(0xFF1A1A1A)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? pedal.color.withValues(alpha: 0.8) : const Color(0xFF3A3A3A),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 16, offset: const Offset(0, 8)),
            if (isSelected) BoxShadow(color: pedal.color.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: -2),
          ],
        ),
        child: AnimatedOpacity(
          duration: AppAnimations.medium,
          opacity: isBypassed ? 0.45 : 1.0,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AmpGrillePainter(color: pedal.color, enabled: pedal.enabled && !_globalBypass),
                ),
              ),
              // Top accent bar
              Positioned(top: 0, left: 0, right: 0, child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [pedal.color.withValues(alpha: 0.5), pedal.color, pedal.color.withValues(alpha: 0.5)]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
              )),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      _ledIndicator(pedal.color, pedal.enabled && !_globalBypass),
                      const SizedBox(width: 6),
                      Expanded(child: Text('AMP HEAD', style: AppFonts.jetBrainsMono(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: pedal.enabled && !_globalBypass ? Colors.white : AppColors.textMuted,
                        letterSpacing: 1.5,
                      ))),
                    ]),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [pedal.color.withValues(alpha: 0.15), pedal.color.withValues(alpha: 0.05)]),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: pedal.color.withValues(alpha: 0.2)),
                      ),
                      child: Text(pedal.name.toUpperCase(), style: AppFonts.jetBrainsMono(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: pedal.enabled && !_globalBypass ? pedal.color : AppColors.textMuted, letterSpacing: 1.5,
                      ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (!_compactView) ...[
                      const Spacer(),
                      _miniKnobsRow(pedal, const Color(0xFF333333)),
                      const SizedBox(height: 6),
                      _chromeFootswitch(
                        onTap: () => _toggleBypass(index, ref.read(pedalChainProvider)),
                        enabled: pedal.enabled, color: pedal.color,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CABINET CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _cabinetCard(PedalState pedal, int index) {
    final isSelected = _selectedPedalIndex == index;
    final isBypassed = !pedal.enabled || _globalBypass;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPedalIndex = isSelected ? null : index);
      },
      onLongPress: () => _showPedalMenu(index),
      child: AnimatedContainer(
        duration: AppAnimations.medium,
        curve: AppAnimations.snapCurve,
        width: 110,
        height: _compactView ? 90 : 165,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isBypassed
                ? [const Color(0xFF151515), const Color(0xFF101010), const Color(0xFF0C0C0C)]
                : [const Color(0xFF2C2218), const Color(0xFF241C14), const Color(0xFF1A1410)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? pedal.color.withValues(alpha: 0.8) : const Color(0xFF3A3530),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 16, offset: const Offset(0, 8)),
            if (isSelected) BoxShadow(color: pedal.color.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: -2),
          ],
        ),
        child: AnimatedOpacity(
          duration: AppAnimations.medium,
          opacity: isBypassed ? 0.45 : 1.0,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 40, 12, 50),
                  child: CustomPaint(
                    painter: _SpeakerGrillePainter(enabled: pedal.enabled && !_globalBypass, color: pedal.color),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      _ledIndicator(pedal.color, pedal.enabled && !_globalBypass),
                      const SizedBox(width: 6),
                      Expanded(child: Text('CABINET', style: AppFonts.jetBrainsMono(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: pedal.enabled && !_globalBypass ? Colors.white : AppColors.textMuted, letterSpacing: 1.5,
                      ))),
                    ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: pedal.color.withValues(alpha: 0.15)),
                      ),
                      child: Text(pedal.name.toUpperCase(), style: AppFonts.jetBrainsMono(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: pedal.enabled && !_globalBypass ? pedal.color.withValues(alpha: 0.8) : AppColors.textMuted, letterSpacing: 1,
                      ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (!_compactView) ...[
                      const SizedBox(height: 6),
                      _chromeFootswitch(
                        onTap: () => _toggleBypass(index, ref.read(pedalChainProvider)),
                        enabled: pedal.enabled, color: pedal.color,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
    final paramGroups = _groupParams(pedal.type, pedal.params);
    final faceplateColor = _PedalColors.faceplate[pedal.type] ?? pedal.color;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF1E1E1E), faceplateColor, 0.06)!,
            Color.lerp(AppColors.bgPanel, faceplateColor, 0.02)!,
            AppColors.bgPanel,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
        border: Border(top: BorderSide(color: faceplateColor.withValues(alpha: 0.8), width: 3.0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 12, offset: const Offset(0, -4)),
          const BoxShadow(color: Color(0xFF2A2A2A), blurRadius: 6, offset: Offset(0, -1)),
          BoxShadow(color: faceplateColor.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -6)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _ledIndicator(faceplateColor, pedal.enabled),
                const SizedBox(width: 10),
                Icon(pedal.icon, size: 20, color: faceplateColor),
                const SizedBox(width: 8),
                Text(pedal.name, style: AppFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                )),
                const Spacer(),
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
                          ? LinearGradient(colors: [
                              const Color(0xFF32D74B).withValues(alpha: 0.2),
                              const Color(0xFF32D74B).withValues(alpha: 0.08),
                            ]) : null,
                      color: pedal.enabled ? null : AppColors.bgInset,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pedal.enabled ? const Color(0xFF32D74B) : AppColors.border),
                      boxShadow: pedal.enabled
                          ? [BoxShadow(color: const Color(0xFF32D74B).withValues(alpha: 0.2), blurRadius: 8)]
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: paramGroups.entries.map((group) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
                        child: Text(group.key.toUpperCase(), style: AppFonts.jetBrainsMono(
                          fontSize: 9, color: faceplateColor.withValues(alpha: 0.6),
                          letterSpacing: 1.5, fontWeight: FontWeight.w600,
                        )),
                      ),
                      Wrap(
                        spacing: 8, runSpacing: 8,
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
                            color: faceplateColor,
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
      EffectType.eq => { 'Equalizer': keys },
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
      EffectType.volume => {
        'Level': keys.where((k) => ['level'].contains(k)).toList(),
        'Curve': keys.where((k) => ['curve'].contains(k)).toList(),
      },
      _ => {'Parameters': keys},
    };
  }

  // ── Premium 3D Knob ──
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
              GestureDetector(
                onPanUpdate: (details) {
                  final delta = -details.delta.dy / 100.0;
                  final newNorm = (normalized + delta).clamp(0.0, 1.0);
                  final newVal = min + newNorm * (max - min);
                  onChanged(newVal);
                },
                child: SizedBox(
                  width: 84, height: 84,
                  child: CustomPaint(
                    painter: _PremiumKnobPainter(value: normalized, color: color),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgInset,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF1A1A1A)),
                ),
                child: Text(
                  value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
                  style: AppFonts.jetBrainsMono(fontSize: 12, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 2),
              Text(_unitForParam(label), style: AppFonts.outfit(fontSize: 8, color: AppColors.textMuted.withValues(alpha: 0.7))),
              const SizedBox(height: 2),
              Text(label.toUpperCase(), style: AppFonts.outfit(
                fontSize: 9, color: color.withValues(alpha: 0.7), letterSpacing: 0.5, fontWeight: FontWeight.w600,
              )),
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
  //  8. BOTTOM STATUS BAR  —  Professional status strip
  //  FIX 13: No scene info — only INPUT, OUTPUT, ACTIVE PEDALS, LATENCY, CPU, MIDI
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBottomStatusBar(List<PedalState> chain) {
    final activePedals = chain.where((p) => p.enabled).length;
    final latency = ref.watch(pedalLatencyMsProvider);

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF080809),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A), width: 1)),
      ),
      child: Row(
        children: [
          // Input indicator
          _statusChip('INPUT', _inputActive ? '● ACTIVE' : '○ NO SIGNAL',
              _inputActive ? const Color(0xFF00FF11) : const Color(0xFF555555)),
          const SizedBox(width: 10),
          _statusChip('OUTPUT', '${(ref.watch(pedalOutputLevelProvider) * 100).toStringAsFixed(0)}%',
              const Color(0xFFFF8C00)),
          const SizedBox(width: 10),
          _statusChip('ACTIVE', '$activePedals PEDALS', const Color(0xFFFF8C00)),
          const Spacer(),
          _statusChip('LATENCY', '${latency.toStringAsFixed(1)} ms', const Color(0xFF555555)),
          const SizedBox(width: 10),
          _statusChip('CPU', '12%', const Color(0xFF555555)),
          const SizedBox(width: 10),
          _statusChip('MIDI', 'NO MIDI', const Color(0xFF555555)),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF222222), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: AppFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF444444), letterSpacing: 1)),
          Text(value, style: AppFonts.jetBrainsMono(fontSize: 9, color: valueColor, letterSpacing: 1)),
        ],
      ),
    );
  }

  void _toggleBypass(int index, List<PedalState> chain) {
    if (_isLocked) return;
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

  // ═══════════════════════════════════════════════════════════════════
  //  FIX 9: TAP TEMPO
  // ═══════════════════════════════════════════════════════════════════

  void _handleTapTempo() {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final timestamps = List<DateTime>.from(ref.read(tapTempoTimestampsProvider));

    // Reset if gap > 3 seconds
    if (timestamps.isNotEmpty && now.difference(timestamps.last).inMilliseconds > 3000) {
      timestamps.clear();
    }

    timestamps.add(now);

    // Keep only last 8 timestamps
    while (timestamps.length > 8) {
      timestamps.removeAt(0);
    }

    ref.read(tapTempoTimestampsProvider.notifier).state = timestamps;

    // Calculate BPM from last 4 taps minimum
    if (timestamps.length >= 2) {
      final count = timestamps.length > 4 ? 4 : timestamps.length;
      final recentTaps = timestamps.sublist(timestamps.length - count);
      double totalMs = 0;
      for (int i = 1; i < recentTaps.length; i++) {
        totalMs += recentTaps[i].difference(recentTaps[i - 1]).inMilliseconds;
      }
      final avgMs = totalMs / (recentTaps.length - 1);
      final bpm = (60000 / avgMs).clamp(30.0, 300.0);
      ref.read(pedalBpmProvider.notifier).state = bpm;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  LIVE MODE
  //  FIX 7: Progressive preset adding, horizontal strip, BPM
  //  FIX 8: BPM editable with keyboard
  //  FIX 9: Tap Tempo functional
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildLiveMode(List<PedalState> chain) {
    final livePresets = ref.watch(livePresetsProvider);
    final activeLiveIdx = ref.watch(activeLivePresetIndexProvider);
    final bpm = ref.watch(pedalBpmProvider);

    // Determine which chain to show
    final displayChain = (livePresets.isNotEmpty && activeLiveIdx < livePresets.length)
        ? livePresets[activeLiveIdx].chain
        : chain;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060606), Color(0xFF030303), Color(0xFF010101)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Live mode header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0E0E0E), Color(0xFF060606)],
                ),
                border: Border(bottom: BorderSide(color: AppColors.danger.withValues(alpha: 0.2), width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _liveMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3A3A3A), Color(0xFF2A2A2A), Color(0xFF1E1E1E)]),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF4A4A4A), width: 0.8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.arrow_back, size: 14, color: Color(0xFFAAAAAA)),
                        const SizedBox(width: 6),
                        Text('EXIT', style: AppFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFAAAAAA), letterSpacing: 1)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // FIX 8: BPM editable display
                  _buildBpmDisplay(bpm),
                  const SizedBox(width: 8),
                  // FIX 9: TAP button
                  GestureDetector(
                    onTap: () => _handleTapTempo(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3A3A3A), Color(0xFF2A2A2A)]),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF4A4A4A), width: 0.8),
                      ),
                      child: Text('TAP', style: AppFonts.jetBrainsMono(
                        fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFFF8C00), letterSpacing: 1,
                      )),
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _ledPulseAnim,
                    builder: (context, child) {
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.2, -0.3),
                              colors: [Color.lerp(Colors.white, AppColors.danger, 0.4)!, AppColors.danger],
                            ),
                            boxShadow: [
                              BoxShadow(color: AppColors.danger.withValues(alpha: 0.6 * _ledPulseAnim.value), blurRadius: 12, spreadRadius: 2),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('LIVE MODE', style: AppTheme.lcdStyle(
                          size: 18, color: AppColors.danger, glowAlpha: 0.3 + 0.3 * _ledPulseAnim.value,
                        ).copyWith(letterSpacing: 3)),
                      ]);
                    },
                  ),
                ],
              ),
            ),
            // FIX 7: Horizontal preset strip at top
            _buildLivePresetStrip(livePresets, activeLiveIdx),
            // Pedal grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.0,
                      ),
                      itemCount: displayChain.length,
                      itemBuilder: (context, index) => _liveStompButton(displayChain[index], index, displayChain),
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

  // FIX 8: BPM display with editable text field
  Widget _buildBpmDisplay(double bpm) {
    return GestureDetector(
      onTap: () => _showBpmEditor(bpm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF333333), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('BPM ', style: AppFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF555555), letterSpacing: 1)),
          Text(bpm.toStringAsFixed(0), style: AppFonts.jetBrainsMono(
            fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFFF8C00), letterSpacing: 1,
          )),
        ]),
      ),
    );
  }

  void _showBpmEditor(double currentBpm) {
    final controller = TextEditingController(text: currentBpm.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Set BPM', style: AppFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: AppFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFFFF8C00)),
          decoration: InputDecoration(
            hintText: '30 - 300',
            hintStyle: AppFonts.jetBrainsMono(fontSize: 14, color: const Color(0xFF555555)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF8C00)),
            ),
          ),
          onSubmitted: (val) {
            final parsed = double.tryParse(val);
            if (parsed != null && parsed >= 30 && parsed <= 300) {
              ref.read(pedalBpmProvider.notifier).state = parsed;
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppFonts.outfit(color: const Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null && parsed >= 30 && parsed <= 300) {
                ref.read(pedalBpmProvider.notifier).state = parsed;
              }
              Navigator.pop(context);
            },
            child: Text('Set', style: AppFonts.outfit(color: const Color(0xFFFF8C00), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // FIX 7: Live preset strip with "+" button
  Widget _buildLivePresetStrip(List<PedalPreset> livePresets, int activeIdx) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A), width: 1)),
      ),
      child: Row(
        children: [
          Text('SETLIST ▸', style: AppFonts.jetBrainsMono(
            fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF555555), letterSpacing: 2,
          )),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: livePresets.length + 1, // +1 for "+" button
              itemBuilder: (context, i) {
                if (i == livePresets.length) {
                  // "+" button to add preset
                  return GestureDetector(
                    onTap: () => _showPresetBrowserForLive(),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF333333), width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add, size: 14, color: Color(0xFFFF8C00)),
                        const SizedBox(width: 4),
                        Text('ADD', style: AppFonts.jetBrainsMono(
                          fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFFF8C00), letterSpacing: 1,
                        )),
                      ]),
                    ),
                  );
                }
                final preset = livePresets[i];
                final isActive = i == activeIdx;
                return GestureDetector(
                  onTap: () {
                    ref.read(activeLivePresetIndexProvider.notifier).state = i;
                    ref.read(pedalChainProvider.notifier).state = List.from(preset.chain);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: AppAnimations.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1A0A00) : const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive ? const Color(0xFFFF8C00) : const Color(0xFF222222),
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(color: const Color(0xFFFF8C00).withValues(alpha: 0.15), blurRadius: 8),
                      ] : null,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${i + 1}', style: AppFonts.jetBrainsMono(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: isActive ? const Color(0xFFFF8C00) : const Color(0xFF555555),
                      )),
                      const SizedBox(width: 6),
                      Text(preset.name.toUpperCase(), style: AppFonts.jetBrainsMono(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : const Color(0xFF888888),
                        letterSpacing: 1,
                      )),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveStompButton(PedalState pedal, int index, List<PedalState> chain) {
    final faceColor = _PedalColors.faceplate[pedal.type] ?? pedal.color;
    final bodyColors = _PedalColors.bodyGradients[pedal.type] ?? [const Color(0xFF2E2E2E), const Color(0xFF222222), const Color(0xFF1A1A1A)];

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
            colors: pedal.enabled ? bodyColors : [const Color(0xFF151515), const Color(0xFF111111), const Color(0xFF0A0A0A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pedal.enabled ? faceColor.withValues(alpha: 0.6) : const Color(0xFF222222),
            width: pedal.enabled ? 2.0 : 1.0,
          ),
          boxShadow: [
            ...AppColors.neumorphicRaised(scale: 1.5, glowColor: pedal.enabled ? faceColor : null),
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            if (!pedal.enabled)
              Positioned(
                bottom: 8, left: 16, right: 16,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _ledPulseAnim,
                    builder: (context, child) {
                      final glow = pedal.enabled ? _ledPulseAnim.value : 0.0;
                      return Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: pedal.enabled
                              ? RadialGradient(
                                  center: const Alignment(-0.2, -0.2),
                                  colors: [Color.lerp(Colors.white, faceColor, 0.3)!, faceColor, faceColor.withValues(alpha: 0.7)],
                                  stops: const [0.0, 0.5, 1.0],
                                )
                              : const RadialGradient(colors: [Color(0xFF2E2E2E), Color(0xFF1E1E1E)]),
                          border: Border.all(
                            color: pedal.enabled ? faceColor.withValues(alpha: 0.5) : const Color(0xFF3A3A3A), width: 1.2,
                          ),
                          boxShadow: pedal.enabled
                              ? [
                                  BoxShadow(color: faceColor.withValues(alpha: 0.7 * glow), blurRadius: 14, spreadRadius: 2),
                                  BoxShadow(color: faceColor.withValues(alpha: 0.35 * glow), blurRadius: 28, spreadRadius: 4),
                                ]
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(pedal.name.toUpperCase(), style: AppFonts.jetBrainsMono(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: pedal.enabled ? AppColors.textPrimary : AppColors.textMuted, letterSpacing: 1.5,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                    decoration: BoxDecoration(
                      color: pedal.enabled ? faceColor.withValues(alpha: 0.2) : AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: pedal.enabled ? faceColor.withValues(alpha: 0.4) : AppColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      pedal.enabled ? 'ON' : 'BYPASS',
                      style: AppFonts.jetBrainsMono(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: pedal.enabled ? faceColor : AppColors.danger.withValues(alpha: 0.6), letterSpacing: 1.5,
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
  //  FIX 14: SIGNAL CHAIN LINEAR VIEW OVERLAY
  // ═══════════════════════════════════════════════════════════════════

  void _showSignalChainOverlay() {
    final chain = ref.read(pedalChainProvider);
    final ampIdx = ref.read(activeAmpModelProvider);
    final cabIdx = ref.read(activeCabinetModelProvider);
    final micIdx = ref.read(activeMicModelProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(color: const Color(0xFF555555), borderRadius: BorderRadius.circular(2)),
                ),
                Text('SIGNAL CHAIN', style: AppFonts.jetBrainsMono(
                  fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFFF8C00), letterSpacing: 3,
                )),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // Guitar input
                      _signalChainNode('🎸 GUITAR INPUT', const Color(0xFF00FF11), isEndpoint: true),
                      _signalChainArrow(),
                      // Pedals
                      for (int i = 0; i < chain.length; i++) ...[
                        _signalChainPedalNode(chain[i], i),
                        if (i < chain.length - 1) _signalChainArrow(),
                      ],
                      _signalChainArrow(),
                      // Amp
                      _signalChainNode(
                        '🔊 AMP: ${ampIdx < ampModels.length ? ampModels[ampIdx].name.toUpperCase() : "NONE"}',
                        const Color(0xFFFF8C00),
                      ),
                      _signalChainArrow(),
                      // Cabinet
                      _signalChainNode(
                        '📦 CAB: ${cabIdx < cabinetModels.length ? cabinetModels[cabIdx].name.toUpperCase() : "NONE"}',
                        const Color(0xFF8B7355),
                      ),
                      _signalChainArrow(),
                      // Mic
                      _signalChainNode(
                        '🎤 MIC: ${micIdx < micModels.length ? micModels[micIdx].name.toUpperCase() : "NONE"}',
                        const Color(0xFF4FC3F7),
                      ),
                      _signalChainArrow(),
                      // Output
                      _signalChainNode('🔊 OUTPUT / FOH', const Color(0xFFFF8C00), isEndpoint: true),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _signalChainNode(String label, Color color, {bool isEndpoint = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: isEndpoint ? 2 : 1),
      ),
      child: Text(label, style: AppFonts.jetBrainsMono(
        fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 1,
      ), textAlign: TextAlign.center),
    );
  }

  Widget _signalChainPedalNode(PedalState pedal, int index) {
    final faceColor = _PedalColors.faceplate[pedal.type] ?? pedal.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          faceColor.withValues(alpha: pedal.enabled ? 0.1 : 0.03),
          faceColor.withValues(alpha: pedal.enabled ? 0.05 : 0.01),
        ]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: pedal.enabled ? faceColor.withValues(alpha: 0.5) : const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pedal.enabled ? faceColor : const Color(0xFF333333),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            '${index + 1}. ${pedal.name.toUpperCase()}',
            style: AppFonts.jetBrainsMono(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: pedal.enabled ? faceColor : const Color(0xFF555555), letterSpacing: 1,
            ),
          )),
          Text(
            pedal.enabled ? 'ON' : 'BYPASS',
            style: AppFonts.jetBrainsMono(
              fontSize: 8, fontWeight: FontWeight.w600,
              color: pedal.enabled ? const Color(0xFF00FF11) : const Color(0xFFFF5252), letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signalChainArrow() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(width: 2, height: 12, color: const Color(0xFF333333)),
            const Icon(Icons.arrow_downward, size: 14, color: Color(0xFF555555)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DIALOGS
  // ═══════════════════════════════════════════════════════════════════

  void _showPresetBrowser() {
    _showPresetBrowserSheet(onSelect: (preset) {
      _loadPreset(preset);
      Navigator.pop(context);
    });
  }

  void _showPresetBrowserForLive() {
    _showPresetBrowserSheet(onSelect: (preset) {
      final livePresets = List<PedalPreset>.from(ref.read(livePresetsProvider));
      livePresets.add(preset);
      ref.read(livePresetsProvider.notifier).state = livePresets;
      ref.read(activeLivePresetIndexProvider.notifier).state = livePresets.length - 1;
      ref.read(pedalChainProvider.notifier).state = List.from(preset.chain);
      Navigator.pop(context);
    });
  }

  void _showPresetBrowserSheet({required void Function(PedalPreset) onSelect}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final presets = ref.watch(pedalPresetsProvider);
        final categories = ['All', ...{...presets.map((p) => p.category)}];
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filter = ref.watch(pedalCategoryFilterProvider);
            final filtered = filter == 'All' ? presets : presets.where((p) => p.category == filter).toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
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
                            onTap: () => onSelect(preset),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.bgInset,
                                borderRadius: BorderRadius.circular(10),
                                border: Border(left: BorderSide(color: catColor, width: 3)),
                              ),
                              child: Row(children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(preset.name, style: AppFonts.outfit(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 3),
                                    Text(preset.category, style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                )),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${preset.chain.length}', style: AppFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: catColor)),
                                ),
                              ]),
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
    ref.read(activeSceneIndexProvider.notifier).state = 0;
    setState(() => _selectedPedalIndex = null);
  }

  void _showAddPedalSheet() {
    const types = EffectType.values;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                final faceColor = _PedalColors.faceplate[type] ?? pedal.color;
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
                      border: Border.all(color: faceColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(pedal.icon, size: 22, color: faceColor),
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
    if (_isLocked) return;
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
//  DOTTED BORDER PAINTER (FIX 3: for empty pedal slots)
// ═══════════════════════════════════════════════════════════════════════

class _DottedBorderPainter extends CustomPainter {
  final Color color;

  _DottedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );

    // Draw dashed border using path metrics
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        final extractPath = metric.extractPath(distance, end);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedBorderPainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════
//  FIX 15: EXPRESSION PEDAL PAINTER (Volume Pedal treadle shape)
// ═══════════════════════════════════════════════════════════════════════

class _ExpressionPedalPainter extends CustomPainter {
  final double level;
  final Color color;
  final bool enabled;

  _ExpressionPedalPainter({required this.level, required this.color, required this.enabled});

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Treadle trapezoid shape
    final treadlePath = Path()
      ..moveTo(size.width * 0.15, size.height * 0.3)
      ..lineTo(size.width * 0.85, size.height * 0.25)
      ..lineTo(size.width * 0.9, size.height * 0.75)
      ..lineTo(size.width * 0.1, size.height * 0.8)
      ..close();

    canvas.drawPath(treadlePath, paint);

    // Treadle hinge line
    final hingePaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final hingeY = size.height * (0.3 + 0.5 * (1.0 - level));
    canvas.drawLine(
      Offset(size.width * 0.12, hingeY),
      Offset(size.width * 0.88, hingeY),
      hingePaint,
    );

    // Side grip lines
    final gripPaint = Paint()
      ..color = color.withValues(alpha: 0.04)
      ..strokeWidth = 0.8;

    for (double y = size.height * 0.35; y < size.height * 0.75; y += 4) {
      canvas.drawLine(
        Offset(size.width * 0.2, y),
        Offset(size.width * 0.8, y),
        gripPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ExpressionPedalPainter old) =>
      old.level != level || old.color != color || old.enabled != enabled;
}

// ═══════════════════════════════════════════════════════════════════════
//  COPPER CABLE PAINTER
// ═══════════════════════════════════════════════════════════════════════

class _CopperCablePainter extends CustomPainter {
  final double progress;
  final bool active;

  _CopperCablePainter({required this.progress, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height * 0.30;
    final droopY = size.height * 0.80;
    const jackRadius = 4.5;
    const jackPadding = 3.0;

    const startX = jackPadding;
    final endX = size.width - jackPadding;

    const copperLight = Color(0xFFD4A04A);
    const copperMid = Color(0xFFB8862A);
    const copperDim = Color(0xFF4A3810);

    const jackGrad = RadialGradient(
      center: Alignment(-0.3, -0.3),
      colors: [Color(0xFFAAAAAA), Color(0xFF777777), Color(0xFF444444)],
    );

    final leftJackRect = Rect.fromCircle(center: Offset(startX, midY), radius: jackRadius);
    final rightJackRect = Rect.fromCircle(center: Offset(endX, midY), radius: jackRadius);

    canvas.drawCircle(Offset(startX, midY), jackRadius,
      Paint()..shader = jackGrad.createShader(leftJackRect));
    canvas.drawCircle(Offset(startX, midY), 2.0,
      Paint()..color = active ? copperLight : const Color(0xFF555555));

    canvas.drawCircle(Offset(endX, midY), jackRadius,
      Paint()..shader = jackGrad.createShader(rightJackRect));
    canvas.drawCircle(Offset(endX, midY), 2.0,
      Paint()..color = active ? copperLight : const Color(0xFF555555));

    final cablePath = Path()
      ..moveTo(startX, midY)
      ..cubicTo(
        startX + (endX - startX) * 0.25, droopY,
        startX + (endX - startX) * 0.75, droopY,
        endX, midY,
      );

    canvas.drawPath(cablePath.shift(const Offset(0.8, 1.5)), Paint()
      ..color = Colors.black.withValues(alpha: active ? 0.5 : 0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 4.0..strokeCap = StrokeCap.round);

    if (active) {
      canvas.drawPath(cablePath, Paint()
        ..color = copperMid.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke..strokeWidth = 8.0..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    canvas.drawPath(cablePath, Paint()
      ..color = active ? copperMid.withValues(alpha: 0.55) : copperDim.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round);

    if (!active) return;

    const dotCount = 3;
    for (int i = 0; i < dotCount; i++) {
      final t = (progress + i / dotCount) % 1.0;
      final pt = _evalCubic(
        Offset(startX, midY),
        Offset(startX + (endX - startX) * 0.25, droopY),
        Offset(startX + (endX - startX) * 0.75, droopY),
        Offset(endX, midY), t,
      );
      final alpha = (1.0 - (t - 0.5).abs() * 2.0).clamp(0.3, 1.0);
      canvas.drawCircle(pt, 3.0, Paint()..color = copperLight.withValues(alpha: alpha * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(pt, 1.5, Paint()..color = copperLight.withValues(alpha: alpha * 0.9));
    }
  }

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
  bool shouldRepaint(_CopperCablePainter old) => old.progress != progress || old.active != active;
}

// ═══════════════════════════════════════════════════════════════════════
//  MINI KNOB PAINTER
// ═══════════════════════════════════════════════════════════════════════

class _MiniKnobPainter extends CustomPainter {
  final double value;
  final Color color;

  _MiniKnobPainter({required this.value, required this.color});

  static const double _startAngle = 2.356;
  static const double _sweepAngle = 4.712;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Knob body - chrome-like gradient
    final isChrome = color.computeLuminance() > 0.4;
    final knobGrad = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.0,
      colors: isChrome
          ? [const Color(0xFFDDDDDD), const Color(0xFF888888), const Color(0xFF444444)]
          : [const Color(0xFF555555), const Color(0xFF1A1A1E), const Color(0xFF0A0A0E)],
    );
    canvas.drawCircle(center, radius, Paint()
      ..shader = knobGrad.createShader(Rect.fromCircle(center: center, radius: radius)));

    canvas.drawCircle(center, radius, Paint()
      ..color = const Color(0xFF666666).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // Indicator line
    final angle = _startAngle + _sweepAngle * value;
    final lineEnd = Offset(
      center.dx + (radius - 2) * math.cos(angle),
      center.dy + (radius - 2) * math.sin(angle),
    );
    canvas.drawLine(center, lineEnd, Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5..strokeCap = StrokeCap.round);

    canvas.drawCircle(center, 2, Paint()..color = const Color(0xFF444444));
  }

  @override
  bool shouldRepaint(_MiniKnobPainter old) => old.value != value || old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════
//  AMP GRILLE PAINTER
// ═══════════════════════════════════════════════════════════════════════

class _AmpGrillePainter extends CustomPainter {
  final Color color;
  final bool enabled;

  _AmpGrillePainter({required this.color, required this.enabled});

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    for (double y = 40; y < size.height - 50; y += 4) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), paint);
    }
  }

  @override
  bool shouldRepaint(_AmpGrillePainter old) => old.color != color || old.enabled != enabled;
}

// ═══════════════════════════════════════════════════════════════════════
//  SPEAKER GRILLE PAINTER
// ═══════════════════════════════════════════════════════════════════════

class _SpeakerGrillePainter extends CustomPainter {
  final bool enabled;
  final Color color;

  _SpeakerGrillePainter({required this.enabled, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(size.width, size.height) / 2 - 2;

    for (int i = 0; i < 6; i++) {
      final r = maxR * (i + 1) / 6;
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..color = enabled ? color.withValues(alpha: 0.08 + (i * 0.02)) : const Color(0xFF222222).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    canvas.drawCircle(Offset(cx, cy), maxR * 0.2,
      Paint()..color = enabled ? color.withValues(alpha: 0.1) : const Color(0xFF1A1A1A));
    canvas.drawCircle(Offset(cx, cy), maxR * 0.2, Paint()
      ..color = enabled ? color.withValues(alpha: 0.15) : const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke..strokeWidth = 1);

    if (enabled) {
      final dotPaint = Paint()..color = color.withValues(alpha: 0.05);
      for (double x = 4; x < size.width - 4; x += 6) {
        for (double y = 4; y < size.height - 4; y += 6) {
          final dx = x - cx;
          final dy = y - cy;
          if (dx * dx + dy * dy < maxR * maxR) {
            canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SpeakerGrillePainter old) => old.enabled != enabled || old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════
//  PREMIUM 3D KNOB PAINTER
// ═══════════════════════════════════════════════════════════════════════

class _PremiumKnobPainter extends CustomPainter {
  final double value;
  final Color color;

  _PremiumKnobPainter({required this.value, required this.color});

  static const double _startAngle = 2.356;
  static const double _sweepAngle = 4.712;
  static const int _tickCount = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 2;
    final knobRadius = outerRadius - 8;

    _drawTicks(canvas, center, outerRadius, knobRadius);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius - 4),
      _startAngle, _sweepAngle, false,
      Paint()..color = const Color(0xFF1A1A1A)..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round,
    );

    if (value > 0.005) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius - 4),
        _startAngle, _sweepAngle * value, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius - 4),
        _startAngle, _sweepAngle * value, false,
        Paint()..color = color.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 8.0..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    final knobGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3), radius: 1.0,
      colors: [const Color(0xFF484848), const Color(0xFF363636), const Color(0xFF2A2A2A), const Color(0xFF222222)],
      stops: const [0.0, 0.35, 0.7, 1.0],
    );

    canvas.drawCircle(center, knobRadius, Paint()
      ..shader = knobGradient.createShader(Rect.fromCircle(center: center, radius: knobRadius)));
    canvas.drawCircle(center, knobRadius, Paint()
      ..color = const Color(0xFF555555).withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1.0);
    canvas.drawCircle(center, knobRadius - 1, Paint()
      ..color = Colors.black.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    final angle = _startAngle + _sweepAngle * value;
    final lineStart = Offset(center.dx + 4 * math.cos(angle), center.dy + 4 * math.sin(angle));
    final lineEnd = Offset(center.dx + (knobRadius - 3) * math.cos(angle), center.dy + (knobRadius - 3) * math.sin(angle));

    canvas.drawLine(lineStart, lineEnd, Paint()
      ..color = Colors.black.withValues(alpha: 0.5)..strokeWidth = 4.0..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawLine(lineStart, lineEnd, Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    canvas.drawCircle(lineEnd, 2.0, Paint()..color = color.withValues(alpha: 0.9));

    final capGrad = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: [const Color(0xFF555555), const Color(0xFF333333)],
    );
    canvas.drawCircle(center, 4, Paint()
      ..shader = capGrad.createShader(Rect.fromCircle(center: center, radius: 4)));
  }

  void _drawTicks(Canvas canvas, Offset center, double outerR, double knobR) {
    final tickOuterR = outerR - 1;
    final tickInnerR = knobR + 4;

    for (int i = 0; i <= _tickCount; i++) {
      final t = i / _tickCount;
      final angle = _startAngle + _sweepAngle * t;
      final isActive = t <= value;
      final isMajor = i % 3 == 0;

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
  bool shouldRepaint(_PremiumKnobPainter old) => old.value != value || old.color != color;
}
