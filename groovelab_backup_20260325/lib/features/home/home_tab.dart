import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';

// ═══════════════════════════════════════════════════════════════════
//  HOME HUB — Compact professional music dashboard (no-scroll)
// ═══════════════════════════════════════════════════════════════════

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang    = ref.watch(langProvider);
    final bpm     = ref.watch(bpmProvider);
    final playing = ref.watch(playingProvider);
    final timeSig = ref.watch(timeSigProvider);

    final modules = _buildModules(lang, playing, bpm);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.of(context).padding.top;
          final bottomPadding = MediaQuery.of(context).padding.bottom;
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;

          // Heights for fixed elements
          const headerHeight = 40.0;
          const liveBarHeight = 28.0;
          const gridPadH = 16.0;
          const gridSpacing = 10.0;

          // Calculate available height for the grid
          final fixedHeight = topPadding + 12 // top safe area + spacing
              + headerHeight + 8             // header + gap
              + (playing ? liveBarHeight + 6 : 0) // live bar + gap
              + 8                            // gap before grid
              + bottomPadding + 12;          // bottom safe area + spacing

          final availableGridHeight = screenHeight - fixedHeight;
          final gridWidth = screenWidth - gridPadH * 2;

          // 3 rows, 3 columns
          final cardHeight = (availableGridHeight - gridSpacing * 2) / 3;
          // cardWidth available for future responsive breakpoints
          final clampedCardHeight = cardHeight.clamp(56.0, 120.0);

          return Column(
            children: [
              SizedBox(height: topPadding + 12),

              // ── Ultra-compact header ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: headerHeight,
                  child: Row(
                    children: [
                      Text(
                        'GRID',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'GrooveLab',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // BPM display when playing
                      if (playing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warm.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.warm.withValues(alpha: 0.40),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5, height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.warm,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.warm.withValues(alpha: 0.70),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$bpm',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warm,
                                ),
                              ),
                              Text(
                                ' BPM',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warm.withValues(alpha: 0.70),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Live status thin bar ──────────────────────────
              if (playing) ...[
                Container(
                  height: liveBarHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warm.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warm.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: AppColors.warm, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'PLAYING',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warm,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$bpm BPM  ${timeSig.label}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.60),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],

              // ── Module grid (3x3) ────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int row = 0; row < 3; row++) ...[
                        if (row > 0) SizedBox(height: gridSpacing),
                        Row(
                          children: [
                            for (int col = 0; col < 3; col++) ...[
                              if (col > 0) SizedBox(width: gridSpacing),
                              Expanded(
                                child: SizedBox(
                                  height: clampedCardHeight,
                                  child: _ModuleCard(
                                    module: modules[row * 3 + col],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(height: bottomPadding + 12),
            ],
          );
        },
      ),
    );
  }

  List<_ModuleData> _buildModules(String lang, bool playing, int bpm) {
    return [
      _ModuleData(
        name: lang == 'es' ? 'Metrónomo' : lang == 'pt' ? 'Metrônomo' : 'Metronome',
        icon: Icons.speed_rounded,
        color: AppColors.accent,
        tabIndex: 0,
        isLive: playing,
      ),
      _ModuleData(
        name: lang == 'es' ? 'Batería' : lang == 'pt' ? 'Bateria' : 'Drums',
        icon: Icons.view_week_rounded,
        color: AppColors.accent2,
        tabIndex: 1,
      ),
      _ModuleData(
        name: 'Pads',
        icon: Icons.grid_view_rounded,
        color: AppColors.warm,
        tabIndex: 4,
      ),
      _ModuleData(
        name: 'Looper',
        icon: Icons.autorenew_rounded,
        color: AppColors.clap,
        tabIndex: 3,
      ),
      _ModuleData(
        name: lang == 'es' ? 'Afinador' : lang == 'pt' ? 'Afinador' : 'Tuner',
        icon: Icons.graphic_eq_rounded,
        color: AppColors.accent2,
        tabIndex: 9,
      ),
      _ModuleData(
        name: lang == 'es' ? 'Biblioteca' : lang == 'pt' ? 'Biblioteca' : 'Library',
        icon: Icons.library_music_rounded,
        color: AppColors.proGold,
        tabIndex: 6,
      ),
      _ModuleData(
        name: lang == 'es' ? 'Práctica' : lang == 'pt' ? 'Prática' : 'Practice',
        icon: Icons.trending_up_rounded,
        color: AppColors.snare,
        tabIndex: 5,
      ),
      _ModuleData(
        name: 'Stats',
        icon: Icons.analytics_rounded,
        color: AppColors.accent,
        tabIndex: 7,
      ),
      _ModuleData(
        name: 'Pedalera',
        icon: Icons.cable_rounded,
        color: const Color(0xFFE84393),
        tabIndex: 11,
      ),
      _ModuleData(
        name: 'Song Lab',
        icon: Icons.library_music_rounded,
        color: const Color(0xFF74B9FF),
        tabIndex: 10,
      ),
      _ModuleData(
        name: lang == 'es' ? 'Grabar' : lang == 'pt' ? 'Gravar' : 'Record',
        icon: Icons.fiber_manual_record_rounded,
        color: AppColors.danger,
        tabIndex: 2,
      ),
    ];
  }
}

// ── Module data model ──────────────────────────────────────────────

class _ModuleData {
  final String name;
  final IconData icon;
  final Color color;
  final int tabIndex;
  final bool isLive;

  const _ModuleData({
    required this.name,
    required this.icon,
    required this.color,
    required this.tabIndex,
    this.isLive = false,
  });
}

// ── Module card — neumorphic compact card ──────────────────────────

class _ModuleCard extends ConsumerStatefulWidget {
  final _ModuleData module;
  const _ModuleCard({required this.module});

  @override
  ConsumerState<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends ConsumerState<_ModuleCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.05, end: 0.12).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    final c = m.color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.mediumImpact();
        ref.read(tabIndexProvider.notifier).state = m.tabIndex;
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (_, child) {
          final shadows = _pressed
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 3, offset: const Offset(1, 1), spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: const Color(0xFF303030),
                    blurRadius: 2, offset: const Offset(-1, -1), spreadRadius: -1,
                  ),
                ]
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.70),
                    blurRadius: 0, offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 6, offset: const Offset(1, 4),
                  ),
                  BoxShadow(
                    color: const Color(0xFF2A2A2A),
                    blurRadius: 4, offset: const Offset(-2, -2),
                  ),
                  BoxShadow(
                    color: c.withValues(alpha: _glowAnim.value * (m.isLive ? 1.5 : 0.7)),
                    blurRadius: m.isLive ? 18 : 12,
                    spreadRadius: -2,
                  ),
                ];

          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            transform: Matrix4.identity()
              ..translate(
                _pressed ? 0.5 : 0.0,
                _pressed ? 2.0 : 0.0,
              )
              ..scale(_pressed ? 0.95 : 1.0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _pressed
                    ? [
                        Color.lerp(const Color(0xFF141414), c, 0.05)!,
                        Color.lerp(const Color(0xFF0E0E0E), c, 0.02)!,
                      ]
                    : [
                        Color.lerp(const Color(0xFF1F1F1F), c, 0.07)!,
                        Color.lerp(const Color(0xFF151515), c, 0.03)!,
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border(
                top: BorderSide(
                  color: _pressed
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF2E2E2E),
                  width: 0.8,
                ),
                left: BorderSide(
                  color: _pressed
                      ? const Color(0xFF181818)
                      : const Color(0xFF282828),
                  width: 0.8,
                ),
                right: BorderSide(
                  color: _pressed ? const Color(0xFF222222) : const Color(0xFF111111),
                  width: 0.8,
                ),
                bottom: BorderSide(
                  color: _pressed
                      ? c.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.50),
                  width: _pressed ? 0.8 : 1.5,
                ),
              ),
              boxShadow: shadows,
            ),
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Top highlight sheen
              Positioned(
                top: 0, left: 0, right: 0, height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: _pressed ? 0.03 : 0.10),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Live glow ring for active modules
              if (m.isLive)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: c.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                  ),
                ),

              // Content: icon + name
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            c.withValues(alpha: 0.22),
                            c.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: c.withValues(alpha: 0.28),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.withValues(alpha: 0.20),
                            blurRadius: 8,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Icon(m.icon, color: c, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.name,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.88),
                        letterSpacing: -0.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}
