import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:groovelab/services/persistence_service.dart';
import 'package:groovelab/models/session.dart';
import 'package:groovelab/models/take.dart';

void main() {
  late PersistenceService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = PersistenceService();
  });

  group('Simple values - defaults', () {
    test('getLang returns "es" by default', () async {
      expect(await service.getLang(), equals('es'));
    });

    test('getBpm returns 120 by default', () async {
      expect(await service.getBpm(), equals(120));
    });

    test('getIsPro returns false by default', () async {
      expect(await service.getIsPro(), isFalse);
    });

    test('getLastBpm returns 120 by default', () async {
      expect(await service.getLastBpm(), equals(120));
    });

    test('getLastTimeSig returns "4/4" by default', () async {
      expect(await service.getLastTimeSig(), equals('4/4'));
    });

    test('getLastClickSound returns "Wood" by default', () async {
      expect(await service.getLastClickSound(), equals('Wood'));
    });

    test('getLastSubdivision returns 1 by default', () async {
      expect(await service.getLastSubdivision(), equals(1));
    });

    test('getLastSwing returns 0 by default', () async {
      expect(await service.getLastSwing(), equals(0));
    });

    test('getHapticEnabled returns false by default', () async {
      expect(await service.getHapticEnabled(), isFalse);
    });

    test('getTotalPracticeTime returns 0 by default', () async {
      expect(await service.getTotalPracticeTime(), equals(0.0));
    });

    test('getSessionCount returns 0 by default', () async {
      expect(await service.getSessionCount(), equals(0));
    });

    test('getWeeklyGoalMinutes returns 60 by default', () async {
      expect(await service.getWeeklyGoalMinutes(), equals(60));
    });

    test('getTargetBpm returns 200 by default', () async {
      expect(await service.getTargetBpm(), equals(200));
    });

    test('getHumanFeel returns 0 by default', () async {
      expect(await service.getHumanFeel(), equals(0));
    });

    test('getPolyrhythmEnabled returns false by default', () async {
      expect(await service.getPolyrhythmEnabled(), isFalse);
    });

    test('getPolyrhythmValue returns 3 by default', () async {
      expect(await service.getPolyrhythmValue(), equals(3));
    });

    test('getOnboardingComplete returns false by default', () async {
      expect(await service.getOnboardingComplete(), isFalse);
    });

    test('getDrumVolumes returns default map', () async {
      final volumes = await service.getDrumVolumes();
      expect(volumes, equals({'kick': 1.0, 'snare': 1.0, 'hihat': 1.0, 'ride': 1.0}));
    });
  });

  group('Simple values - set and get round-trip', () {
    test('setLang and getLang', () async {
      await service.setLang('en');
      expect(await service.getLang(), equals('en'));
    });

    test('setBpm and getBpm', () async {
      await service.setBpm(140);
      expect(await service.getBpm(), equals(140));
    });

    test('setIsPro and getIsPro', () async {
      await service.setIsPro(true);
      expect(await service.getIsPro(), isTrue);
    });

    test('setLastBpm and getLastBpm', () async {
      await service.setLastBpm(90);
      expect(await service.getLastBpm(), equals(90));
    });

    test('setLastTimeSig and getLastTimeSig', () async {
      await service.setLastTimeSig('3/4');
      expect(await service.getLastTimeSig(), equals('3/4'));
    });

    test('setLastClickSound and getLastClickSound', () async {
      await service.setLastClickSound('Digital');
      expect(await service.getLastClickSound(), equals('Digital'));
    });

    test('setLastSubdivision and getLastSubdivision', () async {
      await service.setLastSubdivision(4);
      expect(await service.getLastSubdivision(), equals(4));
    });

    test('setLastSwing and getLastSwing', () async {
      await service.setLastSwing(50);
      expect(await service.getLastSwing(), equals(50));
    });

    test('setHapticEnabled and getHapticEnabled', () async {
      await service.setHapticEnabled(true);
      expect(await service.getHapticEnabled(), isTrue);
    });

    test('setTotalPracticeTime and getTotalPracticeTime', () async {
      await service.setTotalPracticeTime(123.5);
      expect(await service.getTotalPracticeTime(), equals(123.5));
    });

    test('setSessionCount and getSessionCount', () async {
      await service.setSessionCount(42);
      expect(await service.getSessionCount(), equals(42));
    });

    test('setWeeklyGoalMinutes and getWeeklyGoalMinutes', () async {
      await service.setWeeklyGoalMinutes(120);
      expect(await service.getWeeklyGoalMinutes(), equals(120));
    });

    test('setTargetBpm and getTargetBpm', () async {
      await service.setTargetBpm(180);
      expect(await service.getTargetBpm(), equals(180));
    });

    test('setHumanFeel and getHumanFeel', () async {
      await service.setHumanFeel(15);
      expect(await service.getHumanFeel(), equals(15));
    });

    test('setPolyrhythmEnabled and getPolyrhythmEnabled', () async {
      await service.setPolyrhythmEnabled(true);
      expect(await service.getPolyrhythmEnabled(), isTrue);
    });

    test('setPolyrhythmValue and getPolyrhythmValue', () async {
      await service.setPolyrhythmValue(5);
      expect(await service.getPolyrhythmValue(), equals(5));
    });

    test('setOnboardingComplete and getOnboardingComplete', () async {
      await service.setOnboardingComplete(true);
      expect(await service.getOnboardingComplete(), isTrue);
    });

    test('setDrumVolumes and getDrumVolumes', () async {
      final volumes = {'kick': 0.5, 'snare': 0.8, 'hihat': 0.3, 'ride': 0.9};
      await service.setDrumVolumes(volumes);
      expect(await service.getDrumVolumes(), equals(volumes));
    });
  });

  group('Sessions', () {
    PracticeSession _makeSession(String id) {
      return PracticeSession(
        id: id,
        startTime: DateTime.parse('2025-01-15T10:00:00.000'),
        endTime: DateTime.parse('2025-01-15T10:30:00.000'),
        bpmStart: 120,
        bpmEnd: 130,
        timeSignature: '4/4',
      );
    }

    test('getSessions returns empty list by default', () async {
      expect(await service.getSessions(), isEmpty);
    });

    test('addSession and getSessions round-trip', () async {
      final session = _makeSession('s1');
      await service.addSession(session);

      final sessions = await service.getSessions();
      expect(sessions, hasLength(1));
      expect(sessions[0].id, equals('s1'));
      expect(sessions[0].bpmStart, equals(120));
      expect(sessions[0].timeSignature, equals('4/4'));
    });

    test('addSession multiple times accumulates', () async {
      await service.addSession(_makeSession('s1'));
      await service.addSession(_makeSession('s2'));
      await service.addSession(_makeSession('s3'));

      final sessions = await service.getSessions();
      expect(sessions, hasLength(3));
    });

    test('addSession enforces max 500 limit', () async {
      // Pre-populate with 499 sessions
      final existing = List.generate(499, (i) => _makeSession('existing-$i'));
      await service.saveSessions(existing);

      // Add 2 more to exceed 500
      await service.addSession(_makeSession('new-1'));
      await service.addSession(_makeSession('new-2'));

      final sessions = await service.getSessions();
      expect(sessions.length, lessThanOrEqualTo(500));

      // The newest sessions should be present
      final ids = sessions.map((s) => s.id).toList();
      expect(ids, contains('new-1'));
      expect(ids, contains('new-2'));
    });

    test('saveSessions overwrites all sessions', () async {
      await service.addSession(_makeSession('old'));
      await service.saveSessions([_makeSession('new')]);

      final sessions = await service.getSessions();
      expect(sessions, hasLength(1));
      expect(sessions[0].id, equals('new'));
    });
  });

  group('Takes', () {
    Take _makeTake(String id, {String sessionId = 'sess-1'}) {
      return Take(
        id: id,
        sessionId: sessionId,
        timestamp: DateTime.parse('2025-01-15T10:00:00.000'),
        bpm: 120,
        timeSignature: '4/4',
        duration: const Duration(seconds: 30),
      );
    }

    test('getTakes returns empty list by default', () async {
      expect(await service.getTakes(), isEmpty);
    });

    test('saveTake and getTakes round-trip', () async {
      await service.saveTake(_makeTake('t1'));

      final takes = await service.getTakes();
      expect(takes, hasLength(1));
      expect(takes[0].id, equals('t1'));
      expect(takes[0].bpm, equals(120));
    });

    test('getTakes filters by sessionId', () async {
      await service.saveTake(_makeTake('t1', sessionId: 'sess-1'));
      await service.saveTake(_makeTake('t2', sessionId: 'sess-2'));
      await service.saveTake(_makeTake('t3', sessionId: 'sess-1'));

      final filtered = await service.getTakes(sessionId: 'sess-1');
      expect(filtered, hasLength(2));
      expect(filtered.every((t) => t.sessionId == 'sess-1'), isTrue);
    });

    test('saveTake enforces max 1000 limit', () async {
      // Pre-populate with 999 takes via StringList
      final prefs = await SharedPreferences.getInstance();
      final entries = List.generate(
        999,
        (i) => jsonEncode(_makeTake('existing-$i').toJson()),
      );
      await prefs.setStringList('takes_list', entries);

      // Add 2 more to exceed 1000
      await service.saveTake(_makeTake('new-1'));
      await service.saveTake(_makeTake('new-2'));

      final takes = await service.getTakes();
      expect(takes.length, lessThanOrEqualTo(1000));

      // Newest should be present
      final ids = takes.map((t) => t.id).toList();
      expect(ids, contains('new-1'));
      expect(ids, contains('new-2'));
    });

    test('takes migration from old single-blob format', () async {
      // Simulate old format: a JSON string under 'takes' key
      final oldTakes = [
        _makeTake('old-1').toJson(),
        _makeTake('old-2').toJson(),
      ];
      SharedPreferences.setMockInitialValues({
        'takes': jsonEncode(oldTakes),
      });
      service = PersistenceService();

      final takes = await service.getTakes();
      expect(takes, hasLength(2));
      expect(takes[0].id, equals('old-1'));
      expect(takes[1].id, equals('old-2'));

      // Verify migration happened: old key removed, new key created
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('takes'), isFalse);
      expect(prefs.containsKey('takes_list'), isTrue);
    });
  });

  group('Library', () {
    test('getLibrary returns default library when key is missing', () async {
      final library = await service.getLibrary();
      expect(library, hasLength(3));
      expect(library[0]['name'], equals('Blues Jam'));
      expect(library[1]['name'], equals('Rock Groove'));
      expect(library[2]['name'], equals('Funk Practice'));
    });

    test('saveLibrary and getLibrary round-trip', () async {
      final custom = [
        {'id': '10', 'name': 'Jazz Standard', 'bpm': 160, 'timeSig': '4/4', 'style': 'Jazz'},
      ];
      await service.saveLibrary(custom);

      final library = await service.getLibrary();
      expect(library, hasLength(1));
      expect(library[0]['name'], equals('Jazz Standard'));
    });

    test('getLibrary returns default on corrupt JSON', () async {
      SharedPreferences.setMockInitialValues({
        'library': 'not json !!!',
      });
      service = PersistenceService();

      final library = await service.getLibrary();
      expect(library, hasLength(3)); // Falls back to default
    });
  });

  group('Routines', () {
    test('getRoutines returns empty list by default', () async {
      expect(await service.getRoutines(), isEmpty);
    });

    test('saveRoutines and getRoutines round-trip', () async {
      final routines = [
        {'id': 'r1', 'name': 'Warm Up', 'steps': []},
        {'id': 'r2', 'name': 'Speed Drill', 'steps': []},
      ];
      await service.saveRoutines(routines);

      final loaded = await service.getRoutines();
      expect(loaded, hasLength(2));
      expect(loaded[0]['name'], equals('Warm Up'));
      expect(loaded[1]['name'], equals('Speed Drill'));
    });

    test('getRoutines returns empty on corrupt JSON', () async {
      SharedPreferences.setMockInitialValues({
        'routines': '{bad json',
      });
      service = PersistenceService();

      expect(await service.getRoutines(), isEmpty);
    });
  });

  group('Setlists', () {
    test('getSetlists returns empty list by default', () async {
      expect(await service.getSetlists(), isEmpty);
    });

    test('saveSetlists and getSetlists round-trip', () async {
      final setlists = [
        {
          'id': 'sl1',
          'name': 'Gig Set',
          'songs': [
            {'id': 's1', 'name': 'Song A', 'bpm': 120, 'timeSig': '4/4'},
          ],
          'autoAdvance': true,
          'createdAt': '2025-01-15T10:00:00.000',
        },
      ];
      await service.saveSetlists(setlists);

      final loaded = await service.getSetlists();
      expect(loaded, hasLength(1));
      expect(loaded[0]['name'], equals('Gig Set'));
      expect((loaded[0]['songs'] as List), hasLength(1));
    });

    test('migration from old songIds format to songs format', () async {
      // Set up library first (migration reads it)
      final library = [
        {'id': 'lib-1', 'name': 'Blues Jam', 'bpm': 80, 'timeSig': '12/8', 'style': 'Blues'},
        {'id': 'lib-2', 'name': 'Rock Groove', 'bpm': 120, 'timeSig': '4/4', 'style': 'Rock'},
      ];

      final oldSetlists = [
        {
          'id': 'sl1',
          'name': 'Old Setlist',
          'songIds': ['lib-1', 'lib-2'],
        },
      ];

      SharedPreferences.setMockInitialValues({
        'library': jsonEncode(library),
        'setlists': jsonEncode(oldSetlists),
      });
      service = PersistenceService();

      final setlists = await service.getSetlists();
      expect(setlists, hasLength(1));

      final sl = setlists[0];
      expect(sl.containsKey('songIds'), isFalse);
      expect(sl.containsKey('songs'), isTrue);

      final songs = sl['songs'] as List;
      expect(songs, hasLength(2));

      final song1 = songs[0] as Map<String, dynamic>;
      expect(song1['id'], equals('lib-1'));
      expect(song1['name'], equals('Blues Jam'));
      expect(song1['bpm'], equals(80));
      expect(song1['timeSig'], equals('12/8'));

      final song2 = songs[1] as Map<String, dynamic>;
      expect(song2['id'], equals('lib-2'));
      expect(song2['name'], equals('Rock Groove'));
      expect(song2['bpm'], equals(120));

      // Auto-added fields
      expect(sl['autoAdvance'], equals(false));
      expect(sl.containsKey('createdAt'), isTrue);
    });

    test('getSetlists returns empty on corrupt JSON', () async {
      SharedPreferences.setMockInitialValues({
        'setlists': '{{not json',
      });
      service = PersistenceService();

      expect(await service.getSetlists(), isEmpty);
    });
  });
}
