import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// Initialize Firebase for GrooveLab.
///
/// Uses generated firebase_options.dart from `flutterfire configure`.
/// Falls back gracefully if Firebase is unavailable.
Future<bool> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase: Initialized successfully');
    return true;
  } catch (e) {
    debugPrint('Firebase: Init error: $e');
    debugPrint('Firebase: App will continue without cloud sync features.');
    return false;
  }
}
