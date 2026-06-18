import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/platform_fee_model.dart';
import '../../services/api_service.dart';
import '../widgets/shimmer_loading.dart';

class ManagePlatformFeesPage extends StatefulWidget {
  const ManagePlatformFeesPage({super.key});

  @override
  State<ManagePlatformFeesPage> createState() => _ManagePlatformFeesPageState();
}

class _ManagePlatformFeesPageState extends State<ManagePlatformFeesPage> {
  final ApiService _apiService = ApiService();

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color background = const Color(0xFFF7FFF9);

  List<PlatformFeeModel> _platformFees = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlatformFees();
  }

  Future<void> _loadPlatformFees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _apiService.getPlatformFees();
      setState(() {
        _platformFees = list;
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

  Future<void> _deletePlatformFee(PlatformFeeModel fee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Platform Fee', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete "${fee.name}"?'),
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
        await _apiService.deletePlatformFee(id: fee.id);
        _showSnackBar('Successfully deleted "${fee.name}"', primaryGreen);
        _loadPlatformFees();
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar(e.toString().replaceAll("Exception: ", ""), Colors.redAccent);
      }
    }
  }

  void _showAddOrEditDialog({PlatformFeeModel? fee}) {
    final isEdit = fee != null;
    final nameController = TextEditingController(text: fee?.name ?? '');
    final amountController = TextEditingController(text: fee?.amount ?? '');
    bool isActive = fee?.isActive ?? true;

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
                      isEdit ? "Edit Platform Fee" : "Add Platform Fee",
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
                    labelText: "Fee Name",
                    hintText: "e.g. Standard Platform Fee",
                    prefixIcon: Icon(Icons.label_outline_rounded, color: primaryGreen),
                    filled: true,
                    fillColor: Colors.green.shade50.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: "Amount (₹)",
                    hintText: "e.g. 15.00",
                    prefixIcon: Icon(Icons.currency_rupee_rounded, color: primaryGreen),
                    filled: true,
                    fillColor: Colors.green.shade50.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: primaryGreen,
                  title: const Text(
                    "Is Active?",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Activate this fee rate for orders"),
                  value: isActive,
                  onChanged: (val) {
                    setModalState(() {
                      isActive = val;
                    });
                  },
                ),
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
                    final amount = amountController.text.trim();

                    if (name.isEmpty || amount.isEmpty) {
                      _showSnackBar("Please fill out all fields", Colors.redAccent);
                      return;
                    }

                    Navigator.pop(context); // Close sheet
                    setState(() => _isLoading = true);

                    try {
                      if (isEdit) {
                        await _apiService.updatePlatformFee(
                          id: fee.id,
                          name: name,
                          amount: amount,
                          isActive: isActive,
                        );
                        _showSnackBar('Platform Fee "$name" updated successfully!', primaryGreen);
                      } else {
                        await _apiService.createPlatformFee(
                          name: name,
                          amount: amount,
                          isActive: isActive,
                        );
                        _showSnackBar('Platform Fee "$name" created successfully!', primaryGreen);
                      }
                      _loadPlatformFees();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      String msg = e.toString().replaceAll("Exception: ", "");
                      if (msg.contains("already exists")) {
                        msg = "Platform fee configuration already exists. Only one record is allowed.";
                      }
                      _showSnackBar(msg, Colors.redAccent);
                    }
                  },
                  child: Text(
                    isEdit ? "Save Changes" : "Create Platform Fee",
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
                  'Platform Fees',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage administrative fee rates',
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
            onPressed: _loadPlatformFees,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(PlatformFeeModel fee) {
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
            CircleAvatar(
              radius: 24,
              backgroundColor: fee.isActive ? lightGreen : Colors.grey.shade100,
              child: Icon(
                Icons.monetization_on_rounded,
                color: fee.isActive ? primaryGreen : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fee.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${fee.amount}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: fee.isActive ? lightGreen : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          fee.isActive ? "ACTIVE" : "INACTIVE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: fee.isActive ? darkGreen : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddOrEditDialog(fee: fee);
                } else if (value == 'delete') {
                  _deletePlatformFee(fee);
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
            Icon(Icons.monetization_on_outlined, size: 76, color: primaryGreen.withOpacity(0.3)),
            const SizedBox(height: 18),
            const Text(
              "No Platform Fees Configured",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Click the button below to add your first platform fee configuration.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showAddOrEditDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text("Add Platform Fee", style: TextStyle(fontWeight: FontWeight.bold)),
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
              child: _isLoading && _platformFees.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: ProductsListShimmer(itemCount: 3),
                    )
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                      : _platformFees.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _platformFees.length,
                              itemBuilder: (context, index) => _buildCard(_platformFees[index]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
