import 'package:flutter/material.dart';

import '../../models/state_model.dart';
import '../../services/auth_service.dart';

class ViewStatePage extends StatefulWidget {
  const ViewStatePage({super.key});

  @override
  State<ViewStatePage> createState() => _ViewStatePageState();
}

class _ViewStatePageState extends State<ViewStatePage> {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  List<StateModel> states = [];

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);

  @override
  void initState() {
    super.initState();
    getStates();
  }

  Future<void> getStates() async {
    setState(() => isLoading = true);

    try {
      final result = await _authService.getStates();

      if (!mounted) return;

      setState(() {
        states = result;
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

  Widget stateCard(StateModel state) {
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
            child: Icon(Icons.location_city_rounded, color: primaryGreen),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Country: ${state.countryName}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '#${state.id}',
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
          'View States',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: getStates,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: getStates,
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primaryGreen))
            : states.isEmpty
                ? const Center(child: Text('No states found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: states.length,
                    itemBuilder: (context, index) {
                      return stateCard(states[index]);
                    },
                  ),
      ),
    );
  }
}