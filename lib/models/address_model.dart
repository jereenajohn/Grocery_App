class AddressModel {
  final int id;
  final String address;
  final String landmark;
  final String city;
  final int country;
  final String countryName;
  final int state;
  final String stateName;
  final int district;
  final String districtName;
  final String postalCode;
  final double? latitude;
  final double? longitude;
  final String createdAt;

  AddressModel({
    required this.id,
    required this.address,
    required this.landmark,
    required this.city,
    required this.country,
    required this.countryName,
    required this.state,
    required this.stateName,
    required this.district,
    required this.districtName,
    required this.postalCode,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return AddressModel(
      id: json['id'] ?? 0,
      address: json['address']?.toString() ?? '',
      landmark: json['landmark']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      country: json['country'] ?? 0,
      countryName: json['country_name']?.toString() ?? '',
      state: json['state'] ?? 0,
      stateName: json['state_name']?.toString() ?? '',
      district: json['district'] ?? 0,
      districtName: json['district_name']?.toString() ?? '',
      postalCode: json['postal_code']?.toString() ?? '',
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'landmark': landmark,
      'city': city,
      'country': country,
      'state': state,
      'district': district,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
