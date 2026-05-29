import 'package:flutter/material.dart';

import '../../models/country_model.dart';
import '../../services/auth_service.dart';

class AddStatePage extends StatefulWidget {
  const AddStatePage({super.key});

  @override
  State<AddStatePage> createState() => _AddStatePageState();
}

class _AddStatePageState extends State<AddStatePage> {
  final AuthService _authService = AuthService();

  final TextEditingController stateNameController = TextEditingController();

  bool isLoadingCountries = false;
  bool isAddingState = false;

  List<CountryModel> countries = [];
  int? selectedCountryId;

  final Color primaryGreen = const Color(0xFF1B8F3A);

  @override
  void initState() {
    super.initState();
    getCountries();
  }

  @override
  void dispose() {
    stateNameController.dispose();
    super.dispose();
  }

  Future<void> getCountries() async {
    setState(() => isLoadingCountries = true);

    try {
      final result = await _authService.getCountries();

      if (!mounted) return;

      setState(() {
        countries = result;
        isLoadingCountries = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingCountries = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> addState() async {
    if (selectedCountryId == null) {
      showMessage('Select country', Colors.red);
      return;
    }

    if (stateNameController.text.trim().isEmpty) {
      showMessage('Enter state name', Colors.red);
      return;
    }

    setState(() => isAddingState = true);

    try {
      await _authService.addState(
        name: stateNameController.text.trim(),
        country: selectedCountryId!,
      );

      if (!mounted) return;

      stateNameController.clear();

      setState(() => isAddingState = false);

      showMessage('State added successfully', primaryGreen);
    } catch (e) {
      if (!mounted) return;
      setState(() => isAddingState = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFF9),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Add State',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
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
              isLoadingCountries
                  ? CircularProgressIndicator(color: primaryGreen)
                  : DropdownButtonFormField<int>(
                      value: selectedCountryId,
                      decoration: inputDecoration(
                        label: 'Select Country',
                        icon: Icons.public_rounded,
                      ),
                      items: countries.map((country) {
                        return DropdownMenuItem<int>(
                          value: country.id,
                          child: Text(country.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCountryId = value;
                        });
                      },
                    ),
              const SizedBox(height: 14),
              TextField(
                controller: stateNameController,
                decoration: inputDecoration(
                  label: 'State Name',
                  icon: Icons.location_city_rounded,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isAddingState ? null : addState,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isAddingState
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save State',
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