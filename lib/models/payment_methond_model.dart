class PaymentMethodModel {
  final int id;
  final String name;
  final String code;
  final bool isActive;

  PaymentMethodModel({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'is_active': isActive,
    };
  }
}