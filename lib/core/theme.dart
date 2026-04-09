import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_fonts.dart';

// ═══════════════════════════════════════════════════════════════
//  PRO AUDIO COLOR SYSTEM  — Neumorphic Studio Dark aesthetic
//
//  Surface (neumorphic panel)   : #212121  bgPanel
//  Inset   (dials, graphs)      : #1A1A1A  bgInset
//  LED / Active accent          : #00E5FF  Neon Cyan   ← high-visibility
//  Tuner / Graph lines          : #00FF11  Neon Green  ← semantic in-tune
//  Warm    (active/playing)     : #FF9500  iOS Orange
//  Danger  (recording/error)    : #FF3B30  iOS Red
//
//  Neumorphic shadow rule:
//    Raised — dark shadow (bottom-right) + lighter shadow (top-left)
//    Inset  — inverse offsets, pressed-in effect
// ═══════════════════════════════════════════════════════════════

class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────
  static const bgDeepest  = Color(0xFF0A0A0A); // near-black base
  static const bgDark     = Color(0xFF121212); // main scaffold
  static const bgCard     = Color(0xFF1E1E1E); // legacy card surfaces
  static const bgPanel    = Color(0xFF212121); // neumorphic raised surface
  static const bgInset    = Color(0xFF1A1A1A); // neumorphic inset / dials
  static const bgElevated = Color(0xFF252525); // elevated panels
  static const bgInput    = Color(0xFF2C2C2E); // inputs / step cells

  // ── Borders ──────────────────────────────────────────────────
  static const border      = Color(0xFF2A2A2A); // subtle neumorphic edge
  static const borderLight = Color(0xFF333333); // slightly more visible

  // ── Text ─────────────────────────────────────────────────────
  static const textPrimary   = Color(0xDEFFFFFF); // white 87%
  static const textSecondary = Color(0xFF8E8E93); // mid gray
  static const textMuted     = Color(0xFF636366); // tertiary gray

  // ── Brand Accents ─────────────────────────────────────────────
  /// Neon Cyan — LED indicators, active states, nav, interactive elements.
  static const accent     = Color(0xFF00E5FF);
  static const accentDim  = Color(0xFF00AACC);

  /// Neon Green — semantic "success / in-tune / graph lines / tight timing".
  static const accent2    = Color(0xFF00FF11);
  static const accent2Dim = Color(0xFF00CC0D);

  /// iOS Orange — active/playing state indicator (e.g. metronome running).
  static const warm    = Color(0xFFFF9500);
  static const warmDim = Color(0xFFCC7700);

  // ── Functional ────────────────────────────────────────────────
  static const danger  = Color(0xFFFF3B30); // Red
  static const warning = Color(0xFFFF9F0A); // Amber
  static const proGold    = Color(0xFFF59E0B);
  static const proOrange  = Color(0xFFFF9500); // alias warm

  // ── Backward-compat aliases (avoid breaking scattered refs) ──
  static const accent3 = Color(0xFFFF6B35);

  // ── Drum/Pad Track Colors ─────────────────────────────────────
  static const kick  = Color(0xFFFF6B35); // orange-red
  static const snare = Color(0xFF4FC3F7); // sky blue
  static const hihat = Color(0xFF00E5FF); // neon cyan (drum-specific)
  static const ride  = Color(0xFF00FF11); // neon green
  static const clap  = Color(0xFFE040FB); // purple
  static const bass  = Color(0xFFFFB020); // amber

  // ── Surface Gradients ─────────────────────────────────────────
  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF252525), Color(0xFF1E1E1E)],
  );
  static const elevatedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF272727), Color(0xFF1F1F1F)],
  );
  static const deepGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF121212), Color(0xFF0A0A0A)],
  );

  /// Glass shimmer overlay — white 6% at top fading to transparent.
  static const glassShimmer = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.center,
    colors: [Color(0x10FFFFFF), Color(0x00FFFFFF)],
  );

  /// Module-tinted card gradient — adds subtle color personality.
  static LinearGradient moduleGradient(Color tint) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(const Color(0xFF252525), tint, 0.06)!,
      Color.lerp(const Color(0xFF1E1E1E), tint, 0.03)!,
      Color.lerp(const Color(0xFF1A1A1A), tint, 0.08)!, // shelf light
    ],
    stops: const [0.0, 0.7, 1.0],
  );

  /// Radial accent glow — for active states, buttons, knobs.
  static RadialGradient accentGlow(Color color, {double intensity = 0.15}) =>
      RadialGradient(
        colors: [
          color.withValues(alpha: intensity),
          color.withValues(alpha: 0.0),
        ],
      );

  /// Premium metallic gradient — for knobs, pedal surfaces.
  static const metallicGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF3A3A3A),
      Color(0xFF2A2A2A),
      Color(0xFF222222),
      Color(0xFF1A1A1A),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  /// Chromatic edge highlight — used on premium interactive elements.
  static LinearGradient chromaticEdge(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      color.withValues(alpha: 0.30),
      Colors.transparent,
      color.withValues(alpha: 0.15),
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  // ── Neumorphic shadow helpers ─────────────────────────────────
  //
  //  CSS spec (exact match):
  //    .neumorphic-out  → box-shadow: 5px 5px 10px #181818, -5px -5px 10px #2a2a2a
  //                       border: 1px solid rgba(255,255,255,0.03)
  //    .neumorphic-in   → box-shadow: inset 3px 3px 6px #121212,
  //                                   inset -3px -3px 6px #2a2a2a
  //    .active LED glow → box-shadow: 0 0 8px rgba(0,229,255,0.6)

  /// Raised (extruded) surface — exact spec: 5px 5px 10px #181818, -5px -5px 10px #2a2a2a.
  /// Pass [scale] < 1 for smaller widgets; [glowColor] adds a LED halo.
  static List<BoxShadow> neumorphicRaised({
    double scale    = 1.0,
    Color? glowColor,
  }) => [
    // Dark shadow  — bottom-right
    BoxShadow(
      color:      const Color(0xFF181818),
      blurRadius: 10 * scale,
      offset:     Offset(5 * scale, 5 * scale),
    ),
    // Light shadow — top-left
    BoxShadow(
      color:      const Color(0xFF2A2A2A),
      blurRadius: 10 * scale,
      offset:     Offset(-5 * scale, -5 * scale),
    ),
    // Optional LED color glow (e.g. cyan when active)
    if (glowColor != null)
      BoxShadow(
        color:       glowColor.withValues(alpha: 0.22),
        blurRadius:  18 * scale,
        spreadRadius: -1,
      ),
  ];

  /// Inset (pressed) surface — exact spec: inset 3px 3px 6px #121212, inset -3px -3px 6px #2a2a2a.
  /// Flutter has no native `inset` shadows; we simulate with negative [spreadRadius].
  static List<BoxShadow> neumorphicInset({Color? glowColor}) => [
    // Dark inset — top-left (light source blocked)
    BoxShadow(
      color:        const Color(0xFF121212),
      blurRadius:   6,
      offset:       const Offset(3, 3),
      spreadRadius: -2,  // pulls shadow inside the bounds
    ),
    // Light inset — bottom-right (reflected ambient)
    BoxShadow(
      color:        const Color(0xFF2A2A2A),
      blurRadius:   6,
      offset:       const Offset(-3, -3),
      spreadRadius: -2,
    ),
    if (glowColor != null)
      BoxShadow(
        color:       glowColor.withValues(alpha: 0.60),
        blurRadius:  8,
        spreadRadius: -3,
      ),
  ];

  /// LED active glow — exact spec: 0 0 8px rgba(0,229,255,0.6).
  /// Use as an additional BoxShadow on active/lit elements.
  static BoxShadow ledGlow(Color color, {double intensity = 1.0}) => BoxShadow(
    color:      color.withValues(alpha: 0.60 * intensity),
    blurRadius: 8 * intensity,
    spreadRadius: 0,
  );

  /// Subtle white border for raised neumorphic surfaces — rgba(255,255,255,0.03).
  static const BorderSide neumorphicBorder = BorderSide(
    color: Color(0x08FFFFFF), // rgba(255,255,255,0.03) ≈ 0x08
    width: 1,
  );
}

