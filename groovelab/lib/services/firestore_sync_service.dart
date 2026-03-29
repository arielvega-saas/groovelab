import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firestore sync service for GrooveLab.
/// Syncs presets, setlists, practice stats, and user settings across devices.
class FirestoreSyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _userDoc =>
      _uid != null ? _db.collection('users').doc(_uid) : null;

  // MARK: - Presets (Pedalera)

  Future<void> savePreset(Map<String, dynamic> preset) async {
    final doc = _userDoc;
    if (doc == null) return;
    final presetId = preset['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    await doc.collection('presets').doc(presetId).set({
      ...preset,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getPresets() async {
    final doc = _userDoc;
    if (doc == null) return [];
    try {
      final snap = await doc.collection('presets')
          .orderBy('updatedAt', descending: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('FirestoreSync: getPresets error: $e');
      return [];
    }
  }

  Future<void> deletePreset(String presetId) async {
    await _userDoc?.collection('presets').doc(presetId).delete();
  }

  // MARK: - Setlists (Metronome)

  Future<void> saveSetlist(Map<String, dynamic> setlist) async {
    final doc = _userDoc;
    if (doc == null) return;
    final setlistId = setlist['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    await doc.collection('setlists').doc(setlistId).set({
      ...setlist,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getSetlists() async {
    final doc = _userDoc;
    if (doc == null) return [];
    try {
      final snap = await doc.collection('setlists')
          .orderBy('updatedAt', descending: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('FirestoreSync: getSetlists error: $e');
      return [];
    }
  }

  Future<void> deleteSetlist(String setlistId) async {
    await _userDoc?.collection('setlists').doc(setlistId).delete();
  }

  // MARK: - Practice Stats

  Future<void> savePracticeSession(Map<String, dynamic> session) async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.collection('practice_sessions').add({
      ...session,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getPracticeSessions({
    int limit = 50,
    DateTime? after,
  }) async {
    final doc = _userDoc;
    if (doc == null) return [];
    try {
      Query query = doc.collection('practice_sessions')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (after != null) {
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(after));
      }

      final snap = await query.get();
      return snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
    } catch (e) {
      debugPrint('FirestoreSync: getPracticeSessions error: $e');
      return [];
    }
  }

  // MARK: - User Settings

  Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    await _userDoc?.set({
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserSettings() async {
    final doc = _userDoc;
    if (doc == null) return null;
    try {
      final snap = await doc.get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>?;
      return data?['settings'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('FirestoreSync: getUserSettings error: $e');
      return null;
    }
  }

  // MARK: - Song Lab (metadata only — audio files in R2/Storage)

  Future<void> saveSongMetadata(Map<String, dynamic> song) async {
    final doc = _userDoc;
    if (doc == null) return;
    final songId = song['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    await doc.collection('songs').doc(songId).set({
      ...song,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getSongs() async {
    final doc = _userDoc;
    if (doc == null) return [];
    try {
      final snap = await doc.collection('songs')
          .orderBy('updatedAt', descending: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('FirestoreSync: getSongs error: $e');
      return [];
    }
  }

  // MARK: - Real-time Listeners

  Stream<List<Map<String, dynamic>>> watchPresets() {
    final doc = _userDoc;
    if (doc == null) return Stream.value([]);
    return doc.collection('presets')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> watchSetlists() {
    final doc = _userDoc;
    if (doc == null) return Stream.value([]);
    return doc.collection('setlists')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}

// ── Riverpod Providers ──

final firestoreSyncProvider = Provider<FirestoreSyncService>((ref) {
  return FirestoreSyncService();
});
