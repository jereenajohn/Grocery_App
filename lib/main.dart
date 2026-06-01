import 'package:flutter/material.dart';
import 'package:grocery_app/services/api_service.dart';
import 'package:grocery_app/views/request_otp_page.dart';
import 'package:grocery_app/views/Admin/register_page.dart';
import 'package:grocery_app/views/Admin/admin_home_page.dart';
import 'package:grocery_app/views/User/user_home_page.dart';
import 'package:grocery_app/views/Shop/shop_home_page.dart';

void main() {
  runApp(const GroceryApp());
}

class GroceryApp extends StatelessWidget {
  const GroceryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grocery App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      final data = await _apiService.getSavedUserData();
      final String access = data['access'] ?? '';
      final bool firstTime = data['first_time'] ?? true;
      final bool isRegistered = data['is_registered'] ?? false;
      final String userType = data['user_type'] ?? '';
      final String phone = data['phone'] ?? '';

      if (!mounted) return;

      if (access.isEmpty) {
        // Not authenticated, send to Request OTP
        _navigateTo(const RequestOtpPage());
      } else {
        // Authenticated, check user type and registration status
        if (isRegistered || !firstTime) {
          switch (userType) {
            case 'admin':
              _navigateTo(const AdminHomePage());
              break;
            case 'shop':
              _navigateTo(const ShopHomePage());
              break;
            case 'user':
              _navigateTo(const UserHomePage());
              break;
            default:
              _navigateTo(RegisterPage(verifiedPhone: phone.isNotEmpty ? phone : null));
              break;
          }
        } else {
          _navigateTo(RegisterPage(verifiedPhone: phone.isNotEmpty ? phone : null));
        }
      }
    } catch (e) {
      if (!mounted) return;
      _navigateTo(const RequestOtpPage());
    }
  }

  void _navigateTo(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF1B8F3A);
    const Color background = Color(0xFFF7FFF9);

    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_grocery_store_rounded,
                color: primaryGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}