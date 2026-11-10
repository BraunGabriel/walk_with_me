/// A guided tour: an ordered list of POI ids.
class Tour {
  const Tour({
    required this.id,
    required this.name,
    required this.description,
    required this.stopIds,
  });

  final String id;
  final String name;
  final String description;
  final List<String> stopIds;

  factory Tour.fromJson(Map<String, dynamic> json) => Tour(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    stopIds: (json['stops'] as List).cast<String>(),
  );
}
