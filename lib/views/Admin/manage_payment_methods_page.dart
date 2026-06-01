import 'package:flutter/material.dart';
import '../../models/payment_method_model.dart';
import '../../services/api_service.dart';

class ManagePaymentMethodsPage extends StatefulWidget {
  const ManagePaymentMethodsPage({super.key});

  @override
  State<ManagePaymentMethodsPage> createState() => _ManagePaymentMethodsPageState();
}

class _ManagePaymentMethodsPageState extends State<ManagePaymentMethodsPage> {
  final ApiService _apiService = ApiService();

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color background = const Color(0xFFF7FFF9);

  List<PaymentMethodModel> _paymentMethods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _apiService.getPaymentMethods();
      setState(() {
        _paymentMethods = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll("Exception: ", "");
        _isLoading = false;
      });
    }
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

  Future<void> _toggleStatus(PaymentMethodModel method, bool newValue) async {
    try {
      await _apiService.updatePaymentMethod(
        id: method.id,
        name: method.name,
        code: method.code,
        isActive: newValue,
      );
      _showSnackBar(
        'Updated "${method.name}" status to ${newValue ? "Active" : "Inactive"}',
        primaryGreen,
      );
      _loadPaymentMethods();
    } catch (e) {
      _showSnackBar(e.toString().replaceAll("Exception: ", ""), Colors.redAccent);
    }
  }

  Future<void> _deletePaymentMethod(PaymentMethodModel method) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete "${method.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _apiService.deletePaymentMethod(id: method.id);
        _showSnackBar('Successfully deleted "${method.name}"', primaryGreen);
        _loadPaymentMethods();
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar(e.toString().replaceAll("Exception: ", ""), Colors.redAccent);
      }
    }
  }

  void _showAddOrEditDialog({PaymentMethodModel? method}) {
    final isEdit = method != null;
    final nameController = TextEditingController(text: method?.name ?? '');
    final codeController = TextEditingController(text: method?.code ?? '');
    bool isActive = method?.isActive ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? "Edit Payment Method" : "Add Payment Method",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Payment Name",
                    hintText: "e.g. Cash on Delivery",
                    prefixIcon: Icon(Icons.payment_rounded, color: primaryGreen),
                    filled: true,
                    fillColor: Colors.green.shade50.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: "Unique Code",
                    hintText: "e.g. cod",
                    prefixIcon: Icon(Icons.code_rounded, color: primaryGreen),
                    filled: true,
                    fillColor: Colors.green.shade50.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                if (isEdit) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: primaryGreen,
                    title: const Text(
                      "Is Active?",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("Allow users to choose this method during checkout"),
                    value: isActive,
                    onChanged: (val) {
                      setModalState(() {
                        isActive = val;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final code = codeController.text.trim();

                    if (name.isEmpty || code.isEmpty) {
                      _showSnackBar("Please fill out all fields", Colors.redAccent);
                      return;
                    }

                    Navigator.pop(context); // Close sheet
                    setState(() => _isLoading = true);

                    try {
                      if (isEdit) {
                        await _apiService.updatePaymentMethod(
                          id: method.id,
                          name: name,
                          code: code,
                          isActive: isActive,
                        );
                        _showSnackBar('Updated "$name" successfully!', primaryGreen);
                      } else {
                        await _apiService.createPaymentMethod(
                          name: name,
                          code: code,
                        );
                        _showSnackBar('Created "$name" successfully!', primaryGreen);
                      }
                      _loadPaymentMethods();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      _showSnackBar(e.toString().replaceAll("Exception: ", ""), Colors.redAccent);
                    }
                  },
                  child: Text(
                    isEdit ? "Save Changes" : "Create Payment Method",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Methods',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Admin Checkout Gateway Configurations',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadPaymentMethods,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(PaymentMethodModel method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Leading Icon
            CircleAvatar(
              radius: 24,
              backgroundColor: method.isActive ? lightGreen : Colors.grey.shade100,
              child: Icon(
                Icons.credit_card_rounded,
                color: method.isActive ? primaryGreen : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 14),
            // Middle info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Code: ${method.code}",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: method.isActive ? lightGreen : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          method.isActive ? "ACTIVE" : "INACTIVE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: method.isActive ? darkGreen : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Switch(
              activeColor: primaryGreen,
              value: method.isActive,
              onChanged: (val) => _toggleStatus(method, val),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddOrEditDialog(method: method);
                } else if (value == 'delete') {
                  _deletePaymentMethod(method);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.blue.shade600, size: 18),
                      const SizedBox(width: 8),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_rounded, size: 76, color: primaryGreen.withOpacity(0.3)),
            const SizedBox(height: 18),
            const Text(
              "No Payment Methods",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Click the button below to add payment gateways like Cash on Delivery, Stripe, etc.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
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
            Expanded(
              child: _isLoading && _paymentMethods.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                      : _paymentMethods.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _paymentMethods.length,
                              itemBuilder: (context, index) => _buildCard(_paymentMethods[index]),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryGreen,
        onPressed: () => _showAddOrEditDialog(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Add Method", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
