import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Wrapper around RevenueCat SDK for managing in-app subscriptions.
///
/// Both Apple and Google keys are now configured from RevenueCat dashboard.
/// While a platform's key is placeholder, initialization is skipped
/// and the app defaults to fully unlocked (isPro = true).
class RevenueCatService {
  // ── Apple key (App Store - "Test Store" in RevenueCat dashboard) ──
  static const _appleApiKey = 'test_eSwPhlAuaxXNAfVxEwpPu0lFGZL';
  // ── Google key (Play Store - "GrooveLab" in RevenueCat dashboard) ──
  static const _googleApiKey = 'goog_CinTWeVSqwqzqfixolKUpwdozHH';

  // ── Entitlement ID (must match RevenueCat dashboard) ──
  static const entitlementId = 'GrooveLab Pro';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize RevenueCat SDK.
  /// Returns `true` if initialization was successful.
  /// Returns `false` on web, with placeholder keys, or on error.
  Future<bool> initialize() async {
    // Skip on web — RevenueCat mobile SDK doesn't support web
    if (kIsWeb) {
      debugPrint('RevenueCat: Skipping init on web');
      return false;
    }

    try {
      final apiKey = Platform.isIOS ? _appleApiKey : _googleApiKey;

      // Skip if placeholder keys — everything stays unlocked
      if (apiKey.contains('PLACEHOLDER')) {
        debugPrint('RevenueCat: Placeholder API key detected, skipping init. '
            'Replace with real keys from https://app.revenuecat.com');
        return false;
      }

      // Enable debug logging during development
      await Purchases.setLogLevel(LogLevel.debug);

      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);

      _initialized = true;
      debugPrint('RevenueCat: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('RevenueCat: Init error: $e');
      return false;
    }
  }

  /// Check if user has active 'pro' entitlement.
  Future<bool> checkProStatus() async {
    if (!_initialized) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } on PlatformException catch (e) {
      debugPrint('RevenueCat: checkProStatus error: $e');
      return false;
    }
  }

  /// Get available offerings (packages with pricing).
  Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      debugPrint('RevenueCat: getOfferings error: $e');
      return null;
    }
  }

  /// Purchase a package. Returns updated CustomerInfo.
  Future<CustomerInfo?> purchasePackage(Package package) async {
    if (!_initialized) return null;
    try {
      return await Purchases.purchasePackage(package);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('RevenueCat: User cancelled purchase');
        return null; // Not an error
      }
      debugPrint('RevenueCat: Purchase error: $e');
      rethrow;
    }
  }

  /// Restore previous purchases. Returns updated CustomerInfo.
  Future<CustomerInfo?> restorePurchases() async {
    if (!_initialized) return null;
    try {
      return await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      debugPrint('RevenueCat: Restore error: $e');
      rethrow;
    }
  }

  /// Listen for real-time subscription changes.
  void addListener(void Function(CustomerInfo) listener) {
    if (!_initialized) return;
    Purchases.addCustomerInfoUpdateListener(listener);
  }
}
