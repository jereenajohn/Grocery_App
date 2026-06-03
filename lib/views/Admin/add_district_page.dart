import 'package:flutter/material.dart';
import '../widgets/shimmer_loading.dart';

import '../../models/state_model.dart';
import '../../models/district_model.dart';
import '../../services/api_service.dart';

class AddDistrictPage extends StatefulWidget {
  const AddDistrictPage({super.key});

  @override
  State<AddDistrictPage> createState() => _AddDistrictPageState();
}

class _AddDistrictPageState extends State<AddDistrictPage> {
  final ApiService _apiService = ApiService();

  final TextEditingController districtNameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  bool isLoadingStates = false;
  bool isAddingDistrict = false;
  bool isLoadingDistricts = false;

  List<StateModel> states = [];
  List<DistrictModel> districts = [];
  int? selectedStateId;
  DistrictModel? editingDistrict;

  int currentPage = 1;
  int totalCount = 0;
  bool hasNext = false;
  bool hasPrevious = false;

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);

  @override
  void initState() {
    super.initState();
    getStates();
    getDistricts();
  }

  Future<void> getDistricts() async {
    setState(() => isLoadingDistricts = true);

    try {
      final result = await _apiService.getDistricts(
        search: searchController.text.trim(),
        page: currentPage,
      );

      if (!mounted) return;

      setState(() {
        districts = result['results'] as List<DistrictModel>;
        totalCount = result['count'] ?? 0;
        hasNext = result['next'] != null;
        hasPrevious = result['previous'] != null;
        isLoadingDistricts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingDistricts = false);
      showMessage(e.toString().replaceAll('Exception:', '').trim(), Colors.red);
    }
  }

  @override
  void dispose() {
    districtNameController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> getStates() async {
    setState(() => isLoadingStates = true);

    try {
      final result = await _apiService.getStates();

      if (!mounted) return;

      setState(() {
        states = result['results'] as List<StateModel>;
        isLoadingStates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingStates = false);
      showMessage(e.toString().replaceAll('Exception:', '').trim(), Colors.red);
    }
  }

  void showAddEditBottomSheet({DistrictModel? district}) {
    if (district != null) {
      editingDistrict = district;
      districtNameController.text = district.name;
      selectedStateId = states.any((s) => s.id == district.state) ? district.state : null;
    } else {
      editingDistrict = null;
      districtNameController.clear();
      selectedStateId = null;
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
                      editingDistrict != null ? 'Edit District' : 'Add District',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    isLoadingStates
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B8F3A)))
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
                              setModalState(() {
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
                        onPressed: isAddingDistrict
                            ? null
                            : () async {
                                if (selectedStateId == null) {
                                  showMessage('Select state', Colors.red);
                                  return;
                                }

                                if (districtNameController.text.trim().isEmpty) {
                                  showMessage('Enter district name', Colors.red);
                                  return;
                                }

                                setModalState(() => isAddingDistrict = true);

                                try {
                                  if (editingDistrict != null) {
                                    await _apiService.updateDistrict(
                                      id: editingDistrict!.id,
                                      name: districtNameController.text.trim(),
                                      state: selectedStateId!,
                                    );
                                    showMessage('District updated successfully', primaryGreen);
                                  } else {
                                    await _apiService.addDistrict(
                                      name: districtNameController.text.trim(),
                                      state: selectedStateId!,
                                    );
                                    showMessage('District added successfully', primaryGreen);
                                    currentPage = 1; // Reset to page 1 to see the new entry
                                  }

                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  getDistricts();
                                } catch (e) {
                                  showMessage(
                                    e.toString().replaceAll('Exception:', '').trim(),
                                    Colors.red,
                                  );
                                } finally {
                                  setModalState(() => isAddingDistrict = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isAddingDistrict
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                editingDistrict != null ? 'Update District' : 'Save District',
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

  Future<void> deleteDistrict(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this district? This action cannot be undone.'),
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
      await _apiService.deleteDistrict(id: id);
      showMessage('District deleted successfully', primaryGreen);
      if (editingDistrict?.id == id) {
        setState(() {
          editingDistrict = null;
          districtNameController.clear();
          selectedStateId = null;
        });
      }
      getDistricts();
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                onPressed: () => showAddEditBottomSheet(district: district),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                onPressed: () => deleteDistrict(district.id),
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
          'Districts',
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
                  'Added Districts',
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
                hintText: 'Search by district name...',
                prefixIcon: Icon(Icons.search_rounded, color: primaryGreen),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            currentPage = 1;
                          });
                          getDistricts();
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
                getDistricts();
              },
            ),
            const SizedBox(height: 16),
            isLoadingDistricts
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: ProductsListShimmer(itemCount: 4),
                  )
                : districts.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            'No districts found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: districts
                            .map((district) => districtCard(district))
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
                            getDistricts();
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
                            getDistricts();
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