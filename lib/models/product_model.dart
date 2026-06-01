import '../constants/api_constants.dart';

class ProductModel {
  final int id;
  final int category;
  final String categoryName;
  final String name;
  final String description;
  final String price;
  final double stock;
  final String unit;
  final double lowStockThreshold;
  final bool lowStockWarning;
  final String stockDisplay;
  final String? image;
  final String createdAt;

  ProductModel({
    required this.id,
    required this.category,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.unit,
    required this.lowStockThreshold,
    required this.lowStockWarning,
    required this.stockDisplay,
    this.image,
    required this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String? imgUrl = json['image'];
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (!imgUrl.startsWith('http://') && !imgUrl.startsWith('https://')) {
        imgUrl = imgUrl.startsWith('/')
            ? '${ApiConstants.api}${imgUrl.substring(1)}'
            : '${ApiConstants.api}$imgUrl';
      }
    }
    return ProductModel(
      id: json['id'],
      category: json['category'],
      categoryName: json['category_name'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: json['price'] ?? '0.00',
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? 'pcs',
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toDouble() ?? 0.0,
      lowStockWarning: json['low_stock_warning'] ?? false,
      stockDisplay: json['stock_display'] ?? '',
      image: imgUrl,
      createdAt: json['created_at'] ?? '',
    );
  }
}
