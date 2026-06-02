import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/cart_item_model.dart';
import '../../models/address_model.dart';
import '../../models/payment_method_model.dart';
import '../../models/country_model.dart';
import '../../models/state_model.dart';
import '../../models/district_model.dart';
import '../../services/api_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../constants/api_constants.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final ApiService _apiService = ApiService();

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color background = const Color(0xFFF7FFF9);

  List<CartItemModel> _cartItems = [];
  bool _isLoading = true;
  String? _error;

  final _formKey = GlobalKey<FormState>();

  // Contact controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Address controllers (for new address)
  final _addressCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();

  // State lists
  List<AddressModel> _savedAddresses = [];
  List<PaymentMethodModel> _paymentMethods = [];
  List<CountryModel> _countries = [];
  List<StateModel> _states = [];
  List<DistrictModel> _districts = [];

  // Selections
  AddressModel? _selectedAddress;
  PaymentMethodModel? _selectedPaymentMethod;
  CountryModel? _selectedCountry;
  StateModel? _selectedState;
  DistrictModel? _selectedDistrict;

  // Toggles and Loaders
  bool _isSubmittingOrder = false;
  bool _useNewAddress = false;

  late Razorpay _razorpay;

  String? _pendingRazorpayOrderId;

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _loadCart();
    _loadCheckoutData();
  }

  @override
  void dispose() {
    _razorpay.clear();

    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    _addressCtrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();

    super.dispose();
  }

  Future<void> _loadCheckoutData() async {
    try {
      // 1. Load Phone from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('phone') ?? '';
      _phoneCtrl.text = savedPhone;

      // 2. Fetch Addresses
      final addresses = await _apiService.getAddresses();

      // 3. Fetch Active Payment Methods
      final allMethods = await _apiService.getPaymentMethods();
      final activeMethods = allMethods.where((m) => m.isActive).toList();

      // 4. Fetch Countries list (in case they want to add new address)
      final countriesData = await _apiService.getCountries();
      final countriesList = (countriesData['results'] as List<CountryModel>);

      setState(() {
        _savedAddresses = addresses;
        _paymentMethods = activeMethods;
        _countries = countriesList;

        if (addresses.isNotEmpty) {
          _selectedAddress = addresses.first;
          _useNewAddress = false;
        } else {
          _useNewAddress = true;
        }

        if (activeMethods.isNotEmpty) {
          _selectedPaymentMethod = activeMethods.first;
        }
      });
    } catch (e) {
      print("Error loading checkout data: $e");
    }
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _apiService.getCart();
      setState(() {
        _cartItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(CartItemModel item, int newQuantity) async {
    if (newQuantity <= 0) {
      _deleteItem(item);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.addToCart(
        productId: item.product.id,
        quantity: newQuantity,
      );
      final items = await _apiService.getCart();
      setState(() {
        _cartItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    }
  }

  Future<void> _deleteItem(CartItemModel item) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.deleteCartItem(productId: item.product.id);
      final items = await _apiService.getCart();
      setState(() {
        _cartItems = items;
        _isLoading = false;
      });
      _showSnackBar('Removed "${item.product.name}" from cart', primaryGreen);
    } catch (e) {
      // Fallback: If deleteCartItem endpoint fails, try sending quantity 0
      try {
        await _apiService.addToCart(productId: item.product.id, quantity: 0);
        final items = await _apiService.getCart();
        setState(() {
          _cartItems = items;
          _isLoading = false;
        });
        _showSnackBar('Removed "${item.product.name}" from cart', primaryGreen);
      } catch (e2) {
        setState(() => _isLoading = false);
        _showSnackBar(
          e2.toString().replaceFirst('Exception: ', ''),
          Colors.red,
        );
      }
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await _apiService.verifyRazorpayPayment(
        razorpayOrderId: response.orderId ?? _pendingRazorpayOrderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      setState(() => _isSubmittingOrder = false);
      _showSuccessDialog();
    } catch (e) {
      setState(() => _isSubmittingOrder = false);
      _showSnackBar(
        e.toString().replaceFirst("Exception: ", ""),
        Colors.redAccent,
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isSubmittingOrder = false);
    _showSnackBar(
      response.message ?? "Payment failed or cancelled",
      Colors.redAccent,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnackBar(
      "External wallet selected: ${response.walletName ?? ''}",
      primaryGreen,
    );
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  double get _subtotal {
    double total = 0.0;
    for (var item in _cartItems) {
      total += double.tryParse(item.totalPrice) ?? 0.0;
    }
    return total;
  }

  double get _deliveryFee => _cartItems.isEmpty ? 0.00 : 5.00;
  double get _tax => _subtotal * 0.05; // 5% tax
  double get _grandTotal => _subtotal + _deliveryFee + _tax;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading && _cartItems.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildErrorView()
                  : _cartItems.isEmpty
                  ? _buildEmptyView()
                  : _buildCartContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, darkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
                  'My Cart',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_cartItems.length} item${_cartItems.length == 1 ? '' : 's'} ready for checkout',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadCart,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An unexpected error occurred',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadCart,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 96,
              color: primaryGreen.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Cart is Empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse products and add them to your cart to see them here!',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Start Shopping',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cart Items List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _cartItems
                    .map((item) => _buildCartItemCard(item))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            // Checkout Form directly inline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCheckoutFormInline(),
            ),
            const SizedBox(height: 16),
            // Order Summary & Action Button at the very bottom
            _buildOrderSummarySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(CartItemModel item) {
    return Dismissible(
      key: Key('cart_item_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: item.isOutOfStock
                ? Colors.red.shade200
                : Colors.green.shade50,
            width: item.isOutOfStock ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Thumbnail
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    item.product.image != null && item.product.image!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item.product.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.fastfood_rounded,
                            color: primaryGreen,
                            size: 28,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.fastfood_rounded,
                        color: primaryGreen,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 14),
              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Price: \$${item.product.price} / ${item.product.unit}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.isOutOfStock) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Out of Stock',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '\$${item.totalPrice}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: item.isOutOfStock
                            ? Colors.red.shade600
                            : primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Quantity Adjustment Pill
              Container(
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.add_rounded,
                        color: primaryGreen,
                        size: 18,
                      ),
                      onPressed: () => _updateQuantity(item, item.quantity + 1),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                    Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.remove_rounded,
                        color: primaryGreen,
                        size: 18,
                      ),
                      onPressed: () => _updateQuantity(item, item.quantity - 1),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutFormInline() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: darkGreen, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Checkout Details",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // SECTION 1: CONTACT DETAILS
          _sectionHeaderInline("Contact Details", Icons.person_outline_rounded),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameCtrl,
            decoration: _inputDecorationInline(
              "Full Name",
              Icons.person_rounded,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? "Full Name is required"
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: _inputDecorationInline(
              "Contact Phone",
              Icons.phone_android_rounded,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Phone is required" : null,
          ),
          const SizedBox(height: 20),

          // SECTION 2: SHIPPING ADDRESS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeaderInline(
                "Delivery Address",
                Icons.location_on_outlined,
              ),
              if (_savedAddresses.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _useNewAddress = !_useNewAddress;
                    });
                  },
                  icon: Icon(
                    _useNewAddress
                        ? Icons.list_alt_rounded
                        : Icons.add_location_alt_rounded,
                    size: 16,
                    color: primaryGreen,
                  ),
                  label: Text(
                    _useNewAddress ? "Use Saved" : "Add New",
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (!_useNewAddress && _savedAddresses.isNotEmpty) ...[
            // Dropdown for saved addresses
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AddressModel>(
                  value: _selectedAddress,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: primaryGreen,
                  ),
                  items: _savedAddresses.map((addr) {
                    return DropdownMenuItem<AddressModel>(
                      value: addr,
                      child: Text(
                        "${addr.address}, ${addr.city} (${addr.postalCode})",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAddress = val;
                    });
                  },
                ),
              ),
            ),
          ] else ...[
            // Inline Address Form
            TextFormField(
              controller: _addressCtrl,
              decoration: _inputDecorationInline(
                "Street Address",
                Icons.home_rounded,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? "Address is required"
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _landmarkCtrl,
              decoration: _inputDecorationInline(
                "Landmark (optional)",
                Icons.place_rounded,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityCtrl,
                    decoration: _inputDecorationInline(
                      "City",
                      Icons.location_city_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "City is required"
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _postalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecorationInline(
                      "Postal Code",
                      Icons.local_post_office_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "Pincode is required"
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Country Dropdown
            DropdownButtonFormField<CountryModel>(
              value: _selectedCountry,
              decoration: _inputDecorationInline("Country", Icons.flag_rounded),
              items: _countries.map((c) {
                return DropdownMenuItem(value: c, child: Text(c.name));
              }).toList(),
              onChanged: _onCountryChanged,
              validator: (v) => v == null ? "Select Country" : null,
            ),
            const SizedBox(height: 10),
            // State Dropdown
            DropdownButtonFormField<StateModel>(
              value: _selectedState,
              decoration: _inputDecorationInline("State", Icons.map_rounded),
              items: _states.map((s) {
                return DropdownMenuItem(value: s, child: Text(s.name));
              }).toList(),
              onChanged: _onStateChanged,
              validator: (v) => v == null ? "Select State" : null,
            ),
            const SizedBox(height: 10),
            // District Dropdown
            DropdownButtonFormField<DistrictModel>(
              value: _selectedDistrict,
              decoration: _inputDecorationInline(
                "District",
                Icons.grain_rounded,
              ),
              items: _districts.map((d) {
                return DropdownMenuItem(value: d, child: Text(d.name));
              }).toList(),
              onChanged: (d) => setState(() => _selectedDistrict = d),
              validator: (v) => v == null ? "Select District" : null,
            ),
          ],
          const SizedBox(height: 20),

          // SECTION 3: PAYMENT METHOD
          _sectionHeaderInline("Payment Method", Icons.payment_outlined),
          const SizedBox(height: 10),
          if (_paymentMethods.isEmpty)
            const Text(
              "No payment options available. Contact support.",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: _paymentMethods.map((method) {
                final isSelected = _selectedPaymentMethod?.id == method.id;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = method;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? lightGreen : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? primaryGreen : Colors.grey.shade300,
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.credit_card_rounded,
                          size: 18,
                          color: isSelected
                              ? primaryGreen
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          method.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: isSelected
                                ? darkGreen
                                : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),

          // SECTION 4: ORDER NOTES
          _sectionHeaderInline("Order Note", Icons.notes_rounded),
          const SizedBox(height: 10),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: _inputDecorationInline(
              "Delivery Instructions...",
              Icons.edit_note_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeaderInline(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: darkGreen),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: darkGreen,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecorationInline(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryGreen, size: 20),
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.green.shade100),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.green.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryGreen, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.8),
      ),
    );
  }

  Widget _buildOrderSummarySection() {
    final bool hasOutOfStockItems = _cartItems.any((item) => item.isOutOfStock);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasOutOfStockItems) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Some items are currently out of stock. Please remove them to proceed with checkout.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              Text(
                '\$${_subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Fee',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              Text(
                '\$${_deliveryFee.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taxes (5%)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              Text(
                '\$${_tax.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              Text(
                '\$${_grandTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  color: hasOutOfStockItems
                      ? Colors.grey.shade500
                      : primaryGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: hasOutOfStockItems
                  ? () {
                      _showSnackBar(
                        'Please remove out of stock items before proceeding.',
                        Colors.red,
                      );
                    }
                  : _isSubmittingOrder
                  ? null
                  : _submitOrderInline,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasOutOfStockItems
                    ? Colors.grey.shade300
                    : primaryGreen,
                foregroundColor: hasOutOfStockItems
                    ? Colors.grey.shade600
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: hasOutOfStockItems ? 0 : 2,
              ),
              child: _isSubmittingOrder
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      hasOutOfStockItems
                          ? 'Checkout Blocked'
                          : 'Proceed to Checkout',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrderInline() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar("Please fill in all checkout details", Colors.redAccent);
      return;
    }

    if (_selectedPaymentMethod == null) {
      _showSnackBar("Please select a payment method", Colors.orangeAccent);
      return;
    }

    if (!_useNewAddress && _selectedAddress == null) {
      _showSnackBar("Please select a delivery address", Colors.orangeAccent);
      return;
    }

    if (_useNewAddress &&
        (_selectedCountry == null ||
            _selectedState == null ||
            _selectedDistrict == null)) {
      _showSnackBar(
        "Please complete the location details",
        Colors.orangeAccent,
      );
      return;
    }

    setState(() => _isSubmittingOrder = true);

    try {
      AddressModel finalAddress;

      if (_useNewAddress) {
        finalAddress = await _apiService.addAddress(
          address: _addressCtrl.text.trim(),
          landmark: _landmarkCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          country: _selectedCountry!.id,
          state: _selectedState!.id,
          district: _selectedDistrict!.id,
          postalCode: _postalCtrl.text.trim(),
        );
      } else {
        finalAddress = _selectedAddress!;
      }

      String stateName = finalAddress.stateName;
      if (stateName.isEmpty && _selectedState != null) {
        stateName = _selectedState!.name;
      }

      String countryName = finalAddress.countryName;
      if (countryName.isEmpty && _selectedCountry != null) {
        countryName = _selectedCountry!.name;
      }

      String methodCode = _selectedPaymentMethod!.code.trim().toLowerCase();
      final methodName = _selectedPaymentMethod!.name.trim().toLowerCase();

      final bool isCod =
          methodCode == "cod" ||
          methodCode.contains("cash") ||
          methodName.contains("cash") ||
          methodName.contains("cod") ||
          methodName.contains("delivery");

      final bool isUpi =
          methodCode.contains("upi") ||
          methodCode.contains("online") ||
          methodName.contains("upi") ||
          methodName.contains("online") ||
          methodName.contains("razorpay");

      if (isCod) {
        await _apiService.checkout(
          paymentMethod: "cod",
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: finalAddress.address,
          city: finalAddress.city,
          state: stateName,
          pincode: finalAddress.postalCode,
          country: countryName,
          note: _noteCtrl.text.trim(),
        );

        setState(() => _isSubmittingOrder = false);
        _showSuccessDialog();
        return;
      }

      if (isUpi) {
        final razorpayOrder = await _apiService.createRazorpayOrder(
          amount: _subtotal,
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: finalAddress.address,
          city: finalAddress.city,
          state: stateName,
          pincode: finalAddress.postalCode,
          country: countryName,
          note: _noteCtrl.text.trim(),
        );

        _pendingRazorpayOrderId = razorpayOrder['order_id']?.toString();
           
        final options = {
          'key': ApiConstants.razorpayKeyId,
          'amount': razorpayOrder['amount'],
          'currency': razorpayOrder['currency'] ?? 'INR',
          'name': 'Grocery App',
          'description': 'Grocery Order Payment',
          'order_id': razorpayOrder['order_id'],
          'prefill': {
            'contact': _phoneCtrl.text.trim(),
            'name': _nameCtrl.text.trim(),
          },
          'theme': {'color': '#1B8F3A'},
          'method': {
            'upi': true,
            'card': true,
            'netbanking': true,
            'wallet': true,
          },
        };

        _razorpay.open(options);
        return;
      }

      _showSnackBar("Invalid payment method selected", Colors.redAccent);
      setState(() => _isSubmittingOrder = false);
    } catch (e) {
      setState(() => _isSubmittingOrder = false);
      _showSnackBar(
        e.toString().replaceFirst("Exception: ", ""),
        Colors.redAccent,
      );
    }
  }

  Future<void> _onCountryChanged(CountryModel? country) async {
    setState(() {
      _selectedCountry = country;
      _selectedState = null;
      _selectedDistrict = null;
      _states = [];
      _districts = [];
    });
    if (country == null) return;
    try {
      final statesList = await _apiService.getStatesByCountry(
        countryId: country.id,
      );
      setState(() => _states = statesList);
    } catch (_) {}
  }

  Future<void> _onStateChanged(StateModel? state) async {
    setState(() {
      _selectedState = state;
      _selectedDistrict = null;
      _districts = [];
    });
    if (state == null) return;
    try {
      final districtsList = await _apiService.getDistrictsByState(
        stateId: state.id,
      );
      setState(() => _districts = districtsList);
    } catch (_) {}
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: primaryGreen,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Order Placed!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Your order has been placed successfully. Thank you for shopping with us!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Pop back to Shop Home
                },
                child: const Text(
                  "Continue Shopping",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
