import 'package:flutter/material.dart';
import '../widgets/shimmer_loading.dart';
import 'package:grocery_app/services/api_service.dart';
import '../../models/country_model.dart';


class AddCountryPage extends StatefulWidget {
  const AddCountryPage({super.key});

  @override
  State<AddCountryPage> createState() => _AddCountryPageState();
}

class _AddCountryPageState extends State<AddCountryPage> {
  final ApiService _apiService = ApiService();

  final TextEditingController countryNameController = TextEditingController();
  final TextEditingController countryCodeController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  bool isAdding = false;
  bool isLoading = false;
  List<CountryModel> countries = [];
  CountryModel? editingCountry;

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
  }

  Future<void> getCountries() async {
    setState(() => isLoading = true);

    try {
      final result = await _apiService.getCountries(
        search: searchController.text.trim(),
        page: currentPage,
      );

      if (!mounted) return;

      setState(() {  
        countries = result['results'] as List<CountryModel>;
        totalCount = result['count'] ?? 0;
        hasNext = result['next'] != null;
        hasPrevious = result['previous'] != null;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showMessage(e.toString().replaceAll('Exception:', '').trim(), Colors.red);
    }
  }

  @override
  void dispose() {
    countryNameController.dispose();
    countryCodeController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void showAddEditBottomSheet({CountryModel? country}) {
    if (country != null) {
      editingCountry = country;
      countryNameController.text = country.name;
      countryCodeController.text = country.code;
    } else {
      editingCountry = null;
      countryNameController.clear();
      countryCodeController.clear();
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
                      editingCountry != null ? 'Edit Country' : 'Add Country',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: countryNameController,
                      decoration: inputDecoration(
                        label: 'Country Name',
                        icon: Icons.public_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: countryCodeController,
                      decoration: inputDecoration(
                        label: 'Country Code',
                        icon: Icons.call_rounded,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isAdding
                            ? null
                            : () async {
                                if (countryNameController.text.trim().isEmpty) {
                                  showMessage('Enter country name', Colors.red);
                                  return;
                                }

                                if (countryCodeController.text.trim().isEmpty) {
                                  showMessage('Enter country code', Colors.red);
                                  return;
                                }

                                setModalState(() => isAdding = true);

                                try {
                                  if (editingCountry != null) {
                                    await _apiService.updateCountry(
                                      id: editingCountry!.id,
                                      name: countryNameController.text.trim(),
                                      code: countryCodeController.text.trim(),
                                    );
                                    showMessage('Country updated successfully', primaryGreen);
                                  } else {
                                    await _apiService.addCountry(
                                      name: countryNameController.text.trim(),
                                      code: countryCodeController.text.trim(),
                                    );
                                    showMessage('Country added successfully', primaryGreen);
                                    currentPage = 1; // Reset to page 1 to see the new entry
                                  }

                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  getCountries();
                                } catch (e) {
                                  showMessage(
                                    e.toString().replaceAll('Exception:', '').trim(),
                                    Colors.red,
                                  );
                                } finally {
                                  setModalState(() => isAdding = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isAdding
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                editingCountry != null ? 'Update Country' : 'Save Country',
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

  Future<void> deleteCountry(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this country? This action cannot be undone.'),
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
      await _apiService.deleteCountry(id: id);
      showMessage('Country deleted successfully', primaryGreen);
      if (editingCountry?.id == id) {
        setState(() {
          editingCountry = null;
          countryNameController.clear();
          countryCodeController.clear();
        });
      }
      getCountries();
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

  Widget buildHeader() {
    return AppBar(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      title: const Text(
        'Countries',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                onPressed: () => showAddEditBottomSheet(country: country),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                onPressed: () => deleteCountry(country.id),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: buildHeader(),
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
                  'Added Countries',
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
                hintText: 'Search by country name...',
                prefixIcon: Icon(Icons.search_rounded, color: primaryGreen),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            currentPage = 1;
                          });
                          getCountries();
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
                getCountries();
              },
            ),
            const SizedBox(height: 16),
            isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: ProductsListShimmer(itemCount: 4),
                  )
                : countries.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            'No countries found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: countries
                            .map((country) => countryCard(country))
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
                            getCountries();
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
                            getCountries();
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