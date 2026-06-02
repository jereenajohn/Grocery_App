import 'package:flutter/material.dart';
import 'package:grocery_app/views/Admin/add_country_page.dart';
import 'package:grocery_app/views/Admin/add_district_page.dart';
import 'package:grocery_app/views/Admin/manage_banners_page.dart';
import 'add_state_page.dart';
import 'manage_payment_methods_page.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);

  Widget menuTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget page,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: lightGreen,
          child: Icon(icon, color: primaryGreen),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 17,
          color: primaryGreen,
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }

  Widget buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
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
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Manage master data',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFF9),
      body: SafeArea(
        child: Column(
          children: [
            buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    menuTile(
                      context: context,
                      title: 'Add Country',
                      subtitle: 'Create a new country',
                      icon: Icons.add_location_alt_rounded,
                      page: const AddCountryPage(),
                    ),

                    menuTile(
                      context: context,
                      title: 'Add State',
                      subtitle: 'Create state under country',
                      icon: Icons.add_business_rounded,
                      page: const AddStatePage(),
                    ),

                    menuTile(
                      context: context,
                      title: 'Add District',
                      subtitle: 'Create district under state',
                      icon: Icons.add_home_work_rounded,
                      page: const AddDistrictPage(),
                    ),

                    menuTile(
                      context: context,
                      title: 'Payment Methods',
                      subtitle: 'Manage payment gateways',
                      icon: Icons.payment_rounded,
                      page: const ManagePaymentMethodsPage(),
                    ),
                    menuTile(
                      context: context,
                      title: 'Add Banner',
                      subtitle: 'Manage home page banners',
                      icon: Icons.image_rounded,
                      page: const ManageBannersPage(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
