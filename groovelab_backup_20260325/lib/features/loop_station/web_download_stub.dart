/// Stub for native platforms — download not supported via JS.
void triggerWebDownload(String url, [String filename = 'groovelab-loop.wav']) {
  // On native platforms, file downloads are handled via platform channels
  // or share_plus. This is a no-op stub.
}
