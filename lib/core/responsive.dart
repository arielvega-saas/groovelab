import 'package:flutter/material.dart';

/// Device type breakpoints for adaptive layout.
enum DeviceType { phone, tablet, desktop }

class Responsive {
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth = 1024;

  /// Determine device type from available width (not screen width).
  /// Uses constraint width so it works in split-view on iPad.
  static DeviceType fromWidth(double width) {
    if (width <= phoneMaxWidth) return DeviceType.phone;
    if (width <= tabletMaxWidth) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Check if current context is wide enough for side-by-side layout.
  static bool isWide(BuildContext context) {
    return MediaQuery.sizeOf(context).width > phoneMaxWidth;
  }

  /// Check if landscape orientation.
  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  /// Number of columns for grid layouts.
  static int gridColumns(double width) {
    if (width <= phoneMaxWidth) return 2;
    if (width <= tabletMaxWidth) return 3;
    return 4;
  }
}
