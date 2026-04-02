import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io' show Platform;

// ═══════════════════════════════════════════════════════════════════════
//  LIVESTAGE TAB — Professional Multitrack Live Console via WebView
//  Loads the LiveStage UI from assets/livestage/livestage.html
// ═══════════════════════════════════════════════════════════════════════

class LiveStageTab extends ConsumerStatefulWidget {
  const LiveStageTab({super.key});

  @override
  ConsumerState<LiveStageTab> createState() => _LiveStageTabState();
}

class _LiveStageTabState extends ConsumerState<LiveStageTab>
    with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  InAppLocalhostServer? _localhostServer;
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
    _localhostServer = InAppLocalhostServer(port: 8767);
    try {
      await _localhostServer!.start();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('LiveStageTab: failed to start local server: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to start local asset server: $e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Communication: Flutter -> HTML
  // ---------------------------------------------------------------------------

  Future<void> _sendToHtml(Map<String, dynamic> message) async {
    if (_webViewController == null) return;
    final encoded = Uri.encodeComponent(message.toString());
    try {
      await _webViewController!.evaluateJavascript(
        source: 'if(window.handleFlutterMessage) window.handleFlutterMessage($message);',
      );
    } catch (e) {
      debugPrint('LiveStageTab: error sending message to HTML: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorFallback();
    if (kIsWeb) return _buildWebPlatform();
    return _buildNativePlatform();
  }

  // ---------------------------------------------------------------------------
  // Web platform (iframe via HtmlElementView)
  // ---------------------------------------------------------------------------

  Widget _buildWebPlatform() {
    const viewType = 'livestage-webview';
    return const HtmlElementView(viewType: viewType);
  }

  // ---------------------------------------------------------------------------
  // Native platform (InAppWebView)
  // ---------------------------------------------------------------------------

  Widget _buildNativePlatform() {
    if (_localhostServer == null || !_localhostServer!.isRunning()) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    const url = 'http://localhost:8767/assets/livestage/livestage.html';

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
            debugPrint('LiveStageTab [JS]: ${consoleMessage.message}');
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
    debugPrint('LiveStageTab: error (${error.type}): ${error.description}');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage =
            'Failed to load LiveStage (${error.type}): ${error.description}';
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
        'LiveStageTab: HTTP error ($statusCode): ${errorResponse.reasonPhrase}');
    if (statusCode >= 400 && mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage =
            'Failed to load LiveStage (HTTP $statusCode): ${errorResponse.reasonPhrase}';
      });
    }
  }

  Future<PermissionResponse?> _onPermissionRequest(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
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
  // Communication: HTML -> Flutter
  // ---------------------------------------------------------------------------

  void _handleWebMessage(dynamic rawMessage) {
    try {
      final Map<String, dynamic> msg = rawMessage is String
          ? {} // JSON decode would go here
          : Map<String, dynamic>.from(rawMessage as Map);

      final String? type = msg['type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'ready':
          debugPrint('LiveStageTab: HTML LiveStage is ready');
          break;
        case 'error':
          debugPrint(
              'LiveStageTab: HTML error - ${msg['message'] ?? 'unknown'}');
          break;
        default:
          debugPrint('LiveStageTab: event "$type"');
      }
    } catch (e) {
      debugPrint('LiveStageTab: error parsing message: $e');
    }
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
              'LiveStage unavailable',
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
