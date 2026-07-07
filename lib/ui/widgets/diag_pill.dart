import 'package:flutter/material.dart';

import '../../domain/analyzer.dart';
import '../theme/app_theme.dart';

/// GH/NH/Q diagnostic chip (Direction A): tinted pill whose tone encodes the
/// level - green (normal), amber (warning), red (outlier), neutral when the
/// model carries no threshold for the metric.
class DiagPill extends StatelessWidget {
  const DiagPill({super.key, required this.text, this.level});

  /// Display text, e.g. "GH 1.42".
  final String text;

  /// One of [AnalysisResult.levelNormal] / levelWarning / levelOutlier, or
  /// null when the metric has no classification.
  final String? level;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final Color tone;
    switch (level) {
      case AnalysisResult.levelOutlier:
        tone = brightness == Brightness.dark
            ? const Color(0xFFE25A46)
            : const Color(0xFFC02A1C);
        break;
      case AnalysisResult.levelWarning:
        tone = AppTheme.warning;
        break;
      case AnalysisResult.levelNormal:
        tone = AppTheme.successTextOn(brightness);
        break;
      default:
        tone = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    final levelSuffix = level == null || level!.isEmpty ? '' : ' · ${level!}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$text$levelSuffix',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
