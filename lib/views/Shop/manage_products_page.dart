import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';

class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({super.key});

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color background = const Color(0xFFF7FFF9);

  final ApiService _apiService = ApiService();

  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  static const List<String> _unitOptions = ['kg', 'g', 'pcs'];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getProducts(),
        _apiService.getCategories(),
      ]);
      setState(() {
        _products = results[0] as List<ProductModel>;
        final catResponse = results[1] as Map<String, dynamic>;
        _categories = catResponse['results'] as List<CategoryModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<File?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      return File(picked.path);
    }
    return null;
  }

  void _showImageSourcePicker({
    required void Function(File) onPicked,
    required StateSetter setDialogState,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select Image Source',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final file = await _pickImage(ImageSource.camera);
                      if (file != null) onPicked(file);
                    },
                  ),
                  _imageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final file = await _pickImage(ImageSource.gallery);
                      if (file != null) onPicked(file);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: primaryGreen, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerWidget({
    File? selectedImage,
    String? existingImageUrl,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasImage =
        selectedImage != null ||
        (existingImageUrl != null && existingImageUrl.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Product Image'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasImage
                    ? primaryGreen.withOpacity(0.3)
                    : Colors.grey.shade200,
                width: hasImage ? 1.5 : 1,
              ),
            ),
            child: hasImage
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: selectedImage != null
                            ? Image.file(
                                selectedImage,
                                width: double.infinity,
                                height: 140,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                existingImageUrl!,
                                width: double.infinity,
                                height: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.grey.shade400,
                                    size: 40,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onClear,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Change',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 36,
                        color: primaryGreen.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add product image',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final thresholdController = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();

    int? selectedCategoryId;
    String selectedUnit = _unitOptions[0];
    bool isSaving = false;
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: lightGreen,
                        child: Icon(
                          Icons.add_box_rounded,
                          color: primaryGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Product',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Fill in the product details below',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Image Picker
                  _buildImagePickerWidget(
                    selectedImage: selectedImage,
                    onTap: () => _showImageSourcePicker(
                      setDialogState: setDialogState,
                      onPicked: (file) {
                        setDialogState(() => selectedImage = file);
                      },
                    ),
                    onClear: () {
                      setDialogState(() => selectedImage = null);
                    },
                  ),

                  // Category Dropdown
                  _buildLabel('Category *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    decoration: _inputDecoration(
                      'Select category',
                      Icons.category_rounded,
                    ),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedCategoryId = val),
                    validator: (value) =>
                        value == null ? 'Please select a category' : null,
                  ),
                  const SizedBox(height: 16),

                  // Product Name
                  _buildLabel('Product Name *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: _inputDecoration(
                      'e.g. Premium Basmati Rice',
                      Icons.shopping_bag_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter product name'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  _buildLabel('Description'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: descController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      'Product description...',
                      Icons.description_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price & Unit (side by side)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Price *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                '0.00',
                                Icons.attach_money_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Required';
                                if (double.tryParse(v) == null)
                                  return 'Invalid';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Unit *'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedUnit,
                              decoration: _inputDecoration(
                                'Unit',
                                Icons.scale_rounded,
                              ),
                              items: _unitOptions
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setDialogState(() => selectedUnit = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stock
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Stock Qty *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: stockController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                'e.g. 50',
                                Icons.inventory_2_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Required';
                                if (double.tryParse(v) == null)
                                  return 'Invalid';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isSaving = true);

                                  try {
                                    await _apiService.addProduct(
                                      categoryId: selectedCategoryId!,
                                      name: nameController.text.trim(),
                                      description: descController.text.trim(),
                                      price: priceController.text.trim(),
                                      stock: double.parse(
                                        stockController.text.trim(),
                                      ),
                                      unit: selectedUnit,
                                      lowStockThreshold: double.parse(
                                        thresholdController.text.trim(),
                                      ),
                                      image: selectedImage,
                                    );

                                    if (mounted) Navigator.pop(context);
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Product added successfully!',
                                          ),
                                          backgroundColor: primaryGreen,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                    _fetchProducts();
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            e
                                                .toString()
                                                .replaceAll('Exception:', '')
                                                .trim(),
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Add Product',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProductDialog(ProductModel product) {
    final nameController = TextEditingController(text: product.name);
    final descController = TextEditingController(text: product.description);
    final priceController = TextEditingController(text: product.price);
    final stockController = TextEditingController(
      text: product.stock.toString(),
    );
    final thresholdController = TextEditingController(
      text: product.lowStockThreshold.toString(),
    );
    final formKey = GlobalKey<FormState>();

    int? selectedCategoryId = product.category;
    String selectedUnit = _unitOptions.contains(product.unit)
        ? product.unit
        : _unitOptions[0];
    bool isSaving = false;
    File? selectedImage;
    String? existingImageUrl = product.image;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: lightGreen,
                        child: Icon(
                          Icons.edit_rounded,
                          color: primaryGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Product',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Update the product details',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Image Picker
                  _buildImagePickerWidget(
                    selectedImage: selectedImage,
                    existingImageUrl: existingImageUrl,
                    onTap: () => _showImageSourcePicker(
                      setDialogState: setDialogState,
                      onPicked: (file) {
                        setDialogState(() {
                          selectedImage = file;
                          existingImageUrl = null;
                        });
                      },
                    ),
                    onClear: () {
                      setDialogState(() {
                        selectedImage = null;
                        existingImageUrl = null;
                      });
                    },
                  ),

                  // Category Dropdown
                  _buildLabel('Category *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    decoration: _inputDecoration(
                      'Select category',
                      Icons.category_rounded,
                    ),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedCategoryId = val),
                    validator: (value) =>
                        value == null ? 'Please select a category' : null,
                  ),
                  const SizedBox(height: 16),

                  // Product Name
                  _buildLabel('Product Name *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameController,
                    decoration: _inputDecoration(
                      'e.g. Premium Basmati Rice',
                      Icons.shopping_bag_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter product name'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  _buildLabel('Description'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: descController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      'Product description...',
                      Icons.description_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price & Unit
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Price *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                '0.00',
                                Icons.attach_money_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Required';
                                if (double.tryParse(v) == null)
                                  return 'Invalid';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Unit *'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedUnit,
                              decoration: _inputDecoration(
                                'Unit',
                                Icons.scale_rounded,
                              ),
                              items: _unitOptions
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setDialogState(() => selectedUnit = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stock
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Stock Qty *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: stockController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                'e.g. 50',
                                Icons.inventory_2_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Required';
                                if (double.tryParse(v) == null)
                                  return 'Invalid';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isSaving = true);

                                  try {
                                    await _apiService.updateProduct(
                                      productId: product.id,
                                      categoryId: selectedCategoryId!,
                                      name: nameController.text.trim(),
                                      description: descController.text.trim(),
                                      price: priceController.text.trim(),
                                      stock: double.parse(
                                        stockController.text.trim(),
                                      ),
                                      unit: selectedUnit,
                                      lowStockThreshold: double.parse(
                                        thresholdController.text.trim(),
                                      ),
                                      image: selectedImage,
                                    );

                                    if (mounted) Navigator.pop(context);
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Product updated successfully!',
                                          ),
                                          backgroundColor: primaryGreen,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                    _fetchProducts();
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            e
                                                .toString()
                                                .replaceAll('Exception:', '')
                                                .trim(),
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Update Product',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            const SizedBox(width: 10),
            const Text(
              'Delete Product',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _apiService.deleteProduct(productId: product.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${product.name}" deleted successfully!'),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                _fetchProducts();
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceAll('Exception:', '').trim(),
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icon, color: primaryGreen, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primaryGreen, width: 1.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: Colors.black87,
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
                  'My Products',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_products.length} product${_products.length == 1 ? '' : 's'} listed',
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
            onPressed: _fetchProducts,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: CircularProgressIndicator(color: Color(0xFF1B8F3A)),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 72,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No products yet.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the + button to add your first product.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final p = _products[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: p.isOutOfStock
                  ? Colors.red.shade100
                  : (p.lowStockWarning ? Colors.orange.shade100 : Colors.green.shade50),
              width: p.isOutOfStock ? 1.5 : 1,
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
                // Thumbnail / Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: p.image != null && p.image!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            p.image!,
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
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          // Stock status badge
                          if (p.isOutOfStock)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 12,
                                    color: Colors.red.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Out of Stock',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (p.lowStockWarning)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 12,
                                    color: Colors.orange.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Low Stock',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: lightGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.categoryName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (p.description.isNotEmpty)
                        Text(
                          p.description,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _infoChip(
                            Icons.attach_money_rounded,
                            '\$${p.price}',
                            primaryGreen,
                            const Color(0xFFE8F5E9),
                          ),
                          const SizedBox(width: 8),
                          _infoChip(
                            Icons.inventory_2_rounded,
                            p.isOutOfStock ? 'Out of Stock' : p.stockDisplay,
                            p.isOutOfStock ? Colors.red.shade600 : const Color(0xFF0097A7),
                            p.isOutOfStock ? Colors.red.shade50 : const Color(0xFFE0F7FA),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: lightGreen,
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Icons.edit_rounded,
                        color: primaryGreen,
                        size: 20,
                      ),
                      onPressed: () => _showEditProductDialog(p),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      onPressed: () => _showDeleteConfirmationDialog(p),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 14),
                      child: Text(
                        'Product Inventory',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    _buildProductList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _categories.isEmpty ? null : _showAddProductDialog,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Product',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
      ),
    );
  }
}
