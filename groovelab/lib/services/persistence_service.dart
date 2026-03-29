import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';
import '../models/take.dart';

/// Offline-first persistence service.
/// Stores all data locally using SharedPreferences.
class PersistenceService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Simple Values ──

  Future<String> getLang() async => (await prefs).getString('lang') ?? 'es';
  Future<void> setLang(String v) async => (await prefs).setString('lang', v);

  Future<bool> getIsPro() async => (await prefs).getBool('isPro') ?? false;
  Future<void> setIsPro(bool v) async => (await prefs).setBool('isPro', v);

  Future<int> getBpm() async => (await prefs).getInt('bpm') ?? 120;
  Future<void> setBpm(int v) async => (await prefs).setInt('bpm', v);

  // ── Library ──

  Future<List<Map<String, dynamic>>> getLibrary() async {
    final json = (await prefs).getString('library');
    if (json == null) return _defaultLibrary;
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(json));
    } catch (_) {
      return _defaultLibrary;
    }
  }

  Future<void> saveLibrary(List<Map<String, dynamic>> library) async {
    (await prefs).setString('library', jsonEncode(library));
  }

  // ── Sessions ──

  Future<List<PracticeSession>> getSessions() async {
    final json = (await prefs).getString('sessions');
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => PracticeSession.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessions(List<PracticeSession> sessions) async {
    final json = jsonEncode(sessions.map((s) => s.toJson()).toList());
    (await prefs).setString('sessions', json);
  }

  Future<void> addSession(PracticeSession session) async {
    final sessions = await getSessions();
    sessions.add(session);
    // Keep last 500 sessions max
    if (sessions.length > 500) {
      sessions.removeRange(0, sessions.length - 500);
    }
    await saveSessions(sessions);
  }

  // ── Takes ──

  /// Migrate from old single-blob format to per-entry StringList.
  Future<void> _migrateTakesIfNeeded() async {
    final p = await prefs;
    if (p.containsKey('takes') && !p.containsKey('takes_list')) {
      final json = p.getString('takes');
      if (json != null) {
        try {
          final list = jsonDecode(json) as List;
          final entries = list.map((e) => jsonEncode(e)).toList().cast<String>();
          await p.setStringList('takes_list', entries);
        } catch (_) {}
      }
      await p.remove('takes');
    }
  }

  Future<List<Take>> getTakes({String? sessionId}) async {
    await _migrateTakesIfNeeded();
    final entries = (await prefs).getStringList('takes_list');
    if (entries == null || entries.isEmpty) return [];
    try {
      final takes = entries
          .map((e) => Take.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      if (sessionId != null) {
        return takes.where((t) => t.sessionId == sessionId).toList();
      }
      return takes;
    } catch (_) {
      return [];
    }
  }

  /// Append a single take without deserializing all existing entries.
  Future<void> saveTake(Take take) async {
    await _migrateTakesIfNeeded();
    final p = await prefs;
    final entries = p.getStringList('takes_list') ?? [];
    entries.add(jsonEncode(take.toJson()));
    // Keep last 1000 takes
    if (entries.length > 1000) {
      entries.removeRange(0, entries.length - 1000);
    }
    await p.setStringList('takes_list', entries);
  }

  // ── Stats ──

  Future<double> getTotalPracticeTime() async =>
      (await prefs).getDouble('totalPracticeTime') ?? 0;
  Future<void> setTotalPracticeTime(double v) async =>
      (await prefs).setDouble('totalPracticeTime', v);

  Future<int> getSessionCount() async =>
      (await prefs).getInt('sessionCount') ?? 0;
  Future<void> setSessionCount(int v) async =>
      (await prefs).setInt('sessionCount', v);

  // ── Settings ──

  Future<int> getLastBpm() async => (await prefs).getInt('lastBpm') ?? 120;
  Future<void> setLastBpm(int v) async => (await prefs).setInt('lastBpm', v);

  Future<String> getLastTimeSig() async =>
      (await prefs).getString('lastTimeSig') ?? '4/4';
  Future<void> setLastTimeSig(String v) async =>
      (await prefs).setString('lastTimeSig', v);

  Future<String> getLastClickSound() async =>
      (await prefs).getString('lastClickSound') ?? 'Wood';
  Future<void> setLastClickSound(String v) async =>
      (await prefs).setString('lastClickSound', v);

  Future<int> getLastSubdivision() async =>
      (await prefs).getInt('lastSubdivision') ?? 1;
  Future<void> setLastSubdivision(int v) async =>
      (await prefs).setInt('lastSubdivision', v);

  Future<int> getLastSwing() async => (await prefs).getInt('lastSwing') ?? 0;
  Future<void> setLastSwing(int v) async => (await prefs).setInt('lastSwing', v);

  Future<bool> getHapticEnabled() async =>
      (await prefs).getBool('hapticEnabled') ?? false;
  Future<void> setHapticEnabled(bool v) async =>
      (await prefs).setBool('hapticEnabled', v);

  // ── Practice Routines ──

  Future<List<Map<String, dynamic>>> getRoutines() async {
    final json = (await prefs).getString('routines');
    if (json == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(json));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRoutines(List<Map<String, dynamic>> routines) async {
    (await prefs).setString('routines', jsonEncode(routines));
  }

  // ── Weekly Goals ──

  Future<int> getWeeklyGoalMinutes() async =>
      (await prefs).getInt('weeklyGoalMinutes') ?? 60;
  Future<void> setWeeklyGoalMinutes(int v) async =>
      (await prefs).setInt('weeklyGoalMinutes', v);

  // ── Speed Trainer ──

  Future<int> getTargetBpm() async => (await prefs).getInt('targetBpm') ?? 200;
  Future<void> setTargetBpm(int v) async => (await prefs).setInt('targetBpm', v);

  // ── Human Feel & Polyrhythm ──

  Future<int> getHumanFeel() async => (await prefs).getInt('humanFeel') ?? 0;
  Future<void> setHumanFeel(int v) async => (await prefs).setInt('humanFeel', v);

  Future<bool> getPolyrhythmEnabled() async => (await prefs).getBool('polyrhythmEnabled') ?? false;
  Future<void> setPolyrhythmEnabled(bool v) async => (await prefs).setBool('polyrhythmEnabled', v);

  Future<int> getPolyrhythmValue() async => (await prefs).getInt('polyrhythmValue') ?? 3;
  Future<void> setPolyrhythmValue(int v) async => (await prefs).setInt('polyrhythmValue', v);

  // ── Drum Volumes ──

  Future<Map<String, double>> getDrumVolumes() async {
    final json = (await prefs).getString('drumVolumes');
    if (json == null) return {'kick': 1.0, 'snare': 1.0, 'hihat': 1.0, 'ride': 1.0};
    try {
      return Map<String, double>.from(jsonDecode(json));
    } catch (_) {
      return {'kick': 1.0, 'snare': 1.0, 'hihat': 1.0, 'ride': 1.0};
    }
  }

  Future<void> setDrumVolumes(Map<String, double> v) async =>
      (await prefs).setString('drumVolumes', jsonEncode(v));

  // ── Onboarding ──

  Future<bool> getOnboardingComplete() async => (await prefs).getBool('onboardingComplete') ?? false;
  Future<void> setOnboardingComplete(bool v) async => (await prefs).setBool('onboardingComplete', v);

  // ── Setlists ──

  /// Migrate setlists from old format (songIds referencing library) to new
  /// format (self-contained songs with all settings embedded).
  Future<List<Map<String, dynamic>>> _migrateSetlistsIfNeeded(
      List<Map<String, dynamic>> setlists) async {
    bool changed = false;
    final library = await getLibrary();
    for (int i = 0; i < setlists.length; i++) {
      final sl = Map<String, dynamic>.from(setlists[i]);
      // Old format has 'songIds', new format has 'songs'
      if (sl.containsKey('songIds') && !sl.containsKey('songs')) {
        final songIds = (sl['songIds'] as List?)?.cast<String>() ?? [];
        final songs = <Map<String, dynamic>>[];
        for (final id in songIds) {
          final libSong = library.where((s) => s['id'] == id).firstOrNull;
          if (libSong != null) {
            songs.add({
              'id': id,
              'name': libSong['name'] as String? ?? 'Song',
              'bpm': libSong['bpm'] as int? ?? 120,
              'timeSig': libSong['timeSig'] as String? ?? '4/4',
              'subdivision': 1,
              'clickSound': 'Wood',
              'swing': 0,
              'accentPattern': <double>[],
              'hapticMode': false,
              'humanFeel': 0,
              'polyrhythmEnabled': false,
              'polyrhythmValue': 3,
              'drumStyle': libSong['style'] as String? ?? 'Rock',
              'countInBars': 0,
              'notes': '',
            });
          }
        }
        sl['songs'] = songs;
        sl.remove('songIds');
        if (!sl.containsKey('autoAdvance')) sl['autoAdvance'] = false;
        if (!sl.containsKey('createdAt')) {
          sl['createdAt'] = DateTime.now().toIso8601String();
        }
        setlists[i] = sl;
        changed = true;
      }
    }
    if (changed) {
      await saveSetlists(setlists);
    }
    return setlists;
  }

  Future<List<Map<String, dynamic>>> getSetlists() async {
    final json = (await prefs).getString('setlists');
    if (json == null) return [];
    try {
      final setlists = List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e)),
      );
      return _migrateSetlistsIfNeeded(setlists);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSetlists(List<Map<String, dynamic>> setlists) async {
    (await prefs).setString('setlists', jsonEncode(setlists));
  }

  // ── Library ──

  static const _defaultLibrary = [
    {'id': '1', 'name': 'Blues Jam', 'bpm': 80, 'timeSig': '12/8', 'style': 'Blues', 'tags': <String>[], 'isFavorite': false},
    {'id': '2', 'name': 'Rock Groove', 'bpm': 120, 'timeSig': '4/4', 'style': 'Rock', 'tags': <String>[], 'isFavorite': false},
    {'id': '3', 'name': 'Funk Practice', 'bpm': 100, 'timeSig': '4/4', 'style': 'Funk', 'tags': <String>[], 'isFavorite': false},
  ];
}
