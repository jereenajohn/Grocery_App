import 'package:flutter/material.dart';

import '../../models/country_model.dart';
import '../../services/auth_service.dart';

class ViewCountryPage extends StatefulWidget {
  const ViewCountryPage({super.key});

  @override
  State<ViewCountryPage> createState() => _ViewCountryPageState();
}

class _ViewCountryPageState extends State<ViewCountryPage> {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  List<CountryModel> countries = [];

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);

  @override
  void initState() {
    super.initState();
    getCountries();
  }

  Future<void> getCountries() async {
    setState(() => isLoading = true);

    try {
      final result = await _authService.getCountries();

      if (!mounted) return;

      setState(() {
        countries = result;
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

  Widget countryCard(CountryModel country) {
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
            child: Icon(Icons.flag_rounded, color: primaryGreen),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  country.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Code: ${country.code}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '#${country.id}',
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
          'View Countries',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: getCountries,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: getCountries,
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primaryGreen))
            : countries.isEmpty
                ? const Center(child: Text('No countries found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: countries.length,
                    itemBuilder: (context, index) {
                      return countryCard(countries[index]);
                    },
                  ),
      ),
    );
  }
}