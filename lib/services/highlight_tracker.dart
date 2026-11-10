import 'package:apple_maps_flutter/apple_maps_flutter.dart' show LatLng;

import '../models/highlight.dart';
import '../utils/geo.dart';

/// Decides when to point out a highlight: the first time the walker comes
/// within its radius. Each highlight is announced at most once per tour.
class HighlightTracker {
  final _announced = <String>{};

  /// Returns highlights newly in range of [position], nearest first.
  List<Highlight> check(LatLng position, Iterable<Highlight> candidates) {
    final hits = <(Highlight, double)>[];
    for (final h in candidates) {
      if (_announced.contains(h.id)) continue;
      final d = distanceMeters(position, LatLng(h.latitude, h.longitude));
      if (d <= h.radiusMeters) hits.add((h, d));
    }
    hits.sort((a, b) => a.$2.compareTo(b.$2));
    _announced.addAll(hits.map((e) => e.$1.id));
    return [for (final (h, _) in hits) h];
  }

  void reset() => _announced.clear();
}
