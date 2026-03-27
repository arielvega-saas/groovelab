import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'providers/app_providers.dart';
import 'services/revenuecat_service.dart';
import 'services/firebase_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow all orientations — responsive layout handles adaptation.
  // On phones, the UI is optimized for portrait but landscape is allowed.
  // On tablets/desktop, landscape is the preferred experience.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF08090C),
  ));

  // Initialize Firebase (non-blocking — app works without it)
  final firebaseReady = await initializeFirebase();
  if (firebaseReady) {
    debugPrint('GrooveLab: Firebase ready — cloud sync enabled');
  } else {
    debugPrint('GrooveLab: Firebase unavailable — offline mode only');
  }

  // Pre-initialize RevenueCat before the widget tree builds
  final rcService = RevenueCatService();
  await rcService.initialize();

  runApp(ProviderScope(
    overrides: [
      revenueCatServiceProvider.overrideWithValue(rcService),
    ],
    child: const GrooveLabApp(),
  ));
}
