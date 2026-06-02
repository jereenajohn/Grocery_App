import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'Admin/admin_home_page.dart';
import 'Admin/register_page.dart';
import 'User/user_home_page.dart';
import 'Shop/shop_home_page.dart';
import 'Shop/shop_status_pages.dart';


class VerifyOtpPage extends StatefulWidget {
  final String phone;

  const VerifyOtpPage({
    super.key,
    required this.phone,
  });

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController otpController = TextEditingController();

  final ApiService _apiService = ApiService();
  bool isLoading = false;

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color darkGreen = const Color(0xFF0F5F28);

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await _apiService.verifyOtp(
        phone: widget.phone,
        otp: otpController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('OTP verified successfully'),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final bool firstTime = response['first_time'] ?? true;
      final user = response['user'];
      final String userType =
          user is Map<String, dynamic> ? user['user_type']?.toString() ?? '' : '';

      if (firstTime == false) {
        if (userType == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminHomePage(),
            ),
          );
        } else if (userType == 'shop') {
          final String approvalStatus =
              user is Map<String, dynamic> ? user['approval_status']?.toString().toLowerCase() ?? '' : '';

          if (approvalStatus == 'approved') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const ShopHomePage(),
              ),
            );
          } else if (approvalStatus == 'rejected') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const ShopRejectedPage(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const ShopPendingPage(),
              ),
            );
          }
        } else if (userType == 'user') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const UserHomePage(),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegisterPage(
                verifiedPhone: widget.phone,
              ),
            ),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterPage(
              verifiedPhone: widget.phone,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> resendOtp() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await _apiService.requestOtp(
        phone: widget.phone,
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['otp'] != null
                ? "OTP resent. Test OTP: ${response['otp']}"
                : response['detail']?.toString() ?? "OTP resent successfully",
          ),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
        borderSide: BorderSide(color: primaryGreen, width: 1.6),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 35, 22, 32),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: primaryGreen,
              size: 31,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Verify OTP',
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Enter the OTP sent to ${widget.phone}',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVerifyCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 35, 18, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.green.shade50),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: inputDecoration(
                label: 'Enter OTP',
                icon: Icons.lock_outline_rounded,
              ).copyWith(counterText: ''),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter OTP';
                }
                if (value.trim().length != 6) {
                  return 'Enter valid 6 digit OTP';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  disabledBackgroundColor: Colors.green.shade200,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: isLoading ? null : resendOtp,
              child: Text(
                'Resend OTP',
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: lightGreen,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: darkGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Already registered admin will directly go to admin home page.',
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
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
      backgroundColor: const Color(0xFFF7FFF9),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildHeader(),
              buildVerifyCard(),
              buildBottomInfo(),
            ],
          ),
        ),
      ),
    );
  }
}