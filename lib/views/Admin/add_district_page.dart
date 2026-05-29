import 'package:flutter/material.dart';

import '../../models/state_model.dart';
import '../../services/auth_service.dart';

class AddDistrictPage extends StatefulWidget {
  const AddDistrictPage({super.key});

  @override
  State<AddDistrictPage> createState() => _AddDistrictPageState();
}

class _AddDistrictPageState extends State<AddDistrictPage> {
  final AuthService _authService = AuthService();

  final TextEditingController districtNameController = TextEditingController();

  bool isLoadingStates = false;
  bool isAddingDistrict = false;

  List<StateModel> states = [];
  int? selectedStateId;

  final Color primaryGreen = const Color(0xFF1B8F3A);

  @override
  void initState() {
    super.initState();
    getStates();
  }

  @override
  void dispose() {
    districtNameController.dispose();
    super.dispose();
  }

  Future<void> getStates() async {
    setState(() => isLoadingStates = true);

    try {
      final result = await _authService.getStates();

      if (!mounted) return;

      setState(() {
        states = result;
        isLoadingStates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingStates = false);
      showMessage(e.toString().replaceAll('Exception:', '').trim(), Colors.red);
    }
  }

  Future<void> addDistrict() async {
    if (selectedStateId == null) {
      showMessage('Select state', Colors.red);
      return;
    }

    if (districtNameController.text.trim().isEmpty) {
      showMessage('Enter district name', Colors.red);
      return;
    }

    setState(() => isAddingDistrict = true);

    try {
      await _authService.addDistrict(
        name: districtNameController.text.trim(),
        state: selectedStateId!,
      );

      if (!mounted) return;

      districtNameController.clear();

      setState(() => isAddingDistrict = false);

      showMessage('District added successfully', primaryGreen);
    } catch (e) {
      if (!mounted) return;
      setState(() => isAddingDistrict = false);
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
          'Add District',
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
              isLoadingStates
                  ? CircularProgressIndicator(color: primaryGreen)
                  : DropdownButtonFormField<int>(
                      value: selectedStateId,
                      decoration: inputDecoration(
                        label: 'Select State',
                        icon: Icons.map_rounded,
                      ),
                      items: states.map((state) {
                        return DropdownMenuItem<int>(
                          value: state.id,
                          child: Text('${state.name} - ${state.countryName}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedStateId = value;
                        });
                      },
                    ),
              const SizedBox(height: 14),
              TextField(
                controller: districtNameController,
                decoration: inputDecoration(
                  label: 'District Name',
                  icon: Icons.location_on_rounded,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isAddingDistrict ? null : addDistrict,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isAddingDistrict
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save District',
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