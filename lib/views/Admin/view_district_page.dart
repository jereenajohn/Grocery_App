import 'package:flutter/material.dart';

import '../../models/district_model.dart';
import '../../services/auth_service.dart';

class ViewDistrictPage extends StatefulWidget {
  const ViewDistrictPage({super.key});

  @override
  State<ViewDistrictPage> createState() => _ViewDistrictPageState();
}

class _ViewDistrictPageState extends State<ViewDistrictPage> {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  List<DistrictModel> districts = [];

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);

  @override
  void initState() {
    super.initState();
    getDistricts();
  }

  Future<void> getDistricts() async {
    setState(() => isLoading = true);

    try {
      final result = await _authService.getDistricts();

      if (!mounted) return;

      setState(() {
        districts = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget districtCard(DistrictModel district) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: lightGreen,
            child: Icon(Icons.location_on_rounded, color: primaryGreen),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  district.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${district.stateName}, ${district.countryName}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '#${district.id}',
            style: TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.w900,
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
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'View Districts',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: getDistricts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: getDistricts,
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primaryGreen))
            : districts.isEmpty
                ? const Center(child: Text('No districts found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: districts.length,
                    itemBuilder: (context, index) {
                      return districtCard(districts[index]);
                    },
                  ),
      ),
    );
  }
}