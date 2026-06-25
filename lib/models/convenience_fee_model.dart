class ConvenienceFeeModel {
  final int id;
  final String name;
  final String amount;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  ConvenienceFeeModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConvenienceFeeModel.fromJson(Map<String, dynamic> json) {
    return ConvenienceFeeModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0.00',
      isActive: json['is_active'] == true,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
