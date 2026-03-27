/// Master providers file — re-exports all feature-scoped providers.
/// Existing `import 'providers/app_providers.dart'` calls continue to work.
library;

// Feature-scoped providers (new modular structure)
export 'metronome_providers.dart';
export 'drums_providers.dart';
export 'practice_providers.dart';
export 'looper_providers.dart';
export 'recording_providers.dart';

// Providers that remain here (cross-cutting concerns)
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';
import '../services/persistence_service.dart';

// ── Language ──
final langProvider = StateProvider<String>((ref) => 'es');

// ── Navigation ──
final tabIndexProvider = StateProvider<int>((ref) => 9);

// ── RevenueCat IAP ──
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) => RevenueCatService());

class RevenueCatState {
  final bool isLoading;
  final bool isPro;
  final Offerings? offerings;
  final String? errorMessage;
  final bool revenueCatAvailable;

  const RevenueCatState({
    this.isLoading = true,
    this.isPro = false,
    this.offerings,
    this.errorMessage,
    this.revenueCatAvailable = false,
  });

  RevenueCatState copyWith({
    bool? isLoading,
    bool? isPro,
    Offerings? offerings,
    String? errorMessage,
    bool? revenueCatAvailable,
  }) {
    return RevenueCatState(
      isLoading: isLoading ?? this.isLoading,
      isPro: isPro ?? this.isPro,
      offerings: offerings ?? this.offerings,
      errorMessage: errorMessage,
      revenueCatAvailable: revenueCatAvailable ?? this.revenueCatAvailable,
    );
  }
}

class RevenueCatNotifier extends StateNotifier<RevenueCatState> {
  final RevenueCatService _service;

  RevenueCatNotifier(this._service) : super(const RevenueCatState()) {
    _init();
  }

  Future<void> _init() async {
    final available = _service.isInitialized;
    if (!available) {
      state = state.copyWith(
        isLoading: false,
        isPro: true,
        revenueCatAvailable: false,
      );
      return;
    }

    _service.addListener((info) {
      final isPro = info.entitlements.active.containsKey(RevenueCatService.entitlementId);
      state = state.copyWith(isPro: isPro);
    });

    final isPro = await _service.checkProStatus();
    final offerings = await _service.getOfferings();

    state = state.copyWith(
      isLoading: false,
      isPro: isPro,
      offerings: offerings,
      revenueCatAvailable: true,
    );
  }

  Future<void> purchase(Package package) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final info = await _service.purchasePackage(package);
      if (info != null) {
        final isPro = info.entitlements.active.containsKey(RevenueCatService.entitlementId);
        state = state.copyWith(isLoading: false, isPro: isPro);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Purchase failed. Please try again.',
      );
    }
  }

  Future<void> restorePurchases() async {
    if (!_service.isInitialized) {
      state = state.copyWith(isLoading: false, isPro: true, errorMessage: null);
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final info = await _service.restorePurchases();
      if (info != null) {
        final isPro = info.entitlements.active.containsKey(RevenueCatService.entitlementId);
        state = state.copyWith(
          isLoading: false,
          isPro: isPro,
          errorMessage: isPro ? null : 'No previous purchases found.',
        );
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Restore unavailable.');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Restore failed.');
    }
  }
}

final revenueCatProvider = StateNotifierProvider<RevenueCatNotifier, RevenueCatState>((ref) {
  final service = ref.read(revenueCatServiceProvider);
  return RevenueCatNotifier(service);
});

final isProProvider = Provider<bool>((ref) {
  // TODO: Set to false when ready to enforce paywall in production.
  // All features unlocked until RevenueCat products are configured in
  // App Store Connect and Google Play Console.
  return true;
});

// ── Stage mode / Setlists ──
final stageModeProvider = StateProvider<bool>((ref) => false);
final setlistsProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final activeSetlistProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final activeSetlistSongIndexProvider = StateProvider<int>((ref) => 0);
final setlistAutoAdvanceProvider = StateProvider<bool>((ref) => false);

// ── Library ──
final libraryProvider = StateProvider<List<Map<String, dynamic>>>((ref) => [
  {'id': '1', 'name': 'Blues Jam', 'bpm': 80, 'timeSig': '12/8', 'style': 'Blues'},
  {'id': '2', 'name': 'Rock Groove', 'bpm': 120, 'timeSig': '4/4', 'style': 'Rock'},
  {'id': '3', 'name': 'Funk Practice', 'bpm': 100, 'timeSig': '4/4', 'style': 'Funk'},
]);
final librarySearchProvider = StateProvider<String>((ref) => '');
final libraryFavFilterProvider = StateProvider<bool>((ref) => false);

// ── PAD System ──
final padListProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final padMasterVolumeProvider = StateProvider<double>((ref) => 1.0);
final padRoutingPanProvider = StateProvider<double>((ref) => 0.0);
final guideRoutingPanProvider = StateProvider<double>((ref) => 0.0);

// ── MIDI ──
final midiEnabledProvider = StateProvider<bool>((ref) => false);
final midiDevicesProvider = StateProvider<List<Map<String, String>>>((ref) => []);
final lastMidiEventProvider = StateProvider<String>((ref) => '');

// ── Persistence ──
final persistenceProvider = Provider<PersistenceService>((ref) => PersistenceService());
