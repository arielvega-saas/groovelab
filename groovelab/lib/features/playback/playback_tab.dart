import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ═══════════════════════════════════════════════════════════════════════
//  PLAYBACK TAB — Multitrack Live Console via WebView / iframe
//  Loads the professional playback-multitrack UI from assets/playback/
// ═══════════════════════════════════════════════════════════════════════

class PlaybackTab extends ConsumerStatefulWidget {
  const PlaybackTab({super.key});

  @override
  ConsumerState<PlaybackTab> createState() => _PlaybackTabState();
}

class _PlaybackTabState extends ConsumerState<PlaybackTab> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebPlatform();
    return _buildUnsupportedPlatform();
  }

  /// Web platform: use the registered HtmlElementView (iframe).
  Widget _buildWebPlatform() {
    const viewType = 'playback-webview';
    return const HtmlElementView(viewType: viewType);
  }

  /// Native fallback — InAppWebView support can be added later.
  Widget _buildUnsupportedPlatform() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_rounded, size: 48,
              color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('PlayBack — Multitrack Live',
              style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Disponible en la versión web',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              )),
          ],
        ),
      ),
    );
  }
}
