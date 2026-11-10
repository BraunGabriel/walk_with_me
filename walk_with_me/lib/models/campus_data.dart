import 'package:apple_maps_flutter/apple_maps_flutter.dart' show LatLng;

import '../services/route_follower.dart' show walkingSpeedMetersPerSecond;
import '../utils/geo.dart';
import 'highlight.dart';
import 'poi.dart';
import 'tour.dart';

/// Everything bundled with the app, loaded once at startup.
class CampusData {
  CampusData({
    required this.pois,
    required this.tours,
    required this.highlights,
  }) : _poiById = {for (final p in pois) p.id: p};

  final List<Poi> pois;
  final List<Tour> tours;
  final List<Highlight> highlights;
  final Map<String, Poi> _poiById;

  Poi? poi(String id) => _poiById[id];

  /// A tour's stops as POIs, in order, skipping any unknown ids.
  List<Poi> stopsFor(Tour tour) => [
    for (final id in tour.stopIds) ?_poiById[id],
  ];

  /// Rough walking length of a tour. Straight-line distance between stops,
  /// padded because paths aren't straight.
  double approxLengthMeters(Tour tour) {
    final stops = stopsFor(tour);
    var meters = 0.0;
    for (var i = 0; i < stops.length - 1; i++) {
      meters += distanceMeters(
        LatLng(stops[i].latitude, stops[i].longitude),
        LatLng(stops[i + 1].latitude, stops[i + 1].longitude),
      );
    }
    return meters * 1.3;
  }

  Duration approxWalkTime(Tour tour) => Duration(
    seconds: (approxLengthMeters(tour) / walkingSpeedMetersPerSecond).round(),
  );
}
