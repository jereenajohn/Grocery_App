import 'product_model.dart';

class OrderItemModel {
  final int id;
  final ProductModel product;
  final double quantity;
  final String quantityDisplay;
  final String price;
  final int? sellerId;
  final String? sellerPhone;
  final String? shopName;

  OrderItemModel({
    required this.id,
    required this.product,
    required this.quantity,
    required this.quantityDisplay,
    required this.price,
    this.sellerId,
    this.sellerPhone,
    this.shopName,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] ?? 0,
      product: ProductModel.fromJson(json['product'] ?? {}),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityDisplay: json['quantity_display'] ?? '',
      price: json['price']?.toString() ?? '0.00',
      sellerId: json['seller_id'] as int?,
      sellerPhone: json['seller_phone']?.toString(),
      shopName: json['shop_name']?.toString(),
    );
  }
}

class OrderModel {
  final int id;
  final String orderNo;
  final String status;
  final String totalPrice;
  final int paymentMethod;
  final String paymentMethodName;
  final String? paymentRef;
  final String fullName;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final String? note;
  final List<OrderItemModel> items;
  final String createdAt;
  final String updatedAt;
  final String? sellerPaymentStatus;
  final int? customerId;
  final String? customerPhone;
  final String? customerName;

  OrderModel({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.totalPrice,
    required this.paymentMethod,
    required this.paymentMethodName,
    this.paymentRef,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.country,
    this.note,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.sellerPaymentStatus,
    this.customerId,
    this.customerPhone,
    this.customerName,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<OrderItemModel> parsedItems = itemsList
        .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return OrderModel(
      id: json['id'] ?? 0,
      orderNo: json['order_no'] ?? '',
      status: json['status'] ?? 'pending',
      totalPrice: json['total_price']?.toString() ?? '0.00',
      paymentMethod: json['payment_method'] ?? 0,
      paymentMethodName: json['payment_method_name'] ?? '',
      paymentRef: json['payment_ref'],
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'] ?? '',
      country: json['country'] ?? '',
      note: json['note'],
      items: parsedItems,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      sellerPaymentStatus: json['seller_payment_status'],
      customerId: json['customer_id'] as int?,
      customerPhone: json['customer_phone']?.toString(),
      customerName: json['customer_name']?.toString(),
    );
  }
}
