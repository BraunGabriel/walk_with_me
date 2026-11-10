import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart' show LatLng;

import '../models/walking_route.dart';
import '../utils/geo.dart';

/// Typical walking pace, used for "N min" estimates.
const walkingSpeedMetersPerSecond = 1.35;

/// Where the walker is relative to a [WalkingRoute].
class RouteState {
  const RouteState({
    required this.remaining,
    required this.remainingMeters,
    required this.offRouteMeters,
  });

  /// The part of the route still ahead, starting at the walker's snapped
  /// position.
  final List<LatLng> remaining;
  final double remainingMeters;

  /// How far the walker is from the route line.
  final double offRouteMeters;

  bool get isOffRoute => offRouteMeters > RouteFollower.offRouteThresholdMeters;

  Duration get remainingTime => Duration(
    seconds: (remainingMeters / walkingSpeedMetersPerSecond).round(),
  );
}

/// Tracks progress along a route as position updates arrive: trims the part
/// already walked and flags when the walker has strayed.
class RouteFollower {
  RouteFollower(this.route);

  /// Beyond this distance from the line, the walker counts as off route.
  /// Generous because GPS between buildings is often off by 10–20 m.
  static const offRouteThresholdMeters = 40.0;

  /// How many segments behind the furthest progress to still consider, so
  /// a path that doubles back doesn't snap the walker backwards.
  static const _lookBehindSegments = 2;

  final WalkingRoute route;
  int _segment = 0;

  RouteState update(LatLng position) {
    final points = route.points;
    final snap = snapToPolyline(
      points,
      position,
      fromSegment: _segment - _lookBehindSegments,
    );
    // Only advance on a confident snap; while off route, keep prior progress.
    if (snap.distanceMeters <= offRouteThresholdMeters) {
      _segment = math.max(_segment, snap.segment);
    }

    final remaining = [snap.point, ...points.skip(snap.segment + 1)];
    var meters = 0.0;
    for (var i = 0; i < remaining.length - 1; i++) {
      meters += distanceMeters(remaining[i], remaining[i + 1]);
    }
    return RouteState(
      remaining: remaining,
      remainingMeters: meters,
      offRouteMeters: snap.distanceMeters,
    );
  }
}
