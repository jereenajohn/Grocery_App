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

  // New fields
  final String subtotal;
  final String platformFee;
  final String convenienceFee;
  final String deliveryCharge;
  final double amountPaid;
  final Map<String, dynamic>? rating;
  final Map<String, dynamic>? paymentSettlementDetails;

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
    this.subtotal = '0.00',
    this.platformFee = '0.00',
    this.convenienceFee = '0.00',
    this.deliveryCharge = '0.00',
    this.amountPaid = 0.0,
    this.rating,
    this.paymentSettlementDetails,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<OrderItemModel> parsedItems = itemsList
        .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    // Check if seller_payment_details object is present (for shop order details API)
    final sellerPaymentDetails = json['seller_payment_details'] as Map<String, dynamic>?;

    final String parsedTotalPrice = json['total_price']?.toString() ?? 
        sellerPaymentDetails?['total_payable_to_shop']?.toString() ?? 
        '0.00';

    final String parsedSubtotal = json['subtotal']?.toString() ?? 
        sellerPaymentDetails?['subtotal']?.toString() ?? 
        '0.00';

    final String parsedDeliveryCharge = json['delivery_charge']?.toString() ?? 
        sellerPaymentDetails?['delivery_charge']?.toString() ?? 
        '0.00';

    return OrderModel(
      id: json['id'] ?? 0,
      orderNo: json['order_no'] ?? '',
      status: json['status'] ?? 'pending',
      totalPrice: parsedTotalPrice,
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
      subtotal: parsedSubtotal,
      platformFee: json['platform_fee']?.toString() ?? '0.00',
      convenienceFee: json['convenience_fee']?.toString() ?? '0.00',
      deliveryCharge: parsedDeliveryCharge,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      rating: json['rating'] is Map<String, dynamic> ? json['rating'] as Map<String, dynamic> : null,
      paymentSettlementDetails: json['payment_settlement_details'] is Map<String, dynamic> ? json['payment_settlement_details'] as Map<String, dynamic> : null,
    );
  }
}
