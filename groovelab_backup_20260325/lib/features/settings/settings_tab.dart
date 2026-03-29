import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';
import '../../services/revenuecat_service.dart';
import '../../services/firebase_auth_service.dart';
import '../auth/profile_screen.dart';

class SettingsTab extends ConsumerWidget {
  final VoidCallback onSaveData;
  final AudioService audioService;

  const SettingsTab({
    super.key,
    required this.onSaveData,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 24, height: 1, color: AppColors.accent.withValues(alpha: 0.4)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(tr(lang, 'settingsTitle').toUpperCase(), style: GoogleFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 3,
                )),
              ),
              Container(width: 24, height: 1, color: AppColors.accent.withValues(alpha: 0.4)),
            ],
          ),

          const SizedBox(height: 20),
          AppTheme.premiumPanel(title: tr(lang, 'language').toUpperCase(), content: Row(
            children: languages.map((l) {
              final active = lang == l['code'];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      ref.read(langProvider.notifier).state = l['code']!;
                      onSaveData();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: active ? AppColors.accent.withValues(alpha: 0.10) : AppColors.bgInput,
                        border: Border.all(
                          color: active ? AppColors.accent : AppColors.border,
                          width: active ? 1.5 : 1,
                        ),
                        boxShadow: active ? [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ] : null,
                      ),
                      child: Column(
                        children: [
                          _buildRealFlag(l['code']!),
                          const SizedBox(height: 8),
                          Text(l['label']!, style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? AppColors.accent : AppColors.textSecondary,
                          )),
                          if (active) ...[
                            const SizedBox(height: 5),
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                                boxShadow: [
                                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 4),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          )),

          // Account / Profile
          const SizedBox(height: 4),
          _buildAccountPanel(context, ref, lang),

          // Subscription / Pro Status
          _buildSubscriptionPanel(ref, lang),

          // Privacy Policy
          const SizedBox(height: 4),
          AppTheme.premiumPanel(title: tr(lang, 'privacyPolicy').toUpperCase(), content: GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://arieldev-docs.web.app/privacy_policy.html')),
            child: Row(
              children: [
                const Icon(Icons.privacy_tip_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  tr(lang, 'viewPrivacyPolicy'),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accent,
                  ),
                ),
              ],
            ),
          )),

          // Audio info
          const SizedBox(height: 4),
          AppTheme.premiumPanel(title: 'AUDIO ENGINE', accentColor: AppColors.accent2, content: FutureBuilder<double>(
            future: audioService.getOutputLatency(),
            builder: (context, snap) {
              final latency = snap.data?.toStringAsFixed(1) ?? '...';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kIsWeb
                    ? 'Engine: ${tr(lang, 'webAudioEngine')}'
                    : 'Native engine: ${audioService.isNativeAvailable ? "Active" : "Fallback"}',
                    style: AppTheme.monoStyle(size: 12, color: AppColors.accent2)),
                  const SizedBox(height: 4),
                  Text('Output latency: ${latency}ms',
                    style: AppTheme.monoStyle(size: 12, color: AppColors.textMuted)),
                ],
              );
            },
          )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ACCOUNT PANEL
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAccountPanel(BuildContext context, WidgetRef ref, String lang) {
    final userAsync = ref.watch(authStateProvider);

    return AppTheme.premiumPanel(
      title: tr(lang, 'account').toUpperCase(),
      content: userAsync.when(
        loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))),
        error: (_, __) => _accountRow(
          context,
          icon: Icons.person_outline,
          label: tr(lang, 'signIn'),
          subtitle: tr(lang, 'signInSubtitle'),
        ),
        data: (user) {
          if (user == null) {
            return _accountRow(
              context,
              icon: Icons.person_outline,
              label: tr(lang, 'signIn'),
              subtitle: 'Sync data across devices',
            );
          }
          final isAnon = user.isAnonymous;
          return _accountRow(
            context,
            icon: isAnon ? Icons.person_outline : Icons.person,
            label: isAnon
                ? tr(lang, 'createAccount')
                : (user.displayName ?? user.email ?? 'Account'),
            subtitle: isAnon
                ? 'Upgrade to sync across devices'
                : (user.email ?? 'Tap to manage account'),
            accentIcon: !isAnon,
          );
        },
      ),
    );
  }

  Widget _accountRow(BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    bool accentIcon = false,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: accentIcon
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentIcon ? AppColors.accent : AppColors.textMuted, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              if (subtitle != null)
                Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted)),
            ],
          )),
          Icon(Icons.chevron_right, color: AppColors.textMuted.withValues(alpha: 0.5), size: 20),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SUBSCRIPTION PANEL
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSubscriptionPanel(WidgetRef ref, String lang) {
    final rcState = ref.watch(revenueCatProvider);

    // On web or if RevenueCat is not available, don't show subscription UI
    if (kIsWeb || !rcState.revenueCatAvailable) {
      return const SizedBox.shrink();
    }

    final isPro = rcState.isPro;

    if (isPro) {
      // Pro active state
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _panel(tr(lang, 'proPlan'), Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                  ),
                  child: Text(tr(lang, 'proBadge'),
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Text(tr(lang, 'proActive'),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: rcState.isLoading ? null : () {
                ref.read(revenueCatProvider.notifier).restorePurchases();
              },
              child: Text(tr(lang, 'restorePurchase'),
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted,
                  decoration: TextDecoration.underline, decorationColor: AppColors.textMuted)),
            ),
          ],
        )),
      );
    }

    // Not pro — show paywall
    final offerings = rcState.offerings;
    final defaultOffering = offerings?.current;
    final monthlyPkg = defaultOffering?.monthly;
    final annualPkg = defaultOffering?.annual;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _panel(tr(lang, 'upgradeToPro'), Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'proUnlock'),
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(tr(lang, 'proFeatures'),
            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 16),

          // Monthly option
          if (monthlyPkg != null)
            _subscriptionOptionButton(
              label: tr(lang, 'monthly'),
              price: monthlyPkg.storeProduct.priceString,
              onTap: rcState.isLoading ? null : () {
                ref.read(revenueCatProvider.notifier).purchase(monthlyPkg);
              },
            ),

          if (monthlyPkg != null) const SizedBox(height: 8),

          // Annual option (highlighted)
          if (annualPkg != null)
            _subscriptionOptionButton(
              label: tr(lang, 'yearly'),
              price: annualPkg.storeProduct.priceString,
              onTap: rcState.isLoading ? null : () {
                ref.read(revenueCatProvider.notifier).purchase(annualPkg);
              },
              highlighted: true,
            ),

          if (rcState.isLoading) ...[
            const SizedBox(height: 12),
            const Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            )),
          ],

          if (rcState.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(rcState.errorMessage!,
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.redAccent)),
          ],

          const SizedBox(height: 12),
          GestureDetector(
            onTap: rcState.isLoading ? null : () {
              ref.read(revenueCatProvider.notifier).restorePurchases();
            },
            child: Text(tr(lang, 'restorePurchase'),
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.accent,
                decoration: TextDecoration.underline, decorationColor: AppColors.accent)),
          ),
        ],
      )),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SUBSCRIPTION OPTION BUTTON
  // ═══════════════════════════════════════════════════════════════════

  Widget _subscriptionOptionButton({
    required String label,
    required String price,
    VoidCallback? onTap,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: highlighted ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2030), Color(0xFF0F1820)],
          ) : null,
          color: highlighted ? null : AppColors.bgInput,
          border: Border.all(
            color: highlighted ? AppColors.accent.withValues(alpha: 0.6) : AppColors.border,
            width: highlighted ? 1.5 : 1,
          ),
          boxShadow: highlighted ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.12), blurRadius: 16, spreadRadius: -2)] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (highlighted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                    ),
                    child: const Text('BEST VALUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                  ),
                Text(label, style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: highlighted ? AppColors.textPrimary : AppColors.textSecondary,
                )),
              ],
            ),
            Text(price, style: GoogleFonts.outfit(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: highlighted ? AppColors.accent : AppColors.textPrimary,
            )),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  REAL FLAG WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  static Widget _buildRealFlag(String code) {
    const w = 44.0;
    const h = 30.0;
    const radius = BorderRadius.all(Radius.circular(4));

    switch (code) {
      case 'en': // US Flag
        return ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: w, height: h,
            child: CustomPaint(painter: _USFlagPainter()),
          ),
        );
      case 'es': // Spain Flag
        return ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: w, height: h,
            child: CustomPaint(painter: _SpainFlagPainter()),
          ),
        );
      case 'pt': // Brazil Flag
        return ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: w, height: h,
            child: CustomPaint(painter: _BrazilFlagPainter()),
          ),
        );
      default:
        return SizedBox(width: w, height: h);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PANEL HELPER
  // ═══════════════════════════════════════════════════════════════════

  Widget _panel(String title, Widget content) {
    return AppTheme.premiumPanel(title: title.toUpperCase(), content: content);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FLAG PAINTERS — Real colors
// ═══════════════════════════════════════════════════════════════════

/// 🇺🇸 United States — red/white stripes + blue canton with stars
class _USFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stripeH = h / 13;

    // 13 stripes
    for (int i = 0; i < 13; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, stripeH * i, w, stripeH),
        Paint()..color = i.isEven ? const Color(0xFFB22234) : Colors.white,
      );
    }

    // Blue canton
    final cantonW = w * 0.4;
    final cantonH = stripeH * 7;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cantonW, cantonH),
      Paint()..color = const Color(0xFF3C3B6E),
    );

    // Stars (simplified 5x4 + 4x3 grid)
    final starPaint = Paint()..color = Colors.white;
    final starRows = 5;
    final starCols = 4;
    final starDx = cantonW / (starCols + 1);
    final starDy = cantonH / (starRows + 1);
    for (int r = 0; r < starRows; r++) {
      final cols = r.isEven ? starCols : starCols - 1;
      final offsetX = r.isEven ? starDx : starDx * 1.5;
      for (int c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(offsetX + c * starDx, starDy * (r + 1)),
          1.3,
          starPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 🇪🇸 Spain — red, yellow (2x), red horizontal bands
class _SpainFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top red
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.25),
      Paint()..color = const Color(0xFFAA151B),
    );
    // Yellow center
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.25, w, h * 0.5),
      Paint()..color = const Color(0xFFF1BF00),
    );
    // Bottom red
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.75, w, h * 0.25),
      Paint()..color = const Color(0xFFAA151B),
    );

    // Simplified coat of arms (small shield)
    final shieldX = w * 0.3;
    final shieldY = h * 0.32;
    final shieldW = w * 0.06;
    final shieldH = h * 0.36;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(shieldX, shieldY, shieldW, shieldH),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFFAA151B),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(shieldX + 0.6, shieldY + 0.6, shieldW - 1.2, shieldH - 1.2),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFF1BF00)..style = PaintingStyle.stroke..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 🇧🇷 Brazil — green background, yellow diamond, blue globe
class _BrazilFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Green background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF009739),
    );

    // Yellow diamond
    final path = Path()
      ..moveTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.9, h * 0.5)
      ..lineTo(w * 0.5, h * 0.9)
      ..lineTo(w * 0.1, h * 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFEDD00));

    // Blue globe
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      h * 0.22,
      Paint()..color = const Color(0xFF002776),
    );

    // White arc band across globe
    final arcRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.72),
      width: h * 0.44,
      height: h * 0.34,
    );
    canvas.drawArc(
      arcRect, -3.14, 3.14, false,
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
