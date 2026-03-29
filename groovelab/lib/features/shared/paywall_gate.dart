import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../l10n/translations.dart';

/// Wraps a pro-only widget. If the user is not Pro, shows a paywall overlay.
/// Use this to gate features that require a subscription.
///
/// ```dart
/// PaywallGate(
///   feature: 'Looper',
///   child: LooperContent(),
/// )
/// ```
class PaywallGate extends ConsumerWidget {
  final String feature;
  final Widget child;
  final bool inline;

  const PaywallGate({
    super.key,
    required this.feature,
    required this.child,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In debug builds, all features are unlocked for development/testing.
    if (kDebugMode) return child;
    final isPro = ref.watch(isProProvider);
    if (isPro) return child;
    return inline ? _InlinePaywall(feature: feature) : _FullPaywall(feature: feature, ref: ref);
  }
}

/// Inline lock indicator — for individual controls within a tab.
/// Shows a lock icon + "PRO" badge on top of the control.
class PaywallBadge extends ConsumerWidget {
  final Widget child;

  const PaywallBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In debug builds, all features are unlocked for development/testing.
    if (kDebugMode) return child;
    final isPro = ref.watch(isProProvider);
    if (isPro) return child;
    return Stack(
      children: [
        Opacity(opacity: 0.35, child: IgnorePointer(child: child)),
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.proGold,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'PRO',
              style: AppFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlinePaywall extends StatelessWidget {
  final String feature;
  const _InlinePaywall({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.proGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, color: AppColors.proGold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$feature — Pro Feature',
              style: AppFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.proGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'PRO',
              style: AppFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullPaywall extends StatelessWidget {
  final String feature;
  final WidgetRef ref;

  const _FullPaywall({required this.feature, required this.ref});

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final rcState = ref.watch(revenueCatProvider);

    return Container(
      color: AppColors.bgDark,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.proGold, AppColors.proGold.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.lock_rounded, size: 36, color: Colors.black),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                feature,
                style: AppFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(lang, 'featureLockedDesc'),
                style: AppFonts.outfit(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Pro features list
              _featureRow(Icons.music_note, tr(lang, 'proFeatures')),
              const SizedBox(height: 24),

              // Purchase buttons
              if (rcState.revenueCatAvailable && rcState.offerings != null) ...[
                _buildOfferingButtons(context, rcState, ref),
              ] else ...[
                // RevenueCat not available — show info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgPanel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lang == 'es'
                        ? 'Las suscripciones estarán disponibles pronto.'
                        : 'Subscriptions coming soon.',
                    style: AppFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Restore purchases
              TextButton(
                onPressed: () => ref.read(revenueCatProvider.notifier).restorePurchases(),
                child: Text(
                  tr(lang, 'restorePurchase'),
                  style: AppFonts.outfit(
                    fontSize: 14,
                    color: AppColors.accent,
                  ),
                ),
              ),

              // Error message
              if (rcState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  rcState.errorMessage!,
                  style: AppFonts.outfit(fontSize: 13, color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.proGold, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferingButtons(BuildContext context, RevenueCatState rcState, WidgetRef ref) {
    final offerings = rcState.offerings!;
    final packages = offerings.current?.availablePackages ?? [];

    if (packages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: packages.map((pkg) {
        final isMonthly = pkg.packageType == PackageType.monthly;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: rcState.isLoading
                  ? null
                  : () => ref.read(revenueCatProvider.notifier).purchase(pkg),
              style: ElevatedButton.styleFrom(
                backgroundColor: isMonthly ? AppColors.proGold : AppColors.bgPanel,
                foregroundColor: isMonthly ? Colors.black : AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isMonthly
                      ? BorderSide.none
                      : BorderSide(color: AppColors.proGold.withOpacity(0.4)),
                ),
              ),
              child: rcState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      '${pkg.storeProduct.title} — ${pkg.storeProduct.priceString}',
                      style: AppFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

