import 'product_model.dart';

class CartItemModel {
  final int id;
  final ProductModel product;
  final int quantity;
  final String quantityDisplay;
  final String totalPrice;
  final bool stockWarning;

  CartItemModel({
    required this.id,
    required this.product,
    required this.quantity,
    required this.quantityDisplay,
    required this.totalPrice,
    required this.stockWarning,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final productData = json['product'];
    ProductModel product;
    if (productData is Map<String, dynamic>) {
      product = ProductModel.fromJson(productData);
    } else {
      product = ProductModel(
        id: productData is int ? productData : 0,
        category: 0,
        categoryName: '',
        name: json['product_name']?.toString() ?? 'Product #${productData}',
        description: '',
        price: json['product_price']?.toString() ?? json['price']?.toString() ?? '0.00',
        stock: 0,
        unit: 'pcs',
        lowStockThreshold: 0,
        lowStockWarning: false,
        stockDisplay: '',
        createdAt: '',
      );
    }

    final double qty = (json['quantity'] as num?)?.toDouble() ?? 1.0;
    final double itemPrice = double.tryParse(product.price) ?? 0.0;
    final String calculatedTotal = (itemPrice * qty).toStringAsFixed(2);

    return CartItemModel(
      id: json['id'] ?? 0,
      product: product,
      quantity: qty.toInt(),
      quantityDisplay: json['quantity_display']?.toString() ?? '${qty.toInt()} ${product.unit}',
      totalPrice: calculatedTotal,
      stockWarning: json['stock_warning'] ?? false,
    );
  }
}