/// Standardized spacing scale (multiples of 4).
class AppSpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double base = 16;
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 40;
}

/// Standardized border radius tokens.
class AppRadius {
  static const double xs  = 6;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
}

/// Min touch target & icon size tokens.
class AppSizes {
  static const double minTouch   = 44;
  static const double iconSm     = 18;
  static const double iconMd     = 22;
  static const double iconLg     = 28;
  static const double navTabWidth  = 58;
  static const double navBarHeight = 68;
}

/// Standardized animation durations and curves.
class AppAnimations {
  static const fast   = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 250);
  static const slow   = Duration(milliseconds: 400);
  static const pulse  = Duration(milliseconds: 800);
  static const breathe = Duration(milliseconds: 1400);

  static const springCurve = Curves.easeOutBack;
  static const smoothCurve = Curves.easeInOutCubic;
  static const snapCurve   = Curves.easeOutQuint;
  static const bounceCurve = Curves.elasticOut;
}

/// Module accent colors for home grid and section headers.
class ModuleColors {
  static const metronome = AppColors.accent;      // cyan
  static const drums     = AppColors.kick;         // orange-red
  static const pads      = Color(0xFF8B5CF6);      // purple
  static const looper    = AppColors.accent2;       // neon green
  static const tuner     = Color(0xFF06B6D4);       // teal
  static const library   = AppColors.warm;          // orange
  static const practice  = Color(0xFF10B981);       // emerald
  static const stats     = Color(0xFF3B82F6);       // blue
  static const pedalera  = Color(0xFFF43F5E);       // rose
  static const songLab   = Color(0xFFA855F7);       // violet
  static const record    = AppColors.danger;         // red
  static const playback  = Color(0xFF4A90F7);       // bright blue
}

/// Per-instrument color lookup for drum sequencer.
Color instrumentColor(String name) {
  switch (name.toLowerCase()) {
    case 'kick':  return AppColors.kick;
    case 'snare': return AppColors.snare;
    case 'hihat': return AppColors.hihat;
    case 'ride':  return AppColors.ride;
    case 'clap':  return AppColors.clap;
    case 'bass':  return AppColors.bass;
    default:      return AppColors.accent;
  }
}

