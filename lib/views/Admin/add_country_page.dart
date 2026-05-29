import 'package:flutter/material.dart';
import 'package:grocery_app/services/auth_service.dart';


class AddCountryPage extends StatefulWidget {
  const AddCountryPage({super.key});

  @override
  State<AddCountryPage> createState() => _AddCountryPageState();
}

class _AddCountryPageState extends State<AddCountryPage> {
  final AuthService _authService = AuthService();

  final TextEditingController countryNameController = TextEditingController();
  final TextEditingController countryCodeController = TextEditingController();

  bool isAdding = false;

  final Color primaryGreen = const Color(0xFF1B8F3A);

  @override
  void dispose() {
    countryNameController.dispose();
    countryCodeController.dispose();
    super.dispose();
  }

  Future<void> addCountry() async {
    if (countryNameController.text.trim().isEmpty) {
      showMessage('Enter country name', Colors.red);
      return;
    }

    if (countryCodeController.text.trim().isEmpty) {
      showMessage('Enter country code', Colors.red);
      return;
    }

    setState(() => isAdding = true);

    try {
      await _authService.addCountry(
        name: countryNameController.text.trim(),
        code: countryCodeController.text.trim(),
      );

      if (!mounted) return;

      countryNameController.clear();
      countryCodeController.clear();

      setState(() => isAdding = false);

      showMessage('Country added successfully', primaryGreen);
    } catch (e) {
      if (!mounted) return;
      setState(() => isAdding = false);
      showMessage(e.toString().replaceAll('Exception:', '').trim(), Colors.red);
    }
  }

  void showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryGreen),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryGreen, width: 1.5),
      ),
    );
  }

  Widget buildHeader() {
    return AppBar(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      title: const Text(
        'Add Country',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFF9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: buildHeader(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.07),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: countryNameController,
                decoration: inputDecoration(
                  label: 'Country Name',
                  icon: Icons.public_rounded,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: countryCodeController,
                decoration: inputDecoration(
                  label: 'Country Code',
                  icon: Icons.call_rounded,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isAdding ? null : addCountry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isAdding
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Country',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}