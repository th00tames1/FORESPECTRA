import 'package:flutter/material.dart';

import '../../services/i18n.dart';
import '../theme/app_theme.dart';

/// Header connection-status pill (Direction A): green tint when connected,
/// warning tint for test mode or offline. Colors are brightness-aware so the
/// text keeps contrast on dark surfaces.
class ConnChip extends StatelessWidget {
  const ConnChip({super.key, required this.connected, this.testMode = false});

  final bool connected;
  final bool testMode;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color tone;
    final String label;
    if (connected) {
      tone = AppTheme.successTextOn(brightness);
      label = t('common.connected');
    } else if (testMode) {
      tone = AppTheme.warning;
      label = t('common.testMode');
    } else {
      tone = AppTheme.warning;
      label = t('common.offline');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
