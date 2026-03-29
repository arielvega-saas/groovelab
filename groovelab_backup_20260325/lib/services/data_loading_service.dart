import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import 'persistence_service.dart';
import '../providers/app_providers.dart';

/// Extracted from app.dart — handles loading persisted data into providers
/// and saving current provider state back to persistence.
/// Reduces app.dart coupling to persistence layer.
class DataLoadingService {
  final Ref _ref;

  DataLoadingService(this._ref);

  PersistenceService get _persistence => _ref.read(persistenceProvider);

  /// Load all persisted data into Riverpod providers.
  /// Called once at app startup.
  Future<void> loadAll() async {
    _ref.read(langProvider.notifier).state = await _persistence.getLang();
    _ref.read(bpmProvider.notifier).state = await _persistence.getLastBpm();
    _ref.read(clickSoundProvider.notifier).state = await _persistence.getLastClickSound();
    _ref.read(subdivisionProvider.notifier).state = await _persistence.getLastSubdivision();
    _ref.read(swingProvider.notifier).state = await _persistence.getLastSwing();
    _ref.read(hapticModeProvider.notifier).state = await _persistence.getHapticEnabled();
    _ref.read(totalPracticeTimeProvider.notifier).state = await _persistence.getTotalPracticeTime();
    _ref.read(sessionCountProvider.notifier).state = await _persistence.getSessionCount();
    _ref.read(libraryProvider.notifier).state = await _persistence.getLibrary();
    _ref.read(targetBpmProvider.notifier).state = await _persistence.getTargetBpm();
    _ref.read(weeklyGoalMinutesProvider.notifier).state = await _persistence.getWeeklyGoalMinutes();
    _ref.read(sessionsHistoryProvider.notifier).state = await _persistence.getSessions();
    _ref.read(routinesProvider.notifier).state = await _persistence.getRoutines();
    _ref.read(setlistsProvider.notifier).state = await _persistence.getSetlists();
    _ref.read(humanFeelProvider.notifier).state = await _persistence.getHumanFeel();
    _ref.read(polyrhythmEnabledProvider.notifier).state = await _persistence.getPolyrhythmEnabled();
    _ref.read(polyrhythmValueProvider.notifier).state = await _persistence.getPolyrhythmValue();
    _ref.read(drumVolumesProvider.notifier).state = await _persistence.getDrumVolumes();

    // Load and parse time signature
    final tSig = await _persistence.getLastTimeSig();
    final parts = tSig.split('/');
    if (parts.length == 2) {
      final n = int.tryParse(parts[0]) ?? 4;
      final d = int.tryParse(parts[1]) ?? 4;
      _ref.read(timeSigProvider.notifier).state = TimeSig(n, d, tSig);
      _ref.read(accentPatternProvider.notifier).state =
          List.generate(n, (i) => i == 0 ? 1.0 : 0.7);
    }
  }

  /// Save all current provider state to persistence.
  /// Called on app lifecycle changes and after significant state changes.
  Future<void> saveAll() async {
    await _persistence.setLang(_ref.read(langProvider));
    await _persistence.setLastBpm(_ref.read(bpmProvider));
    await _persistence.setLastTimeSig(_ref.read(timeSigProvider).label);
    await _persistence.setLastClickSound(_ref.read(clickSoundProvider));
    await _persistence.setLastSubdivision(_ref.read(subdivisionProvider));
    await _persistence.setLastSwing(_ref.read(swingProvider));
    await _persistence.setHapticEnabled(_ref.read(hapticModeProvider));
    await _persistence.setTotalPracticeTime(_ref.read(totalPracticeTimeProvider));
    await _persistence.setSessionCount(_ref.read(sessionCountProvider));
    await _persistence.saveLibrary(_ref.read(libraryProvider));
    await _persistence.setTargetBpm(_ref.read(targetBpmProvider));
    await _persistence.setWeeklyGoalMinutes(_ref.read(weeklyGoalMinutesProvider));
    await _persistence.setHumanFeel(_ref.read(humanFeelProvider));
    await _persistence.setPolyrhythmEnabled(_ref.read(polyrhythmEnabledProvider));
    await _persistence.setPolyrhythmValue(_ref.read(polyrhythmValueProvider));
    await _persistence.setDrumVolumes(_ref.read(drumVolumesProvider));
    await _persistence.saveRoutines(_ref.read(routinesProvider));
    await _persistence.saveSetlists(_ref.read(setlistsProvider));
  }
}

/// Riverpod provider for DataLoadingService
final dataLoadingServiceProvider = Provider<DataLoadingService>((ref) {
  return DataLoadingService(ref);
});
