/// A point of interest on campus (building, landmark, etc.).
class Poi {
  const Poi({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String description;

  factory Poi.fromJson(Map<String, dynamic> json) => Poi(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    description: json['description'] as String,
  );
}
