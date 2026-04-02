import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'core/audio/audio_service.dart';
import 'models/take.dart';
import 'services/audio_management_service.dart';
import 'services/data_loading_service.dart';
import 'services/persistence_service.dart';
import 'features/timing_analysis/timing_providers.dart';
import 'features/timing_analysis/widgets/timing_heatmap.dart';
import 'features/timing_analysis/widgets/session_metrics.dart';
import 'features/recording/recording_tab.dart';
import 'features/stats/stats_tab.dart';
import 'features/settings/settings_tab.dart';
import 'features/metronome/metronome_tab.dart';
import 'features/drums/drums_tab.dart';
import 'features/practice/practice_tab.dart';
import 'features/library/library_tab.dart';
import 'features/loop_station/loop_station_tab.dart';
import 'features/pads/pads_tab.dart';
import 'features/tuner/tuner_tab.dart';
import 'features/song_lab/song_lab_tab.dart';
import 'features/pedalera/pedalera_tab.dart';
import 'features/pedalera/pedalera_webview.dart';
import 'features/pedalera/pedalera_stub_register.dart'
    if (dart.library.js_interop) 'features/pedalera/pedalera_web_register.dart';
import 'features/playback/playback_tab.dart';
import 'features/home/home_tab.dart';
import 'features/shared/paywall_gate.dart';
import 'core/responsive.dart';
import 'l10n/translations.dart';
import 'providers/app_providers.dart';

// ═══════════════════════════════════════════════════════════════════
//  APP WIDGET — now using native audio engine
// ═══════════════════════════════════════════════════════════════════

class GrooveLabApp extends ConsumerStatefulWidget {
  const GrooveLabApp({super.key});

  @override
  ConsumerState<GrooveLabApp> createState() => _GrooveLabAppState();
}

