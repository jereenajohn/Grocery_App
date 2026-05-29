class StateModel {
  final int id;
  final String countryName;
  final String name;
  final int country;

  StateModel({
    required this.id,
    required this.countryName,
    required this.name,
    required this.country,
  });

  factory StateModel.fromJson(Map<String, dynamic> json) {
    return StateModel(
      id: json['id'] ?? 0,
      countryName: json['country_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      country: json['country'] ?? 0,
    );
  }
}