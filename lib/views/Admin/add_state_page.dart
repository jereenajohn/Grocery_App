import 'package:flutter/material.dart';

import '../../models/country_model.dart';
import '../../models/state_model.dart';
import '../../services/api_service.dart';

class AddStatePage extends StatefulWidget {
  const AddStatePage({super.key});

  @override
  State<AddStatePage> createState() => _AddStatePageState();
}

class _AddStatePageState extends State<AddStatePage> {
  final ApiService _apiService = ApiService();

  final TextEditingController stateNameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  bool isLoadingCountries = false;
  bool isAddingState = false;
  bool isLoadingStates = false;

  List<CountryModel> countries = [];
  List<StateModel> states = [];
  int? selectedCountryId;
  StateModel? editingState;

  int currentPage = 1;
  int totalCount = 0;
  bool hasNext = false;
  bool hasPrevious = false;

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);

  @override
  void initState() {
    super.initState();
    getCountries();
    getStates();
  }

  Future<void> getStates() async {
    setState(() => isLoadingStates = true);

    try {
      final result = await _apiService.getStates(
        search: searchController.text.trim(),
        page: currentPage,
      );

      if (!mounted) return;

      setState(() {
        states = result['results'] as List<StateModel>;
        totalCount = result['count'] ?? 0;
        hasNext = result['next'] != null;
        hasPrevious = result['previous'] != null;
        isLoadingStates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingStates = false);
      showMessage(e.toString().replaceAll('Exception:', '').trim(), Colors.red);
    }
  }

  @override
  void dispose() {
    stateNameController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> getCountries() async {
    setState(() => isLoadingCountries = true);

    try {
      final result = await _apiService.getCountries();

      if (!mounted) return;

      setState(() {
        countries = result['results'] as List<CountryModel>;
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

  void showAddEditBottomSheet({StateModel? state}) {
    if (state != null) {
      editingState = state;
      stateNameController.text = state.name;
      selectedCountryId = countries.any((c) => c.id == state.country) ? state.country : null;
    } else {
      editingState = null;
      stateNameController.clear();
      selectedCountryId = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      editingState != null ? 'Edit State' : 'Add State',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    isLoadingCountries
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B8F3A)))
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
                              setModalState(() {
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
                        onPressed: isAddingState
                            ? null
                            : () async {
                                if (selectedCountryId == null) {
                                  showMessage('Select country', Colors.red);
                                  return;
                                }

                                if (stateNameController.text.trim().isEmpty) {
                                  showMessage('Enter state name', Colors.red);
                                  return;
                                }

                                setModalState(() => isAddingState = true);

                                try {
                                  if (editingState != null) {
                                    await _apiService.updateState(
                                      id: editingState!.id,
                                      name: stateNameController.text.trim(),
                                      country: selectedCountryId!,
                                    );
                                    showMessage('State updated successfully', primaryGreen);
                                  } else {
                                    await _apiService.addState(
                                      name: stateNameController.text.trim(),
                                      country: selectedCountryId!,
                                    );
                                    showMessage('State added successfully', primaryGreen);
                                    currentPage = 1; // Reset to page 1 to see the new entry
                                  }

                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  getStates();
                                } catch (e) {
                                  showMessage(
                                    e.toString().replaceAll('Exception:', '').trim(),
                                    Colors.red,
                                  );
                                } finally {
                                  setModalState(() => isAddingState = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isAddingState
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                editingState != null ? 'Update State' : 'Save State',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Future<void> deleteState(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this state? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.deleteState(id: id);
      showMessage('State deleted successfully', primaryGreen);
      if (editingState?.id == id) {
        setState(() {
          editingState = null;
          stateNameController.clear();
          selectedCountryId = null;
        });
      }
      getStates();
    } catch (e) {
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                onPressed: () => showAddEditBottomSheet(state: state),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                onPressed: () => deleteState(state.id),
              ),
            ],
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
          'States',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Added States',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                if (totalCount > 0)
                  Text(
                    'Total: $totalCount',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search by state name...',
                prefixIcon: Icon(Icons.search_rounded, color: primaryGreen),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            currentPage = 1;
                          });
                          getStates();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryGreen, width: 1.5),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  currentPage = 1;
                });
                getStates();
              },
            ),
            const SizedBox(height: 16),
            isLoadingStates
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: primaryGreen),
                    ),
                  )
                : states.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            'No states found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: states
                            .map((state) => stateCard(state))
                            .toList(),
                      ),
            if (hasPrevious || hasNext) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: primaryGreen,
                    onPressed: hasPrevious
                        ? () {
                            setState(() {
                              currentPage--;
                            });
                            getStates();
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Page $currentPage',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: primaryGreen,
                    onPressed: hasNext
                        ? () {
                            setState(() {
                              currentPage++;
                            });
                            getStates();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: () => showAddEditBottomSheet(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}