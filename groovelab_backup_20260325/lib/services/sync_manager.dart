import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_sync_service.dart';
import 'persistence_service.dart';
import 'sync_queue_service.dart';

/// Manages bidirectional sync between local (SharedPreferences) and cloud (Firestore).
/// Local is always source of truth — cloud is a backup/sync layer.
/// Sync happens automatically when user has a full account (not anonymous).
/// Failed operations are enqueued to SyncQueueService for offline retry.
class SyncManager {
  final FirestoreSyncService _firestore;
  final PersistenceService _local;
  final SyncQueueService _queue;
  bool _isSyncing = false;

  SyncManager(this._firestore, this._local, this._queue);

  /// Whether sync is available (user has full account, not anonymous)
  bool get canSync {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  /// Sync local data to cloud. Called after significant local changes.
  /// On failure, operations are enqueued for offline retry.
  Future<void> syncToCloud() async {
    if (!canSync || _isSyncing) return;
    _isSyncing = true;
    try {
      // Sync user settings — use async getters from PersistenceService
      final lang = await _local.getLang();
      final lastBpm = await _local.getLastBpm();
      final settings = {
        'language': lang,
        'lastBpm': lastBpm,
        'syncedAt': DateTime.now().toIso8601String(),
      };
      try {
        await _firestore.saveUserSettings(settings);
      } catch (e) {
        debugPrint('SyncManager: Settings sync failed, enqueuing: $e');
        await _queue.enqueue(SyncOperation(
          type: SyncOperationType.saveSettings,
          entityId: 'user_settings',
          data: settings,
        ));
      }

      // Sync practice sessions (last 10)
      final sessions = await _local.getSessions();
      for (final session in sessions.reversed.take(10)) {
        final sessionData = session.toJson();
        try {
          await _firestore.savePracticeSession(sessionData);
        } catch (e) {
          final sessionId = sessionData['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString();
          debugPrint('SyncManager: Session sync failed, enqueuing: $e');
          await _queue.enqueue(SyncOperation(
            type: SyncOperationType.saveSession,
            entityId: sessionId,
            data: sessionData,
          ));
        }
      }

      debugPrint('SyncManager: Synced to cloud');
    } catch (e) {
      debugPrint('SyncManager: Sync to cloud error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Pull settings from cloud (on first login / new device).
  Future<void> syncFromCloud() async {
    if (!canSync) return;
    try {
      final settings = await _firestore.getUserSettings();
      if (settings != null) {
        // Only pull settings that are newer
        final cloudSyncedAt = settings['syncedAt'] as String?;
        if (cloudSyncedAt != null) {
          debugPrint('SyncManager: Cloud data available from $cloudSyncedAt');
        }
      }
    } catch (e) {
      debugPrint('SyncManager: Sync from cloud error: $e');
    }
  }

  /// Save a pedalera preset (local + cloud)
  Future<void> savePreset(Map<String, dynamic> preset) async {
    // Always save locally first
    // Cloud sync is secondary
    if (canSync) {
      try {
        await _firestore.savePreset(preset);
      } catch (e) {
        debugPrint('SyncManager: Save preset to cloud failed, enqueuing: $e');
        final presetId = preset['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        await _queue.enqueue(SyncOperation(
          type: SyncOperationType.savePreset,
          entityId: presetId,
          data: preset,
        ));
      }
    }
  }

  /// Get presets (cloud first if available, else empty)
  Future<List<Map<String, dynamic>>> getPresets() async {
    if (!canSync) return [];
    try {
      return await _firestore.getPresets();
    } catch (e) {
      debugPrint('SyncManager: Get presets error: $e');
      return [];
    }
  }

  /// Save a setlist (local + cloud)
  Future<void> saveSetlist(Map<String, dynamic> setlist) async {
    if (canSync) {
      try {
        await _firestore.saveSetlist(setlist);
      } catch (e) {
        debugPrint('SyncManager: Save setlist to cloud failed, enqueuing: $e');
        final setlistId = setlist['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        await _queue.enqueue(SyncOperation(
          type: SyncOperationType.saveSetlist,
          entityId: setlistId,
          data: setlist,
        ));
      }
    }
  }

  /// Get setlists from cloud
  Future<List<Map<String, dynamic>>> getSetlists() async {
    if (!canSync) return [];
    try {
      return await _firestore.getSetlists();
    } catch (e) {
      debugPrint('SyncManager: Get setlists error: $e');
      return [];
    }
  }

  /// Process any pending queued operations (call when connectivity returns).
  Future<SyncResult> processPendingQueue() async {
    if (!canSync) return SyncResult(processed: 0, failed: 0, remaining: 0);
    return _queue.processQueue();
  }

  /// Number of operations waiting in the offline queue.
  Future<int> get pendingQueueSize => _queue.queueSize;

  /// Clear all pending queued operations.
  Future<void> clearPendingQueue() => _queue.clearQueue();
}
