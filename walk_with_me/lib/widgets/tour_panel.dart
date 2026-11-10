import 'package:flutter/material.dart';

import '../models/tour_progress.dart';
import '../services/route_follower.dart' show walkingSpeedMetersPerSecond;

/// Bottom panel shown during an active tour: current stop, distance, and
/// previous / next controls.
class TourPanel extends StatelessWidget {
  const TourPanel({
    super.key,
    required this.progress,
    required this.distanceMeters,
    this.arrived = false,
    this.rerouting = false,
    required this.onPrevious,
    required this.onNext,
    required this.onDetails,
    required this.onDirections,
    required this.onEnd,
  });

  final TourProgress progress;

  /// Walking distance left to the current stop, or null if unknown.
  final double? distanceMeters;

  /// The walker has reached the current stop.
  final bool arrived;

  /// A new route is being fetched because the walker left the old one.
  final bool rerouting;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onDetails;
  final VoidCallback onDirections;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stop = progress.current;
    final distance = distanceMeters;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${progress.tour.name} · Stop ${progress.stopNumber} of ${progress.stopCount}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'End tour',
                    onPressed: onEnd,
                  ),
                ],
              ),
              LinearProgressIndicator(
                value: progress.stopNumber / progress.stopCount,
              ),
              const SizedBox(height: 12),
              Text(stop.name, style: theme.textTheme.titleLarge),
              if (arrived)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "You've arrived — take a look around!",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else if (rerouting)
                Text('Finding a new route…', style: theme.textTheme.bodyMedium)
              else if (distance != null)
                Text(formatWalk(distance), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Details'),
                  ),
                  TextButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Directions'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: progress.isFirst ? null : onPrevious,
                        child: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onNext,
                        child: Text(progress.isLast ? 'Finish' : 'Next stop'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formats meters as US walking distance ("350 ft away", "0.4 mi away").
String formatDistance(double meters) {
  final feet = meters * 3.28084;
  if (feet < 50) return "You're here";
  if (feet < 1000) return '${(feet / 10).round() * 10} ft away';
  return '${(feet / 5280).toStringAsFixed(1)} mi away';
}

/// Formats meters as miles, e.g. "0.6 mi".
String formatMiles(double meters) =>
    '${(meters / 1609.344).toStringAsFixed(1)} mi';

/// Distance plus walking time, e.g. "350 ft away · 2 min walk".
String formatWalk(double meters) {
  final distance = formatDistance(meters);
  if (meters * 3.28084 < 50) return distance;
  final minutes = (meters / walkingSpeedMetersPerSecond / 60).ceil();
  return '$distance · $minutes min walk';
}
