class DistrictModel {
  final int id;
  final String stateName;
  final String countryName;
  final String name;
  final int state;

  DistrictModel({
    required this.id,
    required this.stateName,
    required this.countryName,
    required this.name,
    required this.state,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      id: json['id'] ?? 0,
      stateName: json['state_name']?.toString() ?? '',
      countryName: json['country_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      state: json['state'] ?? 0,
    );
  }
}