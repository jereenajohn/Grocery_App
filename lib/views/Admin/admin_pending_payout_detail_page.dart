import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/order_model.dart';
import '../widgets/shimmer_loading.dart';

class AdminPendingPayoutDetailPage extends StatefulWidget {
  final int orderId;
  const AdminPendingPayoutDetailPage({super.key, required this.orderId});

  @override
  State<AdminPendingPayoutDetailPage> createState() => _AdminPendingPayoutDetailPageState();
}

class _AdminPendingPayoutDetailPageState extends State<AdminPendingPayoutDetailPage> {
  final ApiService _apiService = ApiService();
  
  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color background = const Color(0xFFF7FFF9);
  final Color goldAccent = const Color(0xFFFFB300);

  OrderModel? _orderDetail;
  bool _isLoading = true;
  String? _errorMessage;
  String? _sellerPaymentStatus;
  bool _updatingPaymentStatus = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detailFuture = _apiService.getUnpaidPayoutDetail(orderId: widget.orderId);
      final paymentStatusFuture = _apiService.getOrderPaymentStatus(orderId: widget.orderId);

      final results = await Future.wait([detailFuture, paymentStatusFuture]);

      final detail = results[0] as OrderModel;
      final paymentStatusData = results[1] as Map<String, dynamic>;

      String? parsedStatus;
      if (paymentStatusData['success'] == true && paymentStatusData['data'] is Map) {
        parsedStatus = paymentStatusData['data']['seller_payment_status']?.toString();
      }

