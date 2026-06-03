import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/order_model.dart';
import '../widgets/shimmer_loading.dart';

class AdminOrderDetailPage extends StatefulWidget {
  final int orderId;
  const AdminOrderDetailPage({super.key, required this.orderId});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  final ApiService _apiService = ApiService();
  
  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color background = const Color(0xFFF7FFF9);
  final Color goldAccent = const Color(0xFFFFB300);

  OrderModel? _orderDetail;
  bool _isLoading = true;
  String? _errorMessage;

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
      final detail = await _apiService.getAdminOrderDetail(orderId: widget.orderId);
      if (!mounted) return;
      setState(() {
        _orderDetail = detail;
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
                  'Order Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _orderDetail != null ? _orderDetail!.orderNo : 'Loading order...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
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
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.copy_rounded, color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStepper(String status) {
    final lower = status.toLowerCase();
    int currentStep = 0;
    bool isFailed = lower == 'failed' || lower == 'rejected' || lower == 'cancelled';

    if (lower == 'pending') {
      currentStep = 0;
    } else if (lower == 'processing' || lower == 'approved') {
      currentStep = 1;
    } else if (lower == 'completed') {
      currentStep = 2;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER PROGRESS TIMELINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: primaryGreen,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _stepperNode(
                title: 'Placed',
                subtitle: 'Order Received',
                isActive: currentStep >= 0,
                isCompleted: currentStep > 0,
              ),
              _stepperLine(isActive: currentStep > 0),
              _stepperNode(
                title: isFailed ? 'Failed' : 'Processing',
                subtitle: isFailed ? 'Status: $status' : 'In Preparation',
                isActive: currentStep >= 1 || isFailed,
                isCompleted: currentStep > 1 && !isFailed,
                isError: isFailed,
              ),
              _stepperLine(isActive: currentStep > 1 && !isFailed),
              _stepperNode(
                title: 'Completed',
                subtitle: 'Handed Over',
                isActive: currentStep >= 2 && !isFailed,
                isCompleted: currentStep >= 2 && !isFailed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperNode({
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
    bool isError = false,
  }) {
    Color nodeColor = Colors.grey.shade300;
    IconData icon = Icons.circle_outlined;

    if (isActive) {
      nodeColor = isError ? Colors.red : primaryGreen;
      icon = isError ? Icons.cancel_rounded : (isCompleted ? Icons.check_circle_rounded : Icons.pending_rounded);
    }

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: nodeColor, size: 24),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isActive ? Colors.grey.shade800 : Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _stepperLine({required bool isActive}) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(bottom: 24),
      color: isActive ? primaryGreen : Colors.grey.shade200,
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  if (order.sellerPaymentStatus != null)
                    _infoRow(
                      icon: Icons.toll_rounded,
                      label: 'Seller Payout Status',
                      value: order.sellerPaymentStatus!.toUpperCase(),
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
