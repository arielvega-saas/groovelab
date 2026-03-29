import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../l10n/translations.dart';
import '../../providers/app_providers.dart';

class LibraryTab extends ConsumerStatefulWidget {
  final VoidCallback onSaveData;
  final VoidCallback onTogglePlay;

  const LibraryTab({
    super.key,
    required this.onSaveData,
    required this.onTogglePlay,
  });

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  final TextEditingController _librarySaveCtrl = TextEditingController();

  @override
  void dispose() {
    _librarySaveCtrl.dispose();
    super.dispose();
  }

  // ── Tempo color by BPM ────────────────────────────────────────
  static Color _tempoColor(int bpm) {
    if (bpm < 80) return const Color(0xFF42A5F5);       // Blue - Grave/Adagio
    if (bpm < 110) return const Color(0xFF26C6DA);      // Cyan - Andante/Moderato
    if (bpm < 130) return const Color(0xFF66BB6A);      // Green - Allegretto
    if (bpm < 160) return const Color(0xFFFFA726);      // Orange - Allegro
    return const Color(0xFFEF5350);                      // Red - Vivace/Presto
  }

  static String _tempoLabel(int bpm) {
    if (bpm < 80) return 'Grave';
    if (bpm < 110) return 'Andante';
    if (bpm < 130) return 'Allegretto';
    if (bpm < 160) return 'Allegro';
    return 'Vivace';
  }

  /// Compute average BPM of songs in a setlist for the accent bar color.
  static Color _setlistAccentColor(List<Map<String, dynamic>> songs) {
    if (songs.isEmpty) return AppColors.accent2;
    final avgBpm = songs.fold<int>(0, (sum, s) => sum + (s['bpm'] as int? ?? 120)) ~/ songs.length;
    return _tempoColor(avgBpm);
  }

  /// Estimate total duration: assume ~3 min per song as a rough baseline.
  static String _estimatedDuration(int songCount) {
    final totalMin = songCount * 3;
    if (totalMin < 60) return '~${totalMin}m';
    final hours = totalMin ~/ 60;
    final mins = totalMin % 60;
    return '~${hours}h ${mins}m';
  }

