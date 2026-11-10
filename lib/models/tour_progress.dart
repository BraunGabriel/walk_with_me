import 'poi.dart';
import 'tour.dart';

/// Where the user is within an active tour. Immutable; [next]/[previous]
/// return new instances.
class TourProgress {
  TourProgress({required this.tour, required this.stops, this.index = 0})
    : assert(stops.isNotEmpty),
      assert(index >= 0 && index < stops.length);

  final Tour tour;

  /// Resolved POIs, in tour order.
  final List<Poi> stops;
  final int index;

  Poi get current => stops[index];
  bool get isFirst => index == 0;
  bool get isLast => index == stops.length - 1;

  /// 1-based stop number, for display.
  int get stopNumber => index + 1;
  int get stopCount => stops.length;

  TourProgress next() =>
      isLast ? this : TourProgress(tour: tour, stops: stops, index: index + 1);

  TourProgress previous() =>
      isFirst ? this : TourProgress(tour: tour, stops: stops, index: index - 1);

  /// Position of [poi] in this tour, or -1 if it isn't a stop.
  int indexOf(Poi poi) => stops.indexWhere((s) => s.id == poi.id);

  bool isVisited(Poi poi) {
    final i = indexOf(poi);
    return i >= 0 && i < index;
  }
}
