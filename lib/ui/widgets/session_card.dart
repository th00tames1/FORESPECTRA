import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One row of the Scan screen's session card: leading icon + label on the
/// left, current value on the right (bold part + muted detail), optional
/// chevron for rows that navigate.
class SessionRow {
  const SessionRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueDetail,
    this.chevron = false,
    this.onTap,
    this.enabled = true,
    this.alert = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? valueDetail;
  final bool chevron;
  final VoidCallback? onTap;
  final bool enabled;

  /// Action required: tints the icon and value red so a missing prerequisite
  /// (e.g. no reference) reads at a glance instead of as a long sentence.
  final bool alert;
}

/// Direction A session card: groups the pre-scan checklist (reference, models,
/// scans per capture) into one hairline card of tappable rows.
class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.rows});

  final List<SessionRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slate = theme.colorScheme.onSurfaceVariant;
    final danger = AppTheme.dangerTextOn(theme.brightness);
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(const Divider(height: 1));
      }
      final row = rows[i];
      children.add(
        InkWell(
          onTap: row.enabled ? row.onTap : null,
          child: Opacity(
            opacity: row.enabled ? 1.0 : 0.55,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(row.icon, size: 18, color: row.alert ? danger : slate),
                  const SizedBox(width: 10),
                  Text(row.label, style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: row.value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: row.alert ? danger : null,
                            ),
                          ),
                          if (row.valueDetail != null)
                            TextSpan(
                              text: ' ${row.valueDetail}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: slate,
                              ),
                            ),
                        ],
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (row.chevron) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 18, color: slate),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
