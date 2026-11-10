import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart' show LatLng;

const _earthRadiusMeters = 6371000.0;
double _rad(double deg) => deg * math.pi / 180;

/// Great-circle distance between two points, in meters.
double distanceMeters(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(h));
}

/// The closest point on a polyline to some position.
class PolylineSnap {
  const PolylineSnap({
    required this.segment,
    required this.point,
    required this.distanceMeters,
  });

  /// Index of the segment's start vertex (segment runs [segment]→[segment]+1).
  final int segment;

  /// Closest point on that segment.
  final LatLng point;

  /// Distance from the position to [point].
  final double distanceMeters;
}

/// Finds the closest point to [p] on [points], searching segments from
/// [fromSegment] onward. Uses a local flat projection, which is accurate at
/// campus scale.
PolylineSnap snapToPolyline(
  List<LatLng> points,
  LatLng p, {
  int fromSegment = 0,
}) {
  assert(points.length >= 2);
  final metersPerDegLat = _earthRadiusMeters * math.pi / 180;
  final metersPerDegLng = metersPerDegLat * math.cos(_rad(p.latitude));

  PolylineSnap? best;
  for (var i = math.max(0, fromSegment); i < points.length - 1; i++) {
    final a = points[i], b = points[i + 1];
    // Project into meters with p at the origin.
    final ax = (a.longitude - p.longitude) * metersPerDegLng;
    final ay = (a.latitude - p.latitude) * metersPerDegLat;
    final bx = (b.longitude - p.longitude) * metersPerDegLng;
    final by = (b.latitude - p.latitude) * metersPerDegLat;
    final dx = bx - ax, dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    final t = lenSq == 0 ? 0.0 : ((-ax * dx - ay * dy) / lenSq).clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    final d = math.sqrt(cx * cx + cy * cy);
    if (best == null || d < best.distanceMeters) {
      best = PolylineSnap(
        segment: i,
        point: LatLng(
          a.latitude + t * (b.latitude - a.latitude),
          a.longitude + t * (b.longitude - a.longitude),
        ),
        distanceMeters: d,
      );
    }
  }
  return best!;
}
