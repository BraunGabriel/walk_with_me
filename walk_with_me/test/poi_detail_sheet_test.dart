import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walk_with_me/data/poi_repository.dart';
import 'package:walk_with_me/widgets/poi_detail_sheet.dart';

void main() {
  testWidgets('long descriptions fit in the detail sheet on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334); // iPhone SE
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final pois = await tester.runAsync(() => PoiRepository().loadPois());
    // Longest descriptions first — those are the ones that used to overflow.
    final longest = [...pois!]
      ..sort((a, b) => b.description.length.compareTo(a.description.length));

    for (final poi in longest.take(3)) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(poi.id), // fresh app (no sheet left open) per POI
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => PoiDetailSheet.show(context, poi),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(poi.name), findsOneWidget);
      // A RenderFlex overflow would surface here as an exception.
      expect(tester.takeException(), isNull, reason: poi.id);

      // The end of the description is reachable by scrolling.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: poi.id);
    }
  });
}
