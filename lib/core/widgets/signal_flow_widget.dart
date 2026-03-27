import 'package:flutter/material.dart';
import '../theme.dart';

/// Visual signal flow diagram for the Pedalera.
/// Shows pedals as connected nodes in a chain with bypass indicators.
class SignalFlowWidget extends StatelessWidget {
  final List<Map<String, dynamic>> chain;
  final int? selectedIndex;
  final void Function(int index)? onPedalTap;
  final void Function(int index)? onBypassToggle;

  const SignalFlowWidget({
    super.key,
    required this.chain,
    this.selectedIndex,
    this.onPedalTap,
    this.onBypassToggle,
  });

  static const _pedalIcons = {
    'noiseGate': Icons.noise_aware,
    'compressor': Icons.compress,
    'drive': Icons.local_fire_department,
    'eq': Icons.equalizer,
    'amp': Icons.speaker,
    'cabinet': Icons.speaker_group,
    'chorus': Icons.waves,
    'delay': Icons.timer,
    'reverb': Icons.water_drop,
  };

  static const _pedalColors = {
    'noiseGate': Color(0xFF78909C),
    'compressor': Color(0xFF42A5F5),
    'drive': Color(0xFFEF5350),
    'eq': Color(0xFF66BB6A),
    'amp': Color(0xFFFF9800),
    'cabinet': Color(0xFF8D6E63),
    'chorus': Color(0xFF26C6DA),
    'delay': Color(0xFFAB47BC),
    'reverb': Color(0xFF5C6BC0),
  };

  @override
  Widget build(BuildContext context) {
    if (chain.isEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Text(
          'No pedals in chain',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    return Container(
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgDark.withValues(alpha: 0.6),
            const Color(0xFF0A0A0A),
            AppColors.bgDark.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: chain.length,
        separatorBuilder: (_, __) => _buildConnector(),
        itemBuilder: (_, index) => _buildPedalNode(index),
      ),
    );
  }

  Widget _buildConnector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Container(
        width: 16,
        height: 2,
        color: AppColors.accent.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildPedalNode(int index) {
    final pedal = chain[index];
    final type = pedal['type'] as String? ?? '';
    final enabled = pedal['enabled'] as bool? ?? true;
    final isSelected = selectedIndex == index;
    final color = _pedalColors[type] ?? AppColors.accent;
    final icon = _pedalIcons[type] ?? Icons.tune;

    return GestureDetector(
      onTap: () => onPedalTap?.call(index),
      onLongPress: () => onBypassToggle?.call(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        height: 72,
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppColors.bgDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.3)),
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: enabled ? color : AppColors.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 4),
            Text(
              type.length > 6 ? '${type.substring(0, 5)}.' : type,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 8,
                color: enabled ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.4),
                letterSpacing: 0.5,
                decoration: enabled ? null : TextDecoration.lineThrough,
              ),
            ),
            if (!enabled)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
