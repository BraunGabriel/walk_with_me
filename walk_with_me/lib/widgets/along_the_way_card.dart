import 'package:flutter/material.dart';

import '../models/highlight.dart';

/// Card that slides in over the map to point out something the walker is
/// passing.
class AlongTheWayCard extends StatelessWidget {
  const AlongTheWayCard({
    super.key,
    required this.highlight,
    required this.onDismiss,
    this.onMore,
  });

  final Highlight highlight;
  final VoidCallback onDismiss;

  /// Shown as a "More" button when set (e.g. to open POI details).
  final VoidCallback? onMore;

  static IconData iconFor(String category) => switch (category) {
    'building' => Icons.apartment,
    'tradition' => Icons.celebration,
    'photo-spot' => Icons.photo_camera,
    _ => Icons.auto_awesome,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Icon(iconFor(highlight.category)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    highlight.category == 'building'
                        ? 'YOU\'RE PASSING'
                        : 'ALONG THE WAY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(highlight.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    highlight.text,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (onMore != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: onMore,
                        child: const Text('More'),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Dismiss',
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