      if (!mounted) return;
      setState(() {
        _orderDetail = detail;
        _sellerPaymentStatus = parsedStatus ?? detail.sellerPaymentStatus ?? 'PENDING';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSellerPaymentStatus(String newStatus) async {
    setState(() {
      _updatingPaymentStatus = true;
    });

    try {
      final res = await _apiService.updateOrderPaymentStatus(
        orderId: widget.orderId,
        status: newStatus.toUpperCase(),
      );
      final updatedStatus = res['seller_payment_status']?.toString()?.toUpperCase() ?? newStatus.toUpperCase();

      if (!mounted) return;
      setState(() {
        _sellerPaymentStatus = updatedStatus;
        _updatingPaymentStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Seller payment status updated to ${updatedStatus.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updatingPaymentStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString().replaceAll('Exception:', '').trim()}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } catch (_) {
      return isoString;
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copied to clipboard!'),
          ],
        ),
        backgroundColor: darkGreen,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payout Order Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _orderDetail?.orderNo ?? 'Loading...',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_orderDetail != null)
                      GestureDetector(
                        onTap: () => _copyToClipboard(_orderDetail!.orderNo, 'Order Number'),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_orderDetail != null) ...[
            const SizedBox(width: 8),
            _statusBadge(_orderDetail!.status),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final lower = status.toLowerCase();
    Color bgColor = Colors.white24;
    Color textColor = Colors.white;

    if (lower == 'completed' || lower == 'approved') {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF1B8F3A);
    } else if (lower == 'pending') {
      bgColor = const Color(0xFFFFF3E0);
      textColor = Colors.orange.shade800;
    } else if (lower == 'failed' || lower == 'rejected' || lower == 'cancelled') {
      bgColor = const Color(0xFFFFEBEE);
      textColor = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusStepper(String currentStatus) {
    final lower = currentStatus.toLowerCase();
    int currentStep = 0;
    if (lower == 'pending') currentStep = 0;
    if (lower == 'shipped') currentStep = 1;
    if (lower == 'completed') currentStep = 2;
    if (lower == 'cancelled') currentStep = -1;

    final steps = ['PENDING', 'SHIPPED', 'COMPLETED'];

    if (currentStep == -1) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 12),
            Text(
              'ORDER CANCELLED',
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCompleted = index <= currentStep;
          final stepColor = isCompleted ? primaryGreen : Colors.grey.shade300;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: stepColor.withOpacity(0.12),
                  child: Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: stepColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isCompleted ? Colors.grey.shade800 : Colors.grey.shade400,
                    letterSpacing: 0.3,
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      height: 1.5,
                      color: stepColor,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 17),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _priceSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? Colors.grey.shade800 : Colors.grey.shade600,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? Colors.grey.shade800 : Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryGreen, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (copyable && value.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _copyToClipboard(value, label),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.copy_rounded, color: Colors.grey.shade600, size: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: List.generate(40, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                height: 1,
                color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade300,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDetailItemRow(OrderItemModel item) {
    final double itemTotal = (double.tryParse(item.price) ?? 0.0) * item.quantity;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: lightGreen.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade50),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.product.image != null
                        ? Image.network(
                            item.product.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.shopping_basket_rounded,
                              color: primaryGreen,
                              size: 24,
                            ),
                          )
                        : Icon(
                            Icons.shopping_basket_rounded,
                            color: primaryGreen,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.product.categoryName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${itemTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${item.quantityDisplay} • ₹${item.price}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (item.shopName != null || item.sellerPhone != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, thickness: 0.5, color: Color(0xFFE2F0D9)),
              ),
              Row(
                children: [
                  Icon(Icons.storefront_rounded, size: 13, color: primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Shop: ${item.shopName ?? 'N/A'} ${item.sellerPhone != null ? "(${item.sellerPhone})" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.sellerPhone != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _copyToClipboard(item.sellerPhone!, 'Seller Phone'),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Icon(Icons.copy_rounded, color: primaryGreen, size: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Expanded(
        child: OrderDetailShimmer(),
      );
    }

    if (_errorMessage != null) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 54),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _fetchOrderDetail,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _orderDetail!;

    return Expanded(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            // Timeline stepper
            _buildStatusStepper(order.status),

            // Item Invoice Card
            _sectionCard(
              title: 'INVOICE & RECEIPT ITEMS',
              icon: Icons.receipt_long_rounded,
              accentColor: primaryGreen,
              child: Column(
                children: [
                  ...order.items.map((item) => _buildDetailItemRow(item)),
                  _buildDashedDivider(),
                  _priceSummaryRow('Subtotal', '₹${order.subtotal}'),
                  if (double.tryParse(order.platformFee) != null && double.parse(order.platformFee) > 0) ...[
                    const SizedBox(height: 4),
                    _priceSummaryRow('Platform Fee', '₹${order.platformFee}'),
                  ],
                  if (double.tryParse(order.convenienceFee) != null && double.parse(order.convenienceFee) > 0) ...[
                    const SizedBox(height: 4),
                    _priceSummaryRow('Convenience Fee', '₹${order.convenienceFee}'),
                  ],
                  if (double.tryParse(order.deliveryCharge) != null && double.parse(order.deliveryCharge) > 0) ...[
                    const SizedBox(height: 4),
                    _priceSummaryRow('Delivery Charge', '₹${order.deliveryCharge}'),
                  ],
                  _buildDashedDivider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable Amount',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                      ),
                      Text(
                        '₹${order.totalPrice}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Customer details
            if (order.customerName != null || order.customerPhone != null)
              _sectionCard(
                title: 'CUSTOMER ACCOUNT INFORMATION',
                icon: Icons.person_search_rounded,
                accentColor: Colors.blue.shade700,
                child: Column(
                  children: [
                    if (order.customerName != null)
                      _infoRow(
                        icon: Icons.account_circle_outlined,
                        label: 'Registered Customer Name',
                        value: order.customerName!,
                        copyable: true,
                      ),
                    if (order.customerPhone != null)
                      _infoRow(
                        icon: Icons.phone_iphone_rounded,
                        label: 'Registered Phone No',
                        value: order.customerPhone!,
                        copyable: true,
                      ),
                    if (order.customerId != null)
                      _infoRow(
                        icon: Icons.fingerprint_rounded,
                        label: 'Internal Database ID',
                        value: order.customerId.toString(),
                        copyable: true,
                      ),
                  ],
                ),
              ),

            // Delivery Details
            _sectionCard(
              title: 'DELIVERY ADDRESS & CONTACTS',
              icon: Icons.directions_bike_rounded,
              accentColor: Colors.teal.shade700,
              child: Column(
                children: [
                  _infoRow(
                    icon: Icons.person_rounded,
                    label: 'Recipient Full Name',
                    value: order.fullName,
                    copyable: true,
                  ),
                  _infoRow(
                    icon: Icons.phone_rounded,
                    label: 'Recipient Mobile Number',
                    value: order.phone,
                    copyable: true,
                  ),
                  _infoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Complete Shipping Destination',
                    value: '${order.address}, ${order.city}, ${order.state} - ${order.pincode}, ${order.country}',
                    copyable: true,
                  ),
                  if (order.note != null && order.note!.trim().isNotEmpty)
                    _infoRow(
                      icon: Icons.sticky_note_2_rounded,
                      label: 'Optional Courier Instructions / Note',
                      value: order.note!,
                      copyable: true,
                    ),
                ],
              ),
            ),

            // Payment information
            _sectionCard(
              title: 'PAYMENT GATEWAY DETAILS',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: Colors.amber.shade900,
              child: Column(
                children: [
                  _infoRow(
                    icon: Icons.payment_rounded,
                    label: 'Selected Gateway / Method',
                    value: order.paymentMethodName,
                  ),
                  if (order.paymentRef != null && order.paymentRef!.trim().isNotEmpty)
                    _infoRow(
                      icon: Icons.bookmark_added_rounded,
                      label: 'Payment Gateway Reference / TXN ID',
                      value: order.paymentRef!,
                      copyable: true,
                    ),
                  _infoRow(
                    icon: Icons.toll_rounded,
                    label: 'Seller Payout Status',
                    value: (_sellerPaymentStatus ?? order.sellerPaymentStatus ?? 'PENDING').toUpperCase(),
                  ),
                  _infoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Placed Date & Time',
                    value: _formatDateTime(order.createdAt),
                  ),
                  _infoRow(
                    icon: Icons.update_rounded,
                    label: 'Last Modification Date & Time',
                    value: _formatDateTime(order.updatedAt),
                  ),
                ],
              ),
            ),

            _sectionCard(
              title: 'UPDATE SELLER PAYMENT STATUS',
              icon: Icons.price_check_rounded,
              accentColor: Colors.teal.shade800,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seller Payment State:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade50,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_updatingPaymentStatus)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryGreen,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {'value': 'PENDING', 'label': 'Pending'},
                      {'value': 'PROCESSING', 'label': 'Processing'},
                      {'value': 'PAID', 'label': 'Paid'},
                    ].map((statusMap) {
                      final val = statusMap['value']!;
                      final lbl = statusMap['label']!;
                      final isSelected = (_sellerPaymentStatus ?? 'PENDING').toUpperCase() == val;
                      Color activeColor = Colors.grey.shade700;
                      if (val == 'PAID') activeColor = const Color(0xFF1B8F3A);
                      if (val == 'PENDING') activeColor = Colors.orange.shade800;
                      if (val == 'PROCESSING') activeColor = Colors.blue.shade700;

                      return InkWell(
                        onTap: _updatingPaymentStatus
                            ? null
                            : () => _updateSellerPaymentStatus(val),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? activeColor.withOpacity(0.12)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? activeColor : Colors.grey.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: activeColor,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                lbl.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? activeColor : Colors.grey.shade600,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            if (order.paymentSettlementDetails != null)
              _sectionCard(
                title: 'PAYMENT SETTLEMENT BREAKDOWN',
                icon: Icons.analytics_rounded,
                accentColor: Colors.purple.shade700,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHOP PAYOUT DETAILS (To Seller)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _priceSummaryRow('Subtotal', '₹${order.paymentSettlementDetails!['seller_payment_details']?['subtotal'] ?? '0.00'}'),
                    _priceSummaryRow('Delivery Charge', '₹${order.paymentSettlementDetails!['seller_payment_details']?['delivery_charge'] ?? '0.00'}'),
                    const SizedBox(height: 4),
                    _priceSummaryRow(
                      'Total Payable to Shop',
                      '₹${order.paymentSettlementDetails!['seller_payment_details']?['total_payable_to_shop'] ?? '0.00'}',
                      isBold: true,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, thickness: 0.5, color: Colors.purple),
                    ),
                    const Text(
                      'ADMIN PROFIT DETAILS (To Platform)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _priceSummaryRow('Platform Fee', '₹${order.paymentSettlementDetails!['admin_profit_details']?['platform_fee'] ?? '0.00'}'),
                    _priceSummaryRow('Convenience Fee', '₹${order.paymentSettlementDetails!['admin_profit_details']?['convenience_fee'] ?? '0.00'}'),
                    const SizedBox(height: 4),
                    _priceSummaryRow(
                      'Total Admin Profit',
                      '₹${order.paymentSettlementDetails!['admin_profit_details']?['total_admin_profit'] ?? '0.00'}',
                      isBold: true,
                    ),
                  ],
                ),
              ),

            if (order.rating != null)
              _sectionCard(
                title: 'CUSTOMER FEEDBACK',
                icon: Icons.star_rounded,
                accentColor: goldAccent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            final int score = order.rating!['rating'] ?? 0;
                            return Icon(
                              index < score ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: goldAccent,
                              size: 20,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${order.rating!['rating']}/5)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    if (order.rating!['review'] != null && order.rating!['review'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Text(
                          '"${order.rating!['review']}"',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildBody(),
          ],
        ),
      ),
    );
  }
}
