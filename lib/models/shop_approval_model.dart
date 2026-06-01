class ShopApprovalModel {
  final int id;
  final String phone;
  final String email;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String userType;
  final String approvalStatus;
  final bool isPhoneVerified;
  final String country;
  final String state;
  final String district;
  final String? latitude;
  final String? longitude;
  final String createdAt;

  ShopApprovalModel({
    required this.id,
    required this.phone,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    required this.userType,
    required this.approvalStatus,
    required this.isPhoneVerified,
    required this.country,
    required this.state,
    required this.district,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory ShopApprovalModel.fromJson(Map<String, dynamic> json) {
    return ShopApprovalModel(
      id: json['id'] ?? 0,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      profilePicture: json['profile_picture']?.toString(),
      userType: json['user_type']?.toString() ?? 'shop',
      approvalStatus: json['approval_status']?.toString() ?? 'pending',
      isPhoneVerified: json['is_phone_verified'] ?? false,
      country: json['country']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
