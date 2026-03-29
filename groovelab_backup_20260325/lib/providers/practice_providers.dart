import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';

/// Practice, speed trainer, and session tracking providers.
final targetBpmProvider = StateProvider<int>((ref) => 200);
final speedTrainerReachedProvider = StateProvider<bool>((ref) => false);
final autoIncreaseProvider = StateProvider<bool>((ref) => false);
final incrementBpmProvider = StateProvider<int>((ref) => 5);
final incrementBarsProvider = StateProvider<int>((ref) => 4);
final intervalTrainingProvider = StateProvider<bool>((ref) => false);
final clickBarsProvider = StateProvider<int>((ref) => 4);
final silentBarsProvider = StateProvider<int>((ref) => 2);
final randomSilenceProvider = StateProvider<bool>((ref) => false);
final silenceProbProvider = StateProvider<int>((ref) => 25);
final weeklyGoalMinutesProvider = StateProvider<int>((ref) => 60);
final totalPracticeTimeProvider = StateProvider<double>((ref) => 0);
final sessionCountProvider = StateProvider<int>((ref) => 0);
final sessionsHistoryProvider = StateProvider<List<PracticeSession>>((ref) => []);
final routinesProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
