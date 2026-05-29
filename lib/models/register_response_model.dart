class RegisterResponseModel {
  final String detail;
  final GroceryUser user;

  RegisterResponseModel({
    required this.detail,
    required this.user,
  });

  factory RegisterResponseModel.fromJson(Map<String, dynamic> json) {
    return RegisterResponseModel(
      detail: json['detail']?.toString() ?? '',
      user: GroceryUser.fromJson(json['user'] ?? {}),
    );
  }
}

class GroceryUser {
  final int id;
  final String phone;
  final String firstName;
  final String lastName;
  final String email;
  final String userType;
  final String approvalStatus;
  final String profilePicture;
  final int? country;
  final int? state;
  final int? district;

  GroceryUser({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.userType,
    required this.approvalStatus,
    required this.profilePicture,
    required this.country,
    required this.state,
    required this.district,
  });

  factory GroceryUser.fromJson(Map<String, dynamic> json) {
    return GroceryUser(
      id: json['id'] ?? 0,
      phone: json['phone']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      userType: json['user_type']?.toString() ?? '',
      approvalStatus: json['approval_status']?.toString() ?? '',
      profilePicture: json['profile_picture']?.toString() ?? '',
      country: json['country'],
      state: json['state'],
      district: json['district'],
    );
  }
}