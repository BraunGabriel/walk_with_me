import 'package:flutter_test/flutter_test.dart';
import 'package:walk_with_me/data/poi_repository.dart';
import 'package:walk_with_me/models/poi.dart';
import 'package:walk_with_me/models/tour.dart';
import 'package:walk_with_me/models/tour_progress.dart';
import 'package:walk_with_me/widgets/tour_panel.dart';

Poi _poi(String id) => Poi(
  id: id,
  name: id,
  category: 'x',
  latitude: 0,
  longitude: 0,
  description: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every tour stop refers to a real POI', () async {
    final repo = PoiRepository();
    final ids = (await repo.loadPois()).map((p) => p.id).toSet();
    for (final tour in await repo.loadTours()) {
      expect(tour.stopIds, isNotEmpty, reason: tour.id);
      for (final stop in tour.stopIds) {
        expect(ids, contains(stop), reason: '${tour.id} -> $stop');
      }
    }
  });

  group('TourProgress', () {
    final stops = [_poi('a'), _poi('b'), _poi('c')];
    const tour = Tour(
      id: 't',
      name: 'T',
      description: '',
      stopIds: ['a', 'b', 'c'],
    );

    test('steps forward and back, clamped at the ends', () {
      var p = TourProgress(tour: tour, stops: stops);
      expect(p.isFirst, isTrue);
      expect(p.previous().index, 0);
      p = p.next().next();
      expect(p.current.id, 'c');
      expect(p.isLast, isTrue);
      expect(p.next().index, 2);
      expect(p.previous().current.id, 'b');
    });

    test('tracks visited stops', () {
      final p = TourProgress(tour: tour, stops: stops, index: 1);
      expect(p.isVisited(stops[0]), isTrue);
      expect(p.isVisited(stops[1]), isFalse);
      expect(p.isVisited(_poi('elsewhere')), isFalse);
    });
  });

  test('formatDistance', () {
    expect(formatDistance(5), "You're here");
    expect(formatDistance(100), '330 ft away');
    expect(formatDistance(1609), '1.0 mi away');
  });
}
