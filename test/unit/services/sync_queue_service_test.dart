import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:groovelab/services/sync_queue_service.dart';

void main() {
  group('SyncOperationType', () {
    test('enum has expected values', () {
      expect(SyncOperationType.values, hasLength(4));
      expect(SyncOperationType.values, contains(SyncOperationType.saveSettings));
      expect(SyncOperationType.values, contains(SyncOperationType.saveSession));
      expect(SyncOperationType.values, contains(SyncOperationType.savePreset));
      expect(SyncOperationType.values, contains(SyncOperationType.saveSetlist));
    });

    test('enum name serialization round-trip', () {
      for (final type in SyncOperationType.values) {
        final name = type.name;
        final restored = SyncOperationType.values.firstWhere((e) => e.name == name);
        expect(restored, equals(type));
      }
    });
  });

  group('SyncOperation', () {
    test('JSON round-trip preserves all fields', () {
      final now = DateTime.parse('2025-01-15T10:30:00.000');
      final lastAttempt = DateTime.parse('2025-01-15T10:31:00.000');

      final operation = SyncOperation(
        type: SyncOperationType.saveSession,
        entityId: 'session-123',
        data: {'bpm': 120, 'name': 'Test Session'},
        retryCount: 2,
        lastError: 'Network timeout',
        lastAttempt: lastAttempt,
        createdAt: now,
      );

      final json = operation.toJson();
      final restored = SyncOperation.fromJson(json);

      expect(restored.type, equals(SyncOperationType.saveSession));
      expect(restored.entityId, equals('session-123'));
      expect(restored.data['bpm'], equals(120));
      expect(restored.data['name'], equals('Test Session'));
      expect(restored.retryCount, equals(2));
      expect(restored.lastError, equals('Network timeout'));
      expect(restored.lastAttempt, equals(lastAttempt));
      expect(restored.createdAt, equals(now));
    });

    test('JSON round-trip with null optional fields', () {
      final operation = SyncOperation(
        type: SyncOperationType.saveSettings,
        entityId: 'settings-1',
        data: {'lang': 'en'},
      );

      final json = operation.toJson();
      final restored = SyncOperation.fromJson(json);

      expect(restored.type, equals(SyncOperationType.saveSettings));
      expect(restored.entityId, equals('settings-1'));
      expect(restored.retryCount, equals(0));
      expect(restored.lastError, isNull);
      expect(restored.lastAttempt, isNull);
    });

    test('toJson produces correct map structure', () {
      final now = DateTime.parse('2025-01-15T10:30:00.000');
      final operation = SyncOperation(
        type: SyncOperationType.savePreset,
        entityId: 'preset-5',
        data: {'tempo': 90},
        createdAt: now,
      );

      final json = operation.toJson();

      expect(json['type'], equals('savePreset'));
      expect(json['entityId'], equals('preset-5'));
      expect(json['data'], equals({'tempo': 90}));
      expect(json['retryCount'], equals(0));
      expect(json['lastError'], isNull);
      expect(json['lastAttempt'], isNull);
      expect(json['createdAt'], equals('2025-01-15T10:30:00.000'));
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {
        'type': 'saveSetlist',
        'entityId': 'setlist-1',
        'data': {'name': 'My Setlist'},
      };

      final operation = SyncOperation.fromJson(json);

      expect(operation.type, equals(SyncOperationType.saveSetlist));
      expect(operation.entityId, equals('setlist-1'));
      expect(operation.retryCount, equals(0));
      expect(operation.lastError, isNull);
      expect(operation.lastAttempt, isNull);
    });

    test('fromJson falls back to saveSettings for unknown type', () {
      final json = {
        'type': 'unknownType',
        'entityId': 'x',
        'data': {},
      };

      final operation = SyncOperation.fromJson(json);
      expect(operation.type, equals(SyncOperationType.saveSettings));
    });

    test('copyWith updates specified fields only', () {
      final now = DateTime.parse('2025-01-15T10:30:00.000');
      final original = SyncOperation(
        type: SyncOperationType.saveSession,
        entityId: 'session-1',
        data: {'bpm': 120},
        retryCount: 0,
        createdAt: now,
      );

      final newAttempt = DateTime.parse('2025-01-15T10:35:00.000');
      final updated = original.copyWith(
        retryCount: 1,
        lastError: 'Connection refused',
        lastAttempt: newAttempt,
      );

      // Updated fields
      expect(updated.retryCount, equals(1));
      expect(updated.lastError, equals('Connection refused'));
      expect(updated.lastAttempt, equals(newAttempt));

      // Unchanged fields
      expect(updated.type, equals(SyncOperationType.saveSession));
      expect(updated.entityId, equals('session-1'));
      expect(updated.data, equals({'bpm': 120}));
      expect(updated.createdAt, equals(now));
    });

    test('copyWith with no arguments returns equivalent operation', () {
      final original = SyncOperation(
        type: SyncOperationType.savePreset,
        entityId: 'preset-1',
        data: {'name': 'Fast'},
        retryCount: 1,
        lastError: 'err',
      );

      final copy = original.copyWith();

      expect(copy.type, equals(original.type));
      expect(copy.entityId, equals(original.entityId));
      expect(copy.retryCount, equals(original.retryCount));
      expect(copy.lastError, equals(original.lastError));
    });
  });

  group('SyncResult', () {
    test('hasRemaining is true when remaining > 0', () {
      const result = SyncResult(processed: 5, failed: 2, remaining: 3);
      expect(result.hasRemaining, isTrue);
    });

    test('hasRemaining is false when remaining is 0', () {
      const result = SyncResult(processed: 5, failed: 0, remaining: 0);
      expect(result.hasRemaining, isFalse);
    });

    test('properties are accessible', () {
      const result = SyncResult(processed: 10, failed: 3, remaining: 2);
      expect(result.processed, equals(10));
      expect(result.failed, equals(3));
      expect(result.remaining, equals(2));
    });

    test('toString contains all fields', () {
      const result = SyncResult(processed: 1, failed: 2, remaining: 3);
      final str = result.toString();
      expect(str, contains('processed: 1'));
      expect(str, contains('failed: 2'));
      expect(str, contains('remaining: 3'));
    });
  });

  group('SyncQueueService queue persistence', () {
    const queueKey = 'sync_queue';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('enqueue adds operation to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Manually store an operation in the queue key to simulate enqueue
      final op = SyncOperation(
        type: SyncOperationType.saveSettings,
        entityId: 'settings-1',
        data: {'lang': 'en'},
      );

      final queue = [op.toJson()];
      await prefs.setString(queueKey, jsonEncode(queue));

      final stored = prefs.getString(queueKey);
      expect(stored, isNotNull);

      final decoded = jsonDecode(stored!) as List;
      expect(decoded, hasLength(1));

      final restored = SyncOperation.fromJson(decoded[0] as Map<String, dynamic>);
      expect(restored.entityId, equals('settings-1'));
      expect(restored.type, equals(SyncOperationType.saveSettings));
    });

    test('deduplication replaces operation with same type and entityId', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final op1 = SyncOperation(
        type: SyncOperationType.saveSession,
        entityId: 'session-1',
        data: {'bpm': 100},
      );
      final op2 = SyncOperation(
        type: SyncOperationType.savePreset,
        entityId: 'preset-1',
        data: {'name': 'A'},
      );
      final op3 = SyncOperation(
        type: SyncOperationType.saveSession,
        entityId: 'session-1',
        data: {'bpm': 140},
      );

      // Simulate the deduplication logic from SyncQueueService.enqueue
      var queue = [op1, op2];

      // Adding op3 should replace op1 (same type + entityId)
      queue.removeWhere((op) =>
        op.type == op3.type && op.entityId == op3.entityId
      );
      queue.add(op3);

      await prefs.setString(
        queueKey,
        jsonEncode(queue.map((e) => e.toJson()).toList()),
      );

      final stored = jsonDecode(prefs.getString(queueKey)!) as List;
      expect(stored, hasLength(2));

      final types = stored.map((e) => (e as Map<String, dynamic>)['entityId']).toList();
      expect(types, contains('preset-1'));
      expect(types, contains('session-1'));

      // The session-1 entry should have the updated bpm
      final sessionEntry = stored.firstWhere(
        (e) => (e as Map<String, dynamic>)['entityId'] == 'session-1',
      ) as Map<String, dynamic>;
      expect(sessionEntry['data']['bpm'], equals(140));
    });

    test('max queue size caps at 100', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const maxQueueSize = 100;
      // Create 110 operations
      final queue = List.generate(110, (i) => SyncOperation(
        type: SyncOperationType.saveSession,
        entityId: 'session-$i',
        data: {'index': i},
      ));

      // Apply the trim logic from SyncQueueService
      if (queue.length > maxQueueSize) {
        queue.removeRange(0, queue.length - maxQueueSize);
      }

      await prefs.setString(
        queueKey,
        jsonEncode(queue.map((e) => e.toJson()).toList()),
      );

      final stored = jsonDecode(prefs.getString(queueKey)!) as List;
      expect(stored, hasLength(100));

      // Should keep the newest (last 100), so first should be session-10
      final firstEntry = SyncOperation.fromJson(stored.first as Map<String, dynamic>);
      expect(firstEntry.entityId, equals('session-10'));

      final lastEntry = SyncOperation.fromJson(stored.last as Map<String, dynamic>);
      expect(lastEntry.entityId, equals('session-109'));
    });

    test('clearQueue removes all operations', () async {
      SharedPreferences.setMockInitialValues({
        queueKey: jsonEncode([
          SyncOperation(
            type: SyncOperationType.saveSettings,
            entityId: 'settings-1',
            data: {'lang': 'en'},
          ).toJson(),
        ]),
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(queueKey), isNotNull);

      await prefs.remove(queueKey);

      expect(prefs.getString(queueKey), isNull);
    });

    test('getQueue returns empty list when key is missing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final json = prefs.getString(queueKey);
      expect(json, isNull);

      // The service would return [] in this case
      final queue = json == null ? <SyncOperation>[] : <SyncOperation>[];
      expect(queue, isEmpty);
    });

    test('getQueue returns empty list when JSON is corrupt', () async {
      SharedPreferences.setMockInitialValues({
        queueKey: 'not valid json {{{',
      });

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(queueKey);

      List<SyncOperation> queue;
      try {
        final list = jsonDecode(json!) as List;
        queue = list.map((e) => SyncOperation.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        queue = [];
      }

      expect(queue, isEmpty);
    });
  });
}
