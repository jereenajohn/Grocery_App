import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class ChangePhonePage extends StatefulWidget {
  final String currentPhone;
  const ChangePhonePage({super.key, required this.currentPhone});

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 1; // 1: input new phone & request old otp, 2: verify old otp, 3: verify new otp
  bool _isLoading = false;

  final TextEditingController _oldPhoneController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();
  final TextEditingController _oldOtpController = TextEditingController();
  final TextEditingController _newOtpController = TextEditingController();

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color goldAccent = const Color(0xFFFFB300);
  final Color background = const Color(0xFFF7FFF9);

  @override
  void initState() {
    super.initState();
    _oldPhoneController.text = widget.currentPhone;
  }

  @override
  void dispose() {
    _oldPhoneController.dispose();
    _newPhoneController.dispose();
    _oldOtpController.dispose();
    _newOtpController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 8), // Hold the OTP longer so it's readable
      ),
    );
  }

  Future<void> _handleStep1RequestOldOtp() async {
    if (_oldPhoneController.text.trim().isEmpty) {
      _showError("Please enter your old phone number");
      return;
    }
    if (_newPhoneController.text.trim().isEmpty) {
      _showError("Please enter your new phone number");
      return;
    }
    if (_newPhoneController.text.trim() == _oldPhoneController.text.trim()) {
      _showError("New phone number must be different from the old one");
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.requestOldPhoneOtp(
        oldPhone: _oldPhoneController.text.trim(),
        newPhone: _newPhoneController.text.trim(),
      );

      // Extract OTP from response if present
      final otp = response['otp']?.toString() ?? response['code']?.toString() ?? '';
      if (otp.isNotEmpty) {
        _showSuccess("OTP Sent successfully! Code: $otp");
      } else {
        _showSuccess(response['message'] ?? response['detail'] ?? "OTP sent to your old phone number");
      }

      setState(() {
        _currentStep = 2;
      });
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStep2VerifyOldOtp() async {
    if (_oldOtpController.text.trim().isEmpty) {
      _showError("Please enter the verification code");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Verify the old OTP
      await _apiService.verifyOldPhoneOtp(
        oldOtp: _oldOtpController.text.trim(),
      );
      _showSuccess("Current phone verified successfully!");

      // 2. Automatically request OTP to the new phone number right after verification succeeds
      try {
        final response = await _apiService.requestNewPhoneOtp(
          newPhone: _newPhoneController.text.trim(),
        );

        final otp = response['otp']?.toString() ?? response['code']?.toString() ?? '';
        if (otp.isNotEmpty) {
          _showSuccess("OTP Sent to New Number! Code: $otp");
        } else {
          _showSuccess(response['message'] ?? response['detail'] ?? "OTP sent to your new phone number");
        }

        setState(() {
          _currentStep = 3; // Move directly to verify new OTP step
        });
      } catch (e) {
        _showError("Old verified, but new OTP request failed: ${e.toString().replaceAll("Exception: ", "")}");
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStep3VerifyNewOtp() async {
    if (_newOtpController.text.trim().isEmpty) {
      _showError("Please enter the verification code sent to your new phone");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _apiService.verifyNewPhoneOtp(
        newOtp: _newOtpController.text.trim(),
        newPhone: _newPhoneController.text.trim(),
      );
      
      // Beautiful Success Dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: primaryGreen, size: 28),
              const SizedBox(width: 10),
              const Text("Success", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "Your phone number has been updated successfully! Please re-login with your new phone number if prompted.",
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context); // Pop dialog
                Navigator.pop(context, true); // Go back with success flag
              },
              child: const Text("Awesome", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStepNode(1, "Request OTP"),
          _buildStepLine(1),
          _buildStepNode(2, "Verify Old"),
          _buildStepLine(2),
          _buildStepNode(3, "Verify New"),
        ],
      ),
    );
  }

  Widget _buildStepNode(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: isCompleted
                ? primaryGreen
                : isActive
                    ? lightGreen
                    : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive ? primaryGreen : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive ? darkGreen : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? darkGreen
                : isCompleted
                    ? primaryGreen
                    : Colors.grey.shade400,
            fontSize: 10,
            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isCompleted = _currentStep > afterStep;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 2,
        color: isCompleted ? primaryGreen : Colors.grey.shade300,
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          "Change Phone Number",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(),
                const SizedBox(height: 30),
                
                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.green.shade50),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Form Headers
                      if (_currentStep == 1) ...[
                        const Text(
                          "Step 1: Enter New Phone Number",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Provide your new number. We'll send the verification code to your current registered number first.",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _oldPhoneController,
                          label: "Current Phone Number",
                          hint: "e.g. +1234567890",
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                          readOnly: true, // Prefilled from current user profile
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _newPhoneController,
                          label: "New Phone Number",
                          hint: "Enter your new phone number",
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),
                        _buildButton(
                          label: "Send OTP to Current Number",
                          onPressed: _handleStep1RequestOldOtp,
                        ),
                      ] else if (_currentStep == 2) ...[
                        const Text(
                          "Step 2: Verify Current Phone",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enter the verification code sent to your old number: ${_oldPhoneController.text}.",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _oldOtpController,
                          label: "Verification Code",
                          hint: "Enter OTP code",
                          icon: Icons.lock_open_rounded,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 24),
                        _buildButton(
                          label: "Verify Code",
                          onPressed: _handleStep2VerifyOldOtp,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _currentStep = 1;
                              _oldOtpController.clear();
                            });
                          },
                          child: Text(
                            "Back & Resend OTP",
                            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ] else if (_currentStep == 3) ...[
                        const Text(
                          "Step 3: Verify New Phone",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Now, enter the verification code sent to your new phone number: ${_newPhoneController.text}.",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _newOtpController,
                          label: "Verification Code",
                          hint: "Enter OTP code",
                          icon: Icons.lock_open_rounded,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 24),
                        _buildButton(
                          label: "Verify & Update Number",
                          onPressed: _handleStep3VerifyNewOtp,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _currentStep = 2;
                              _newOtpController.clear();
                            });
                          },
                          child: Text(
                            "Back",
                            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: "",
        prefixIcon: Icon(icon, color: primaryGreen),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade50 : Colors.green.shade50.withOpacity(0.15),
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
          borderSide: BorderSide(color: primaryGreen, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "This field is required";
        }
        return null;
      },
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryGreen.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
