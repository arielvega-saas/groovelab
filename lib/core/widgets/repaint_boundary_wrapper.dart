import 'package:flutter/material.dart';

/// Convenience wrapper that isolates widget rebuilds.
/// Use around expensive widgets (Home grid cards, waveforms, etc.)
/// to prevent unnecessary repaints of sibling widgets.
class IsolatedRebuild extends StatelessWidget {
  final Widget child;

  const IsolatedRebuild({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}