class _GrooveLabAppState extends ConsumerState<GrooveLabApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  BuildContext get _dialogContext => _navigatorKey.currentContext ?? context;

  // Beat pulse animation
  double _beatPulse = 0.0;

  bool _showOnboarding = false;
  int _onboardingPage = 0;

  // Audio management service (extracted from this file)
  late AudioManagementService _audioManager;

  @override
  void initState() {
    super.initState();
    _audioManager = ref.read(audioManagementProvider);
    _loadDataViaService();
    _initAudioViaService();
    _checkOnboarding();
  }

  Future<void> _loadDataViaService() async {
    await ref.read(dataLoadingServiceProvider).loadAll();
  }

  Future<void> _initAudioViaService() async {
    await _audioManager.init(
      onBeatPulse: _triggerBeatPulse,
    );
  }

  Future<void> _checkOnboarding() async {
    final done = await ref.read(persistenceProvider).getOnboardingComplete();
    if (!done && mounted) {
      setState(() => _showOnboarding = true);
    }
  }

  void _completeOnboarding() async {
    setState(() => _showOnboarding = false);
    await ref.read(persistenceProvider).setOnboardingComplete(true);
  }

  // _initAudio logic now lives in AudioManagementService (see _initAudioViaService above)

  // _loadData and _saveData now delegated to DataLoadingService
  Future<void> _saveData() => ref.read(dataLoadingServiceProvider).saveAll();

  // ── Setlist Core Logic ──

  /// Apply ALL settings from a setlist song atomically.
  void _applySetlistSong(Map<String, dynamic> song) {
    // Stop playback if running
    if (ref.read(playingProvider)) {
      _togglePlay();
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

    // Accent pattern — rebuild from time sig if empty
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
      ScaffoldMessenger.of(_dialogContext).showSnackBar(SnackBar(
        content: Text('✓ $name — $bpm BPM',
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

  /// Navigate to previous song in active setlist.
  void _setlistPrev() {
    final setlist = ref.read(activeSetlistProvider);
    if (setlist == null) return;
    final songs = (setlist['songs'] as List?) ?? [];
    if (songs.isEmpty) return;
    final idx = ref.read(activeSetlistSongIndexProvider);
    if (idx > 0) {
      ref.read(activeSetlistSongIndexProvider.notifier).state = idx - 1;
      _applySetlistSong(Map<String, dynamic>.from(songs[idx - 1]));
    }
  }

  /// Navigate to next song in active setlist.
  void _setlistNext() {
    final setlist = ref.read(activeSetlistProvider);
    if (setlist == null) return;
    final songs = (setlist['songs'] as List?) ?? [];
    if (songs.isEmpty) return;
    final idx = ref.read(activeSetlistSongIndexProvider);
    if (idx < songs.length - 1) {
      ref.read(activeSetlistSongIndexProvider.notifier).state = idx + 1;
      _applySetlistSong(Map<String, dynamic>.from(songs[idx + 1]));
    }
  }

  /// Exit live mode.
  void _exitLiveMode() {
    ref.read(activeSetlistProvider.notifier).state = null;
    ref.read(activeSetlistSongIndexProvider.notifier).state = 0;
    ref.read(setlistAutoAdvanceProvider.notifier).state = false;
  }

  /// Persist setlists helper — saves after any modification.
  void _persistSetlists() {
    ref.read(persistenceProvider).saveSetlists(ref.read(setlistsProvider));
  }

  /// Check if any audio source is currently active.
  bool _isAnyAudioActive() => _audioManager.isAnyAudioActive;

  /// PANIC / STOP ALL — immediately stops every audio source.
  void _stopAllAudio() => _audioManager.stopAllAudio();

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: AppColors.border,
              ),
            ),
            // Settings content
            Expanded(
              child: SettingsTab(
                onSaveData: _saveData,
                audioService: ref.read(audioServiceProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePlay() async {
    await _audioManager.togglePlay();
    // Handle setlist auto-advance after stop
    if (!ref.read(playingProvider) &&
        ref.read(activeSetlistProvider) != null &&
        ref.read(setlistAutoAdvanceProvider)) {
      final setlist = ref.read(activeSetlistProvider)!;
      final songs = (setlist['songs'] as List?) ?? [];
      final idx = ref.read(activeSetlistSongIndexProvider);
      if (idx < songs.length - 1) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _setlistNext();
        });
      }
    }
    // Save data after stop
    if (!ref.read(playingProvider)) {
      _saveData();
    }
  }

  void _toggleRecording() => _audioManager.toggleRecording();

  void _handleLogoTap() {
    // Reserved for future use
  }

  void _onTapTempo() => _audioManager.onTapTempo();

  void _triggerBeatPulse() {
    setState(() => _beatPulse = 1.0);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _beatPulse = 0.0);
    });
  }

  @override
  void dispose() {
    _audioManager.dispose();
    ref.read(audioServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final tabIdx = ref.watch(tabIndexProvider);

    // Web: show/hide pedalera iframe overlay based on active tab
    if (kIsWeb) {
      if (tabIdx == 11) {
        WidgetsBinding.instance.addPostFrameCallback((_) => showPedaleraOverlay());
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => hidePedaleraOverlay());
      }
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'GrooveLab',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: Stack(
            children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
                  defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.linux;
              final isWide = isDesktop || constraints.maxWidth > Responsive.phoneMaxWidth;
              return Row(
                children: [
                  // ── SIDE NAV (tablet/desktop only) ──
                  if (isWide) _buildSideNav(lang, tabIdx),
                  // ── MAIN CONTENT ──
                  Expanded(child: Column(
            children: [
              // ── HEADER ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.bgDeepest,
                  border: Border(bottom: BorderSide(
                    color: AppColors.borderLight.withValues(alpha: 0.5), width: 0.5)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _handleLogoTap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/icons/icon.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                gradient: const LinearGradient(
                                  colors: [AppColors.accent, AppColors.accent2],
                                ),
                              ),
                              child: Center(
                                child: Text('GL', style: AppTheme.monoStyle(
                                  size: 14, weight: FontWeight.w800, color: AppColors.bgDeepest,
                                )),
                              ),
                            ),
                          ),
                        ),
                    ),),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('GrooveLab',
                              style: AppFonts.outfit(
                                fontSize: 20, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            // PRO badge removed — all features unlocked
                          ],
                        ),
                        Text(
                          tr(lang, 'subtitle'),
                          style: AppFonts.outfit(
                            fontSize: 10, fontWeight: FontWeight.w400,
                            color: AppColors.textMuted, letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // ── STOP ALL / PANIC BUTTON ──
                    if (_isAnyAudioActive())
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: _stopAllAudio,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppColors.danger.withValues(alpha: 0.12),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.40), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stop_circle_outlined, size: 13, color: AppColors.danger),
                                const SizedBox(width: 5),
                                Text(
                                  tr(lang, 'stopAll'),
                                  style: AppFonts.outfit(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: AppColors.danger, letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        final activeSetlist = ref.read(activeSetlistProvider);
                        if (activeSetlist != null) {
                          _exitLiveMode();
                        } else {
                          _showSetlistPickerForStage();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: ref.watch(activeSetlistProvider) != null
                            ? AppColors.accent.withValues(alpha: 0.15)
                            : AppColors.bgPanel,
                          border: Border.all(
                            color: ref.watch(activeSetlistProvider) != null
                              ? AppColors.accent.withValues(alpha: 0.60)
                              : AppColors.border,
                            width: ref.watch(activeSetlistProvider) != null ? 1.2 : 0.5,
                          ),
                          boxShadow: ref.watch(activeSetlistProvider) != null
                            ? AppColors.neumorphicRaised(glowColor: AppColors.accent)
                            : AppColors.neumorphicRaised(scale: 0.75),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              ref.watch(activeSetlistProvider) != null
                                ? Icons.close_rounded : Icons.queue_music_rounded,
                              size: 14,
                              color: ref.watch(activeSetlistProvider) != null
                                ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              ref.watch(activeSetlistProvider) != null
                                ? tr(lang, 'exitLive') : tr(lang, 'stage'),
                              style: AppFonts.outfit(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: ref.watch(activeSetlistProvider) != null
                                  ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── SETTINGS GEAR ICON ──
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showSettingsModal(_dialogContext),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bgPanel,
                          border: const Border.fromBorderSide(AppColors.neumorphicBorder),
                          boxShadow: AppColors.neumorphicRaised(scale: 0.80),
                        ),
                        child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              // ── CONTENT ──
              Expanded(
                child: IndexedStack(
                  index: tabIdx,
                  children: [
                    MetronomeTab(onTogglePlay: _togglePlay, onTapTempo: _onTapTempo, beatPulse: _beatPulse, onSaveData: _saveData),
                    DrumsTab(onTogglePlay: _togglePlay, beatPulse: _beatPulse),
                    PaywallGate(feature: 'Recording', child: _buildRecordingTab()),
                    PaywallGate(feature: 'Loop Station', child: LoopStationTab(onTogglePlay: _togglePlay)),
                    PaywallGate(feature: 'Pads', child: const PadsTab()),
                    PracticeTab(onTogglePlay: _togglePlay, onSaveData: _saveData),
                    LibraryTab(onSaveData: _saveData, onTogglePlay: _togglePlay),
                    StatsTab(onSaveData: _saveData),
                    const TunerTab(),
                    const HomeTab(), // index 9
                    PaywallGate(feature: 'Song Lab', child: const SongLabTab()), // index 10
                    PaywallGate(feature: 'Pedalera', child: const PedaleraWebView()), // index 11
                    PaywallGate(feature: 'PlayBack', child: const PlaybackTab()), // index 12
                  ],
                ),
              ),

              // ── GLOBAL AUDIO STATUS BAR ──
              if (_isAnyAudioActive())
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeepest,
                    border: Border(top: BorderSide(
                      color: AppColors.borderLight.withValues(alpha: 0.4), width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      // Animated status dot — pulsing ring when recording
                      RecordPulseRing(
                        isRecording: ref.watch(loopIsRecordingProvider) || ref.watch(isRecordingProvider),
                        size: 7,
                        child: Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ref.watch(loopIsRecordingProvider) || ref.watch(isRecordingProvider)
                                ? AppColors.danger : AppColors.warm,
                            boxShadow: [BoxShadow(
                              color: (ref.watch(loopIsRecordingProvider) || ref.watch(isRecordingProvider)
                                  ? AppColors.danger : AppColors.warm).withValues(alpha: 0.65),
                              blurRadius: 8, spreadRadius: 1,
                            )],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (ref.watch(playingProvider))
                        Text('${ref.watch(bpmProvider)} BPM', style: AppTheme.monoStyle(
                          size: 11, color: AppColors.textSecondary, weight: FontWeight.w500,
                        )),
                      if (ref.watch(playingProvider) && ref.watch(loopIsPlayingProvider))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(width: 1, height: 10, color: AppColors.borderLight),
                        ),
                      if (ref.watch(loopIsPlayingProvider))
                        Text('LOOP', style: AppFonts.outfit(
                          fontSize: 10, color: AppColors.warm, fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        )),
                      if (ref.watch(loopIsRecordingProvider))
                        Text(' ● REC', style: AppFonts.outfit(
                          fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        )),
                      const Spacer(),
                      GestureDetector(
                        onTap: _stopAllAudio,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.30), width: 0.8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.stop_rounded, size: 12, color: AppColors.danger),
                            const SizedBox(width: 4),
                            Text('STOP', style: AppFonts.outfit(
                              fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                            )),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── BOTTOM NAV (hidden on desktop/wide screens — side nav is used instead) ──
              Builder(builder: (context) {
                final isDesktopNav = defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.linux;
                final isWideNav = isDesktopNav || MediaQuery.sizeOf(context).width > Responsive.phoneMaxWidth;
                if (isWideNav) return const SizedBox.shrink();
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgDeepest,
                    border: Border(top: BorderSide(
                      color: AppColors.borderLight.withValues(alpha: 0.45), width: 0.5)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const tabW = AppSizes.navTabWidth;
                        final totalW = tabW * 10;
                        final useFlex = constraints.maxWidth >= totalW;

                        Widget buildTabs({bool flex = false}) {
                          final tabs = [
                            _navTab(9, Icons.home_rounded,             'Home',                   flex ? null : tabW),
                            _navTab(0, Icons.speed_rounded,            tr(lang, 'tabMetronome'), flex ? null : tabW),
                            _navTab(1, Icons.view_week_rounded,        tr(lang, 'tabDrums'),     flex ? null : tabW),
                            _navTab(4, Icons.piano_rounded,            tr(lang, 'tabPads'),      flex ? null : tabW),
                            _navTab(3, Icons.autorenew_rounded,        tr(lang, 'tabLooper'),    flex ? null : tabW),
                            _navTab(8, Icons.graphic_eq_rounded,       tr(lang, 'tabTuner'),     flex ? null : tabW),
                            _navTab(6, Icons.library_books_rounded,   tr(lang, 'tabLibrary'),   flex ? null : tabW),
                            _navTab(11, Icons.cable_rounded,          'Pedalera',               flex ? null : tabW),
                            _navTab(12, Icons.play_circle_rounded,   'PlayBack',               flex ? null : tabW),
                            _navTab(10, Icons.library_music_rounded,  tr(lang, 'tabSongLab'),   flex ? null : tabW),
                          ];
                          if (flex) {
                            return Row(children: tabs.map((t) => Expanded(child: t)).toList());
                          }
                          return Row(children: tabs);
                        }

                        if (useFlex) {
                          return SizedBox(
                            height: AppSizes.navBarHeight,
                            child: buildTabs(flex: true),
                          );
                        }
                        return SizedBox(
                          height: AppSizes.navBarHeight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: buildTabs(flex: false),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          )), // close Expanded + Column
                ],
              ); // close Row
            }, // close LayoutBuilder builder
          ), // close LayoutBuilder
          // Setlist Live Mode overlay
          if (ref.watch(activeSetlistProvider) != null) _buildSetlistLiveMode(lang),
          // Onboarding overlay
          if (_showOnboarding) _buildOnboarding(lang),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboarding(String lang) {
    final pages = [
      {'icon': Icons.speed, 'title': tr(lang, 'onb1Title'), 'desc': tr(lang, 'onb1Desc')},
      {'icon': Icons.grid_on, 'title': tr(lang, 'onb2Title'), 'desc': tr(lang, 'onb2Desc')},
      {'icon': Icons.mic, 'title': tr(lang, 'onb3Title'), 'desc': tr(lang, 'onb3Desc')},
      {'icon': Icons.fitness_center, 'title': tr(lang, 'onb4Title'), 'desc': tr(lang, 'onb4Desc')},
    ];

    final page = pages[_onboardingPage];
    final isLast = _onboardingPage == pages.length - 1;

    return Container(
      color: AppColors.bgDeepest.withValues(alpha: 0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent2]),
                ),
                child: Icon(page['icon'] as IconData, size: 40, color: AppColors.bgDeepest),
              ),
              const SizedBox(height: 24),
              Text(page['title'] as String, style: AppFonts.outfit(
                fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
              )),
              const SizedBox(height: 12),
              Text(page['desc'] as String, textAlign: TextAlign.center, style: AppFonts.outfit(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5,
              )),
              const SizedBox(height: 40),
              // Page dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) => Container(
                  width: i == _onboardingPage ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i == _onboardingPage ? AppColors.accent : AppColors.bgElevated,
                  ),
                )),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  if (isLast) {
                    _completeOnboarding();
                  } else {
                    setState(() => _onboardingPage++);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent2]),
                  ),
                  child: Center(
                    child: Text(
                      isLast ? tr(lang, 'onbStart') : tr(lang, 'onbNext'),
                      style: AppFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.bgDeepest,
                      ),
                    ),
                  ),
                ),
              ),
              if (!isLast) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _completeOnboarding,
                  child: Text(tr(lang, 'onbSkip'), style: AppFonts.outfit(
                    fontSize: 13, color: AppColors.textMuted,
                  )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Side navigation rail for tablet/desktop (width > 600dp).
  Widget _buildSideNav(String lang, int tabIdx) {
    final navItems = [
      (9, Icons.home_rounded, 'Home'),
      (0, Icons.speed_rounded, tr(lang, 'tabMetronome')),
      (1, Icons.view_week_rounded, tr(lang, 'tabDrums')),
      (4, Icons.piano_rounded, tr(lang, 'tabPads')),
      (3, Icons.autorenew_rounded, tr(lang, 'tabLooper')),
      (8, Icons.graphic_eq_rounded, tr(lang, 'tabTuner')),
      (11, Icons.cable_rounded, 'Pedalera'),
      (12, Icons.play_circle_rounded, 'PlayBack'),
      (10, Icons.library_music_rounded, tr(lang, 'tabSongLab')),
      (6, Icons.library_books_rounded, tr(lang, 'tabLibrary')),
    ];

    // Map tabIdx to rail selectedIndex
    final selectedIndex = navItems.indexWhere((item) => item.$1 == tabIdx);

    return NavigationRail(
      backgroundColor: AppColors.bgDeepest,
      selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
      onDestinationSelected: (index) {
        HapticFeedback.selectionClick();
        ref.read(tabIndexProvider.notifier).state = navItems[index].$1;
      },
      labelType: NavigationRailLabelType.all,
      indicatorColor: AppColors.accent.withValues(alpha: 0.15),
      selectedIconTheme: const IconThemeData(color: AppColors.accent, size: 22),
      unselectedIconTheme: const IconThemeData(color: AppColors.textMuted, size: 20),
      selectedLabelTextStyle: AppFonts.outfit(
        fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent,
      ),
      unselectedLabelTextStyle: AppFonts.outfit(
        fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.textMuted,
      ),
      leading: const SizedBox(height: 8), // Logo is in the header bar, no duplicate needed
      destinations: navItems.map((item) => NavigationRailDestination(
        icon: Icon(item.$2),
        selectedIcon: Icon(item.$2),
        label: Text(item.$3),
      )).toList(),
    );
  }

  Widget _navTab(int idx, IconData icon, String label, [double? width]) {
    final active = ref.watch(tabIndexProvider) == idx;
    final isRec = ref.watch(isRecordingProvider);
    final showDot = idx == 2 && isRec;
    // Smart label: keep meaningful chars, don't hard-truncate words
    final shortLabel = label.length > 8 ? label.substring(0, 7) : label;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(tabIndexProvider.notifier).state = idx;
      },
      child: SizedBox(
        width: width,
        height: AppSizes.navBarHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // ── Top line indicator (Logic Pro / iOS 18 style) ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 2,
              width: active ? 28.0 : 0.0,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                color: AppColors.accent,
                boxShadow: active ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.80),
                    blurRadius: 10, spreadRadius: 1,
                  ),
                ] : null,
              ),
            ),
            const SizedBox(height: 6),

            // ── Icon + notification dot ──
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedScale(
                  scale: active ? 1.18 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    icon,
                    size: 22,
                    color: active
                        ? AppColors.accent
                        : AppColors.textMuted.withValues(alpha: 0.55),
                    shadows: active ? [
                      Shadow(
                        color: AppColors.accent.withValues(alpha: 0.50),
                        blurRadius: 10,
                      ),
                    ] : null,
                  ),
                ),
                if (showDot)
                  Positioned(
                    right: -5, top: -3,
                    child: Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bgDeepest, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: AppColors.danger.withValues(alpha: 0.70), blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),

            // ── Label ──
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: AppFonts.outfit(
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active
                    ? AppColors.accent
                    : AppColors.textMuted.withValues(alpha: 0.45),
                letterSpacing: active ? 0.5 : 0.1,
                height: 1,
              ),
              child: Text(shortLabel, maxLines: 1, overflow: TextOverflow.clip),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Metronome and Drums tabs extracted to features/metronome/ and features/drums/

  // ═══════════════════════════════════════════════════════════════════
  //  WEB RECORDING TAB
  // ═══════════════════════════════════════════════════════════════════

  Timer? _webRecTimer;

  Widget _buildWebRecordingTab(String lang) {
    final webState = ref.watch(webRecStateProvider);
    final hasRec = ref.watch(webRecHasRecordingProvider);
    final recDuration = ref.watch(recordingDurationProvider);
    final recMinutes = recDuration.inMinutes.toString().padLeft(2, '0');
    final recSeconds = (recDuration.inSeconds % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Recording display
          _panel('RECORD', Column(
            children: [
              // Status indicator
              Container(
                width: double.infinity,
                height: 120,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: webState == 'recording' ? AppColors.danger : AppColors.border,
                    width: webState == 'recording' ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (webState == 'recording') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12, height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$recMinutes:$recSeconds',
                            style: AppTheme.monoStyle(size: 32, weight: FontWeight.w800, color: AppColors.danger)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(lang == 'es' ? 'Grabando...' : lang == 'pt' ? 'Gravando...' : 'Recording...',
                        style: AppFonts.outfit(fontSize: 13, color: AppColors.danger)),
                    ] else if (webState == 'stopped' || (webState == 'idle' && hasRec)) ...[
                      Icon(Icons.check_circle, size: 32, color: AppColors.accent2),
                      const SizedBox(height: 8),
                      Text('$recMinutes:$recSeconds',
                        style: AppTheme.monoStyle(size: 24, weight: FontWeight.w700, color: AppColors.accent2)),
                      Text(lang == 'es' ? 'Grabación lista' : lang == 'pt' ? 'Gravação pronta' : 'Recording ready',
                        style: AppFonts.outfit(fontSize: 12, color: AppColors.textMuted)),
                    ] else if (webState == 'playing') ...[
                      Icon(Icons.volume_up, size: 32, color: AppColors.accent),
                      const SizedBox(height: 8),
                      Text(lang == 'es' ? 'Reproduciendo...' : lang == 'pt' ? 'Reproduzindo...' : 'Playing...',
                        style: AppFonts.outfit(fontSize: 14, color: AppColors.accent)),
                    ] else if (webState == 'permission_denied') ...[
                      Icon(Icons.mic_off, size: 32, color: AppColors.danger),
                      const SizedBox(height: 8),
                      Text(lang == 'es' ? 'Permiso de micrófono denegado' : lang == 'pt' ? 'Permissão de microfone negada' : 'Microphone permission denied',
                        textAlign: TextAlign.center,
                        style: AppFonts.outfit(fontSize: 13, color: AppColors.danger)),
                      Text(lang == 'es' ? 'Habilitá el micrófono en los ajustes del navegador' : 'Enable microphone in browser settings',
                        textAlign: TextAlign.center,
                        style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                    ] else if (webState == 'error') ...[
                      Icon(Icons.error_outline, size: 32, color: AppColors.warning),
                      const SizedBox(height: 8),
                      Text(lang == 'es' ? 'No se pudo acceder al micrófono' : 'Could not access microphone',
                        textAlign: TextAlign.center,
                        style: AppFonts.outfit(fontSize: 13, color: AppColors.warning)),
                    ] else ...[
                      Icon(Icons.mic, size: 40, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(lang == 'es' ? 'Tocá REC para grabar' : lang == 'pt' ? 'Toque REC para gravar' : 'Tap REC to record',
                        style: AppFonts.outfit(fontSize: 14, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // REC / STOP button
                  GestureDetector(
                    onTap: () async {
                      final audio = ref.read(audioServiceProvider);
                      if (webState == 'recording') {
                        // Stop recording
                        await audio.stopWebRecording();
                        _webRecTimer?.cancel();
                        ref.read(webRecStateProvider.notifier).state = 'stopped';
                        ref.read(webRecHasRecordingProvider.notifier).state = true;
                      } else {
                        // Start recording
                        ref.read(recordingDurationProvider.notifier).state = Duration.zero;
                        final result = await audio.startWebRecording();
                        if (result == 'recording') {
                          ref.read(webRecStateProvider.notifier).state = 'recording';
                          final start = DateTime.now();
                          _webRecTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
                            if (mounted) {
                              ref.read(recordingDurationProvider.notifier).state =
                                DateTime.now().difference(start);
                            }
                          });
                        } else if (result == 'permission_denied') {
                          ref.read(webRecStateProvider.notifier).state = 'permission_denied';
                        } else {
                          ref.read(webRecStateProvider.notifier).state = 'error';
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: webState == 'recording' ? AppColors.danger : AppColors.danger.withValues(alpha: 0.8),
                        boxShadow: webState == 'recording' ? [
                          BoxShadow(color: AppColors.danger.withValues(alpha: 0.4), blurRadius: 12),
                        ] : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            webState == 'recording' ? Icons.stop : Icons.fiber_manual_record,
                            size: 18, color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            webState == 'recording' ? 'STOP' : 'REC',
                            style: AppFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Play/Stop playback
                  if (hasRec && webState != 'recording') ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final audio = ref.read(audioServiceProvider);
                        if (webState == 'playing') {
                          await audio.stopWebPlayback();
                          ref.read(webRecStateProvider.notifier).state = 'stopped';
                        } else {
                          await audio.playWebRecording();
                          ref.read(webRecStateProvider.notifier).state = 'playing';
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: webState == 'playing' ? AppColors.accent : AppColors.accent.withValues(alpha: 0.2),
                          border: Border.all(color: AppColors.accent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              webState == 'playing' ? Icons.stop : Icons.play_arrow,
                              size: 18,
                              color: webState == 'playing' ? AppColors.bgDeepest : AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              webState == 'playing' ? 'STOP' : (lang == 'es' ? 'ESCUCHAR' : 'PLAY'),
                              style: AppFonts.outfit(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: webState == 'playing' ? AppColors.bgDeepest : AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Discard
                  if (hasRec && webState != 'recording') ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final audio = ref.read(audioServiceProvider);
                        await audio.stopWebPlayback();
                        await audio.discardWebRecording();
                        ref.read(webRecStateProvider.notifier).state = 'idle';
                        ref.read(webRecHasRecordingProvider.notifier).state = false;
                        ref.read(recordingDurationProvider.notifier).state = Duration.zero;
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bgElevated,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          )),

          // Info panel
          _panel(lang == 'es' ? 'INFORMACIÓN' : 'INFO', Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang == 'es'
                  ? 'La grabación web captura audio desde tu micrófono. Para análisis de timing avanzado, usá la app nativa (iOS/Android).'
                  : lang == 'pt'
                    ? 'A gravação web captura áudio do seu microfone. Para análise de timing avançada, use o app nativo (iOS/Android).'
                    : 'Web recording captures audio from your microphone. For advanced timing analysis, use the native app (iOS/Android).',
                style: AppFonts.outfit(fontSize: 12, color: AppColors.textMuted, height: 1.5),
              ),
            ],
          )),

        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  RECORDING TAB — Native (iOS/Android)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRecordingTab() {
    final lang = ref.watch(langProvider);

    // Web recording: use MediaRecorder API
    if (kIsWeb) {
      return _buildWebRecordingTab(lang);
    }

    final playing = ref.watch(playingProvider);
    final isRec = ref.watch(isRecordingProvider);
    final recDuration = ref.watch(recordingDurationProvider);
    final liveOnsets = ref.watch(liveOnsetsProvider);
    final metrics = ref.watch(currentMetricsProvider);
    final takes = ref.watch(takesProvider);
    final timeSig = ref.watch(timeSigProvider);
    final showOverlay = ref.watch(showTimingOverlayProvider);
    final bestTake = ref.watch(bestTakeProvider);

    final recMinutes = recDuration.inMinutes.toString().padLeft(2, '0');
    final recSeconds = (recDuration.inSeconds % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Recording status + waveform
          _panel('Recording', Column(
            children: [
              Container(
                width: double.infinity,
                height: 90,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isRec ? AppColors.danger : AppColors.border,
                    width: isRec ? 2 : 1,
                  ),
                ),
                child: isRec
                  ? Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$recMinutes:$recSeconds', style: AppTheme.monoStyle(
                              size: 16, weight: FontWeight.w800, color: AppColors.danger,
                            )),
                            Text('${liveOnsets.length} notes', style: AppFonts.outfit(
                              fontSize: 11, color: AppColors.textMuted,
                            )),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: OnsetWaveform(
                            onsets: liveOnsets,
                            isRecording: true,
                          ),
                        ),
                      ],
                    )
                  : liveOnsets.isNotEmpty
                    ? OnsetWaveform(onsets: liveOnsets)
                    : Center(
                        child: Text(
                          playing ? 'Tap REC to analyze timing' : 'Start metronome first',
                          style: AppFonts.outfit(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: playing ? _toggleRecording : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: isRec ? AppColors.danger : (playing ? AppColors.danger.withValues(alpha: 0.8) : AppColors.bgElevated),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRec ? Icons.stop : Icons.fiber_manual_record,
                            size: 16,
                            color: playing ? Colors.white : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isRec ? 'STOP' : 'REC',
                            style: AppFonts.outfit(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: playing ? Colors.white : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!playing) ...[
                    const SizedBox(width: 12),
                    _playButton(playing),
                  ],
                ],
              ),
            ],
          )),

          // Timing analysis results
          if (metrics != null && showOverlay) ...[
            const SizedBox(height: 12),
            SessionMetricsCard(
              metrics: metrics,
              previousMetrics: takes.length > 1 ? takes[takes.length - 2].metrics : null,
            ),
            const SizedBox(height: 12),
            DeviationChart(onsets: liveOnsets),
            const SizedBox(height: 12),
            TimingHeatmap(
              onsets: liveOnsets,
              beatsPerBar: timeSig.num,
              subdivision: ref.read(subdivisionProvider),
            ),
          ],

          // Takes list
          if (takes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _panel('Takes (${takes.length})', Column(
              children: takes.reversed.map((take) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TakeListItem(
                          take: take,
                          isBest: bestTake != null && take.id == bestTake.id,
                          onTap: () {
                            if (take.metrics != null) {
                              ref.read(currentMetricsProvider.notifier).state = take.metrics;
                              ref.read(liveOnsetsProvider.notifier).state = take.onsets;
                              ref.read(showTimingOverlayProvider.notifier).state = true;
                            }
                          },
                        ),
                      ),
                      if (take.audioFilePath != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _exportTake(take),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.accent.withValues(alpha: 0.1),
                            ),
                            child: const Icon(Icons.share, size: 16, color: AppColors.accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            )),
          ],
        ],
      ),
    );
  }

  // Practice tab extracted to features/practice/
  // Practice tab extracted to features/practice/

  void _exportTake(Take take) async {
    if (take.audioFilePath == null) return;
    try {
      await Share.shareXFiles(
        [XFile(take.audioFilePath!)],
        text: 'GrooveLab recording - ${take.bpm} BPM',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(_dialogContext).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }


  // Library tab extracted to features/library/

  // Stats and Settings tabs extracted to features/stats/ and features/settings/
  // ═══════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  Widget _playButton(bool playing) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: playing
              ? [AppColors.danger, AppColors.danger]
              : [AppColors.accent, AppColors.accent2],
          ),
          boxShadow: [
            BoxShadow(
              color: (playing ? AppColors.danger : AppColors.accent).withValues(alpha: 0.4),
              blurRadius: 16, spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(playing ? Icons.stop : Icons.play_arrow,
          size: 28, color: Colors.white),
      ),
    );
  }

  Widget _panel(String title, Widget content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.outfit(
            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1.5,
          )),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SETLIST STAGE MODE (kept in app.dart — used by build overlay)
  // ═══════════════════════════════════════════════════════════════════

  /// Setlist picker dialog — shown when STAGE button is tapped.
  void _showSetlistPickerForStage() {
    final lang = ref.read(langProvider);
    final setlists = ref.read(setlistsProvider);

    if (setlists.isEmpty) {
      // Navigate to Library tab to create a setlist
      ref.read(tabIndexProvider.notifier).state = 4;
      ScaffoldMessenger.of(_dialogContext).showSnackBar(SnackBar(
        content: Text(tr(lang, 'noSetlists'),
          style: AppFonts.outfit(color: Colors.white)),
        backgroundColor: AppColors.bgElevated,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      return;
    }

    showModalBottomSheet(
      context: _dialogContext,
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
              child: Text(tr(lang, 'selectSetlist'),
                style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
            ),
            ...setlists.map((setlist) {
              final songs = (setlist['songs'] as List?) ?? [];
              return ListTile(
                leading: const Icon(Icons.queue_music, color: AppColors.accent2),
                title: Text(setlist['name'] as String? ?? 'Setlist',
                  style: AppFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                subtitle: Text('${songs.length} songs',
                  style: AppFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (songs.isEmpty) return;
                  ref.read(activeSetlistProvider.notifier).state = Map<String, dynamic>.from(setlist);
                  ref.read(activeSetlistSongIndexProvider.notifier).state = 0;
                  ref.read(setlistAutoAdvanceProvider.notifier).state =
                    setlist['autoAdvance'] as bool? ?? false;
                  _applySetlistSong(Map<String, dynamic>.from(songs[0] as Map));
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Full-screen live mode overlay for setlist performance.
  Widget _buildSetlistLiveMode(String lang) {
    final setlist = ref.watch(activeSetlistProvider);
    if (setlist == null) return const SizedBox.shrink();

    final songs = (setlist['songs'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? [];
    final currentIdx = ref.watch(activeSetlistSongIndexProvider);
    final autoAdv = ref.watch(setlistAutoAdvanceProvider);
    final playing = ref.watch(playingProvider);

    final currentSong = currentIdx < songs.length
        ? songs[currentIdx]
        : <String, dynamic>{};

    return Positioned.fill(
      child: Container(
        color: AppColors.bgDeepest,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.queue_music, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(lang, 'liveMode'),
                          style: AppFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppColors.accent, letterSpacing: 1.5)),
                        Text(setlist['name'] as String? ?? '',
                          style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                      ],
                    )),
                    GestureDetector(
                      onTap: _exitLiveMode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                          color: AppColors.danger.withValues(alpha: 0.1),
                        ),
                        child: Text(tr(lang, 'exitLive'),
                          style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.danger)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              // Current song display (large for stage visibility)
              if (currentSong.isNotEmpty) Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: playing
                        ? AppColors.accent.withValues(alpha: 0.6)
                        : AppColors.accent.withValues(alpha: 0.3),
                      width: playing ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.accent.withValues(alpha: playing ? 0.15 : 0.05),
                        blurRadius: 24, spreadRadius: 4),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Song position
                      Text('${currentIdx + 1} / ${songs.length}',
                        style: AppTheme.monoStyle(size: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      // Song name — large for stage
                      Text(currentSong['name'] as String? ?? 'Song',
                        style: AppFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                        textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      // BPM — extra large
                      Text('${currentSong["bpm"]}',
                        style: AppTheme.monoStyle(size: 48, weight: FontWeight.w900,
                          color: AppColors.accent)),
                      Text('BPM', style: AppTheme.monoStyle(size: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      // Time sig + click sound
                      Text('${currentSong["timeSig"]} \u00b7 ${currentSong["clickSound"]}',
                        style: AppTheme.monoStyle(size: 14, color: AppColors.textSecondary)),
                      // Beat indicator
                      if (playing) ...[
                        const SizedBox(height: 14),
                        _buildStageBeatIndicator(),
                      ],
                      if ((currentSong['notes'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.bgInput,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(currentSong['notes'] as String,
                            style: AppFonts.outfit(fontSize: 13, color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Next song preview
              if (currentIdx < songs.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('${tr(lang, "nextSong")}: ', style: AppFonts.outfit(
                        fontSize: 11, color: AppColors.textMuted)),
                      Text('${songs[currentIdx + 1]["name"]} \u00b7 ${songs[currentIdx + 1]["bpm"]} BPM',
                        style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // PREV / PLAY / NEXT buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // PREV
                  GestureDetector(
                    onTap: currentIdx > 0 ? _setlistPrev : null,
                    child: Container(
                      width: 64, height: 52,
                      decoration: BoxDecoration(
                        color: currentIdx > 0 ? AppColors.bgElevated : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.skip_previous, size: 22,
                            color: currentIdx > 0 ? AppColors.textPrimary : AppColors.textMuted),
                          Text(tr(lang, 'prev'), style: AppFonts.outfit(fontSize: 8,
                            color: currentIdx > 0 ? AppColors.textSecondary : AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // PLAY/STOP — large for stage
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: playing
                            ? [AppColors.danger, AppColors.accent3]
                            : [AppColors.accent, AppColors.accent2],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (playing ? AppColors.danger : AppColors.accent).withValues(alpha: 0.4),
                            blurRadius: 20, spreadRadius: 3),
                        ],
                      ),
                      child: Icon(
                        playing ? Icons.stop : Icons.play_arrow,
                        size: 40, color: AppColors.bgDeepest),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // NEXT
                  GestureDetector(
                    onTap: currentIdx < songs.length - 1 ? _setlistNext : null,
                    child: Container(
                      width: 64, height: 52,
                      decoration: BoxDecoration(
                        color: currentIdx < songs.length - 1 ? AppColors.bgElevated : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.skip_next, size: 22,
                            color: currentIdx < songs.length - 1 ? AppColors.textPrimary : AppColors.textMuted),
                          Text(tr(lang, 'next'), style: AppFonts.outfit(fontSize: 8,
                            color: currentIdx < songs.length - 1 ? AppColors.textSecondary : AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Auto-advance toggle
              GestureDetector(
                onTap: () => ref.read(setlistAutoAdvanceProvider.notifier).state = !autoAdv,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(autoAdv ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18, color: autoAdv ? AppColors.accent : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(tr(lang, 'autoAdvance'),
                      style: AppFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              // Song list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: songs.length,
                  itemBuilder: (ctx, idx) {
                    final song = songs[idx];
                    final isCurrent = idx == currentIdx;
                    return GestureDetector(
                      onTap: () {
                        ref.read(activeSetlistSongIndexProvider.notifier).state = idx;
                        _applySetlistSong(Map<String, dynamic>.from(song));
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.accent.withValues(alpha: 0.1) : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: isCurrent ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
                            width: isCurrent ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isCurrent)
                              const Icon(Icons.play_arrow, size: 16, color: AppColors.accent)
                            else
                              Text('${idx + 1}',
                                style: AppTheme.monoStyle(size: 12, color: AppColors.textMuted)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(song['name'] as String? ?? 'Song',
                                  style: AppFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                                    color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
                                  )),
                                Text('${song["bpm"]} BPM \u00b7 ${song["timeSig"]}',
                                  style: AppTheme.monoStyle(size: 10,
                                    color: isCurrent ? AppColors.accent : AppColors.textMuted)),
                              ],
                            )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Beat indicator dots for stage mode — shows current beat in bar.
  Widget _buildStageBeatIndicator() {
    final currentBeat = ref.watch(currentBeatProvider);
    final timeSig = ref.watch(timeSigProvider);
    final beatsPerBar = timeSig.num;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(beatsPerBar, (i) {
        final isActive = i == currentBeat;
        final isDownbeat = i == 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: isActive ? 20 : 14,
            height: isActive ? 20 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                ? (isDownbeat ? AppColors.accent : AppColors.accent2)
                : AppColors.bgInput,
              border: Border.all(
                color: isActive
                  ? (isDownbeat ? AppColors.accent : AppColors.accent2)
                  : AppColors.border,
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive ? [
                BoxShadow(
                  color: (isDownbeat ? AppColors.accent : AppColors.accent2).withValues(alpha: 0.5),
                  blurRadius: 8, spreadRadius: 1,
                ),
              ] : [],
            ),
          ),
        );
      }),
    );
  }

}

// ArcPainter moved to features/metronome/metronome_tab.dart

