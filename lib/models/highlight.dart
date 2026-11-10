import 'poi.dart';

/// Something worth pointing out as the walker passes by: a fun fact, a
/// tradition, a photo spot, or a campus building that isn't a tour stop.
class Highlight {
  const Highlight({
    required this.id,
    required this.title,
    required this.text,
    required this.latitude,
    required this.longitude,
    this.category = 'fact',
    this.radiusMeters = defaultRadiusMeters,
    this.poiId,
  });

  static const defaultRadiusMeters = 35.0;

  final String id;
  final String title;
  final String text;
  final double latitude;
  final double longitude;

  /// Free-form type ("fact", "tradition", "photo-spot", "building", ...).
  final String category;

  /// How close the walker must get before it's announced.
  final double radiusMeters;

  /// Set when this highlight describes a POI, so the UI can open its details.
  final String? poiId;

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
    id: json['id'] as String,
    title: json['title'] as String,
    text: json['text'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    category: json['category'] as String? ?? 'fact',
    radiusMeters: (json['radius'] as num?)?.toDouble() ?? defaultRadiusMeters,
    poiId: json['poi'] as String?,
  );

  /// Treats a campus building as a pass-by highlight.
  factory Highlight.fromPoi(Poi poi) => Highlight(
    id: 'poi:${poi.id}',
    title: poi.name,
    text: poi.description,
    latitude: poi.latitude,
    longitude: poi.longitude,
    category: 'building',
    poiId: poi.id,
  );
}
