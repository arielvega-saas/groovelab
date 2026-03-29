import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';
import '../../core/theme.dart';
import '../../core/audio/audio_service.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';
import 'pad_models.dart';
import 'pad_file_picker_bridge.dart';

// ═══════════════════════════════════════════════════════════════════
//  PADS TAB - Professional Pad Performance Module
// ═══════════════════════════════════════════════════════════════════

class PadsTab extends ConsumerStatefulWidget {
  const PadsTab({super.key});
  @override
  ConsumerState<PadsTab> createState() => _PadsTabState();
}

class _PadsTabState extends ConsumerState<PadsTab> with TickerProviderStateMixin {
  late AudioService audio;

  // ── Sub-navigation ──
  PadSubView _currentView = PadSubView.live;

  // ── Pad state ──
  List<PadSound> _sounds = [];
  int _activeSoundIndex = -1;
  String? _activeKey;
  bool _isPlaying = false;
  bool _isHolding = false;
  bool _isLoading = false;

  // ── Factory ambient pad loading ──
  final Set<String> _loadingFactoryIds = {};     // currently downloading
  final Set<String> _loadedFactoryIds = {};       // already in engine

  // ── Transport ──
  TransitionMode _transitionMode = TransitionMode.smooth;
  double _masterVolume = 1.0;

  // ── Setlist ──
  List<PadSong> _songs = List.from(kFactoryCMajorPads);
  List<PadSetlist> _setlists = [];
  PadSetlist? _activeSetlist;
  int _activeSetlistSongIdx = 0;

  // ── Mixer ──
  double _padVolume = 1.0;
  double _padPan = 0.0;
  double _clickVolume = 0.7;
  double _clickPan = 0.0;

  // ── Stage mode ──
  bool _stageLocked = false;

  // ── Animation ──
  late AnimationController _pulseController;

