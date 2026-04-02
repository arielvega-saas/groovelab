import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';
import '../../core/theme.dart';

// ═══════════════════════════════════════════════════════════════════
//  MULTITRACK TAB (PROTOTYPE)
//  Live performance stem player & sequence launcher
// ═══════════════════════════════════════════════════════════════════

class MultitrackTab extends ConsumerStatefulWidget {
  const MultitrackTab({super.key});

  @override
  ConsumerState<MultitrackTab> createState() => _MultitrackTabState();
}

class _MultitrackTabState extends ConsumerState<MultitrackTab> {
  // Prototype State
  bool _isPlaying = false;
  double _playbackPosition = 0.35; // 35% through the song

  // Mock Stem levels and mutes
  final List<Map<String, dynamic>> _stems = [
    {'name': 'CLICK',   'level': 0.8, 'mute': false, 'solo': false, 'color': AppColors.warm},
    {'name': 'DRUMS',   'level': 0.9, 'mute': false, 'solo': false, 'color': AppColors.accent},
    {'name': 'BASS',    'level': 0.7, 'mute': false, 'solo': false, 'color': AppColors.accent2},
    {'name': 'GUITARS', 'level': 0.6, 'mute': true,  'solo': false, 'color': AppColors.danger},
    {'name': 'KEYS',    'level': 0.7, 'mute': false, 'solo': false, 'color': AppColors.warning},
    {'name': 'VOCALS',  'level': 0.8, 'mute': false, 'solo': true,  'color': AppColors.kick},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgDark,
      child: Column(
        children: [
          _buildSetlistHeader(),
          Expanded(
            flex: 2,
            child: _buildTimelineArea(),
          ),
          Expanded(
            flex: 3,
            child: _buildMixerArea(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  TOP: SETLIST & TRANSPORT
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSetlistHeader() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.bgDeepest,
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // Setlist Titles
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SETLIST', style: AppFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('Domingo PM', style: AppFonts.outfit(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 24),
          // Horizontal scrolling songs
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildSongCard('La Gloria de Dios', '72 BPM · Ab', isActive: true),
                _buildSongCard('Santo Por Siempre', '140 BPM · D'),
                _buildSongCard('Digno de Adorar', '68 BPM · G'),
              ],
            ),
          ),
          // Transport Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _transportBtn(Icons.skip_previous_rounded),
                const SizedBox(width: 8),
                _playButton(),
                const SizedBox(width: 8),
                _transportBtn(Icons.loop_rounded, isActive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongCard(String title, String subtitle, {bool isActive = false}) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: AppFonts.outfit(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppFonts.jetBrainsMono(
              fontSize: 9,
              color: isActive ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transportBtn(IconData icon, {bool isActive = false}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.accent.withValues(alpha: 0.2) : AppColors.bgPanel,
        border: Border.all(color: isActive ? AppColors.accent : AppColors.border),
      ),
      child: Icon(icon, color: isActive ? AppColors.accent : AppColors.textSecondary, size: 20),
    );
  }

  Widget _playButton() {
    return GestureDetector(
      onTap: () => setState(() => _isPlaying = !_isPlaying),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: _isPlaying
                ? [AppColors.danger, AppColors.danger.withValues(alpha: 0.7)]
                : [AppColors.accent, AppColors.accent2],
          ),
          boxShadow: [
            BoxShadow(
              color: (_isPlaying ? AppColors.danger : AppColors.accent).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            )
          ],
        ),
        child: Icon(
          _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          color: AppColors.bgDeepest,
          size: 32,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MIDDLE: TIMELINE & SECTIONS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTimelineArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Stack(
        children: [
          // Mock Waveform visual
          Positioned.fill(
            child: Row(
              children: [
                _buildSectionBox('Intro', const Color(0xFF00D4AA), 1.5, true),
                _buildSectionBox('Verso 1', const Color(0xFF4488AA), 2.5, false),
                _buildSectionBox('Coro', const Color(0xFFE0B840), 2.0, false),
                _buildSectionBox('Verso 2', const Color(0xFF4488AA), 2.5, false),
                _buildSectionBox('Coro', const Color(0xFFE0B840), 2.0, false),
                _buildSectionBox('Puente', const Color(0xFFD44A6A), 3.0, false),
                _buildSectionBox('Coro Final', const Color(0xFFE0B840), 2.5, false),
                _buildSectionBox('Outro', const Color(0xFF00D4AA), 1.5, false),
              ],
            ),
          ),
          // Glowing Playhead
          Positioned(
            left: MediaQuery.of(context).size.width * _playbackPosition,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.white, blurRadius: 8, spreadRadius: 1)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBox(String name, Color color, double flex, bool isCurrent) {
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border(right: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5))),
        ),
        child: Stack(
          children: [
            // Waveform mockup (using a simplified opacity block for prototype)
            Center(
              child: Container(
                height: 40,
                color: color.withValues(alpha: 0.4),
              ),
            ),
            // Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: color.withValues(alpha: 0.2),
                child: Text(
                  name.toUpperCase(),
                  style: AppFonts.jetBrainsMono(fontSize: 9, color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // Loop bracket mockup
            if (name.contains('Coro'))
              Positioned(
                top: 20,
                left: 4,
                child: Icon(Icons.keyboard_return_rounded, size: 12, color: color.withValues(alpha: 0.7)),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BOTTOM: MIXER V2
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildMixerArea() {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24, left: 16, right: 16),
      decoration: BoxDecoration(
        color: AppColors.bgDeepest,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, -10)),
        ],
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < _stems.length; i++)
            Expanded(child: _buildMixerChannel(i)),
          
          // Master Fader
          Container(width: 1, color: AppColors.borderLight, margin: const EdgeInsets.symmetric(horizontal: 8)),
          Expanded(
            child: _buildMixerChannel(-1, isMaster: true),
          ),
        ],
      ),
    );
  }

  Widget _buildMixerChannel(int index, {bool isMaster = false}) {
    final Map<String, dynamic> spec = isMaster
        ? {'name': 'MASTER', 'level': 0.85, 'mute': false, 'solo': false, 'color': Colors.white}
        : _stems[index];

    final isMuted = spec['mute'] as bool;
    final isSolo = spec['solo'] as bool;
    final lvl = spec['level'] as double;
    final color = spec['color'] as Color;

    return Column(
      children: [
        // Name
        Text(
          spec['name'],
          style: AppFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isMaster ? Colors.white : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Mute / Solo Buttons
        if (!isMaster)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _mixerButton('M', isMuted, AppColors.danger, () {
                setState(() => _stems[index]['mute'] = !isMuted);
                HapticFeedback.lightImpact();
              }),
              const SizedBox(width: 4),
              _mixerButton('S', isSolo, AppColors.warning, () {
                setState(() => _stems[index]['solo'] = !isSolo);
                HapticFeedback.lightImpact();
              }),
            ],
          )
        else
          const SizedBox(height: 28), // Spacer for Master
        
        const Spacer(),
        
        // Fader Track
        Expanded(
          flex: 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Fader Track Groove
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF222222)),
                  boxShadow: [
                    BoxShadow(color: Colors.white.withValues(alpha: 0.05), offset: const Offset(1, 1)),
                  ],
                ),
              ),
              // Level meter visual (mock)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 2,
                  height: 100 * lvl,
                  decoration: BoxDecoration(
                    color: (isMuted && !isMaster) ? Colors.transparent : color.withValues(alpha: 0.8),
                    boxShadow: [BoxShadow(color: color, blurRadius: 4)],
                  ),
                ),
              ),
              // Neumorphic Fader Cap (Hardware feel)
              Positioned(
                bottom: (200 * lvl) - 20, // Mock positioning mapping
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    // Mock interaction
                  },
                  child: Container(
                    width: 32,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF4A4A4A), Color(0xFF2A2A2A)],
                      ),
                      border: Border.all(color: const Color(0xFF555555), width: 1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 8, offset: const Offset(0, 4)),
                        BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 2, offset: const Offset(0, -1)),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 2,
                        decoration: BoxDecoration(
                          color: isMaster ? Colors.white : color,
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mixerButton(String label, bool active, Color activeColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.2) : AppColors.bgInput,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? activeColor : AppColors.border,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
            ? [BoxShadow(color: activeColor.withValues(alpha: 0.4), blurRadius: 4)]
            : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: active ? activeColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