  /// Apply ALL settings from a setlist song atomically.
  void _applySetlistSong(Map<String, dynamic> song) {
    // Stop playback if running
    if (ref.read(playingProvider)) {
      widget.onTogglePlay();
    }

    // Update ALL providers
    ref.read(bpmProvider.notifier).state = song['bpm'] as int? ?? 120;
    final tsLabel = song['timeSig'] as String? ?? '4/4';
    final ts = timeSignatures.firstWhere(
      (t) => t.label == tsLabel,
      orElse: () => const TimeSig(4, 4, '4/4'),
    );
    ref.read(timeSigProvider.notifier).state = ts;
    ref.read(subdivisionProvider.notifier).state = song['subdivision'] as int? ?? 1;
    ref.read(clickSoundProvider.notifier).state = song['clickSound'] as String? ?? 'Wood';
    ref.read(swingProvider.notifier).state = song['swing'] as int? ?? 0;

    // Accent pattern -- rebuild from time sig if empty
    final accentRaw = song['accentPattern'];
    List<double> accents;
    if (accentRaw is List && accentRaw.isNotEmpty) {
      accents = accentRaw.map((e) => (e as num).toDouble()).toList();
    } else {
      accents = List.generate(ts.num, (i) => i == 0 ? 1.0 : 0.7);
    }
    ref.read(accentPatternProvider.notifier).state = accents;

    ref.read(hapticModeProvider.notifier).state = song['hapticMode'] as bool? ?? false;
    ref.read(humanFeelProvider.notifier).state = song['humanFeel'] as int? ?? 0;
    ref.read(polyrhythmEnabledProvider.notifier).state = song['polyrhythmEnabled'] as bool? ?? false;
    ref.read(polyrhythmValueProvider.notifier).state = song['polyrhythmValue'] as int? ?? 3;
    ref.read(drumStyleProvider.notifier).state = song['drumStyle'] as String? ?? 'Rock';

    // Visual feedback
    final name = song['name'] as String? ?? 'Song';
    final bpm = song['bpm'] as int? ?? 120;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('\u2713 $name \u2014 $bpm BPM',
          style: AppFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.accent,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  /// Capture current metronome settings as a setlist song map.
  Map<String, dynamic> _currentSettingsAsSetlistSong(String name) {
    final ts = ref.read(timeSigProvider);
    return {
      'id': const Uuid().v4(),
      'name': name,
      'bpm': ref.read(bpmProvider),
      'timeSig': ts.label,
      'subdivision': ref.read(subdivisionProvider),
      'clickSound': ref.read(clickSoundProvider),
      'swing': ref.read(swingProvider),
      'accentPattern': ref.read(accentPatternProvider),
      'hapticMode': ref.read(hapticModeProvider),
      'humanFeel': ref.read(humanFeelProvider),
      'polyrhythmEnabled': ref.read(polyrhythmEnabledProvider),
      'polyrhythmValue': ref.read(polyrhythmValueProvider),
      'drumStyle': ref.read(drumStyleProvider),
      'countInBars': 0,
      'notes': '',
    };
  }

  /// Persist setlists helper -- saves after any modification.
  void _persistSetlists() {
    ref.read(persistenceProvider).saveSetlists(ref.read(setlistsProvider));
  }

  /// Move a song within a setlist (direction: -1 = up, +1 = down).
  void _moveSetlistSong(String setlistId, int songIdx, int direction) {
    final allSl = [...ref.read(setlistsProvider)];
    final slIdx = allSl.indexWhere((s) => s['id'] == setlistId);
    if (slIdx < 0) return;
    final songs = List<Map<String, dynamic>>.from(
      (allSl[slIdx]['songs'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final newIdx = songIdx + direction;
    if (newIdx < 0 || newIdx >= songs.length) return;
    final temp = songs[songIdx];
    songs[songIdx] = songs[newIdx];
    songs[newIdx] = temp;
    allSl[slIdx] = {...allSl[slIdx], 'songs': songs};
    ref.read(setlistsProvider.notifier).state = allSl;
    _persistSetlists();
  }

  /// Show context menu for a song in a setlist.
  void _showSongActionsMenu(String setlistId, int songIdx, int totalSongs, String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune, color: AppColors.accent2),
              title: Text(tr(lang, 'editSong'), style: AppFonts.outfit(color: AppColors.textPrimary)),
              onTap: () { Navigator.pop(ctx); _showEditSetlistSongDialog(setlistId, songIdx); },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.textSecondary),
              title: Text(tr(lang, 'duplicateSong'), style: AppFonts.outfit(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _duplicateSetlistSong(setlistId, songIdx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text(tr(lang, 'removeSong'), style: AppFonts.outfit(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _removeSetlistSong(setlistId, songIdx);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Duplicate a song within a setlist.
  void _duplicateSetlistSong(String setlistId, int songIdx) {
    final allSl = [...ref.read(setlistsProvider)];
    final slIdx = allSl.indexWhere((s) => s['id'] == setlistId);
    if (slIdx < 0) return;
    final songs = List<Map<String, dynamic>>.from(
      (allSl[slIdx]['songs'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (songIdx >= songs.length) return;
    final copy = Map<String, dynamic>.from(songs[songIdx]);
    copy['id'] = const Uuid().v4();
    copy['name'] = '${copy["name"]} (copy)';
    songs.insert(songIdx + 1, copy);
    allSl[slIdx] = {...allSl[slIdx], 'songs': songs};
    ref.read(setlistsProvider.notifier).state = allSl;
    _persistSetlists();
  }

  /// Remove a song from a setlist.
  void _removeSetlistSong(String setlistId, int songIdx) {
    final allSl = [...ref.read(setlistsProvider)];
    final slIdx = allSl.indexWhere((s) => s['id'] == setlistId);
    if (slIdx < 0) return;
    final songs = List<Map<String, dynamic>>.from(
      (allSl[slIdx]['songs'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (songIdx >= songs.length) return;
    songs.removeAt(songIdx);
    allSl[slIdx] = {...allSl[slIdx], 'songs': songs};
    ref.read(setlistsProvider.notifier).state = allSl;
    _persistSetlists();
  }

  /// Simple dialog: create a new setlist (name only).
  void _showCreateSetlistDialog() {
    if (!mounted) return;
    final nameCtrl = TextEditingController();
    final lang = ref.read(langProvider);

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(tr(lang, 'newSetlist'),
          style: AppFonts.outfit(color: AppColors.textPrimary, fontSize: 16)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            style: AppFonts.outfit(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: tr(lang, 'setlistName'),
              hintStyle: AppFonts.outfit(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.bgInput,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr(lang, 'cancel'), style: AppFonts.outfit(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr(lang, 'enterName'),
                    style: AppFonts.outfit(color: Colors.white)),
                  backgroundColor: AppColors.danger,
                  duration: const Duration(seconds: 2),
                ));
                return;
              }
              final setlist = {
                'id': const Uuid().v4(),
                'name': name,
                'songs': <Map<String, dynamic>>[],
                'autoAdvance': false,
                'createdAt': DateTime.now().toIso8601String(),
              };
              final setlists = [...ref.read(setlistsProvider), setlist];
              ref.read(setlistsProvider.notifier).state = setlists;
              _persistSetlists();
              HapticFeedback.mediumImpact();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('\u2713 $name',
                  style: AppFonts.outfit(color: Colors.white)),
                backgroundColor: AppColors.accent2,
                duration: const Duration(seconds: 2),
              ));
            },
            child: Text(tr(lang, 'save'),
              style: AppFonts.outfit(color: AppColors.accent2, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Rename a setlist.
  void _showRenameSetlistDialog(String setlistId, String currentName) {
    final nameCtrl = TextEditingController(text: currentName);
    final lang = ref.read(langProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(tr(lang, 'renameSl'),
          style: AppFonts.outfit(color: AppColors.textPrimary, fontSize: 16)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            style: AppFonts.outfit(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: tr(lang, 'setlistName'),
              hintStyle: AppFonts.outfit(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.bgInput,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr(lang, 'cancel'), style: AppFonts.outfit(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final allSl = [...ref.read(setlistsProvider)];
              final idx = allSl.indexWhere((s) => s['id'] == setlistId);
              if (idx >= 0) {
                allSl[idx] = {...allSl[idx], 'name': nameCtrl.text.trim()};
                ref.read(setlistsProvider.notifier).state = allSl;
                _persistSetlists();
              }
              Navigator.of(ctx).pop();
            },
            child: Text(tr(lang, 'save'),
              style: AppFonts.outfit(color: AppColors.accent2, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Add song to setlist -- choose from library or add blank.
  void _showAddSongToSetlistDialog(String setlistId, List<Map<String, dynamic>> library, String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr(lang, 'addSong'),
                style: AppFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
            ),
            // Add blank song (current settings)
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: AppColors.accent),
              title: Text(tr(lang, 'addBlank'),
                style: AppFonts.outfit(color: AppColors.textPrimary)),
              subtitle: Text('${ref.read(bpmProvider)} BPM \u00b7 ${ref.read(timeSigProvider).label}',
                style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                final song = _currentSettingsAsSetlistSong('Song ${DateTime.now().millisecondsSinceEpoch % 1000}');
                _addSongToSetlist(setlistId, song);
              },
            ),
            const Divider(color: AppColors.border, height: 1),
            // Library songs
            if (library.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(tr(lang, 'addFromLibrary'),
                  style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
              ),
              ...library.map((libSong) => ListTile(
                dense: true,
                leading: const Icon(Icons.music_note, size: 18, color: AppColors.textMuted),
                title: Text('${libSong["name"]}',
                  style: AppFonts.outfit(fontSize: 13, color: AppColors.textPrimary)),
                subtitle: Text('${libSong["bpm"]} BPM \u00b7 ${libSong["timeSig"]} \u00b7 ${libSong["style"] ?? "Rock"}',
                  style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  final song = {
                    'id': const Uuid().v4(),
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
                  };
                  _addSongToSetlist(setlistId, song);
                },
              )),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Helper: add a song map to a setlist.
  void _addSongToSetlist(String setlistId, Map<String, dynamic> song) {
    final allSl = [...ref.read(setlistsProvider)];
    final slIdx = allSl.indexWhere((s) => s['id'] == setlistId);
    if (slIdx < 0) return;
    final songs = List<Map<String, dynamic>>.from(
      (allSl[slIdx]['songs'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
    );
    songs.add(song);
    allSl[slIdx] = {...allSl[slIdx], 'songs': songs};
    ref.read(setlistsProvider.notifier).state = allSl;
    _persistSetlists();
  }

  /// Full song editor dialog with ALL 14 settings.
  void _showEditSetlistSongDialog(String setlistId, int songIdx) {
    final allSl = ref.read(setlistsProvider);
    final slIdx = allSl.indexWhere((s) => s['id'] == setlistId);
    if (slIdx < 0) return;
    final songs = (allSl[slIdx]['songs'] as List?) ?? [];
    if (songIdx >= songs.length) return;
    final song = Map<String, dynamic>.from(songs[songIdx] as Map);

    final nameCtrl = TextEditingController(text: song['name'] as String? ?? '');
    final notesCtrl = TextEditingController(text: song['notes'] as String? ?? '');
    final lang = ref.read(langProvider);

    // Mutable state for the dialog
    int bpm = song['bpm'] as int? ?? 120;
    String timeSig = song['timeSig'] as String? ?? '4/4';
    int subdivision = song['subdivision'] as int? ?? 1;
    String clickSound = song['clickSound'] as String? ?? 'Wood';
    int swing = song['swing'] as int? ?? 0;
    bool hapticMode = song['hapticMode'] as bool? ?? false;
    int humanFeel = song['humanFeel'] as int? ?? 0;
    bool polyrhythmEnabled = song['polyrhythmEnabled'] as bool? ?? false;
    int polyrhythmValue = song['polyrhythmValue'] as int? ?? 3;
    String drumStyle = song['drumStyle'] as String? ?? 'Rock';
    int countInBars = song['countInBars'] as int? ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text(tr(lang, 'editSong'),
            style: AppFonts.outfit(color: AppColors.textPrimary, fontSize: 16)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  TextField(
                    controller: nameCtrl,
                    style: AppFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: tr(lang, 'songName'),
                      labelStyle: AppFonts.outfit(color: AppColors.textMuted, fontSize: 11),
                      filled: true, fillColor: AppColors.bgInput,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // BPM + TimeSig row
                  Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BPM', style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => setDialogState(() { if (bpm > 20) bpm--; }),
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.remove, size: 14, color: AppColors.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$bpm', style: AppTheme.monoStyle(size: 16, color: AppColors.textPrimary)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setDialogState(() { if (bpm < 500) bpm++; }),
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(lang, 'timeSignature'), style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          DropdownButton<String>(
                            value: timeSignatures.any((t) => t.label == timeSig) ? timeSig : '4/4',
                            dropdownColor: AppColors.bgCard,
                            style: AppTheme.monoStyle(size: 13, color: AppColors.textPrimary),
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            items: timeSignatures.map((ts) => DropdownMenuItem(
                              value: ts.label, child: Text(ts.label),
                            )).toList(),
                            onChanged: (v) => setDialogState(() { timeSig = v ?? '4/4'; }),
                          ),
                        ],
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Subdivision + Click Sound row
                  Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(lang, 'subdivision'), style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          DropdownButton<int>(
                            value: subdivision,
                            dropdownColor: AppColors.bgCard,
                            style: AppTheme.monoStyle(size: 12, color: AppColors.textPrimary),
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('Quarter')),
                              DropdownMenuItem(value: 2, child: Text('Eighth')),
                              DropdownMenuItem(value: 3, child: Text('Triplet')),
                              DropdownMenuItem(value: 4, child: Text('16th')),
                            ],
                            onChanged: (v) => setDialogState(() { subdivision = v ?? 1; }),
                          ),
                        ],
                      )),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(lang, 'clickSound'), style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          DropdownButton<String>(
                            value: clickSoundNames.contains(clickSound) ? clickSound : 'Wood',
                            dropdownColor: AppColors.bgCard,
                            style: AppTheme.monoStyle(size: 12, color: AppColors.textPrimary),
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            items: clickSoundNames.map((s) => DropdownMenuItem(
                              value: s, child: Text(s),
                            )).toList(),
                            onChanged: (v) => setDialogState(() { clickSound = v ?? 'Wood'; }),
                          ),
                        ],
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Swing slider
                  Text('${tr(lang, "swing")}: $swing%', style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                  Slider(
                    value: swing.toDouble(), min: 0, max: 100,
                    activeColor: AppColors.accent, inactiveColor: AppColors.border,
                    onChanged: (v) => setDialogState(() { swing = v.round(); }),
                  ),
                  // Human Feel slider
                  Text('${tr(lang, "humanFeel")}: $humanFeel%', style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                  Slider(
                    value: humanFeel.toDouble(), min: 0, max: 50,
                    activeColor: AppColors.accent, inactiveColor: AppColors.border,
                    onChanged: (v) => setDialogState(() { humanFeel = v.round(); }),
                  ),
                  // Drum Style + Count-in row
                  Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(lang, 'style'), style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          DropdownButton<String>(
                            value: drumStyles.contains(drumStyle) ? drumStyle : 'Rock',
                            dropdownColor: AppColors.bgCard,
                            style: AppTheme.monoStyle(size: 12, color: AppColors.textPrimary),
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            items: drumStyles.map((s) => DropdownMenuItem(
                              value: s, child: Text(s),
                            )).toList(),
                            onChanged: (v) => setDialogState(() { drumStyle = v ?? 'Rock'; }),
                          ),
                        ],
                      )),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(lang, 'countIn'), style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          DropdownButton<int>(
                            value: countInBars,
                            dropdownColor: AppColors.bgCard,
                            style: AppTheme.monoStyle(size: 12, color: AppColors.textPrimary),
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('Off')),
                              DropdownMenuItem(value: 1, child: Text('1 bar')),
                              DropdownMenuItem(value: 2, child: Text('2 bars')),
                              DropdownMenuItem(value: 4, child: Text('4 bars')),
                            ],
                            onChanged: (v) => setDialogState(() { countInBars = v ?? 0; }),
                          ),
                        ],
                      )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Haptic + Polyrhythm toggles
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setDialogState(() { hapticMode = !hapticMode; }),
                        child: Row(children: [
                          Icon(hapticMode ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 16, color: hapticMode ? AppColors.accent : AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(tr(lang, 'haptic'),
                            style: AppFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => setDialogState(() { polyrhythmEnabled = !polyrhythmEnabled; }),
                        child: Row(children: [
                          Icon(polyrhythmEnabled ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 16, color: polyrhythmEnabled ? AppColors.accent : AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(tr(lang, 'polyrhythm'),
                            style: AppFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                        ]),
                      ),
                    ],
                  ),
                  if (polyrhythmEnabled) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Poly: ', style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                        DropdownButton<int>(
                          value: polyrhythmValue,
                          dropdownColor: AppColors.bgCard,
                          style: AppTheme.monoStyle(size: 12, color: AppColors.textPrimary),
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          items: [2, 3, 4, 5, 6, 7].map((v) => DropdownMenuItem(
                            value: v, child: Text('$v'),
                          )).toList(),
                          onChanged: (v) => setDialogState(() { polyrhythmValue = v ?? 3; }),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Notes
                  Text(tr(lang, 'songNotes'), style: AppFonts.outfit(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: AppFonts.outfit(color: AppColors.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '...',
                      hintStyle: AppFonts.outfit(color: AppColors.textMuted),
                      filled: true, fillColor: AppColors.bgInput,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Capture current settings button
                  GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        bpm = ref.read(bpmProvider);
                        timeSig = ref.read(timeSigProvider).label;
                        subdivision = ref.read(subdivisionProvider);
                        clickSound = ref.read(clickSoundProvider);
                        swing = ref.read(swingProvider);
                        hapticMode = ref.read(hapticModeProvider);
                        humanFeel = ref.read(humanFeelProvider);
                        polyrhythmEnabled = ref.read(polyrhythmEnabledProvider);
                        polyrhythmValue = ref.read(polyrhythmValueProvider);
                        drumStyle = ref.read(drumStyleProvider);
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        color: AppColors.accent.withValues(alpha: 0.05),
                      ),
                      child: Text(tr(lang, 'saveCurrentSettings'),
                        textAlign: TextAlign.center,
                        style: AppFonts.outfit(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr(lang, 'cancel'), style: AppFonts.outfit(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                // Parse time sig for accent pattern
                final tsParts = timeSig.split('/');
                final tsNum = int.tryParse(tsParts[0]) ?? 4;

                final updatedSong = {
                  'id': song['id'] ?? const Uuid().v4(),
                  'name': nameCtrl.text.trim(),
                  'bpm': bpm,
                  'timeSig': timeSig,
                  'subdivision': subdivision,
                  'clickSound': clickSound,
                  'swing': swing,
                  'accentPattern': List.generate(tsNum, (i) => i == 0 ? 1.0 : 0.7),
                  'hapticMode': hapticMode,
                  'humanFeel': humanFeel,
                  'polyrhythmEnabled': polyrhythmEnabled,
                  'polyrhythmValue': polyrhythmValue,
                  'drumStyle': drumStyle,
                  'countInBars': countInBars,
                  'notes': notesCtrl.text.trim(),
                };

                final allSl2 = [...ref.read(setlistsProvider)];
                final idx2 = allSl2.indexWhere((s) => s['id'] == setlistId);
                if (idx2 >= 0) {
                  final songsList = List<Map<String, dynamic>>.from(
                    (allSl2[idx2]['songs'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
                  );
                  if (songIdx < songsList.length) {
                    songsList[songIdx] = updatedSong;
                    allSl2[idx2] = {...allSl2[idx2], 'songs': songsList};
                    ref.read(setlistsProvider.notifier).state = allSl2;
                    _persistSetlists();
                  }
                }
                Navigator.of(ctx).pop();
              },
              child: Text(tr(lang, 'save'),
                style: AppFonts.outfit(color: AppColors.accent2, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog(Map<String, dynamic> song, List<Map<String, dynamic>> library) {
    final tagCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(tr(ref.read(langProvider), 'addTag'),
          style: AppFonts.outfit(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: tagCtrl,
          autofocus: true,
          style: AppFonts.outfit(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'rock, jazz, warmup...',
            hintStyle: AppFonts.outfit(color: AppColors.textMuted),
            filled: true, fillColor: AppColors.bgInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) {
            if (v.trim().isEmpty) return;
            _addTagToSong(song, library, v.trim());
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppFonts.outfit(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (tagCtrl.text.trim().isEmpty) return;
              _addTagToSong(song, library, tagCtrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: Text('Add', style: AppFonts.outfit(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _addTagToSong(Map<String, dynamic> song, List<Map<String, dynamic>> library, String tag) {
    final existingTags = (song['tags'] as List?)?.cast<String>() ?? <String>[];
    if (existingTags.contains(tag)) return;
    final newTags = [...existingTags, tag];
    final lib = library.map((s) {
      if (s['id'] == song['id']) return {...s, 'tags': newTags};
      return s;
    }).toList();
    ref.read(libraryProvider.notifier).state = lib;
    widget.onSaveData();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final library = ref.watch(libraryProvider);
    final search = ref.watch(librarySearchProvider).toLowerCase();
    final favOnly = ref.watch(libraryFavFilterProvider);
    final nameCtrl = _librarySaveCtrl;

    // Filter library
    var filtered = library.where((s) {
      if (favOnly && s['isFavorite'] != true) return false;
      if (search.isNotEmpty) {
        final name = (s['name'] as String).toLowerCase();
        final style = (s['style'] as String? ?? '').toLowerCase();
        final tags = (s['tags'] as List?)?.cast<String>() ?? <String>[];
        if (!name.contains(search) && !style.contains(search) &&
            !tags.any((t) => t.toLowerCase().contains(search))) {
          return false;
        }
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Setlists
          _buildSetlistsPanel(lang, library),
          AppTheme.premiumDivider(margin: const EdgeInsets.symmetric(vertical: 8)),
          // Save current settings
          _panel(tr(lang, 'saveCurrentSettings'), Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  style: AppFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: tr(lang, 'songPlaceholder'),
                    hintStyle: AppFonts.outfit(color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.bgInput,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty) return;
                  final bpm = ref.read(bpmProvider);
                  final ts = ref.read(timeSigProvider);
                  final style = ref.read(drumStyleProvider);
                  final lib = [...library, {
                    'id': const Uuid().v4(),
                    'name': nameCtrl.text,
                    'bpm': bpm,
                    'timeSig': ts.label,
                    'style': style,
                    'tags': <String>[],
                    'isFavorite': false,
                  }];
                  ref.read(libraryProvider.notifier).state = lib;
                  widget.onSaveData();
                  nameCtrl.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDeepest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(tr(lang, 'save'), style: AppFonts.outfit(fontWeight: FontWeight.w700)),
              ),
            ],
          )),
          AppTheme.premiumDivider(margin: const EdgeInsets.symmetric(vertical: 8)),
          // Search + filter bar
          _panel(tr(lang, 'savedSongs'), Column(
            children: [
              AppTheme.sectionHeader(tr(lang, 'savedSongs').toUpperCase(),
                color: AppColors.accent, icon: Icons.library_music_rounded),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => ref.read(librarySearchProvider.notifier).state = v,
                      style: AppFonts.outfit(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: tr(lang, 'searchSongs'),
                        hintStyle: AppFonts.outfit(fontSize: 13, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                        filled: true, fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => ref.read(libraryFavFilterProvider.notifier).state = !favOnly,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: favOnly ? AppColors.accent.withValues(alpha: 0.2) : AppColors.bgInput,
                        border: Border.all(color: favOnly ? AppColors.accent : AppColors.border),
                      ),
                      child: Icon(favOnly ? Icons.favorite : Icons.favorite_border,
                        size: 18, color: favOnly ? AppColors.accent : AppColors.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Neumorphic inset container for song list
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: AppTheme.insetPanel(radius: 12),
                child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(library.isEmpty ? tr(lang, 'noSongsYet') : tr(lang, 'noResults'),
                        style: AppFonts.outfit(color: AppColors.textMuted)),
                    )
                  : Column(
                      children: filtered.map((song) => _librarySongCard(song, library, lang)).toList(),
                    ),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildSetlistsPanel(String lang, List<Map<String, dynamic>> library) {
    final setlists = ref.watch(setlistsProvider);

    return _panel(tr(lang, 'setlists'), Column(
      children: [
        AppTheme.sectionHeader(tr(lang, 'setlists').toUpperCase(),
          color: ModuleColors.library, icon: Icons.queue_music_rounded),
        // ── Empty state ──────────────────────────────────────────
        if (setlists.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppTheme.insetPanel(radius: 14),
            child: Column(
              children: [
                // Illustration icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ModuleColors.library.withValues(alpha: 0.15),
                        ModuleColors.library.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                  child: Icon(Icons.library_music_outlined,
                    size: 32, color: ModuleColors.library.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),
                Text('Start your music library',
                  style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text('Create setlists to organize your songs and practice sessions',
                  textAlign: TextAlign.center,
                  style: AppFonts.outfit(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 20),
                // Prominent Create Setlist button with accent gradient + glow
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showCreateSetlistDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [AppColors.accent2, AppColors.accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent2.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.20),
                          blurRadius: 24,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.playlist_add_rounded, size: 20, color: AppColors.bgDeepest),
                        const SizedBox(width: 8),
                        Text('Create Setlist',
                          style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.bgDeepest)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        // ── Setlist cards ────────────────────────────────────────
        ...setlists.asMap().entries.map((entry) {
          final setlist = entry.value;
          final songs = (setlist['songs'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ?? [];
          final autoAdv = setlist['autoAdvance'] as bool? ?? false;
          final accentColor = _setlistAccentColor(songs);

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: AppTheme.premiumGlassCard(
              radius: 14,
              tint: accentColor,
              glowColor: songs.isNotEmpty ? accentColor.withValues(alpha: 0.15) : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: IntrinsicHeight(child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left accent bar (4px, tempo-based color) ──
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accentColor, accentColor.withValues(alpha: 0.4)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(1, 0),
                        ),
                      ],
                    ),
                  ),
                  // ── Card content ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Name + info chips + actions
                          Row(
                            children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    setlist['name'] as String? ?? 'Setlist',
                                    style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  // Info chips row
                                  Row(
                                    children: [
                                      // Song count chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          color: accentColor.withValues(alpha: 0.10),
                                          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.music_note_rounded, size: 10, color: accentColor),
                                            const SizedBox(width: 3),
                                            Text('${songs.length}',
                                              style: AppTheme.monoStyle(size: 10, color: accentColor)),
                                          ],
                                        ),
                                      ),
                                      if (songs.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        // Duration chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(6),
                                            color: AppColors.bgInset,
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.schedule_rounded, size: 10, color: AppColors.textMuted),
                                              const SizedBox(width: 3),
                                              Text(_estimatedDuration(songs.length),
                                                style: AppTheme.monoStyle(size: 9, color: AppColors.textMuted)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Mini song-count dots visualization
                                        ...List.generate(
                                          songs.length > 8 ? 8 : songs.length,
                                          (i) {
                                            final sBpm = songs[i]['bpm'] as int? ?? 120;
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 2),
                                              child: Container(
                                                width: 5, height: 5,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: _tempoColor(sBpm),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _tempoColor(sBpm).withValues(alpha: 0.5),
                                                      blurRadius: 3,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        if (songs.length > 8)
                                          Text('+${songs.length - 8}',
                                            style: AppTheme.monoStyle(size: 8, color: AppColors.textMuted)),
                                      ],
                                    ],
                                  ),
                                ],
                              )),
                              GestureDetector(
                                onTap: () => _showRenameSetlistDialog(setlist['id'] as String, setlist['name'] as String? ?? ''),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  final updated = setlists.where((s) => s['id'] != setlist['id']).toList();
                                  ref.read(setlistsProvider.notifier).state = updated;
                                  _persistSetlists();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                          AppTheme.premiumDivider(margin: const EdgeInsets.symmetric(vertical: 8)),
                          // ── Songs list (neumorphic inset container) ──
                          if (songs.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: AppTheme.insetPanel(radius: 8),
                              child: Center(
                                child: Text(tr(lang, 'noSongs'),
                                  style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                              ),
                            ),
                          if (songs.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: AppTheme.insetPanel(radius: 10),
                              child: Column(
                                children: songs.asMap().entries.map((songEntry) {
                                  final songIdx = songEntry.key;
                                  final song = songEntry.value;
                                  final songBpm = song['bpm'] as int? ?? 120;
                                  final tColor = _tempoColor(songBpm);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: GestureDetector(
                                      onTap: () => _applySetlistSong(song),
                                      onLongPress: () => _showSongActionsMenu(
                                        setlist['id'] as String, songIdx, songs.length, lang),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgElevated,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                        ),
                                        child: Row(
                                          children: [
                                            // Drag handle
                                            const Icon(Icons.drag_indicator_rounded,
                                              size: 14, color: AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            // Tempo color dot
                                            Container(
                                              width: 8, height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: tColor,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: tColor.withValues(alpha: 0.6),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Song number
                                            Text('${songIdx + 1}.',
                                              style: AppTheme.monoStyle(size: 10, color: AppColors.textMuted)),
                                            const SizedBox(width: 6),
                                            // Song name + subtitle
                                            Expanded(child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(song['name'] as String? ?? 'Song',
                                                  style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500,
                                                    color: AppColors.textPrimary)),
                                                const SizedBox(height: 1),
                                                Text('${song["clickSound"]} \u00b7 ${_tempoLabel(songBpm)}',
                                                  style: AppFonts.outfit(fontSize: 9, color: AppColors.textMuted)),
                                              ],
                                            )),
                                            // BPM + time signature in monospace
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(4),
                                                color: tColor.withValues(alpha: 0.08),
                                              ),
                                              child: Text('${song["bpm"]}',
                                                style: AppTheme.monoStyle(size: 11, weight: FontWeight.w700, color: tColor)),
                                            ),
                                            const SizedBox(width: 4),
                                            Text('${song["timeSig"]}',
                                              style: AppTheme.monoStyle(size: 9, color: AppColors.textSecondary)),
                                            const SizedBox(width: 6),
                                            // Move up/down
                                            if (songIdx > 0)
                                              GestureDetector(
                                                onTap: () => _moveSetlistSong(setlist['id'] as String, songIdx, -1),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(3),
                                                  child: Icon(Icons.arrow_upward, size: 13, color: AppColors.textMuted),
                                                ),
                                              ),
                                            if (songIdx < songs.length - 1)
                                              GestureDetector(
                                                onTap: () => _moveSetlistSong(setlist['id'] as String, songIdx, 1),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(3),
                                                  child: Icon(Icons.arrow_downward, size: 13, color: AppColors.textMuted),
                                                ),
                                              ),
                                            GestureDetector(
                                              onTap: () => _showEditSetlistSongDialog(setlist['id'] as String, songIdx),
                                              child: const Padding(
                                                padding: EdgeInsets.all(3),
                                                child: Icon(Icons.tune, size: 13, color: AppColors.accent2),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Auto-advance toggle
                          GestureDetector(
                            onTap: () {
                              final allSl = [...ref.read(setlistsProvider)];
                              final idx = allSl.indexWhere((s) => s['id'] == setlist['id']);
                              if (idx >= 0) {
                                allSl[idx] = {...allSl[idx], 'autoAdvance': !autoAdv};
                                ref.read(setlistsProvider.notifier).state = allSl;
                                _persistSetlists();
                              }
                            },
                            child: Row(
                              children: [
                                Icon(autoAdv ? Icons.check_box : Icons.check_box_outline_blank,
                                  size: 16, color: autoAdv ? AppColors.accent : AppColors.textMuted),
                                const SizedBox(width: 6),
                                Text(tr(lang, 'autoAdvance'),
                                  style: AppFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Add Song button
                          GestureDetector(
                            onTap: () => _showAddSongToSetlistDialog(setlist['id'] as String, library, lang),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.accent2.withValues(alpha: 0.3)),
                                color: AppColors.accent2.withValues(alpha: 0.05),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_rounded, size: 14, color: AppColors.accent2),
                                  const SizedBox(width: 5),
                                  Text(tr(lang, 'addSong'),
                                    style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent2)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )),
            ),
          );
        }),
        if (setlists.isNotEmpty) ...[
          const SizedBox(height: 8),
          // New Setlist button (only when list is not empty; empty state has its own button)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showCreateSetlistDialog();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent2.withValues(alpha: 0.08),
                    AppColors.accent.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(color: AppColors.accent2.withValues(alpha: 0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent2.withValues(alpha: 0.10),
                    blurRadius: 12,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_add_rounded, size: 18, color: AppColors.accent2),
                  const SizedBox(width: 8),
                  Text(tr(lang, 'newSetlist'),
                    style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent2)),
                ],
              ),
            ),
          ),
        ],
      ],
    ));
  }

  Widget _librarySongCard(Map<String, dynamic> song, List<Map<String, dynamic>> library, String lang) {
    final isFav = song['isFavorite'] == true;
    final tags = (song['tags'] as List?)?.cast<String>() ?? <String>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () {
          ref.read(bpmProvider.notifier).state = song['bpm'] as int;
          final tsLabel = song['timeSig'] as String;
          final ts = timeSignatures.firstWhere((t) => t.label == tsLabel, orElse: () => const TimeSig(4, 4, '4/4'));
          ref.read(timeSigProvider.notifier).state = ts;
          ref.read(drumStyleProvider.notifier).state = song['style'] as String? ?? 'Rock';
          ref.read(tabIndexProvider.notifier).state = 0;
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isFav ? AppColors.accent.withValues(alpha: 0.04) : AppColors.bgInput,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFav ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border,
              width: isFav ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // BPM badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.bgCard,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('${song['bpm']}', style: AppTheme.monoStyle(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song['name'] as String, style: AppFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text('${song['timeSig']}  ·  ${song['style']}',
                          style: AppTheme.monoStyle(size: 10, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  // Favorite toggle
                  GestureDetector(
                    onTap: () {
                      final lib = library.map((s) {
                        if (s['id'] == song['id']) return {...s, 'isFavorite': !(s['isFavorite'] == true)};
                        return s;
                      }).toList();
                      ref.read(libraryProvider.notifier).state = lib;
                      widget.onSaveData();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                        size: 20, color: isFav ? AppColors.accent : AppColors.textMuted),
                    ),
                  ),
                  // Delete
                  GestureDetector(
                    onTap: () {
                      final lib = library.where((s) => s['id'] != song['id']).toList();
                      ref.read(libraryProvider.notifier).state = lib;
                      widget.onSaveData();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
              // Tags row
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.accent.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tag, style: AppFonts.outfit(fontSize: 10, color: AppColors.accent)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            final newTags = tags.where((t) => t != tag).toList();
                            final lib = library.map((s) {
                              if (s['id'] == song['id']) return {...s, 'tags': newTags};
                              return s;
                            }).toList();
                            ref.read(libraryProvider.notifier).state = lib;
                            widget.onSaveData();
                          },
                          child: const Icon(Icons.close, size: 12, color: AppColors.accent),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ],
              // Add tag button
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showAddTagDialog(song, library),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Text(tr(ref.read(langProvider), 'addTag'),
                      style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(String title, Widget content) {
    return AppTheme.premiumPanel(title: title.toUpperCase(), content: content);
  }
}
