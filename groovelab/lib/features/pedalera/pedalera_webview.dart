import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import 'dart:io' show Platform;

import 'pedalera_models.dart';
import 'pedalera_providers.dart';
import 'pedalera_stub_register.dart'
    if (dart.library.js_interop) 'pedalera_web_register.dart';

/// WebView-based pedalboard that loads the HTML pedalboard from assets.
///
/// On native platforms (iOS/Android) it uses [InAppWebView].
/// On web it renders an iframe via HtmlElementView.
class PedaleraWebView extends ConsumerStatefulWidget {
  const PedaleraWebView({super.key});

  @override
  ConsumerState<PedaleraWebView> createState() => _PedaleraWebViewState();
}

class _PedaleraWebViewState extends ConsumerState<PedaleraWebView>
    with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  InAppLocalhostServer? _localhostServer;
  int _serverPort = 8765;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _startLocalServer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localhostServer?.close();
    _webViewController = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _sendToHtml({'type': 'lifecycle', 'action': 'pause'});
        break;
      case AppLifecycleState.resumed:
        _sendToHtml({'type': 'lifecycle', 'action': 'resume'});
        break;
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Local asset server (native only)
  // ---------------------------------------------------------------------------

  Future<void> _startLocalServer() async {
    // Try multiple ports in case the previous one is still in use
    for (final port in [8765, 8766, 8767, 8768, 8769]) {
      _localhostServer = InAppLocalhostServer(port: port);
      try {
        await _localhostServer!.start();
        _serverPort = port;
        debugPrint('PedaleraWebView: local server started on port $port');
        if (mounted) setState(() {});
        return;
      } catch (e) {
        debugPrint('PedaleraWebView: port $port unavailable: $e');
        _localhostServer = null;
      }
    }
    // All ports failed
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to start local asset server on any port';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Communication: Flutter -> HTML
  // ---------------------------------------------------------------------------

  /// Sends a JSON message to the HTML pedalboard via `window.handleFlutterMessage`.
  Future<void> _sendToHtml(Map<String, dynamic> message) async {
    if (_webViewController == null) return;
    final encoded = jsonEncode(message);
    try {
      await _webViewController!.evaluateJavascript(
        source: 'if(window.handleFlutterMessage) window.handleFlutterMessage($encoded);',
      );
    } catch (e) {
      debugPrint('PedaleraWebView: error sending message to HTML: $e');
    }
  }

  /// Public accessor so parent widgets can also send messages.
  void sendToHtml(Map<String, dynamic> message) => _sendToHtml(message);

  // ---------------------------------------------------------------------------
  // Communication: HTML -> Flutter  (via GrooveLabChannel)
  // ---------------------------------------------------------------------------

  void _handleWebMessage(dynamic rawMessage) {
    try {
      final Map<String, dynamic> msg = rawMessage is String
          ? jsonDecode(rawMessage) as Map<String, dynamic>
          : Map<String, dynamic>.from(rawMessage as Map);

      final String? type = msg['type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'pedalChainUpdate':
          _handlePedalChainUpdate(msg);
          break;
        case 'presetSelected':
          _handlePresetSelected(msg);
          break;
        case 'presetListUpdate':
          _handlePresetListUpdate(msg);
          break;
        case 'inputActiveChanged':
          ref.read(pedalInputActiveProvider.notifier).state =
              msg['active'] as bool? ?? false;
          break;
        case 'outputLevelChanged':
          ref.read(pedalOutputLevelProvider.notifier).state =
              (msg['level'] as num?)?.toDouble() ?? 0.0;
          break;
        case 'latencyChanged':
          ref.read(pedalLatencyMsProvider.notifier).state =
              (msg['latencyMs'] as num?)?.toDouble() ?? 0.0;
          break;
        case 'pedalSelected':
          ref.read(pedalSelectedIndexProvider.notifier).state =
              msg['index'] as int?;
          break;
        case 'liveModeChanged':
          ref.read(pedalLiveModeProvider.notifier).state =
              msg['enabled'] as bool? ?? false;
          break;
        case 'categoryFilterChanged':
          ref.read(pedalCategoryFilterProvider.notifier).state =
              msg['category'] as String? ?? 'All';
          break;
        case 'ready':
          debugPrint('PedaleraWebView: HTML pedalboard is ready');
          break;
        case 'error':
          debugPrint(
              'PedaleraWebView: HTML error - ${msg['message'] ?? 'unknown'}');
          break;
        default:
          debugPrint('PedaleraWebView: unhandled event type "$type"');
      }
    } catch (e) {
      debugPrint('PedaleraWebView: error parsing message: $e');
    }
  }

  void _handlePedalChainUpdate(Map<String, dynamic> msg) {
    final List<dynamic>? pedals = msg['pedals'] as List<dynamic>?;
    if (pedals == null) return;

    final chain = pedals.map((p) {
      final map = Map<String, dynamic>.from(p as Map);
      return PedalState.fromJson(map);
    }).toList();

    ref.read(pedalChainProvider.notifier).state = chain;
  }

  void _handlePresetSelected(Map<String, dynamic> msg) {
    final presetData = msg['preset'] as Map<String, dynamic>?;
    if (presetData == null) {
      ref.read(activePresetProvider.notifier).state = null;
      return;
    }
    ref.read(activePresetProvider.notifier).state =
        PedalPreset.fromJson(presetData);
  }

  void _handlePresetListUpdate(Map<String, dynamic> msg) {
    final List<dynamic>? presets = msg['presets'] as List<dynamic>?;
    if (presets == null) return;

    ref.read(pedalPresetsProvider.notifier).state = presets.map((p) {
      final map = Map<String, dynamic>.from(p as Map);
      return PedalPreset.fromJson(map);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorFallback();
    }

    if (kIsWeb) {
      return _buildWebPlatform();
    }

    return _buildNativePlatform();
  }

  // ---------------------------------------------------------------------------
  // Web platform (iframe via HtmlElementView)
  // ---------------------------------------------------------------------------

  Widget _buildWebPlatform() {
    // On web, the pedalera is shown as a DOM iframe overlay managed by app.dart.
    // This widget is just a placeholder while the overlay is active.
    return const SizedBox.expand();
  }

  // ---------------------------------------------------------------------------
  // Native platform (InAppWebView)
  // ---------------------------------------------------------------------------

  Widget _buildNativePlatform() {
    // Wait for local server before rendering the WebView.
    if (_localhostServer == null || !_localhostServer!.isRunning()) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final url = 'http://localhost:$_serverPort/assets/pedalera/pedalboard.html';

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url)),
          initialSettings: _buildSettings(),
          onWebViewCreated: _onWebViewCreated,
          onLoadStop: _onLoadStop,
          onReceivedError: _onReceivedError,
          onReceivedHttpError: _onReceivedHttpError,
          onPermissionRequest: _onPermissionRequest,
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint(
                'PedaleraWebView [JS]: ${consoleMessage.message}');
          },
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator.adaptive()),
      ],
    );
  }

  InAppWebViewSettings _buildSettings() {
    final settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      allowFileAccessFromFileURLs: true,
      allowUniversalAccessFromFileURLs: true,
      useShouldOverrideUrlLoading: false,
      transparentBackground: true,
    );

    // Platform-specific tweaks.
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        settings.useHybridComposition = true;
        settings.domStorageEnabled = true;
        settings.mixedContentMode =
            MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW;
      }
      if (Platform.isIOS) {
        settings.allowsBackForwardNavigationGestures = false;
        settings.applePayAPIEnabled = false;
      }
    }

    return settings;
  }

  // ---------------------------------------------------------------------------
  // WebView callbacks
  // ---------------------------------------------------------------------------

  void _onWebViewCreated(InAppWebViewController controller) {
    _webViewController = controller;

    // Register the JavaScript handler that the HTML calls via
    // GrooveLabChannel.postMessage(...)
    controller.addJavaScriptHandler(
      handlerName: 'GrooveLabChannel',
      callback: (List<dynamic> args) {
        if (args.isNotEmpty) {
          _handleWebMessage(args.first);
        }
      },
    );
  }

  void _onLoadStop(InAppWebViewController controller, WebUri? url) async {
    // Bridge: HTML calls window.GrooveLabChannel.postMessage(str)
    // but flutter_inappwebview needs window.flutter_inappwebview.callHandler().
    await controller.evaluateJavascript(source: '''
      window.GrooveLabChannel = {
        postMessage: function(str) {
          try {
            var data = (typeof str === 'string') ? JSON.parse(str) : str;
            window.flutter_inappwebview.callHandler('GrooveLabChannel', data);
          } catch(e) {
            window.flutter_inappwebview.callHandler('GrooveLabChannel', str);
          }
        }
      };
    ''');

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    debugPrint('PedaleraWebView: error (${error.type}): ${error.description}');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage =
            'Failed to load pedalboard (${error.type}): ${error.description}';
      });
    }
  }

  void _onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse errorResponse,
  ) {
    final statusCode = errorResponse.statusCode ?? 0;
    debugPrint(
        'PedaleraWebView: HTTP error ($statusCode): ${errorResponse.reasonPhrase}');
    if (statusCode >= 400 && mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage =
            'Failed to load pedalboard (HTTP $statusCode): ${errorResponse.reasonPhrase}';
      });
    }
  }

  Future<PermissionResponse?> _onPermissionRequest(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    // Auto-grant audio-related permissions so the pedalboard can process audio.
    final audioResources = [
      PermissionResourceType.MICROPHONE,
      PermissionResourceType.PROTECTED_MEDIA_ID,
    ];

    for (final resource in request.resources) {
      if (audioResources.contains(resource)) {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      }
    }

    return PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.DENY,
    );
  }

  // ---------------------------------------------------------------------------
  // Error fallback UI
  // ---------------------------------------------------------------------------

  Widget _buildErrorFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Pedalboard unavailable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _isLoading = true;
    });
    if (!kIsWeb) {
      _localhostServer?.close();
      _startLocalServer();
    }
  }
}