/// Per-instrument icon for drum sequencer.
IconData instrumentIcon(String name) {
  switch (name.toLowerCase()) {
    case 'kick':  return Icons.circle;
    case 'snare': return Icons.radio_button_unchecked;
    case 'hihat': return Icons.close;
    case 'ride':  return Icons.album_outlined;
    case 'clap':  return Icons.back_hand_outlined;
    case 'bass':  return Icons.waves;
    default:      return Icons.music_note;
  }
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.accent,
        secondary: AppColors.accent2,
        surface:   AppColors.bgCard,
        error:     AppColors.danger,
      ),
      textTheme: AppFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: AppColors.textPrimary),
          displayMedium: TextStyle(color: AppColors.textPrimary),
          bodyLarge:    TextStyle(color: AppColors.textPrimary),
          bodyMedium:   TextStyle(color: AppColors.textSecondary),
          bodySmall:    TextStyle(color: AppColors.textMuted),
          labelLarge:   TextStyle(color: AppColors.textPrimary),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDeepest,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        shadowColor: Colors.black,
        elevation: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.accent : AppColors.bgInput),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgDeepest,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
      ),
    );
  }

  static TextStyle monoStyle({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.textPrimary,
  }) {
    return AppFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  GLASS CARD DECORATION  — deeper elevation, true dark surface
  // ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════
  //  NEUMORPHIC SECTION CARD — .neumorphic-out equivalent
  //  CSS: background bgPanel, shadow 5px/#181818 + -5px/#2a2a2a,
  //       border 1px solid rgba(255,255,255,0.03)
  // ═══════════════════════════════════════════════════════════════

  static BoxDecoration glassCard({
    Color? borderColor,
    double borderWidth = 1,
    double radius = 16,
    Color? glowColor,
    Color? bgColor,
  }) {
    return BoxDecoration(
      color: bgColor ?? AppColors.bgPanel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        // Spec: border 1px solid rgba(255,255,255,0.03)
        color: borderColor ?? const Color(0x08FFFFFF),
        width: borderWidth,
      ),
      boxShadow: AppColors.neumorphicRaised(glowColor: glowColor),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PREMIUM GLASS CARD — with shimmer overlay
  // ═══════════════════════════════════════════════════════════════

  /// Glass card with optional top-edge shimmer for premium feel.
  static BoxDecoration premiumGlassCard({
    Color? borderColor,
    double radius = 16,
    Color? glowColor,
    Color? tint,
  }) {
    return BoxDecoration(
      gradient: tint != null ? AppColors.moduleGradient(tint) : AppColors.cardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? const Color(0x0CFFFFFF),
        width: 1,
      ),
      boxShadow: [
        ...AppColors.neumorphicRaised(glowColor: glowColor),
        // Subtle inner light — simulates glass edge catch
        const BoxShadow(
          color: Color(0x08FFFFFF),
          blurRadius: 1,
          offset: Offset(0, -1),
          spreadRadius: 0,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  NEUMORPHIC INSET PANEL — .neumorphic-in equivalent
  //  CSS: background bgInset, inset 3px/#121212, inset -3px/#2a2a2a
  // ═══════════════════════════════════════════════════════════════

  /// Inset panel — for LCD displays, graph backgrounds, pressed inputs.
  static BoxDecoration insetPanel({
    double radius = 12,
    Color? borderColor,
    Color? glowColor,
  }) {
    return BoxDecoration(
      color: AppColors.bgInset,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? const Color(0x08FFFFFF),
        width: 1,
      ),
      boxShadow: AppColors.neumorphicInset(glowColor: glowColor),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  NEUMORPHIC CIRCLE — raised circular surface
  // ═══════════════════════════════════════════════════════════════

  /// Raised neumorphic circle (knobs, pads, circular buttons).
  static BoxDecoration neumorphicCircle({
    Color? color,
    Color? glowColor,
    bool inset = false,
  }) {
    return BoxDecoration(
      shape: BoxShape.circle,
      color: inset ? AppColors.bgInset : (color ?? AppColors.bgPanel),
      border: const Border.fromBorderSide(AppColors.neumorphicBorder),
      boxShadow: inset
          ? AppColors.neumorphicInset(glowColor: glowColor)
          : AppColors.neumorphicRaised(glowColor: glowColor),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LED TEXT STYLE — JetBrains Mono + 0 0 8px glow shadow
  //  CSS: color --pro-accent-blue; text-shadow 0 0 8px rgba(0,229,255,0.6)
  // ═══════════════════════════════════════════════════════════════

  /// Monospace LCD-style text with optional neon glow (matches CSS text-shadow spec).
  static TextStyle lcdStyle({
    double size   = 14,
    FontWeight weight = FontWeight.w700,
    Color color   = AppColors.accent,
    bool glow     = true,
    double glowAlpha = 0.60,
  }) {
    return AppFonts.jetBrainsMono(
      fontSize:   size,
      fontWeight: weight,
      color:      color,
      shadows: glow ? [
        // CSS spec: text-shadow 0 0 8px rgba(0,229,255,0.6)
        Shadow(color: color.withValues(alpha: glowAlpha), blurRadius: 8),
        Shadow(color: color.withValues(alpha: glowAlpha * 0.4), blurRadius: 20),
      ] : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PREMIUM PANEL with section title
  // ═══════════════════════════════════════════════════════════════

  static Widget premiumPanel({
    required String title,
    required Widget content,
    Color? accentColor,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    final col = accentColor ?? AppColors.textMuted;
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      decoration: glassCard(
        glowColor: accentColor,
        borderColor: accentColor != null
            ? accentColor.withValues(alpha: 0.20)
            : AppColors.borderLight.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: padding != null
                ? EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0)
                : const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 3, height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: col,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(color: col.withValues(alpha: 0.45), blurRadius: 6),
                    ],
                  ),
                ),
                Text(title, style: AppFonts.outfit(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: col, letterSpacing: 1.8,
                )),
              ],
            ),
          ),
          Container(
            margin: padding != null
                ? EdgeInsets.fromLTRB(padding.left, 10, padding.right, padding.bottom)
                : const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: content,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PREMIUM CHIP
  // ═══════════════════════════════════════════════════════════════

  static Widget chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color activeColor = AppColors.accent,
    double fontSize = 12,
    EdgeInsets? padding,
    IconData? icon,
  }) {
    final bg = active
        ? activeColor.withValues(alpha: 0.35)
        : const Color(0xFF1E1E1E);
    final border = active
        ? activeColor
        : const Color(0xFF333333);
    final textColor = active ? Colors.white : AppColors.textSecondary;

    final radius = BorderRadius.circular(AppRadius.sm);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: activeColor.withValues(alpha: 0.25),
        highlightColor: activeColor.withValues(alpha: 0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: border, width: active ? 1.5 : 0.8),
            boxShadow: active
                ? [BoxShadow(color: activeColor.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: -2)]
                : [const BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: textColor),
                  const SizedBox(width: 5),
                ],
                Text(label, style: AppFonts.outfit(
                  fontSize: fontSize,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: textColor,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PREMIUM SECTION HEADER
  // ═══════════════════════════════════════════════════════════════

  static Widget sectionHeader(String title, {Color? color, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color ?? AppColors.textMuted),
            const SizedBox(width: 6),
          ],
          Text(title, style: AppFonts.outfit(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: color ?? AppColors.textMuted,
            letterSpacing: 1.8,
          )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  NEUMORPHIC SLIDER THEME + PREMIUM SLIDER
  //  Track: inset groove (#1A1A1A) with neon active fill + glow
  //  Thumb: raised neumorphic fader cap with center LED stripe
  // ═══════════════════════════════════════════════════════════════

  /// Drop-in neumorphic SliderThemeData.
  /// Usage: `SliderTheme(data: AppTheme.neumorphicSliderTheme(color), child: Slider(...))`
  static SliderThemeData neumorphicSliderTheme(
    Color color, {
    double grooveHeight = 5,
    double thumbRadius = 10,
  }) {
    return SliderThemeData(
      trackShape: _NeuTrackShape(activeColor: color, grooveHeight: grooveHeight),
      thumbShape: _NeuThumbShape(color: color, radius: thumbRadius),
      overlayColor: color.withValues(alpha: 0.08),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
      activeTrackColor: color,
      inactiveTrackColor: Colors.transparent,
      thumbColor: color,
      trackHeight: grooveHeight,
    );
  }

  static Widget premiumSlider({
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 1,
    Color color = AppColors.accent,
    String? label,
    String? valueText,
    int? divisions,
  }) {
    return Column(
      children: [
        if (label != null || valueText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(label, style: AppFonts.outfit(
                    fontSize: 11, color: AppColors.textMuted,
                  )),
                if (valueText != null)
                  Text(valueText, style: monoStyle(
                    size: 11, color: color, weight: FontWeight.w600,
                  )),
              ],
            ),
          ),
        SliderTheme(
          data: neumorphicSliderTheme(color),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PRO TRANSPORT BUTTON
  //  ▸ Idle    → .neumorphic-out  (raised, spec shadows)
  //  ▸ Playing → .neumorphic-in + LED orange glow (.btn-neumorphic.active)
  // ═══════════════════════════════════════════════════════════════

  // transportButton now delegates to HardwareTransportButton for full physics.
  static Widget transportButton({
    required bool isPlaying,
    required VoidCallback onTap,
    double size = 60,
    double pulseValue = 0,
  }) {
    return HardwareTransportButton(
      isPlaying: isPlaying,
      onTap: onTap,
      size: size,
      pulseValue: pulseValue,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PREMIUM BPM STEP BUTTON (-5 / -1 / +1 / +5)
  // ═══════════════════════════════════════════════════════════════

  static Widget bpmStepButton({
    required String label,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: HardwareButton(
        onTap: onTap,
        borderRadius: AppRadius.sm,
        elevation: 0.75,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 7 : 9,
        ),
        child: Text(label, style: monoStyle(
          size: compact ? 11 : 12,
          color: AppColors.textSecondary,
          weight: FontWeight.w500,
        )),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DRUM STEP CELL
  // ═══════════════════════════════════════════════════════════════

  static Widget drumStepCell({
    required bool isOn,
    required bool isPlayhead,
    required bool isBeatBoundary,
    required Color trackColor,
    required VoidCallback onTap,
    double height = 34,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.snapCurve,
        height: height,
        margin: EdgeInsets.only(
          left: isBeatBoundary ? 3 : 1,
          right: 1,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          // LED-lit radial gradient when active
          gradient: isOn
              ? RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    isPlayhead ? trackColor : trackColor.withValues(alpha: 0.85),
                    isPlayhead
                        ? trackColor.withValues(alpha: 0.7)
                        : trackColor.withValues(alpha: 0.5),
                  ],
                )
              : null,
          color: isOn ? null : (isPlayhead ? AppColors.bgElevated : AppColors.bgPanel),
          border: Border.all(
            color: isOn
                ? trackColor.withValues(alpha: isPlayhead ? 1 : 0.6)
                : isPlayhead
                    ? AppColors.accent.withValues(alpha: 0.50)
                    : AppColors.border.withValues(alpha: 0.40),
            width: isPlayhead ? 1.5 : 0.6,
          ),
          boxShadow: [
            if (isOn) ...[
              BoxShadow(
                color: trackColor.withValues(alpha: isPlayhead ? 0.65 : 0.30),
                blurRadius: isPlayhead ? 14 : 6,
                spreadRadius: isPlayhead ? 2 : 0,
              ),
              // Inner glow for lit LED effect
              BoxShadow(
                color: trackColor.withValues(alpha: 0.15),
                blurRadius: 2,
                spreadRadius: -1,
              ),
            ],
            if (!isOn && isPlayhead)
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.15),
                blurRadius: 10,
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STATUS INDICATOR DOT
  // ═══════════════════════════════════════════════════════════════

  static Widget statusDot({
    required Color color,
    double size = 8,
    bool glow = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow ? [
          BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: 10, spreadRadius: 1),
        ] : null,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PREMIUM DIVIDER
  // ═══════════════════════════════════════════════════════════════

  static Widget premiumDivider({EdgeInsets? margin}) {
    return Container(
      height: 1,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, AppColors.borderLight, Colors.transparent],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACCENT BADGE
  // ═══════════════════════════════════════════════════════════════

  static Widget accentBadge(String text, {Color color = AppColors.accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.38), width: 0.8),
      ),
      child: Text(text, style: AppFonts.outfit(
        fontSize: 10, fontWeight: FontWeight.w600,
        color: color, letterSpacing: 0.5,
      )),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PREMIUM ICON BUTTON
  // ═══════════════════════════════════════════════════════════════

  static Widget iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    Color? bgColor,
    double size = 18,
    double padding = 8,
    bool active = false,
    Color activeColor = AppColors.accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: active
              ? activeColor.withValues(alpha: 0.10)
              : (bgColor ?? AppColors.bgPanel),
          border: Border.all(
            color: active ? activeColor.withValues(alpha: 0.50) : const Color(0x08FFFFFF),
            width: 1,
          ),
          boxShadow: active
              ? AppColors.neumorphicInset(glowColor: activeColor)
              : AppColors.neumorphicRaised(scale: 0.7),
        ),
        child: Icon(icon, size: size,
          color: active ? activeColor : (color ?? AppColors.textSecondary)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PRO CONTROL BUTTON  — circular, dark, single-color icon
  //  Used for secondary controls (tap tempo, loop, etc.)
  // ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════
  //  PRO CONTROL BUTTON — circular, neumorphic
  //  ▸ Idle   → .neumorphic-out (spec shadows)
  //  ▸ Active → .neumorphic-in + LED glow (.btn-neumorphic.active)
  // ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════
  //  LOGIC PRO STYLE CHANNEL STRIP
  //  Vertical fader · dB scale · M/S buttons · pan mini-slider
  //  Inspired by Logic Pro / MainStage mixer channel aesthetics
  // ═══════════════════════════════════════════════════════════════

  /// Converts a 0–1 linear volume to a dB string (e.g. "-6.0", "-∞").
  static String _volToDb(double vol) {
    if (vol <= 0) return '-∞';
    final db = 20 * math.log(vol) / math.ln10;
    return db >= 0 ? '+${db.toStringAsFixed(1)}' : db.toStringAsFixed(1);
  }

  /// Logic Pro / MainStage style M or S button (mute / solo).
  static Widget _logicMsBtn(
      String label, bool active, Color activeColor, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 24,
        height: 17,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: active ? activeColor : const Color(0xFF333333),
          border: Border.all(
            color: active ? activeColor : const Color(0xFF484848),
            width: 0.8,
          ),
          boxShadow: active
              ? [BoxShadow(color: activeColor.withValues(alpha: 0.42), blurRadius: 6)]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppFonts.outfit(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: active
                  ? (label == 'S' ? Colors.black : Colors.white)
                  : const Color(0xFF777777),
            ),
          ),
        ),
      ),
    );
  }

  /// Full Logic Pro / MainStage channel strip widget.
  ///
  /// Parameters:
  /// - [color]          — track accent color (shown in top bar + active fader)
  /// - [name]           — track / layer name
  /// - [volume]         — 0.0 … 1.0
  /// - [onVolume]       — volume change callback (null = disabled)
  /// - [pan]            — -1.0 … 1.0 (omit to hide pan row)
  /// - [onPan]          — pan change callback (null = hide pan slider)
  /// - [muted] / [solo] — state flags
  /// - [isRecording]    — shows red accent bar + REC badge
  /// - [waveformWidget] — optional compact waveform (drawn at 30 px height)
  /// - [statusBadge]    — optional extra widget below name
  /// - [faderHeight]    — height of the vertical fader section
  /// - [stripWidth]     — total channel width (default 68)
  static Widget logicChannelStrip({
    required Color color,
    required String name,
    required double volume,
    required ValueChanged<double>? onVolume,
    double pan = 0.0,
    ValueChanged<double>? onPan,
    bool muted = false,
    bool solo = false,
    bool isRecording = false,
    VoidCallback? onMute,
    VoidCallback? onSolo,
    IconData? trackIcon,
    Widget? waveformWidget,
    Widget? statusBadge,
    double faderHeight = 140,
    double stripWidth = 68,
    GestureTapCallback? onTap,
    GestureTapCallback? onDoubleTap,
  }) {
    const channelBg     = Color(0xFF252525);
    const mutedBg       = Color(0xFF1D1D1D);
    const borderColor   = Color(0xFF3C3C3C);
    const labelColor    = Color(0xFF666666);
    const valueColor    = Color(0xFFAAAAAA);

    final activeColor   = muted ? const Color(0xFF555555) : color;
    final dbStr         = _volToDb(volume);
    final panStr        = pan == 0 ? 'C'
        : pan < 0 ? 'L${(-pan * 100).round()}'
        : 'R${(pan * 100).round()}';

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        width: stripWidth,
        decoration: BoxDecoration(
          color: muted ? mutedBg : channelBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isRecording
                ? AppColors.danger.withValues(alpha: 0.55)
                : solo
                    ? const Color(0xFFFFDC00).withValues(alpha: 0.50)
                    : borderColor,
            width: isRecording || solo ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Accent bar (color / recording) ────────────────────
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: isRecording
                    ? AppColors.danger
                    : muted ? const Color(0xFF404040) : color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                boxShadow: (muted || isRecording)
                    ? null
                    : [BoxShadow(color: color.withValues(alpha: 0.50), blurRadius: 8)],
              ),
            ),

            // ── Icon + Name ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
              child: Column(
                children: [
                  if (trackIcon != null)
                    Icon(trackIcon, size: 13,
                        color: muted ? labelColor : activeColor.withValues(alpha: 0.85)),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: AppFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: muted ? labelColor : valueColor),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                  if (statusBadge != null) statusBadge,
                ],
              ),
            ),

            // ── Compact waveform (optional) ───────────────────────
            if (waveformWidget != null) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(height: 28, child: waveformWidget),
                ),
              ),
            ],

            const SizedBox(height: 6),

            // ── Pan row ───────────────────────────────────────────
            Text('PAN',
                style: AppFonts.outfit(
                    fontSize: 7,
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
            Text(panStr,
                style: AppFonts.jetBrainsMono(fontSize: 8, color: valueColor)),
            if (onPan != null)
              SizedBox(
                height: 20,
                child: SliderTheme(
                  data: neumorphicSliderTheme(activeColor,
                      grooveHeight: 2, thumbRadius: 5),
                  child: Slider(
                    value: (pan.clamp(-1.0, 1.0) + 1) / 2,
                    onChanged:
                        muted ? null : (v) => onPan!((v * 2) - 1),
                  ),
                ),
              )
            else
              const SizedBox(height: 4),

            const SizedBox(height: 3),

            // ── dB readout ────────────────────────────────────────
            Text(
              dbStr,
              style: AppFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: muted
                    ? labelColor
                    : (volume > 0.87
                        ? AppColors.danger
                        : volume > 0.65
                            ? AppColors.warm
                            : activeColor),
              ),
            ),
            Text('dB',
                style: AppFonts.outfit(fontSize: 7, color: labelColor)),

            const SizedBox(height: 5),

            // ── Vertical fader + dB scale ─────────────────────────
            SizedBox(
              height: faderHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // dB tick marks
                  CustomPaint(
                    size: Size(17, faderHeight),
                    painter: _DbScalePainter(height: faderHeight),
                  ),
                  // Rotated horizontal slider → vertical fader
                  SizedBox(
                    width: stripWidth - 23,
                    height: faderHeight,
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: SizedBox(
                        width: faderHeight,
                        child: SliderTheme(
                          data: neumorphicSliderTheme(
                            muted ? AppColors.textMuted : color,
                            grooveHeight: 4,
                            thumbRadius: 8,
                          ),
                          child: Slider(
                            value: volume,
                            onChanged: muted ? null : onVolume,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── M / S buttons ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _logicMsBtn('M', muted, AppColors.warm, onMute),
                const SizedBox(width: 3),
                _logicMsBtn('S', solo, const Color(0xFFFFDC00), onSolo),
              ],
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Widget controlButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 50,
    Color? activeColor,
    bool active = false,
    bool danger = false,
  }) {
    final ledColor = danger
        ? AppColors.danger
        : active ? (activeColor ?? AppColors.accent) : null;

    // Shadows: inset when active, raised when idle
    final shadows = active || danger
        ? AppColors.neumorphicInset(glowColor: ledColor)
        : AppColors.neumorphicRaised(scale: 0.85);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgPanel,
          border: const Border.fromBorderSide(AppColors.neumorphicBorder),
          boxShadow: shadows,
        ),
        child: Center(
          child: Icon(
            icon,
            size: size * 0.42,
            color: ledColor ?? AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  NEUMORPHIC SLIDER SHAPES — private helpers for AppTheme
// ═══════════════════════════════════════════════════════════════

/// Inset track groove with neon active fill + subtle glow halo.
class _NeuTrackShape extends SliderTrackShape {
  final Color activeColor;
  final double grooveHeight;

  const _NeuTrackShape({required this.activeColor, this.grooveHeight = 5});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackTop = offset.dy + (parentBox.size.height - grooveHeight) / 2;
    return Rect.fromLTWH(offset.dx, trackTop, parentBox.size.width, grooveHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final canvas = context.canvas;
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
    );
    final rrRadius = Radius.circular(grooveHeight / 2);
    final rrFull = RRect.fromRectAndRadius(rect, rrRadius);

    // ── 1. Groove background (bgInset) ──────────────────────────
    canvas.drawRRect(rrFull, Paint()..color = const Color(0xFF1A1A1A));

    // ── 2. Inset bevel effect (clip so edges stay rounded) ──────
    canvas.save();
    canvas.clipRRect(rrFull);
    // Dark top-edge shadow
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, 1.5),
      Paint()..color = const Color(0xFF0D0D0D),
    );
    // Lighter bottom-edge ambient
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.bottom - 1.5, rect.width, 1.5),
      Paint()..color = const Color(0xFF2E2E2E),
    );
    canvas.restore();

    // ── 3. Active fill (left → thumb) with glow ─────────────────
    final activeRight = thumbCenter.dx.clamp(rect.left, rect.right);
    if (activeRight > rect.left + 1) {
      final activeRect = Rect.fromLTRB(rect.left, rect.top, activeRight, rect.bottom);

      // Soft glow halo behind the fill
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect.inflate(2.5), rrRadius),
        Paint()
          ..color = activeColor.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );

      // Gradient fill (dimmer at origin → brighter near thumb)
      canvas.save();
      canvas.clipRRect(rrFull);
      canvas.drawRect(
        activeRect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              activeColor.withValues(alpha: 0.30),
              activeColor.withValues(alpha: 0.72),
            ],
          ).createShader(activeRect),
      );
      canvas.restore();
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  DB SCALE PAINTER — Logic Pro / MainStage tick marks
// ═══════════════════════════════════════════════════════════════

/// Paints Logic Pro-style dB scale tick marks beside a vertical fader.
/// The fader travels top (1.0 = 0 dB) → bottom (0.0 = -∞).
class _DbScalePainter extends CustomPainter {
  final double height;
  const _DbScalePainter({required this.height});

  // (linearValue 0-1, label) — same marks used by Logic Pro channel strips
  static const List<(double, String)> _marks = [
    (1.000, '0'),
    (0.708, '-3'),
    (0.501, '-6'),
    (0.251, '-12'),
    (0.100, '-20'),
    (0.032, '-30'),
    (0.000, '∞'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const tickColor = Color(0xFF484848);
    const textColor = Color(0xFF555555);
    // Approximate thumb-padding Flutter's Slider adds (thumbRadius ≈ 8 + padding)
    const pad = 13.0;
    final travel = height - 2 * pad;

    for (final (value, label) in _marks) {
      final y = pad + (1.0 - value) * travel;

      // Tick mark on the right edge
      canvas.drawLine(
        Offset(size.width - 5, y),
        Offset(size.width, y),
        Paint()
          ..color = tickColor
          ..strokeWidth = 0.8,
      );

      // Numeric label, right-aligned
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 6.0,
            color: textColor,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 6);
      tp.paint(
        canvas,
        Offset(size.width - tp.width - 7, y - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_DbScalePainter old) => old.height != height;
}

/// Raised neumorphic fader cap with a center LED indicator stripe.
class _NeuThumbShape extends SliderComponentShape {
  final Color color;
  final double radius;

  const _NeuThumbShape({required this.color, this.radius = 10});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Fader cap: taller-than-wide capsule (hardware fader aesthetics)
    final w = radius * 1.65;
    final h = radius * 2.7;
    final capRect = Rect.fromCenter(center: center, width: w, height: h);
    final capRR = RRect.fromRectAndRadius(capRect, Radius.circular(w * 0.28));

    // ── Neumorphic raised shadows ────────────────────────────────
    // Dark shadow — bottom-right
    canvas.drawRRect(
      capRR.shift(const Offset(2.5, 2.5)),
      Paint()
        ..color = const Color(0xFF181818)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Light shadow — top-left
    canvas.drawRRect(
      capRR.shift(const Offset(-2.5, -2.5)),
      Paint()
        ..color = const Color(0xFF2E2E2E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── Fader cap body: subtle gradient (lighter top → darker bottom) ──
    canvas.drawRRect(
      capRR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2C2C), Color(0xFF1D1D1D)],
        ).createShader(capRect),
    );

    // ── White neumorphic border (spec: rgba(255,255,255,0.06)) ───
    canvas.drawRRect(
      capRR,
      Paint()
        ..color = const Color(0x0FFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Grip ridges (subtle texture lines above/below center) ────
    for (final dy in [-h * 0.20, h * 0.20]) {
      canvas.drawLine(
        Offset(center.dx - w * 0.30, center.dy + dy),
        Offset(center.dx + w * 0.30, center.dy + dy),
        Paint()
          ..color = const Color(0xFF2D2D2D)
          ..strokeWidth = 0.9,
      );
    }

    // ── Center LED indicator: glow + core line ───────────────────
    final ledLeft  = center.dx - w * 0.40;
    final ledRight = center.dx + w * 0.40;

    // Outer glow
    canvas.drawLine(
      Offset(ledLeft, center.dy),
      Offset(ledRight, center.dy),
      Paint()
        ..color = color.withValues(alpha: 0.50)
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Core LED stripe
    canvas.drawLine(
      Offset(ledLeft, center.dy),
      Offset(ledRight, center.dy),
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//
//  ██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗    ██╗ █████╗ ██████╗ ███████╗
//  ██║  ██║██╔══██╗██╔══██╗██╔══██╗██║    ██║██╔══██╗██╔══██╗██╔════╝
//  ███████║███████║██████╔╝██║  ██║██║ █╗ ██║███████║██████╔╝█████╗
//  ██╔══██║██╔══██║██╔══██╗██║  ██║██║███╗██║██╔══██║██╔══██╗██╔══╝
//  ██║  ██║██║  ██║██║  ██║██████╔╝╚███╔███╔╝██║  ██║██║  ██║███████╗
//  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
//
//  HARDWARE BUTTON SYSTEM — Expert 1 & 3 Implementation
//
//  Design Reference: Logic Pro, Moog Model 15, Soundbrenner
//  Physics: onTapDown → scale 0.94 + Y+2px + shadow inversion (80ms easeIn)
//           onTapUp   → spring back 1.0 + Y 0 (400ms elasticOut)
//  Surface: Radial gradient (lighter center-top) + specular sheen arc
//  Border:  Beveled — top 0x30FFFFFF, bottom 0x90000000
//  States:  idle / pressed / active (LED glow) / disabled
//
// ═══════════════════════════════════════════════════════════════════════════

/// General-purpose hardware-style pressable button.
/// Wraps any child with physical press physics: scale + Y-translate + shadow inversion.
///
/// Usage:
/// ```dart
/// HardwareButton(
///   onTap: () { ... },
///   glowColor: AppColors.accent,
///   isActive: true,
///   child: Text('PLAY'),
/// )
/// ```
class HardwareButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color surfaceColor;
  final Color? glowColor;
  final bool isActive;
  final bool isDisabled;
  final double borderRadius;
  final EdgeInsets padding;
  final bool circle;
  final double? width;
  final double? height;
  final double elevation;

  const HardwareButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.surfaceColor = AppColors.bgPanel,
    this.glowColor,
    this.isActive = false,
    this.isDisabled = false,
    this.borderRadius = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.circle = false,
    this.width,
    this.height,
    this.elevation = 1.0,
  });

  @override
  State<HardwareButton> createState() => _HardwareButtonState();
}

class _HardwareButtonState extends State<HardwareButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _pressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (widget.isDisabled) return;
    _ctrl.animateTo(1.0, duration: const Duration(milliseconds: 70), curve: Curves.easeIn);
  }

  void _up(TapUpDetails _) {
    if (widget.isDisabled) return;
    _ctrl.animateTo(0.0, duration: const Duration(milliseconds: 380), curve: Curves.elasticOut);
    widget.onTap?.call();
  }

  void _cancel() {
    _ctrl.animateTo(0.0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor ?? AppColors.accent;
    final active = widget.isActive;

    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (_, child) {
          final p = _pressAnim.value;
          return Transform.translate(
            offset: Offset(0, p * 2.5),
            child: Transform.scale(
              scale: 1.0 - p * 0.045,
              child: _buildSurface(p, glow, active, child!),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }

  Widget _buildSurface(double p, Color glow, bool active, Widget content) {
    // Gradient: pressed = dark flat, idle = lighter-top gradient
    final gradient = p > 0.5
        ? LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: active
                ? [Color.lerp(const Color(0xFF1A1A1A), glow, 0.35)!, Color.lerp(const Color(0xFF181818), glow, 0.20)!]
                : [const Color(0xFF1A1A1A), const Color(0xFF181818)],
          )
        : LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: active
                ? [Color.lerp(const Color(0xFF2A2A2A), glow, 0.30)!, Color.lerp(const Color(0xFF1E1E1E), glow, 0.18)!]
                : [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)],
          );

    // Shadows: raised → inset as p increases
    final raisedShadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.75 * widget.elevation),
        blurRadius: 0, offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.45 * widget.elevation),
        blurRadius: 8, offset: const Offset(2, 6),
      ),
      BoxShadow(
        color: const Color(0xFF2E2E2E).withValues(alpha: 0.8 * widget.elevation),
        blurRadius: 6, offset: const Offset(-2, -2),
      ),
      if (active)
        BoxShadow(color: glow.withValues(alpha: 0.70), blurRadius: 20, spreadRadius: -1),
      if (!active)
        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, spreadRadius: -3),
    ];

    final insetShadows = [
      BoxShadow(color: Colors.black.withValues(alpha: 0.65), blurRadius: 5, offset: const Offset(2, 2)),
      BoxShadow(color: const Color(0xFF303030).withValues(alpha: 0.70), blurRadius: 4, offset: const Offset(-1, -1)),
    ];

    final shadows = p > 0.5 ? insetShadows : raisedShadows;

    // Beveled border: lighter top, darker bottom
    final border = widget.circle
        ? Border.all(
            color: p > 0.5
                ? Colors.black38
                : const Color(0x18FFFFFF),
            width: 1,
          )
        : active
            ? Border.all(color: glow.withValues(alpha: 0.85), width: 1.5)
            : Border(
                top: BorderSide(
                  color: p > 0.5 ? Colors.black38 : const Color(0x20FFFFFF),
                  width: 1,
                ),
                left: BorderSide(
                  color: p > 0.5 ? Colors.black26 : const Color(0x12FFFFFF),
                  width: 1,
                ),
                right: BorderSide(color: Colors.black.withValues(alpha: 0.45), width: 1),
                bottom: BorderSide(color: Colors.black.withValues(alpha: p > 0.5 ? 0.35 : 0.70), width: 2),
              );

    final shape = widget.circle ? BoxShape.circle : BoxShape.rectangle;
    final radius = widget.circle ? null : BorderRadius.circular(widget.borderRadius);

    return Container(
      width: widget.width,
      height: widget.height,
      padding: widget.circle ? EdgeInsets.zero : widget.padding,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        gradient: gradient,
        border: border,
        boxShadow: shadows,
      ),
      child: Stack(
        children: [
          // Content
          Center(child: content),
          // Specular sheen — top highlight (only when NOT pressed)
          if (p < 0.3)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: widget.circle
                    ? BorderRadius.circular(10000)
                    : BorderRadius.circular(widget.borderRadius),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: (widget.height ?? 40) * 0.4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: (0.07 - p * 0.07).clamp(0, 0.07)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HARDWARE TRANSPORT BUTTON — Play / Stop with LED glow + beat pulse
//  Specialist implementation of HardwareButton for the primary transport.
//
//  Idle    : Raised, subtle cyan glow hint, play arrow
//  Playing : Inset feel, orange LED ambient, stop square
//  Pressed : Scale 0.94 + Y+2.5px + shadow inverts instantly (70ms)
// ═══════════════════════════════════════════════════════════════════════════

class HardwareTransportButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;
  final double pulseValue; // 0.0–1.0 from beatPulse

  const HardwareTransportButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.size = 62,
    this.pulseValue = 0,
  });

  @override
  State<HardwareTransportButton> createState() => _HardwareTransportButtonState();
}

class _HardwareTransportButtonState extends State<HardwareTransportButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _down(TapDownDetails _) =>
      _ctrl.animateTo(1.0, duration: const Duration(milliseconds: 65), curve: Curves.easeIn);

  void _up(TapUpDetails _) {
    _ctrl.animateTo(0.0, duration: const Duration(milliseconds: 360), curve: Curves.elasticOut);
    widget.onTap();
  }

  void _cancel() =>
      _ctrl.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final playing = widget.isPlaying;
    final pulse = widget.pulseValue;
    final led = playing ? AppColors.warm : AppColors.accent;

    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final p = _ctrl.value;
          final size = widget.size;
          return Transform.translate(
            offset: Offset(0, p * 3.0),
            child: Transform.scale(
              scale: 1.0 - p * 0.05,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Radial gradient: lighter center-top = studio light above
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    radius: 0.95,
                    colors: p > 0.5
                        ? [const Color(0xFF1C1C1C), const Color(0xFF151515)]
                        : playing
                            ? [const Color(0xFF272727), const Color(0xFF1C1C1C)]
                            : [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)],
                  ),
                  // Beveled circular border
                  border: Border.all(
                    color: p > 0.5
                        ? Colors.black54
                        : playing
                            ? led.withValues(alpha: 0.45)
                            : const Color(0x16FFFFFF),
                    width: p > 0.5 ? 1.5 : 1,
                  ),
                  boxShadow: p > 0.5
                      // Pressed: inset illusion
                      ? [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.80), blurRadius: 6, offset: const Offset(3, 3)),
                          BoxShadow(color: const Color(0xFF2E2E2E).withValues(alpha: 0.55), blurRadius: 5, offset: const Offset(-2, -2)),
                        ]
                      // Idle: 3D raised hardware look
                      : [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.80), blurRadius: 0, offset: const Offset(0, 4)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.50), blurRadius: 10, offset: const Offset(3, 8)),
                          BoxShadow(color: const Color(0xFF2E2E2E).withValues(alpha: 0.90), blurRadius: 8, offset: const Offset(-3, -3)),
                          BoxShadow(color: led.withValues(alpha: playing ? 0.55 + pulse * 0.25 : 0.15), blurRadius: playing ? 18 + pulse * 14 : 12, spreadRadius: playing ? -1 : -4),
                        ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Icon
                    Icon(
                      playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: size * 0.44,
                      color: p > 0.5
                          ? led.withValues(alpha: 0.75)
                          : playing
                              ? led
                              : led.withValues(alpha: 0.90),
                      shadows: p < 0.3 && playing
                          ? [Shadow(color: led.withValues(alpha: 0.60 + pulse * 0.25), blurRadius: 12)]
                          : null,
                    ),
                    // Specular crescent (top-left arc, disappears on press)
                    if (p < 0.25)
                      Positioned(
                        top: size * 0.08,
                        left: size * 0.10,
                        child: Container(
                          width: size * 0.45,
                          height: size * 0.20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(size),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: (0.09 - p * 0.36).clamp(0, 0.09)),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  RECORD PULSE RING — Expert 3
//  Shows an expanding glow ring that pulses at BPM rate.
//  Wrap the Record button or show as overlay.
// ═══════════════════════════════════════════════════════════════════════════

class RecordPulseRing extends StatefulWidget {
  final Widget child;
  final bool isRecording;
  final double size;

  const RecordPulseRing({
    super.key,
    required this.child,
    required this.isRecording,
    this.size = 44,
  });

  @override
  State<RecordPulseRing> createState() => _RecordPulseRingState();
}

class _RecordPulseRingState extends State<RecordPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _ring = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (widget.isRecording) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(RecordPulseRing old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !old.isRecording) {
      _ctrl.repeat();
    } else if (!widget.isRecording && old.isRecording) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording) return widget.child;
    return AnimatedBuilder(
      animation: _ring,
      builder: (_, child) {
        final v = _ring.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Expanding ring
            Container(
              width: widget.size + v * 24,
              height: widget.size + v * 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: (1 - v) * 0.70),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: (1 - v) * 0.35),
                    blurRadius: 12,
                    spreadRadius: v * 4,
                  ),
                ],
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
