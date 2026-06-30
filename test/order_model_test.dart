import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_app/models/order_model.dart';

void main() {
  test('OrderModel parses the updated shop order detail response correctly', () {
    final responseJson = {
      "id": 16,
      "order_no": "GRC-20260625-061529-9418",
      "status": "completed",
      "payment_method": 3,
      "payment_method_name": "UPI",
      "payment_ref": "pay_T5lHn9wIdwlAsJ",
      "full_name": "sneha",
      "phone": "9745030424",
      "address": "MDR, Thoppumpady",
      "city": "Kochi",
      "state": "Kerala",
      "pincode": "682005",
      "country": "India",
      "note": null,
      "seller_payment_status": "PENDING",
      "items": [
        {
          "id": 17,
          "product": {
            "id": 12,
            "category": 7,
            "category_name": "Ice cream",
            "name": "Vannilla Ice Cream",
            "description": "Ice cream",
            "price": "25.00",
            "stock": 5.0,
            "unit": "pcs",
            "stock_display": "5 pcs",
            "is_out_of_stock": false,
            "image": "http://127.0.0.1:8000/media/products/scaled_1000013011.jpg",
            "created_at": "2026-06-04T04:59:50.527315Z"
          },
          "quantity": 1.0,
          "quantity_display": "1 pcs",
          "price": "25.00"
        }
      ],
      "rating": {
        "id": 6,
        "user": 3,
        "user_name": "Aazim N",
        "order": 16,
        "rating": 4,
        "review": "good",
        "created_at": "2026-06-25T06:29:43.060782Z",
        "updated_at": "2026-06-25T06:29:55.355370Z"
      },
      "seller_payment_details": {
        "subtotal": "25.00",
        "delivery_charge": "40.00",
        "total_payable_to_shop": "65.00"
      },
      "created_at": "2026-06-25T06:15:29.323378Z",
      "updated_at": "2026-06-25T06:15:44.996944Z"
    };

    final order = OrderModel.fromJson(responseJson);

    expect(order.id, 16);
    expect(order.orderNo, "GRC-20260625-061529-9418");
    expect(order.status, "completed");
    expect(order.paymentMethod, 3);
    expect(order.paymentMethodName, "UPI");
    expect(order.paymentRef, "pay_T5lHn9wIdwlAsJ");
    expect(order.fullName, "sneha");
    expect(order.phone, "9745030424");
    expect(order.address, "MDR, Thoppumpady");
    expect(order.city, "Kochi");
    expect(order.state, "Kerala");
    expect(order.pincode, "682005");
    expect(order.country, "India");
    expect(order.note, isNull);
    expect(order.sellerPaymentStatus, "PENDING");
    
    // Items check
    expect(order.items.length, 1);
    final item = order.items.first;
    expect(item.id, 17);
    expect(item.quantity, 1.0);
    expect(item.quantityDisplay, "1 pcs");
    expect(item.price, "25.00");
    expect(item.product.id, 12);
    expect(item.product.name, "Vannilla Ice Cream");
    
    // Rating check
    expect(order.rating, isNotNull);
    expect(order.rating!['id'], 6);
    expect(order.rating!['rating'], 4);
    expect(order.rating!['review'], "good");

    // Seller payment details check
    expect(order.subtotal, "25.00");
    expect(order.deliveryCharge, "40.00");
    expect(order.totalPrice, "65.00");
  });

  test('OrderModel parses the updated admin order detail response correctly', () {
    final responseJson = {
      "id": 16,
      "order_no": "GRC-20260625-061529-9418",
      "status": "completed",
      "total_price": "90.00",
      "subtotal": "25.00",
      "platform_fee": "15.00",
      "convenience_fee": "10.00",
      "delivery_charge": "40.00",
      "amount_paid": 90.0,
      "payment_method": 3,
      "payment_method_name": "UPI",
      "payment_ref": "pay_T5lHn9wIdwlAsJ",
      "full_name": "sneha",
      "phone": "9745030424",
      "address": "MDR, Thoppumpady",
      "city": "Kochi",
      "state": "Kerala",
      "pincode": "682005",
      "country": "India",
      "note": null,
      "seller_payment_status": "PENDING",
      "items": [
        {
          "id": 17,
          "product": {
            "id": 12,
            "category": 7,
            "category_name": "Ice cream",
            "name": "Vannilla Ice Cream",
            "description": "Ice cream",
            "price": "25.00",
            "stock": 5.0,
            "unit": "pcs",
            "stock_display": "5 pcs",
            "is_out_of_stock": false,
            "image": "/media/products/scaled_1000013011.jpg",
            "created_at": "2026-06-04T04:59:50.527315Z"
          },
          "quantity": 1.0,
          "quantity_display": "1 pcs",
          "price": "25.00",
          "seller_id": 18,
          "seller_phone": "9999999993",
          "shop_name": "Fresh Choice"
        }
      ],
      "customer_id": 3,
      "customer_phone": "9745030424",
      "customer_name": "Aazim N",
      "rating": {
        "id": 6,
        "user": 3,
        "user_name": "Aazim N",
        "order": 16,
        "rating": 4,
        "review": "good",
        "created_at": "2026-06-25T06:29:43.060782Z",
        "updated_at": "2026-06-25T06:29:55.355370Z"
      },
      "payment_settlement_details": {
        "seller_payment_details": {
          "subtotal": "25.00",
          "delivery_charge": "40.00",
          "total_payable_to_shop": "65.00"
        },
        "admin_profit_details": {
          "platform_fee": "15.00",
          "convenience_fee": "10.00",
          "total_admin_profit": "25.00"
        }
      },
      "created_at": "2026-06-25T06:15:29.323378Z",
      "updated_at": "2026-06-25T06:15:44.996944Z"
    };

    final order = OrderModel.fromJson(responseJson);

    expect(order.id, 16);
    expect(order.orderNo, "GRC-20260625-061529-9418");
    expect(order.status, "completed");
    expect(order.totalPrice, "90.00");
    expect(order.subtotal, "25.00");
    expect(order.platformFee, "15.00");
    expect(order.convenienceFee, "10.00");
    expect(order.deliveryCharge, "40.00");
    expect(order.amountPaid, 90.0);
    
    // Items seller info check
    expect(order.items.length, 1);
    final item = order.items.first;
    expect(item.sellerId, 18);
    expect(item.sellerPhone, "9999999993");
    expect(item.shopName, "Fresh Choice");
    
    // Customer Info check
    expect(order.customerId, 3);
    expect(order.customerPhone, "9745030424");
    expect(order.customerName, "Aazim N");

    // Rating check
    expect(order.rating, isNotNull);
    expect(order.rating!['rating'], 4);
    expect(order.rating!['review'], "good");

    // Payment settlement details check
    expect(order.paymentSettlementDetails, isNotNull);
    expect(order.paymentSettlementDetails!['seller_payment_details']?['total_payable_to_shop'], "65.00");
    expect(order.paymentSettlementDetails!['admin_profit_details']?['total_admin_profit'], "25.00");
  });
}
