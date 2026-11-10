import 'package:apple_maps_flutter/apple_maps_flutter.dart' show LatLng;
import 'package:flutter_test/flutter_test.dart';
import 'package:walk_with_me/data/poi_repository.dart';
import 'package:walk_with_me/models/highlight.dart';
import 'package:walk_with_me/models/walking_route.dart';
import 'package:walk_with_me/services/highlight_tracker.dart';
import 'package:walk_with_me/services/route_follower.dart';
import 'package:walk_with_me/utils/geo.dart';

/// An L-shaped route on campus: east ~160 m, then north ~110 m.
const _a = LatLng(42.9620, -85.8900);
const _b = LatLng(42.9620, -85.8880);
const _c = LatLng(42.9630, -85.8880);

WalkingRoute _route() => WalkingRoute(
  points: const [_a, _b, _c],
  distanceMeters: distanceMeters(_a, _b) + distanceMeters(_b, _c),
  durationSeconds: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('distanceMeters is sane at campus scale', () {
    // 0.001° latitude ≈ 111 m.
    expect(distanceMeters(_b, _c), closeTo(111, 1));
  });

  group('RouteFollower', () {
    test('at the start, the whole route remains', () {
      final s = RouteFollower(_route()).update(_a);
      expect(s.remainingMeters, closeTo(_route().distanceMeters, 1));
      expect(s.isOffRoute, isFalse);
    });

    test('halfway along the first leg trims the walked part', () {
      final follower = RouteFollower(_route());
      final s = follower.update(const LatLng(42.96202, -85.8890));
      final expected =
          distanceMeters(const LatLng(42.9620, -85.8890), _b) +
          distanceMeters(_b, _c);
      expect(s.remainingMeters, closeTo(expected, 3));
      expect(s.remaining.first.longitude, closeTo(-85.8890, 1e-6));
      expect(s.remaining.last, _c);
      expect(s.offRouteMeters, lessThan(5));
    });

    test('flags walking far from the path as off route', () {
      final s = RouteFollower(_route()).update(const LatLng(42.9610, -85.8890));
      expect(s.offRouteMeters, greaterThan(100));
      expect(s.isOffRoute, isTrue);
    });

    test('does not snap backwards once progress is made', () {
      final follower = RouteFollower(_route());
      follower.update(_b);
      follower.update(const LatLng(42.9625, -85.8880));
      final s = follower.update(const LatLng(42.9628, -85.8880));
      expect(s.remaining.length, 2);
      expect(
        s.remainingMeters,
        closeTo(distanceMeters(s.remaining.first, _c), 1),
      );
    });
  });

  group('HighlightTracker', () {
    const h = Highlight(
      id: 'h',
      title: 'H',
      text: '',
      latitude: 42.9620,
      longitude: -85.8890,
      radiusMeters: 30,
    );

    test('announces once when entering the radius', () {
      final tracker = HighlightTracker();
      expect(tracker.check(_a, [h]), isEmpty); // ~80 m away
      expect(tracker.check(const LatLng(42.9620, -85.8891), [h]), [h]);
      expect(tracker.check(const LatLng(42.9620, -85.8890), [h]), isEmpty);
      tracker.reset();
      expect(tracker.check(const LatLng(42.9620, -85.8890), [h]), [h]);
    });
  });

  test('bundled highlights load and point at real POIs', () async {
    final repo = PoiRepository();
    final poiIds = (await repo.loadPois()).map((p) => p.id).toSet();
    final highlights = await repo.loadHighlights();
    expect(highlights.map((h) => h.id).toSet().length, highlights.length);
    for (final h in highlights) {
      if (h.poiId != null) expect(poiIds, contains(h.poiId), reason: h.id);
      expect(h.latitude, closeTo(42.963, 0.02), reason: h.id);
      expect(h.longitude, closeTo(-85.889, 0.02), reason: h.id);
    }
  });
}
