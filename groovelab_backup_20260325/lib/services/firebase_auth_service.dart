import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Auth service for GrooveLab.
/// Supports anonymous auth (for immediate use), email/password, Google, and Apple Sign-In.
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Current user (null if not signed in)
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether user is signed in (anonymous or full account)
  bool get isSignedIn => _auth.currentUser != null;

  /// Whether user has a real account (not anonymous)
  bool get hasFullAccount =>
      _auth.currentUser != null && !(_auth.currentUser!.isAnonymous);

  /// Sign in anonymously — lets users try the app immediately
  /// without creating an account. Can be upgraded later.
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      debugPrint('FirebaseAuth: Signed in anonymously: ${credential.user?.uid}');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth: Anonymous sign-in error: ${e.code}');
      return null;
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth: Email sign-in error: ${e.code}');
      rethrow;
    }
  }

  /// Create account with email and password
  Future<User?> createAccountWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth: Create account error: ${e.code}');
      rethrow;
    }
  }

  /// Upgrade anonymous account to email/password
  Future<User?> linkAnonymousWithEmail(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) return user;

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      final result = await user.linkWithCredential(credential);
      debugPrint('FirebaseAuth: Anonymous upgraded to email: ${result.user?.email}');
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth: Link error: ${e.code}');
      rethrow;
    }
  }

  /// Sign in with Apple (iOS)
  Future<User?> signInWithApple() async {
    try {
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      final credential = await _auth.signInWithProvider(appleProvider);
      debugPrint('FirebaseAuth: Signed in with Apple: ${credential.user?.uid}');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth: Apple sign-in error: ${e.code}');
      rethrow;
    }
  }

  /// Link anonymous account with Apple
  Future<User?> linkAnonymousWithApple() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) return user;

    try {
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      final result = await user.linkWithProvider(appleProvider);
      debugPrint('FirebaseAuth: Anonymous linked with Apple: ${result.user?.uid}');
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth: Link Apple error: ${e.code}');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Delete account permanently
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }
}

// ── Riverpod Providers ──

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

final hasFullAccountProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null && !user.isAnonymous;
});