  // ── Refresh timer ──
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    // Auto-load the first factory ambient pad so users hear something immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFactoryPadAsset(kFactoryAmbientPads.first);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _ensureAudio() {
    audio = ref.read(audioServiceProvider);
  }

  /// Sync pad playback state reactively instead of polling.
  /// Falls back to a lightweight 500ms check only when a pad is actively playing,
  /// and stops immediately when idle — saving CPU vs the old 300ms always-on timer.
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _syncPadState(); // Immediate check
    // Only poll while a pad is playing; use longer interval to reduce CPU
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) { _refreshTimer?.cancel(); return; }
      _syncPadState();
      // Auto-stop polling when nothing is playing
      if (!_isPlaying) {
        _refreshTimer?.cancel();
        _refreshTimer = null;
      }
    });
  }

  void _syncPadState() {
    final playing = audio.isActivePadPlaying();
    final key = audio.getActivePadKey();
    if (playing != _isPlaying || key != _activeKey) {
      setState(() {
        _isPlaying = playing;
        _activeKey = key;
      });
    }
  }

  // ── Factory asset loader ──
  Future<void> _loadFactoryPadAsset(FactoryPadAsset asset) async {
    if (_loadedFactoryIds.contains(asset.id)) return;
    if (_loadingFactoryIds.contains(asset.id)) return;
    _ensureAudio();
    setState(() => _loadingFactoryIds.add(asset.id));
    try {
      final result = await audio.loadPadFromUrl(asset.urlPath, asset.name, asset.key, 120.0);
      if (!mounted) return;
      if (result['success'] == true) {
        final idx = result['padIndex'] as int;
        final dur = result['duration'] as double;
        setState(() {
          _loadedFactoryIds.add(asset.id);
          _sounds.add(PadSound(
            index: idx,
            name: asset.name,
            duration: dur,
            category: asset.category,
            originalKey: asset.key,
            isFactory: true,
          ));
          // Auto-select first factory sound if nothing loaded yet
          if (_activeSoundIndex < 0) {
            _activeSoundIndex = idx;
            audio.setActivePadSound(idx);
            _startRefreshTimer();
          }
        });
      }
    } catch (e) {
      debugPrint('PadsTab: factory pad load error: $e');
    } finally {
      if (mounted) setState(() => _loadingFactoryIds.remove(asset.id));
    }
  }

  // ── Last imported file info (for visual confirmation) ──
  String? _lastImportedFileName;
  Uint8List? _lastImportedBytes;

  // ── File picker ──
  Future<void> _pickAndLoadSound() async {
    _ensureAudio();
    setState(() => _isLoading = true);
    try {
      late Uint8List bytes;
      late String fileName;

      // Use file_picker directly on native; bridge on web
      if (kIsWeb) {
        final fileData = await pickPadAudioFileWeb();
        if (fileData == null) { if (mounted) setState(() => _isLoading = false); return; }
        bytes = fileData['bytes'] as Uint8List;
        fileName = fileData['name'] as String;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final file = result.files.first;
        if (file.bytes == null) {
          debugPrint('PadsTab: File selected but bytes are null');
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        bytes = file.bytes!;
        fileName = file.name;
      }

      final name = fileName.replaceAll(RegExp(r'\.\w+$'), '');
      await _handleFileLoaded(bytes, name, fileName);
    } catch (e) {
      debugPrint('PadsTab: file pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load audio file', style: AppFonts.outfit(color: Colors.white)),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFileLoaded(Uint8List uint8, String name, [String? originalFileName]) async {
    try {
      final loadResult = await audio.loadPad(uint8, name, 'C', 120);
      if (loadResult['success'] == true) {
        final idx = loadResult['padIndex'] as int;
        final dur = loadResult['duration'] as double;
        setState(() {
          _sounds.add(PadSound(
            index: idx,
            name: name,
            duration: dur,
            category: SoundCategory.userImported,
          ));
          // Always auto-select the newly imported sound and make it playable
          _activeSoundIndex = idx;
          audio.setActivePadSound(idx);
          _startRefreshTimer();
          // Store for visual confirmation
          _lastImportedFileName = originalFileName ?? name;
          _lastImportedBytes = uint8;
        });
        // Show confirmation snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.accent2, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
                      )),
                      Text('${dur.toStringAsFixed(1)}s — Ready to play',
                        style: AppFonts.outfit(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.accent2.withValues(alpha: 0.4)),
            ),
            duration: const Duration(seconds: 3),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not decode audio file', style: AppFonts.outfit(color: Colors.white)),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    } catch (e) {
      debugPrint('PadsTab: file read error: $e');
    }
  }

  // ── Pad actions ──

  void _onKeyTap(String key) {
    _ensureAudio();
    if (_activeSoundIndex < 0) return;
    if (_isHolding) return;

    // MONO toggle: tap same key = stop, tap different key = crossfade
    if (_activeKey == key && _isPlaying) {
      // Toggle off - fade out current key
      audio.fadeOutActivePad(fadeTime: 0.3);
      setState(() {
        _isPlaying = false;
        _activeKey = null;
      });
    } else {
      // Play new key (crossfades automatically from previous)
      audio.playPadAtKey(key);
      setState(() {
        _activeKey = key;
        _isPlaying = true;
      });
    }
  }

  void _onStop() {
    _ensureAudio();
    audio.stopActivePad();
    setState(() {
      _isPlaying = false;
      _activeKey = null;
      _isHolding = false;
    });
  }

  void _onFadeOut() {
    _ensureAudio();
    audio.fadeOutActivePad();
    setState(() => _isHolding = false);
    Future.delayed(Duration(milliseconds: (_transitionMode.defaultDuration * 1000).toInt()), () {
      if (mounted) setState(() { _isPlaying = false; _activeKey = null; });
    });
  }

  void _onHoldToggle() {
    _ensureAudio();
    setState(() => _isHolding = !_isHolding);
    audio.setPadHold(_isHolding);
  }

  void _selectSound(int index) {
    _ensureAudio();
    if (index < 0 || index >= _sounds.length) return;
    final wasPlaying = _isPlaying;
    final prevKey = _activeKey;

    audio.setActivePadSound(_sounds[index].index);
    setState(() => _activeSoundIndex = _sounds[index].index);

    if (wasPlaying && prevKey != null) {
      audio.playPadAtKey(prevKey);
    }
  }

  void _deleteSound(int listIdx) {
    _ensureAudio();
    final sound = _sounds[listIdx];
    if (sound.index == _activeSoundIndex) {
      _onStop();
      _activeSoundIndex = -1;
    }
    audio.removePad(sound.index);
    setState(() => _sounds.removeAt(listIdx));
  }

  void _loadSongPreset(PadSong song) {
    _ensureAudio();
    // Find sound by name or index
    if (song.soundIndex != null && song.soundIndex! >= 0) {
      _selectSound(song.soundIndex!);
    }
    // Apply key
    if (_activeSoundIndex >= 0) {
      audio.playPadAtKey(song.key);
      setState(() {
        _activeKey = song.key;
        _isPlaying = true;
      });
    }
    // Apply volume
    audio.setPadMasterVolume(song.volume);
    setState(() => _masterVolume = song.volume);
  }

  void _setTransitionMode(TransitionMode mode) {
    _ensureAudio();
    audio.setPadTransition(mode.name, mode.defaultDuration);
    setState(() => _transitionMode = mode);
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    _ensureAudio();
    final lang = ref.watch(langProvider);
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            _buildTopBar(lang),
            // ── Sub-navigation ──
            _buildSubNav(),
            // ── Content ──
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildCurrentView(lang, screenW),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTopBar(String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.bgDeepest,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Title
          Text('PADS', style: AppFonts.outfit(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: _isPlaying ? AppColors.accent : AppColors.textPrimary,
            letterSpacing: 2,
          )),
          if (_isPlaying) ...[
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.5 + _pulseController.value * 0.5),
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          // Active sound name
          if (_activeSoundIndex >= 0 && _sounds.isNotEmpty)
            Expanded(
              child: Text(
                _sounds.firstWhere((s) => s.index == _activeSoundIndex, orElse: () => const PadSound(index: -1, name: '—')).name,
                style: AppFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Expanded(child: SizedBox()),
          // Active key badge
          if (_activeKey != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Text(_activeKey!, style: AppTheme.monoStyle(
                size: 14, weight: FontWeight.w700, color: AppColors.accent,
              )),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SUB-NAVIGATION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSubNav() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E0F16), Color(0xFF0B0C12)],
        ),
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.7), width: 0.5)),
      ),
      child: Row(
        children: PadSubView.values.map((view) {
          final selected = view == _currentView;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentView = view),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.accent : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(view.icon, size: 15,
                      color: selected ? AppColors.accent : AppColors.textMuted),
                    const SizedBox(height: 2),
                    Text(view.label, style: AppFonts.outfit(
                      fontSize: 9.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected ? AppColors.accent : AppColors.textMuted,
                    )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentView(String lang, double screenW) {
    switch (_currentView) {
      case PadSubView.live:
        return _LiveView(key: const ValueKey('live'), parent: this);
      case PadSubView.setlist:
        return _SetlistView(key: const ValueKey('setlist'), parent: this);
      case PadSubView.sounds:
        return _SoundsView(key: const ValueKey('sounds'), parent: this);
      case PadSubView.mixer:
        return _MixerView(key: const ValueKey('mixer'), parent: this);
      case PadSubView.stage:
        return _StageView(key: const ValueKey('stage'), parent: this);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  LIVE VIEW - 12-Key Grid + Transport
// ═══════════════════════════════════════════════════════════════════

class _LiveView extends StatelessWidget {
  final _PadsTabState parent;
  const _LiveView({super.key, required this.parent});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final hasSounds = parent._sounds.isNotEmpty;

    return Column(
      children: [
        // ── 12-Key Grid ──
        Expanded(
          child: hasSounds
            ? _buildKeyGrid(screenW)
            : _buildEmptyState(),
        ),
        // ── Transport Bar ──
        _buildTransportBar(),
        // ── Transition Mode Selector ──
        _buildTransitionSelector(),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isAutoLoading = parent._loadingFactoryIds.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.accent.withValues(alpha: 0.15),
                AppColors.accent.withValues(alpha: 0.03),
              ]),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: isAutoLoading
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                  )
                : const Icon(Icons.piano_rounded, size: 28, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          Text(
            isAutoLoading ? 'Loading factory pad...' : 'No pad sound loaded',
            style: AppFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAutoLoading
                ? 'Cello Pads will be ready in a moment'
                : 'Load a factory pad or import your own',
            style: AppFonts.outfit(fontSize: 12, color: AppColors.textMuted),
          ),
          if (!isAutoLoading) ...[
            const SizedBox(height: 24),
            _buildAddSoundButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildAddSoundButton() {
    return GestureDetector(
      onTap: parent._isLoading ? null : parent._pickAndLoadSound,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: parent._isLoading ? null : const LinearGradient(
            colors: [AppColors.accent, AppColors.accent2],
          ),
          color: parent._isLoading ? AppColors.bgInput : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: parent._isLoading ? null : [
            BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: -2),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (parent._isLoading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            else
              const Icon(Icons.upload_file_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Text(parent._isLoading ? 'Loading...' : 'Import Sound',
              style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: parent._isLoading ? AppColors.textMuted : Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyGrid(double screenW) {
    final isWide = screenW > 500;
    final cols = isWide ? 4 : 3;
    final rows = isWide ? 3 : 4;
    final gap = isWide ? 6.0 : 4.0;
    final pad = isWide ? 12.0 : 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth - pad * 2 - gap * (cols - 1);
        final availH = constraints.maxHeight - pad * 2 - gap * (rows - 1);
        final cellW = availW / cols;
        final cellH = availH / rows;

        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(rows, (row) {
              return Padding(
                padding: EdgeInsets.only(bottom: row < rows - 1 ? gap : 0),
                child: Row(
                  children: List.generate(cols, (col) {
                    final idx = row * cols + col;
                    if (idx >= 12) return SizedBox(width: cellW);
                    return Padding(
                      padding: EdgeInsets.only(right: col < cols - 1 ? gap : 0),
                      child: SizedBox(
                        width: cellW,
                        height: cellH,
                        child: _buildKeyPad(musicalKeys[idx]),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildKeyPad(String key) {
    final isActive = parent._activeKey == key && parent._isPlaying;
    final isCurrentKey = parent._activeKey == key;
    final isSharp = key.contains('#');

    return GestureDetector(
      onTap: () => parent._onKeyTap(key),
      onLongPress: () => _showKeyActions(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          // Active → inner gradient + LED glow ring
          // Idle   → neumorphic-out (raised), sharps get subtle colored border
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.bgInset,
                    AppColors.accent.withValues(alpha: 0.08),
                    AppColors.bgInset,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                )
              : null,
          color: isActive
              ? null
              : isSharp ? AppColors.bgDeepest : AppColors.bgPanel,
          border: Border.all(
            color: isActive
                ? AppColors.accent.withValues(alpha: 0.70)
                : isCurrentKey
                    ? AppColors.accent.withValues(alpha: 0.40)
                    : isSharp
                        ? AppColors.accent.withValues(alpha: 0.10)
                        : const Color(0x08FFFFFF),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              // Active: inset shadows + bright glow ring
              ? [
                  const BoxShadow(color: Color(0xFF121212), blurRadius: 6, offset: Offset(3, 3), spreadRadius: -2),
                  const BoxShadow(color: Color(0xFF2A2A2A), blurRadius: 6, offset: Offset(-3, -3), spreadRadius: -2),
                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.60), blurRadius: 10, spreadRadius: 1),
                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: -2),
                ]
              // Idle: neumorphic-out
              : [
                  const BoxShadow(color: Color(0xFF181818), blurRadius: 10, offset: Offset(5, 5)),
                  const BoxShadow(color: Color(0xFF2A2A2A), blurRadius: 10, offset: Offset(-5, -5)),
                ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(key, style: AppTheme.monoStyle(
                size: isActive ? 24 : 20,
                weight: FontWeight.w800,
                color: isActive
                  ? Colors.white
                  : isCurrentKey
                    ? AppColors.accent
                    : isSharp ? AppColors.textSecondary : AppColors.textPrimary,
              )),
              if (isActive) ...[
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) => Container(
                    width: 4, height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.5 + i * 0.2),
                    ),
                  )),
                ),
              ] else if (isSharp) ...[
                const SizedBox(height: 3),
                Container(
                  width: 20, height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: AppColors.borderLight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showKeyActions(String key) {
    // Long-press context menu for a key
    showModalBottomSheet(
      context: parent.context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key: $key', style: AppFonts.outfit(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
            )),
            const SizedBox(height: 16),
            _actionTile(Icons.save, 'Save as Song', () {
              Navigator.pop(parent.context);
              _createSongFromKey(key);
            }),
            _actionTile(Icons.favorite_border, 'Favorite', () => Navigator.pop(parent.context)),
            _actionTile(Icons.music_note, 'Assign Sound', () => Navigator.pop(parent.context)),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(label, style: AppFonts.outfit(fontSize: 14, color: AppColors.textPrimary)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  void _createSongFromKey(String key) {
    final song = PadSong(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Song in $key',
      key: key,
      soundIndex: parent._activeSoundIndex,
      soundName: parent._sounds.isNotEmpty
        ? parent._sounds.firstWhere((s) => s.index == parent._activeSoundIndex,
            orElse: () => const PadSound(index: -1, name: 'Unknown')).name
        : null,
      volume: parent._masterVolume,
      transitionMode: parent._transitionMode,
    );
    parent.setState(() => parent._songs.add(song));
  }

  // ── Transport Bar ──

  Widget _buildTransportBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0E14), Color(0xFF09090E)],
        ),
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _transportBtn(
            icon: Icons.stop_rounded,
            label: 'Stop',
            color: AppColors.danger,
            active: false,
            onTap: parent._isPlaying ? parent._onStop : null,
          ),
          _transportBtn(
            icon: Icons.back_hand_rounded,
            label: 'Hold',
            color: AppColors.warning,
            active: parent._isHolding,
            onTap: parent._isPlaying ? parent._onHoldToggle : null,
          ),
          _transportBtn(
            icon: Icons.trending_down_rounded,
            label: 'Fade',
            color: AppColors.accent,
            active: false,
            onTap: parent._isPlaying ? parent._onFadeOut : null,
          ),
          _transportBtn(
            icon: Icons.add_circle_outline_rounded,
            label: 'Sound',
            color: AppColors.accent2,
            active: false,
            onTap: parent._pickAndLoadSound,
          ),
          // Volume
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.volume_up, size: 14, color: AppColors.textMuted),
                  Expanded(
                    child: SliderTheme(
                      data: AppTheme.neumorphicSliderTheme(AppColors.accent, grooveHeight: 5, thumbRadius: 8),
                      child: Slider(
                        value: parent._masterVolume,
                        onChanged: (v) {
                          parent.setState(() => parent._masterVolume = v);
                          parent.audio.setPadMasterVolume(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transportBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool active,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active
            ? color.withValues(alpha: 0.18)
            : enabled
              ? AppColors.bgCard.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: enabled ? 0.6 : 0.2),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: -2)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: enabled ? (active ? color : color.withValues(alpha: 0.75)) : color.withValues(alpha: 0.25)),
            const SizedBox(height: 3),
            Text(label, style: AppFonts.outfit(
              fontSize: 9, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: enabled ? (active ? color : color.withValues(alpha: 0.7)) : color.withValues(alpha: 0.25),
            )),
          ],
        ),
      ),
    );
  }

  // ── Transition Mode Selector ──

  Widget _buildTransitionSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgDeepest,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 0.5)),
      ),
      child: Row(
        children: [
          Text('XFADE', style: AppTheme.monoStyle(size: 9, weight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          ...TransitionMode.values.map((mode) {
            final selected = mode == parent._transitionMode;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => parent._setTransitionMode(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: selected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 8)] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(mode.icon, size: 11,
                        color: selected ? AppColors.accent : AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(mode.label, style: AppFonts.outfit(
                        fontSize: 10,
                        color: selected ? AppColors.accent : AppColors.textMuted,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SETLIST VIEW
// ═══════════════════════════════════════════════════════════════════

class _SetlistView extends StatefulWidget {
  final _PadsTabState parent;
  const _SetlistView({super.key, required this.parent});
  @override
  State<_SetlistView> createState() => _SetlistViewState();
}

class _SetlistViewState extends State<_SetlistView> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.parent;
    final songs = p._songs;

    return Column(
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('Songs', style: AppFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
              )),
              const SizedBox(width: 8),
              Text('${songs.length}', style: AppTheme.monoStyle(
                size: 12, color: AppColors.textMuted,
              )),
              const Spacer(),
              _headerBtn(Icons.edit, _editMode ? 'Done' : 'Edit', () {
                setState(() => _editMode = !_editMode);
              }),
              const SizedBox(width: 8),
              _headerBtn(Icons.add, 'New', () => _showSongEditor(null)),
            ],
          ),
        ),
        // ── Song list ──
        Expanded(
          child: songs.isEmpty
            ? Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music, size: 40, color: AppColors.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('No songs yet', style: AppFonts.outfit(fontSize: 14, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Text('Create songs to save your pad presets', style: AppFonts.outfit(fontSize: 12, color: AppColors.textMuted.withValues(alpha: 0.6))),
                ],
              ))
            : ReorderableListView.builder(
                itemCount: songs.length,
                onReorder: (oldIdx, newIdx) {
                  if (newIdx > oldIdx) newIdx--;
                  p.setState(() {
                    final song = p._songs.removeAt(oldIdx);
                    p._songs.insert(newIdx, song);
                  });
                },
                itemBuilder: (_, i) => _buildSongCard(songs[i], i),
              ),
        ),
      ],
    );
  }

  Widget _headerBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(label, style: AppFonts.outfit(fontSize: 11, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }

  Widget _buildSongCard(PadSong song, int index) {
    final isActive = widget.parent._activeKey == song.key && widget.parent._isPlaying;

    return Container(
      key: ValueKey(song.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? song.color.withValues(alpha: 0.08) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? song.color.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: song.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(song.key, style: AppTheme.monoStyle(
            size: 14, weight: FontWeight.w700, color: song.color,
          ))),
        ),
        title: Text(song.title, style: AppFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
        )),
        subtitle: Row(
          children: [
            if (song.soundName != null)
              Text(song.soundName!, style: AppFonts.outfit(
                fontSize: 11, color: AppColors.textMuted,
              )),
            if (song.clickEnabled) ...[
              const SizedBox(width: 8),
              Icon(Icons.av_timer, size: 12, color: AppColors.textMuted),
              Text(' ${song.bpm.toInt()}', style: AppTheme.monoStyle(
                size: 11, color: AppColors.textMuted,
              )),
            ],
          ],
        ),
        trailing: _editMode
          ? IconButton(
              icon: const Icon(Icons.delete, size: 18, color: AppColors.danger),
              onPressed: () {
                widget.parent.setState(() => widget.parent._songs.removeAt(index));
              },
            )
          : Icon(Icons.play_arrow, size: 20,
              color: isActive ? song.color : AppColors.textMuted),
        onTap: _editMode ? () => _showSongEditor(song) : () => widget.parent._loadSongPreset(song),
      ),
    );
  }

  void _showSongEditor(PadSong? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SongEditorSheet(
        parent: widget.parent,
        existing: existing,
        onSave: (song) {
          widget.parent.setState(() {
            if (existing != null) {
              final idx = widget.parent._songs.indexWhere((s) => s.id == existing.id);
              if (idx >= 0) widget.parent._songs[idx] = song;
            } else {
              widget.parent._songs.add(song);
            }
          });
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SONG EDITOR SHEET
// ═══════════════════════════════════════════════════════════════════

class _SongEditorSheet extends StatefulWidget {
  final _PadsTabState parent;
  final PadSong? existing;
  final void Function(PadSong) onSave;
  const _SongEditorSheet({required this.parent, this.existing, required this.onSave});
  @override
  State<_SongEditorSheet> createState() => _SongEditorSheetState();
}

class _SongEditorSheetState extends State<_SongEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _notesCtrl;
  late String _key;
  late double _bpm;
  late bool _clickEnabled;
  late double _volume;
  late SoundMood _mood;
  late HarmonicType _harmonicType;
  late int _colorValue;
  late TransitionMode _transitionMode;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _key = e?.key ?? 'C';
    _bpm = e?.bpm ?? 120;
    _clickEnabled = e?.clickEnabled ?? false;
    _volume = e?.volume ?? 1.0;
    _mood = e?.mood ?? SoundMood.neutral;
    _harmonicType = e?.harmonicType ?? HarmonicType.rootOnly;
    _colorValue = e?.colorValue ?? 0xFF00D4FF;
    _transitionMode = e?.transitionMode ?? TransitionMode.smooth;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Row(
              children: [
                Text(widget.existing != null ? 'Edit Song' : 'New Song',
                  style: AppFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Save', style: AppFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black,
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Title ──
            _inputField('Title', _titleCtrl),
            const SizedBox(height: 12),

            // ── Key selector ──
            _sectionLabel('Key'),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: musicalKeys.map((k) => _chipSelect(k, k == _key, () => setState(() => _key = k))).toList(),
            ),
            const SizedBox(height: 12),

            // ── BPM ──
            _sectionLabel('BPM'),
            Row(
              children: [
                _bpmBtn(-5), _bpmBtn(-1),
                const SizedBox(width: 8),
                Text('${_bpm.toInt()}', style: AppTheme.monoStyle(size: 18, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                _bpmBtn(1), _bpmBtn(5),
                const SizedBox(width: 16),
                _chipSelect('Click ${_clickEnabled ? "ON" : "OFF"}', _clickEnabled,
                  () => setState(() => _clickEnabled = !_clickEnabled)),
              ],
            ),
            const SizedBox(height: 12),

            // ── Volume ──
            _sectionLabel('Volume'),
            SliderTheme(
              data: AppTheme.neumorphicSliderTheme(AppColors.accent, grooveHeight: 5, thumbRadius: 8),
              child: Slider(
                value: _volume,
                onChanged: (v) => setState(() => _volume = v),
              ),
            ),

            // ── Mood ──
            _sectionLabel('Mood'),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: SoundMood.values.map((m) => _chipSelect(m.label, m == _mood, () => setState(() => _mood = m))).toList(),
            ),
            const SizedBox(height: 12),

            // ── Harmonic Type ──
            _sectionLabel('Harmonic'),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: HarmonicType.values.map((h) => _chipSelect(h.label, h == _harmonicType, () => setState(() => _harmonicType = h))).toList(),
            ),
            const SizedBox(height: 12),

            // ── Color ──
            _sectionLabel('Color'),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: songColorPresets.map((c) => GestureDetector(
                onTap: () => setState(() => _colorValue = c),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: c == _colorValue
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),

            // ── Notes ──
            _inputField('Notes', _notesCtrl, maxLines: 3),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _save() {
    final song = PadSong(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.isEmpty ? 'Song in $_key' : _titleCtrl.text,
      key: _key,
      soundIndex: widget.parent._activeSoundIndex,
      soundName: widget.parent._sounds.isNotEmpty
        ? widget.parent._sounds.firstWhere((s) => s.index == widget.parent._activeSoundIndex,
            orElse: () => const PadSound(index: -1, name: '')).name
        : null,
      bpm: _bpm,
      clickEnabled: _clickEnabled,
      volume: _volume,
      notes: _notesCtrl.text,
      colorValue: _colorValue,
      mood: _mood,
      harmonicType: _harmonicType,
      transitionMode: _transitionMode,
    );
    widget.onSave(song);
    Navigator.pop(context);
  }

  Widget _inputField(String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: AppFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppFonts.outfit(fontSize: 14, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: AppFonts.outfit(
        fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted,
        letterSpacing: 1,
      )),
    );
  }

  Widget _chipSelect(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Text(label, style: AppFonts.outfit(
          fontSize: 12,
          color: selected ? AppColors.accent : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }

  Widget _bpmBtn(int delta) {
    return GestureDetector(
      onTap: () => setState(() => _bpm = (_bpm + delta).clamp(40, 300)),
      child: Container(
        width: 32, height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: Text(
          delta > 0 ? '+$delta' : '$delta',
          style: AppTheme.monoStyle(size: 10, color: AppColors.textSecondary),
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SOUNDS VIEW
// ═══════════════════════════════════════════════════════════════════

class _SoundsView extends StatefulWidget {
  final _PadsTabState parent;
  const _SoundsView({super.key, required this.parent});
  @override
  State<_SoundsView> createState() => _SoundsViewState();
}

class _SoundsViewState extends State<_SoundsView> {
  SoundCategory? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final p = widget.parent;
    final sounds = p._sounds;
    final filtered = _filterCategory == null
      ? sounds
      : sounds.where((s) => s.category == _filterCategory).toList();

    return Column(
      children: [
        // ── Category filter ──
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _catChip(null, 'All'),
              ...SoundCategory.values.map((c) => _catChip(c, c.label)),
            ],
          ),
        ),
        // ── Content ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              // Factory Library section
              _buildSectionHeader('FACTORY LIBRARY', Icons.auto_awesome_rounded, AppColors.accent2),
              const SizedBox(height: 6),
              ...kFactoryAmbientPads.map((asset) => _buildFactoryCard(asset)),
              const SizedBox(height: 16),
              // Loaded sounds section
              if (filtered.isNotEmpty) ...[
                _buildSectionHeader('LOADED', Icons.playlist_play_rounded, AppColors.accent),
                const SizedBox(height: 6),
                ...filtered.asMap().entries.map((e) => _buildSoundCard(e.value, e.key)),
              ] else if (_filterCategory == null && sounds.isEmpty)
                const SizedBox.shrink()
              else
                _buildEmptySounds(),
              const SizedBox(height: 12),
            ],
          ),
        ),
        // ── Import button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GestureDetector(
            onTap: p._pickAndLoadSound,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.file_upload, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text('Import Sound', style: AppFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent,
                  )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppFonts.outfit(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: color, letterSpacing: 1.5,
        )),
      ],
    );
  }

  Widget _buildFactoryCard(FactoryPadAsset asset) {
    final p = widget.parent;
    final isLoaded = p._loadedFactoryIds.contains(asset.id);
    final isLoading = p._loadingFactoryIds.contains(asset.id);
    final color = Color(asset.colorValue);

    // Find matching PadSound if loaded
    final matchedSound = isLoaded
        ? p._sounds.where((s) => s.name == asset.name && s.isFactory).cast<PadSound?>().firstOrNull
        : null;
    final isActive = matchedSound != null && matchedSound.index == p._activeSoundIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.12)
            : isLoaded
                ? AppColors.bgCard
                : AppColors.bgDeepest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.5)
              : isLoaded
                  ? AppColors.border
                  : AppColors.border.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(asset.category.icon, size: 18, color: color),
        ),
        title: Text(asset.name, style: AppFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w500,
          color: isActive ? color : AppColors.textPrimary,
        )),
        subtitle: Row(
          children: [
            Text(asset.category.label, style: AppFonts.outfit(
              fontSize: 11, color: AppColors.textMuted,
            )),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Key ${asset.key}', style: AppTheme.monoStyle(
                size: 9, color: color, weight: FontWeight.w700,
              )),
            ),
          ],
        ),
        trailing: isLoading
            ? SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: color,
                ),
              )
            : isLoaded
                ? GestureDetector(
                    onTap: matchedSound != null
                        ? () {
                            final idx = p._sounds.indexWhere((s) => s.index == matchedSound.index);
                            if (idx >= 0) p._selectSound(idx);
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isActive ? color.withValues(alpha: 0.2) : AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isActive ? color.withValues(alpha: 0.4) : AppColors.border),
                      ),
                      child: Text(isActive ? 'ACTIVE' : 'USE', style: AppFonts.outfit(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: isActive ? color : AppColors.textMuted,
                        letterSpacing: 1,
                      )),
                    ),
                  )
                : GestureDetector(
                    onTap: () => p._loadFactoryPadAsset(asset),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          color.withValues(alpha: 0.6),
                          color.withValues(alpha: 0.3),
                        ]),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('LOAD', style: AppFonts.outfit(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 1,
                          )),
                        ],
                      ),
                    ),
                  ),
        onTap: isLoaded && matchedSound != null
            ? () {
                final idx = p._sounds.indexWhere((s) => s.index == matchedSound.index);
                if (idx >= 0) p._selectSound(idx);
              }
            : isLoading ? null : () => p._loadFactoryPadAsset(asset),
      ),
    );
  }

  Widget _catChip(SoundCategory? cat, String label) {
    final selected = cat == _filterCategory;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: GestureDetector(
        onTap: () => setState(() => _filterCategory = cat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
            ),
          ),
          child: Text(label, style: AppFonts.outfit(
            fontSize: 11,
            color: selected ? AppColors.accent : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          )),
        ),
      ),
    );
  }

  Widget _buildEmptySounds() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music, size: 40, color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(_filterCategory != null ? 'No ${_filterCategory!.label} sounds' : 'No sounds loaded',
            style: AppFonts.outfit(fontSize: 14, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSoundCard(PadSound sound, int index) {
    final isActive = sound.index == widget.parent._activeSoundIndex;
    final isUserImported = sound.category == SoundCategory.userImported;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent.withValues(alpha: 0.08) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgElevated,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive ? [
              BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 8),
            ] : null,
          ),
          child: Icon(
            sound.category.icon,
            size: 18,
            color: isActive ? AppColors.accent : AppColors.textMuted,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(sound.name, style: AppFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: isActive ? AppColors.accent : AppColors.textPrimary,
              )),
            ),
            if (isUserImported && widget.parent._lastImportedFileName != null
                && sound.name == widget.parent._lastImportedFileName!.replaceAll(RegExp(r'\.\w+$'), ''))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent2.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.accent2.withValues(alpha: 0.3)),
                ),
                child: Text(widget.parent._lastImportedFileName!,
                  style: AppFonts.jetBrainsMono(fontSize: 8, color: AppColors.accent2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(sound.category.label, style: AppFonts.outfit(
              fontSize: 11, color: AppColors.textMuted,
            )),
            const SizedBox(width: 8),
            Text('${sound.duration.toStringAsFixed(1)}s', style: AppTheme.monoStyle(
              size: 11, color: AppColors.textMuted,
            )),
            if (isUserImported) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, size: 12, color: AppColors.accent2.withValues(alpha: 0.7)),
              const SizedBox(width: 3),
              Text('Imported', style: AppFonts.outfit(fontSize: 10, color: AppColors.accent2.withValues(alpha: 0.7))),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('ACTIVE', style: AppFonts.outfit(
                  fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accent,
                  letterSpacing: 1,
                )),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _confirmDelete(index),
              child: Icon(Icons.close, size: 16, color: AppColors.textMuted.withValues(alpha: 0.5)),
            ),
          ],
        ),
        onTap: () => widget.parent._selectSound(index),
      ),
          // Waveform preview for user-imported sounds
          if (isUserImported)
            Container(
              height: 32,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              decoration: BoxDecoration(
                color: AppColors.bgInset,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: CustomPaint(
                  size: const Size(double.infinity, 32),
                  painter: _MiniWaveformPainter(
                    color: isActive ? AppColors.accent : AppColors.textMuted.withValues(alpha: 0.5),
                    seed: sound.name.hashCode,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Delete Sound?', style: AppFonts.outfit(color: AppColors.textPrimary)),
        content: Text('This will remove the sound from the pad.', style: AppFonts.outfit(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppFonts.outfit(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.parent._deleteSound(index);
              setState(() {});
            },
            child: Text('Delete', style: AppFonts.outfit(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  MIXER VIEW
// ═══════════════════════════════════════════════════════════════════

class _MixerView extends StatelessWidget {
  final _PadsTabState parent;
  const _MixerView({super.key, required this.parent});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Master Output ──
        _buildSection('MASTER OUTPUT', [
          _buildChannelStrip(
            name: 'Master',
            icon: Icons.speaker,
            volume: parent._masterVolume,
            onVolumeChanged: (v) {
              parent.setState(() => parent._masterVolume = v);
              parent.audio.setPadMasterVolume(v);
            },
            color: AppColors.accent,
          ),
        ]),
        const SizedBox(height: 12),

        // ── Pad Channel ──
        _buildSection('PAD', [
          _buildChannelStrip(
            name: 'Pad',
            icon: Icons.grid_view,
            volume: parent._padVolume,
            onVolumeChanged: (v) {
              parent.setState(() => parent._padVolume = v);
              // Apply to individual active pad volume
              if (parent._activeSoundIndex >= 0) {
                parent.audio.setPadVolume(parent._activeSoundIndex, v);
              }
            },
            pan: parent._padPan,
            onPanChanged: (v) {
              parent.setState(() => parent._padPan = v);
              parent.audio.setPadRouting(v, parent._clickPan);
            },
            color: AppColors.accent2,
          ),
        ]),
        const SizedBox(height: 12),

        // ── Click Channel ──
        _buildSection('CLICK / GUIDE', [
          _buildChannelStrip(
            name: 'Click',
            icon: Icons.av_timer,
            volume: parent._clickVolume,
            onVolumeChanged: (v) {
              parent.setState(() => parent._clickVolume = v);
              // Apply to guide/click volume via audio engine
              parent.audio.setGuideVolume(v);
            },
            pan: parent._clickPan,
            onPanChanged: (v) {
              parent.setState(() => parent._clickPan = v);
              parent.audio.setPadRouting(parent._padPan, v);
            },
            color: AppColors.warning,
          ),
        ]),
        const SizedBox(height: 12),

        // ── Stereo Routing Presets ──
        _buildSection('ROUTING PRESETS', [
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _routingPreset('Pad L / Click R', -1.0, 1.0),
              _routingPreset('Pad R / Click L', 1.0, -1.0),
              _routingPreset('Center', 0.0, 0.0),
            ],
          ),
        ]),
        const SizedBox(height: 12),

        // ── Crossfade Settings ──
        _buildSection('CROSSFADE', [
          Row(
            children: [
              Text('Time', style: AppFonts.outfit(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: AppTheme.neumorphicSliderTheme(AppColors.accent, grooveHeight: 5, thumbRadius: 8),
                  child: Slider(
                    value: parent._transitionMode.defaultDuration,
                    min: 0.05,
                    max: 5.0,
                    onChanged: (_) {}, // Read-only, controlled by transition mode
                  ),
                ),
              ),
              Text('${parent._transitionMode.defaultDuration.toStringAsFixed(1)}s',
                style: AppTheme.monoStyle(size: 12, color: AppColors.textSecondary)),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.outfit(
            fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted,
            letterSpacing: 1.5,
          )),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildChannelStrip({
    required String name,
    required IconData icon,
    required double volume,
    required ValueChanged<double> onVolumeChanged,
    double? pan,
    ValueChanged<double>? onPanChanged,
    required Color color,
  }) {
    return Column(
      children: [
        // Volume
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(name, style: AppFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
            )),
            const Spacer(),
            Text('${(volume * 100).toInt()}%', style: AppTheme.monoStyle(
              size: 11, color: AppColors.textSecondary,
            )),
          ],
        ),
        SliderTheme(
          data: AppTheme.neumorphicSliderTheme(color, grooveHeight: 5, thumbRadius: 8),
          child: Slider(value: volume, onChanged: onVolumeChanged),
        ),
        // Pan (if provided)
        if (pan != null && onPanChanged != null) ...[
          Row(
            children: [
              Text('L', style: AppTheme.monoStyle(size: 10, color: AppColors.textMuted)),
              Expanded(
                child: SliderTheme(
                  data: AppTheme.neumorphicSliderTheme(color, grooveHeight: 4, thumbRadius: 7),
                  child: Slider(
                    value: pan,
                    min: -1, max: 1,
                    onChanged: onPanChanged,
                  ),
                ),
              ),
              Text('R', style: AppTheme.monoStyle(size: 10, color: AppColors.textMuted)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _routingPreset(String label, double padPan, double guidePan) {
    final isActive = (parent._padPan - padPan).abs() < 0.1 && (parent._clickPan - guidePan).abs() < 0.1;
    return GestureDetector(
      onTap: () {
        parent.setState(() {
          parent._padPan = padPan;
          parent._clickPan = guidePan;
        });
        parent.audio.setPadRouting(padPan, guidePan);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Text(label, style: AppFonts.outfit(
          fontSize: 12,
          color: isActive ? AppColors.accent : AppColors.textSecondary,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  STAGE VIEW - Minimal Performance Mode
// ═══════════════════════════════════════════════════════════════════

class _StageView extends StatelessWidget {
  final _PadsTabState parent;
  const _StageView({super.key, required this.parent});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final hasSounds = parent._sounds.isNotEmpty;
    final hasSetlist = parent._songs.isNotEmpty;
    final currentSong = hasSetlist && parent._activeSetlistSongIdx < parent._songs.length
      ? parent._songs[parent._activeSetlistSongIdx]
      : null;

    return Container(
      color: AppColors.bgDeepest,
      child: parent._stageLocked
        ? _buildLockedScreen()
        : Column(
            children: [
              const Spacer(flex: 1),

              // ── Current state display ──
              _buildCurrentState(currentSong),

              const Spacer(flex: 1),

              // ── Active Key Display ──
              if (parent._isPlaying && parent._activeKey != null)
                Text(parent._activeKey!, style: AppTheme.monoStyle(
                  size: 72, weight: FontWeight.w800, color: AppColors.accent,
                ))
              else
                Text('—', style: AppTheme.monoStyle(
                  size: 72, weight: FontWeight.w300, color: AppColors.textMuted.withValues(alpha: 0.3),
                )),

              const Spacer(flex: 1),

              // ── Big Buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Stop button
                    _bigButton(
                      icon: Icons.stop,
                      label: 'STOP',
                      color: AppColors.danger,
                      onTap: parent._isPlaying ? parent._onStop : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // Hold
                        Expanded(child: _bigButton(
                          icon: Icons.pan_tool,
                          label: 'HOLD',
                          color: AppColors.warning,
                          active: parent._isHolding,
                          onTap: parent._isPlaying ? parent._onHoldToggle : null,
                        )),
                        const SizedBox(width: 12),
                        // Fade Out
                        Expanded(child: _bigButton(
                          icon: Icons.trending_down,
                          label: 'FADE',
                          color: AppColors.accent,
                          onTap: parent._isPlaying ? parent._onFadeOut : null,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Next Song
                    if (hasSetlist)
                      _bigButton(
                        icon: Icons.skip_next,
                        label: currentSong != null ? 'NEXT: ${_nextSongName()}' : 'NEXT',
                        color: AppColors.accent2,
                        onTap: () => _goNextSong(),
                      ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // ── Lock button ──
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () => parent.setState(() => parent._stageLocked = true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text('Lock Screen', style: AppFonts.outfit(
                        fontSize: 12, color: AppColors.textMuted,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildLockedScreen() {
    return GestureDetector(
      onDoubleTap: () => parent.setState(() => parent._stageLocked = false),
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              if (parent._isPlaying && parent._activeKey != null)
                Text(parent._activeKey!, style: AppTheme.monoStyle(
                  size: 56, weight: FontWeight.w800, color: AppColors.accent.withValues(alpha: 0.5),
                )),
              const SizedBox(height: 16),
              Text('Double-tap to unlock', style: AppFonts.outfit(
                fontSize: 13, color: AppColors.textMuted.withValues(alpha: 0.5),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentState(PadSong? currentSong) {
    if (currentSong != null) {
      return Column(
        children: [
          Text(currentSong.title, style: AppFonts.outfit(
            fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
          const SizedBox(height: 4),
          Text('Key: ${currentSong.key}  •  ${currentSong.bpm.toInt()} BPM',
            style: AppTheme.monoStyle(size: 13, color: AppColors.textSecondary)),
        ],
      );
    }

    final activeName = parent._sounds.isNotEmpty && parent._activeSoundIndex >= 0
      ? parent._sounds.firstWhere((s) => s.index == parent._activeSoundIndex,
          orElse: () => const PadSound(index: -1, name: '—')).name
      : 'No sound';

    return Text(activeName, style: AppFonts.outfit(
      fontSize: 16, color: AppColors.textSecondary,
    ));
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required Color color,
    bool active = false,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : (enabled ? color.withValues(alpha: 0.1) : AppColors.bgCard),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : (enabled ? color.withValues(alpha: 0.3) : AppColors.border),
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: enabled ? color : color.withValues(alpha: 0.3)),
            const SizedBox(width: 10),
            Text(label, style: AppFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: enabled ? color : color.withValues(alpha: 0.3),
              letterSpacing: 1,
            )),
          ],
        ),
      ),
    );
  }

  String _nextSongName() {
    final nextIdx = parent._activeSetlistSongIdx + 1;
    if (nextIdx < parent._songs.length) {
      return parent._songs[nextIdx].title;
    }
    return 'End';
  }

  void _goNextSong() {
    final nextIdx = parent._activeSetlistSongIdx + 1;
    if (nextIdx < parent._songs.length) {
      parent.setState(() => parent._activeSetlistSongIdx = nextIdx);
      parent._loadSongPreset(parent._songs[nextIdx]);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  MINI WAVEFORM PAINTER — visual confirmation for imported sounds
// ═══════════════════════════════════════════════════════════════════

class _MiniWaveformPainter extends CustomPainter {
  final Color color;
  final int seed;

  _MiniWaveformPainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final barCount = (size.width / 3).floor();
    final barWidth = size.width / barCount;
    final maxH = size.height * 0.85;
    final midY = size.height / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      // Generate pseudo-waveform shape: envelope rises and falls
      final t = i / barCount;
      final envelope = math.sin(t * math.pi) * 0.7 + 0.3;
      final h = (rng.nextDouble() * 0.6 + 0.2) * maxH * envelope;
      final x = i * barWidth + barWidth / 2;
      canvas.drawLine(
        Offset(x, midY - h / 2),
        Offset(x, midY + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniWaveformPainter old) =>
      old.color != color || old.seed != seed;
}
