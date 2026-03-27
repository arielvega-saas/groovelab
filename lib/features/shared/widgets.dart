import 'package:flutter/material.dart';

/// Color helper for consistency scores.
Color scoreColor(int score) {
  if (score >= 80) return const Color(0xFF00FF88);
  if (score >= 50) return const Color(0xFFFFB020);
  return const Color(0xFFFF3B5C);
}
