import '../constants/api_constants.dart';

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
  final String? productImage;
  final double? productPrice;
  final double? avgRating;
  final String createdAt;
  final bool isOpen;

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
    this.productImage,
    this.productPrice,
    this.avgRating,
    required this.createdAt,
    required this.isOpen,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    String? profilePic = json['profile_picture']?.toString();
    if (profilePic != null && profilePic.isNotEmpty) {
      if (!profilePic.startsWith('http://') && !profilePic.startsWith('https://')) {
        profilePic = profilePic.startsWith('/')
            ? '${ApiConstants.api}${profilePic.substring(1)}'
            : '${ApiConstants.api}$profilePic';
      }
    }
    String? productImg = json['product_image']?.toString();
    if (productImg != null && productImg.isNotEmpty) {
      if (!productImg.startsWith('http://') && !productImg.startsWith('https://')) {
        productImg = productImg.startsWith('/')
            ? '${ApiConstants.api}${productImg.substring(1)}'
            : '${ApiConstants.api}$productImg';
      }
    }
    final double? productPri = json['product_price'] != null
        ? double.tryParse(json['product_price'].toString())
        : null;
    final double? rating = json['avg_rating'] != null
        ? double.tryParse(json['avg_rating'].toString())
        : null;

    return ShopModel(
      id: json['id'] ?? 0,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      shop_name: json['shop_name']?.toString() ?? '',
      profilePicture: profilePic,
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
      productImage: productImg,
      productPrice: productPri,
      avgRating: rating,
      createdAt: json['created_at']?.toString() ?? '',
      isOpen: json['is_open'] ?? json['is_active'] ?? true,
    );
  }
}
