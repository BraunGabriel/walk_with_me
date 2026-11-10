import 'package:apple_maps_flutter/apple_maps_flutter.dart' show LatLng;

/// A walking path between two points, as returned by MapKit directions.
class WalkingRoute {
  const WalkingRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isApproximate = false,
  }) : assert(points.length >= 2);

  /// Path geometry, start to destination.
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  /// True when directions were unavailable and this is a straight line.
  final bool isApproximate;

  LatLng get destination => points.last;
}
