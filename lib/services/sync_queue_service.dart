import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_sync_service.dart';

/// Offline-resilient sync queue for Firebase operations.
/// Queues failed sync operations and retries them when connectivity returns.
/// Uses SharedPreferences for persistence (no extra dependencies).
class SyncQueueService {
  static const _queueKey = 'sync_queue';
  static const _maxQueueSize = 100;
  static const _maxRetries = 3;

  final FirestoreSyncService _firestore;
  SharedPreferences? _prefs;
  bool _isProcessing = false;

  SyncQueueService(this._firestore);

  Future<SharedPreferences> get _storage async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Enqueue a sync operation. Will be retried if it fails.
  Future<void> enqueue(SyncOperation operation) async {
    final prefs = await _storage;
    final queue = await _getQueue();

    // Prevent duplicate operations
    queue.removeWhere((op) =>
      op.type == operation.type &&
      op.entityId == operation.entityId
    );

    queue.add(operation);

    // Trim queue to max size (remove oldest)
    if (queue.length > _maxQueueSize) {
      queue.removeRange(0, queue.length - _maxQueueSize);
    }

    await _saveQueue(queue);

    // Try to process immediately
    await processQueue();
  }

  /// Process all queued operations.
  Future<SyncResult> processQueue() async {
    if (_isProcessing) return SyncResult(processed: 0, failed: 0, remaining: 0);
    _isProcessing = true;

    int processed = 0;
    int failed = 0;

    try {
      final queue = await _getQueue();
      final remaining = <SyncOperation>[];

      for (final op in queue) {
        try {
          await _executeOperation(op);
          processed++;
          debugPrint('SyncQueue: Processed ${op.type}/${op.entityId}');
        } catch (e) {
          final retries = op.retryCount + 1;
          if (retries < _maxRetries) {
            remaining.add(op.copyWith(
              retryCount: retries,
              lastError: e.toString(),
              lastAttempt: DateTime.now(),
            ));
            debugPrint('SyncQueue: Retry $retries/${_maxRetries} for ${op.type}/${op.entityId}: $e');
          } else {
            debugPrint('SyncQueue: Dropped ${op.type}/${op.entityId} after $_maxRetries retries');
          }
          failed++;
        }
      }

      await _saveQueue(remaining);
      return SyncResult(processed: processed, failed: failed, remaining: remaining.length);
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _executeOperation(SyncOperation op) async {
    switch (op.type) {
      case SyncOperationType.saveSettings:
        await _firestore.saveUserSettings(op.data);
      case SyncOperationType.saveSession:
        await _firestore.savePracticeSession(op.data);
      case SyncOperationType.savePreset:
        await _firestore.savePreset(op.data);
      case SyncOperationType.saveSetlist:
        await _firestore.saveSetlist(op.data);
    }
  }

  /// Get current queue size
  Future<int> get queueSize async {
    final queue = await _getQueue();
    return queue.length;
  }

  /// Clear all queued operations
  Future<void> clearQueue() async {
    final prefs = await _storage;
    await prefs.remove(_queueKey);
  }

  Future<List<SyncOperation>> _getQueue() async {
    final prefs = await _storage;
    final json = prefs.getString(_queueKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => SyncOperation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<SyncOperation> queue) async {
    final prefs = await _storage;
    await prefs.setString(_queueKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
  }
}

/// Types of sync operations
enum SyncOperationType {
  saveSettings,
  saveSession,
  savePreset,
  saveSetlist,
}

/// A queued sync operation
class SyncOperation {
  final SyncOperationType type;
  final String entityId;
  final Map<String, dynamic> data;
  final int retryCount;
  final String? lastError;
  final DateTime? lastAttempt;
  final DateTime createdAt;

  SyncOperation({
    required this.type,
    required this.entityId,
    required this.data,
    this.retryCount = 0,
    this.lastError,
    this.lastAttempt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  SyncOperation copyWith({
    int? retryCount,
    String? lastError,
    DateTime? lastAttempt,
  }) {
    return SyncOperation(
      type: type,
      entityId: entityId,
      data: data,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'entityId': entityId,
    'data': data,
    'retryCount': retryCount,
    'lastError': lastError,
    'lastAttempt': lastAttempt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      type: SyncOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SyncOperationType.saveSettings,
      ),
      entityId: json['entityId'] as String? ?? '',
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      lastAttempt: json['lastAttempt'] != null
          ? DateTime.tryParse(json['lastAttempt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Result of processing the sync queue
class SyncResult {
  final int processed;
  final int failed;
  final int remaining;

  const SyncResult({
    required this.processed,
    required this.failed,
    required this.remaining,
  });

  bool get hasRemaining => remaining > 0;

  @override
  String toString() => 'SyncResult(processed: $processed, failed: $failed, remaining: $remaining)';
}
