import 'package:flutter_test/flutter_test.dart';
import 'package:walk_with_me/data/poi_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled POIs load and are near GVSU Allendale', () async {
    final pois = await PoiRepository().loadPois();
    expect(pois, isNotEmpty);
    expect(
      pois.map((p) => p.id).toSet().length,
      pois.length,
      reason: 'POI ids must be unique',
    );
    for (final p in pois) {
      expect(p.latitude, closeTo(42.963, 0.02), reason: p.name);
      expect(p.longitude, closeTo(-85.889, 0.02), reason: p.name);
    }
  });
}
