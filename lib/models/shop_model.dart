class ShopModel {
  final int id;
  final String phone;
  final String email;
  final String firstName;
  final String shop_name;
  final String lastName;
  final String? profilePicture;
  final String userType;
  final String approvalStatus;
  final bool isPhoneVerified;
  final int country;
  final String countryName;
  final int state;
  final String stateName;
  final int district;
  final String districtName;
  final String? latitude;
  final String? longitude;
  final String createdAt;

  ShopModel({
    required this.id,
    required this.phone,
    required this.email,
    required this.firstName,
    required this.shop_name,
    required this.lastName,
    this.profilePicture,
    required this.userType,
    required this.approvalStatus,
    required this.isPhoneVerified,
    required this.country,
    required this.countryName,
    required this.state,
    required this.stateName,
    required this.district,
    required this.districtName,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] ?? 0,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      shop_name: json['shop_name']?.toString() ?? '',
      profilePicture: json['profile_picture']?.toString(),
      userType: json['user_type']?.toString() ?? '',
      approvalStatus: json['approval_status']?.toString() ?? '',
      isPhoneVerified: json['is_phone_verified'] ?? false,
      country: json['country'] ?? 0,
      countryName: json['country_name']?.toString() ?? '',
      state: json['state'] ?? 0,
      stateName: json['state_name']?.toString() ?? '',
      district: json['district'] ?? 0,
      districtName: json['district_name']?.toString() ?? '',
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
