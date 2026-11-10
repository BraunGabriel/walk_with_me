import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/campus_data.dart';
import '../models/highlight.dart';
import '../models/poi.dart';
import '../models/tour.dart';

/// Loads campus points of interest and tours from bundled JSON assets.
class PoiRepository {
  static const _poiPath = 'assets/data/pois.json';
  static const _tourPath = 'assets/data/tours.json';
  static const _highlightPath = 'assets/data/highlights.json';

  Future<CampusData> loadAll() async {
    final (pois, tours, highlights) = await (
      loadPois(),
      loadTours(),
      loadHighlights(),
    ).wait;
    return CampusData(pois: pois, tours: tours, highlights: highlights);
  }

  Future<List<Poi>> loadPois() async {
    final decoded = jsonDecode(await rootBundle.loadString(_poiPath)) as Map;
    return (decoded['pois'] as List)
        .map((e) => Poi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Highlight>> loadHighlights() async {
    final decoded =
        jsonDecode(await rootBundle.loadString(_highlightPath)) as Map;
    return (decoded['highlights'] as List)
        .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Tour>> loadTours() async {
    final decoded = jsonDecode(await rootBundle.loadString(_tourPath)) as Map;
    return (decoded['tours'] as List)
        .map((e) => Tour.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
