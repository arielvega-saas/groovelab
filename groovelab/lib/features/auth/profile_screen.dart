import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firestore_sync_service.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';
import 'dart:io' show Platform;

/// Profile / Account management screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showUpgradeForm = false;
  bool _isLoading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _upgradeWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter email and password');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = ref.read(firebaseAuthServiceProvider);
      await auth.linkAnonymousWithEmail(email, password);
      setState(() {
        _success = 'Account created! Your data will now sync across devices.';
        _showUpgradeForm = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Error creating account');
    } catch (e) {
      setState(() => _error = 'Error creating account');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _upgradeWithApple() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = ref.read(firebaseAuthServiceProvider);
      await auth.linkAnonymousWithApple();
      setState(() => _success = 'Account linked with Apple ID!');
    } catch (e) {
      setState(() => _error = 'Error linking with Apple');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final sync = ref.read(firestoreSyncProvider);
      await sync.getUserSettings();
      setState(() => _success = 'Data synced successfully');
    } catch (e) {
      setState(() => _error = 'Sync failed: check your connection');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your local data will be kept. You can sign back in to restore cloud sync.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Color(0xFFFF9F0A))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(firebaseAuthServiceProvider).signOut();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete your account and all cloud data. '
          'Local data on this device will be kept. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(firebaseAuthServiceProvider).deleteAccount();
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        setState(() => _error = 'Error deleting account. You may need to sign in again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final userAsync = ref.watch(authStateProvider);
    final showApple = !kIsWeb && (Platform.isIOS || Platform.isMacOS);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(tr(lang, 'profile'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00C9A7))),
        error: (_, __) => _buildNoAuth(lang),
        data: (user) => user == null ? _buildNoAuth(lang) : _buildProfile(user, lang, showApple),
      ),
    );
  }

  Widget _buildNoAuth(String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'Not signed in',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to sync your data across devices and backup your presets.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(User user, String lang, bool showApple) {
    final isAnonymous = user.isAnonymous;
    final proState = ref.watch(revenueCatProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar + info
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF00C9A7).withOpacity(0.2),
                  child: Icon(
                    isAnonymous ? Icons.person_outline : Icons.person,
                    size: 40, color: const Color(0xFF00C9A7),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isAnonymous ? 'Anonymous User' : (user.displayName ?? user.email ?? 'User'),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                if (!isAnonymous && user.email != null) ...[
                  const SizedBox(height: 4),
                  Text(user.email!, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: proState.isPro
                        ? const Color(0xFF00C9A7).withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    proState.isPro ? '⭐ Pro' : 'Free',
                    style: TextStyle(
                      color: proState.isPro ? const Color(0xFF00C9A7) : Colors.white.withOpacity(0.5),
                      fontSize: 13, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          if (_success != null) _messageCard(_success!, const Color(0xFF32D74B)),
          if (_error != null) _messageCard(_error!, const Color(0xFFFF3B30)),

          // Upgrade anonymous account
          if (isAnonymous) ...[
            _sectionTitle(tr(lang, 'createAccount')),
            _infoCard(
              icon: Icons.cloud_sync,
              title: 'Sync across devices',
              subtitle: 'Create an account to backup presets, setlists, and practice stats to the cloud.',
            ),
            const SizedBox(height: 12),
            if (showApple)
              _actionButton(
                icon: Icons.apple,
                label: 'Link with Apple ID',
                onTap: _isLoading ? null : _upgradeWithApple,
              ),
            const SizedBox(height: 8),
            _actionButton(
              icon: Icons.email_outlined,
              label: 'Create with Email',
              onTap: _isLoading ? null : () => setState(() => _showUpgradeForm = !_showUpgradeForm),
            ),
            if (_showUpgradeForm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Password (min 6 chars)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _upgradeWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C9A7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr(lang, 'createAccount'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],

          // Cloud sync (for full accounts)
          if (!isAnonymous) ...[
            _sectionTitle('Cloud Sync'),
            _actionButton(icon: Icons.sync, label: 'Sync Now', onTap: _isLoading ? null : _syncNow),
            const SizedBox(height: 24),
          ],

          // Account actions
          _sectionTitle(tr(lang, 'account')),
          _actionButton(icon: Icons.logout, label: 'Sign Out', onTap: _signOut, color: const Color(0xFFFF9F0A)),
          const SizedBox(height: 8),
          _actionButton(icon: Icons.delete_forever, label: 'Delete Account', onTap: _deleteAccount, color: const Color(0xFFFF3B30)),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'ID: ${user.uid.substring(0, 8)}...',
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: TextStyle(
      color: Colors.white.withOpacity(0.5), fontSize: 13,
      fontWeight: FontWeight.w600, letterSpacing: 0.5,
    )),
  );

  Widget _actionButton({required IconData icon, required String label, VoidCallback? onTap, Color? color}) {
    return Material(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: color ?? Colors.white.withOpacity(0.7), size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 16))),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2)),
          ]),
        ),
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00C9A7).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00C9A7).withOpacity(0.15)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF00C9A7), size: 32),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          ],
        )),
      ]),
    );
  }

  Widget _messageCard(String msg, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(msg, style: TextStyle(color: color, fontSize: 14)),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
    filled: true,
    fillColor: Colors.white.withOpacity(0.06),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF00C9A7)),
    ),
  );
}
