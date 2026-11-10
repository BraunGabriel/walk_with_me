import 'package:apple_maps_flutter/apple_maps_flutter.dart' show LatLng;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/walking_route.dart';
import '../utils/geo.dart';
import 'route_follower.dart' show walkingSpeedMetersPerSecond;

/// Walking directions from MapKit (via the native channel in AppDelegate.swift).
class DirectionsService {
  static const _channel = MethodChannel('walk_with_me/directions');

  /// Returns a walking route from [from] to [to]. Falls back to a straight
  /// line if MapKit has no route or is unreachable (e.g. offline), so the
  /// tour keeps working.
  Future<WalkingRoute> walkingRoute(LatLng from, LatLng to) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'walkingRoute',
        {
          'fromLat': from.latitude,
          'fromLng': from.longitude,
          'toLat': to.latitude,
          'toLng': to.longitude,
        },
      );
      final flat = (result!['points'] as List).cast<num>();
      final points = [
        for (var i = 0; i + 1 < flat.length; i += 2)
          LatLng(flat[i].toDouble(), flat[i + 1].toDouble()),
      ];
      if (points.length >= 2) {
        return WalkingRoute(
          points: points,
          distanceMeters: (result['distance'] as num).toDouble(),
          durationSeconds: (result['duration'] as num).toDouble(),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Walking directions unavailable: ${e.message}');
    } on MissingPluginException {
      debugPrint('Walking directions channel not registered');
    }
    final meters = distanceMeters(from, to);
    return WalkingRoute(
      points: [from, to],
      distanceMeters: meters,
      durationSeconds: meters / walkingSpeedMetersPerSecond,
      isApproximate: true,
    );
  }
}
