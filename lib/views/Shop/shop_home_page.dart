import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:grocery_app/models/country_model.dart';
import 'package:grocery_app/models/state_model.dart';
import 'package:grocery_app/models/district_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../Admin/register_page.dart';
import '../widgets/shimmer_loading.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/order_model.dart';
import '../../services/api_service.dart';
import '../address_page.dart';
import '../request_otp_page.dart';
import 'change_phone_page.dart';
import 'manage_products_page.dart';

class ShopHomePage extends StatefulWidget {
  const ShopHomePage({super.key});

  @override
  State<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends State<ShopHomePage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _isStoreOpen = true;
  bool _togglingStoreStatus = false;
  int _activeNavIndex = 0;

  // Search & Filter State
  String _selectedStatusFilter = 'all';
  String _orderSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<OrderModel> _shopOrders = [];
  bool _shopOrdersLoading = true;
  String? _shopOrdersError;

  // Dashboard Data State
  Map<String, dynamic>? _dashboardData;
  bool _dashboardLoading = true;
  String? _dashboardError;
  DateTime _selectedStartDate = DateTime(2026, 6, 2);
  DateTime _selectedEndDate = DateTime(2026, 6, 2);

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color goldAccent = const Color(0xFFFFB300);
  final Color background = const Color(0xFFF7FFF9);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadShopOrders();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _apiService.getSavedUserData();
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userData = data;
        _isStoreOpen = prefs.getBool('is_store_open') ?? true;
      });
 
      // Fetch latest profile asynchronously to update SharedPreferences & state
      final profile = await _apiService.getProfile();
      bool serverStatus = _isStoreOpen;
      if (profile.containsKey('is_active')) {
        serverStatus = profile['is_active'] == true;
      } else if (profile.containsKey('is_open')) {
        serverStatus = profile['is_open'] == true;
      } else if (profile.containsKey('shop_status')) {
        serverStatus =
            profile['shop_status'].toString().toLowerCase() == 'open' ||
            profile['shop_status'] == true;
      } else if (profile.containsKey('status')) {
        serverStatus =
            profile['status'].toString().toLowerCase() == 'open' ||
            profile['status'].toString().toLowerCase() == 'active' ||
            profile['status'] == true;
      }
 
      await prefs.setBool('is_store_open', serverStatus);
      final updatedData = await _apiService.getSavedUserData();
      if (mounted) {
        setState(() {
          _userData = updatedData;
          _isStoreOpen = serverStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleStoreStatus(bool newVal) async {
    setState(() {
      _togglingStoreStatus = true;
    });
    try {
      final res = await _apiService.toggleShopStatus(newVal);

      bool finalStatus = newVal;
      if (res.containsKey('is_active')) {
        finalStatus = res['is_active'] == true;
      } else if (res.containsKey('is_open')) {
        finalStatus = res['is_open'] == true;
      } else if (res.containsKey('shop_status')) {
        finalStatus =
            res['shop_status'].toString().toLowerCase() == 'open' ||
            res['shop_status'] == true;
      } else if (res.containsKey('status')) {
        finalStatus =
            res['status'].toString().toLowerCase() == 'open' ||
            res['status'].toString().toLowerCase() == 'active' ||
            res['status'] == true;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_store_open', finalStatus);

      setState(() {
        _isStoreOpen = finalStatus;
        _togglingStoreStatus = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalStatus
                  ? 'Store is now active and open!'
                  : 'Store is now offline.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: finalStatus ? primaryGreen : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _togglingStoreStatus = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error toggling status: ${e.toString().replaceAll('Exception:', '').trim()}',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadShopOrders() async {
    if (!mounted) return;
    setState(() {
      _shopOrdersLoading = true;
      _shopOrdersError = null;
    });
    try {
      final orders = await _apiService.getShopOrders();
      if (!mounted) return;
      setState(() {
        _shopOrders = orders;
        _shopOrdersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shopOrdersError = e.toString().replaceAll('Exception:', '').trim();
        _shopOrdersLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _dashboardLoading = true;
      _dashboardError = null;
    });
    try {
      final startStr = _formatDate(_selectedStartDate);
      final endStr = _formatDate(_selectedEndDate);
      final res = await _apiService.getShopDashboard(startStr, endStr);
      if (!mounted) return;
      setState(() {
        if (res['success'] == true) {
          _dashboardData = res['data'];
        } else {
          _dashboardError = res['message'] ?? "Failed to load dashboard data";
        }
        _dashboardLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dashboardError = e.toString().replaceAll('Exception:', '').trim();
        _dashboardLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out of your vendor account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _apiService.clearSavedUserData();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RequestOtpPage()),
        (route) => false,
      );
    }
  }

  Widget _buildHeader() {
    final String firstName = _userData['first_name'] ?? 'Vendor';
    final String lastName = _userData['last_name'] ?? '';
    final String shopName = (_userData['shop_name']?.toString() ?? '').isNotEmpty
        ? _userData['shop_name'].toString()
        : (firstName.toLowerCase() == 'vendor'
            ? 'Vendor Store'
            : '$firstName $lastName\'s Hub'.trim());
    final String profilePicture = _userData['profile_picture'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, darkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: profilePicture.isNotEmpty
                          ? NetworkImage(profilePicture)
                          : null,
                      child: profilePicture.isEmpty
                          ? const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 28,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Merchant Dashboard',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 5),
                          // Container(
                          //   padding: const EdgeInsets.symmetric(
                          //     horizontal: 6,
                          //     vertical: 2,
                          //   ),
                          //   decoration: BoxDecoration(
                          //     color: goldAccent,
                          //     borderRadius: BorderRadius.circular(6),
                          //   ),
                          //   child: const Row(
                          //     children: [
                          //       Icon(
                          //         Icons.verified_rounded,
                          //         size: 9,
                          //         color: Colors.black87,
                          //       ),
                          //       SizedBox(width: 2),
                          //       Text(
                          //         'PRO',
                          //         style: TextStyle(
                          //           fontSize: 8,
                          //           fontWeight: FontWeight.bold,
                          //           color: Colors.black87,
                          //         ),
                          //       ),
                          //     ],
                          //   ),
                          // ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shopName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      height: 12,
                      width: 12,
                      decoration: BoxDecoration(
                        color: _isStoreOpen ? primaryGreen : Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isStoreOpen ? primaryGreen : Colors.red)
                                .withOpacity(0.4),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isStoreOpen
                              ? 'Store is Open & Active'
                              : 'Store is Offline',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _isStoreOpen
                              ? 'Accepting delivery requests'
                              : 'Tap to go active',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _togglingStoreStatus
                    ? const Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFF1B8F3A),
                          ),
                        ),
                      )
                    : Switch.adaptive(
                        value: _isStoreOpen,
                        activeColor: primaryGreen,
                        onChanged: _toggleStoreStatus,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_activeNavIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildShopOrdersTab();
      case 2:
        return const ManageProductsPage(showBackButton: false);
      case 3:
        return _buildSettingsView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSettingsView() {
    final String firstName = _userData['first_name'] ?? 'Vendor';
    final String lastName = _userData['last_name'] ?? '';
    final String shopName = (_userData['shop_name']?.toString() ?? '').isNotEmpty
        ? _userData['shop_name'].toString()
        : (firstName.toLowerCase() == 'vendor'
            ? 'Vendor Store'
            : '$firstName $lastName\'s Hub'.trim());
    final String profilePicture = _userData['profile_picture'] ?? '';
    final String email = _userData['email'] ?? 'vendor@groceryapp.com';
    final String phone = _userData['phone'] ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, darkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    backgroundImage: profilePicture.isNotEmpty
                        ? NetworkImage(profilePicture)
                        : null,
                    child: profilePicture.isEmpty
                        ? const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 45,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                // Container(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 10,
                //     vertical: 4,
                //   ),
                //   decoration: BoxDecoration(
                //     color: goldAccent,
                //     borderRadius: BorderRadius.circular(8),
                //   ),
                //   child: const Row(
                //     mainAxisSize: MainAxisSize.min,
                //     children: [
                //       Icon(
                //         Icons.verified_rounded,
                //         size: 12,
                //         color: Colors.black87,
                //       ),
                //       SizedBox(width: 4),
                //       Text(
                //         'PRO MERCHANT',
                //         style: TextStyle(
                //           fontSize: 10,
                //           fontWeight: FontWeight.bold,
                //           color: Colors.black87,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                if (email.isNotEmpty || phone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    email.isNotEmpty ? email : phone,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 30),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                _buildSettingsTile(
                  icon: Icons.inventory_2_rounded,
                  title: 'My Products',
                  subtitle: 'Manage inventory, prices, & active status',
                  iconBgColor: lightGreen,
                  iconColor: primaryGreen,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageProductsPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                _buildSettingsTile(
                  icon: Icons.location_on_rounded,
                  title: 'My Addresses',
                  subtitle: 'Manage shop address & delivery locations',
                  iconBgColor: lightGreen,
                  iconColor: primaryGreen,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddressPage()),
                    );
                  },
                ),

                const SizedBox(height: 16),

                _buildSettingsTile(
                  icon: Icons.phone_android_rounded,
                  title: 'Change Phone Number',
                  subtitle: 'Update your registered merchant contact number',
                  iconBgColor: lightGreen,
                  iconColor: primaryGreen,
                  onTap: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangePhonePage(
                          currentPhone: _userData['phone'] ?? '',
                        ),
                      ),
                    );
                    if (updated == true) {
                      _loadUserData();
                    }
                  },
                ),

                const SizedBox(height: 16),

                _buildSettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal and shop details',
                  iconBgColor: lightGreen,
                  iconColor: primaryGreen,
                  onTap: () {
                    _showEditProfileBottomSheet();
                  },
                ),

                const SizedBox(height: 16),

                _buildSettingsTile(
                  icon: Icons.account_balance_rounded,
                  title: 'Bank Account Details',
                  subtitle: 'Manage bank details & payout UPI ID',
                  iconBgColor: lightGreen,
                  iconColor: primaryGreen,
                  onTap: () {
                    _showBankDetailsBottomSheet();
                  },
                ),

                const SizedBox(height: 30),

                const Text(
                  'System',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Sign out of your vendor account securely',
                  iconBgColor: const Color(0xFFFFEBEE),
                  iconColor: Colors.redAccent,
                  isDestructive: true,
                  onTap: _logout,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileBottomSheet() {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(text: _userData['first_name'] ?? '');
    final lastNameController = TextEditingController(text: _userData['last_name'] ?? '');
    final emailController = TextEditingController(text: _userData['email'] ?? '');
    final shopNameController = TextEditingController(text: _userData['shop_name'] ?? '');
    final latitudeController = TextEditingController(text: _userData['latitude'] ?? '');
    final longitudeController = TextEditingController(text: _userData['longitude'] ?? '');
    bool isOpen = _userData['is_open'] ?? _isStoreOpen;
    
    File? selectedImage;
    final picker = ImagePicker();

    bool isLoadingLocations = true;
    bool locationsLoaded = false;
    List<CountryModel> countriesList = [];
    List<StateModel> statesList = [];
    List<DistrictModel> districtsList = [];
    CountryModel? selectedCountry;
    StateModel? selectedState;
    DistrictModel? selectedDistrict;

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> loadInitialLocations() async {
              try {
                final res = await _apiService.getCountries();
                countriesList = List<CountryModel>.from(res['results'] ?? []);
                
                final countryVal = _userData['country'];
                final countryNameVal = _userData['country_name'];
                if ((countryVal != null && countryVal != 0) || (countryNameVal != null && countryNameVal.toString().isNotEmpty)) {
                  for (var c in countriesList) {
                    if ((countryVal != null && countryVal != 0 && c.id == countryVal) ||
                        (countryNameVal != null && c.name.trim().toLowerCase() == countryNameVal.toString().trim().toLowerCase())) {
                      selectedCountry = c;
                      break;
                    }
                  }
                }
                
                if (selectedCountry != null) {
                  statesList = await _apiService.getStatesByCountry(countryId: selectedCountry!.id);
                  final stateVal = _userData['state'];
                  final stateNameVal = _userData['state_name'];
                  if ((stateVal != null && stateVal != 0) || (stateNameVal != null && stateNameVal.toString().isNotEmpty)) {
                    for (var s in statesList) {
                      if ((stateVal != null && stateVal != 0 && s.id == stateVal) ||
                          (stateNameVal != null && s.name.trim().toLowerCase() == stateNameVal.toString().trim().toLowerCase())) {
                        selectedState = s;
                        break;
                      }
                    }
                  }
                }
                
                if (selectedState != null) {
                  districtsList = await _apiService.getDistrictsByState(stateId: selectedState!.id);
                  final districtVal = _userData['district'];
                  final districtNameVal = _userData['district_name'];
                  if ((districtVal != null && districtVal != 0) || (districtNameVal != null && districtNameVal.toString().isNotEmpty)) {
                    for (var d in districtsList) {
                      if ((districtVal != null && districtVal != 0 && d.id == districtVal) ||
                          (districtNameVal != null && d.name.trim().toLowerCase() == districtNameVal.toString().trim().toLowerCase())) {
                        selectedDistrict = d;
                        break;
                      }
                    }
                  }
                }
              } catch (e) {
                print("Error loading locations: $e");
              } finally {
                setModalState(() {
                  isLoadingLocations = false;
                });
              }
            }

            Future<void> onCountryChanged(CountryModel? country) async {
              setModalState(() {
                selectedCountry = country;
                selectedState = null;
                selectedDistrict = null;
                statesList = [];
                districtsList = [];
                isLoadingLocations = true;
              });
              if (country != null) {
                try {
                  final list = await _apiService.getStatesByCountry(countryId: country.id);
                  setModalState(() {
                    statesList = list;
                    isLoadingLocations = false;
                  });
                } catch (_) {
                  setModalState(() {
                    isLoadingLocations = false;
                  });
                }
              } else {
                setModalState(() {
                  isLoadingLocations = false;
                });
              }
            }

            Future<void> onStateChanged(StateModel? state) async {
              setModalState(() {
                selectedState = state;
                selectedDistrict = null;
                districtsList = [];
                isLoadingLocations = true;
              });
              if (state != null) {
                try {
                  final list = await _apiService.getDistrictsByState(stateId: state.id);
                  setModalState(() {
                    districtsList = list;
                    isLoadingLocations = false;
                  });
                } catch (_) {
                  setModalState(() {
                    isLoadingLocations = false;
                  });
                }
              } else {
                setModalState(() {
                  isLoadingLocations = false;
                });
              }
            }

            Future<void> pickNewImage() async {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (BuildContext sheetCtx) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Select Store Logo Source',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(sheetCtx);
                                try {
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.camera,
                                    maxWidth: 512,
                                    maxHeight: 512,
                                    imageQuality: 85,
                                  );
                                  if (image != null) {
                                    setModalState(() {
                                      selectedImage = File(image.path);
                                    });
                                  }
                                } catch (e) {
                                  print("Error picking image from camera: $e");
                                }
                              },
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: lightGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.camera_alt_rounded, color: primaryGreen, size: 30),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Camera',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(sheetCtx);
                                try {
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 512,
                                    maxHeight: 512,
                                    imageQuality: 85,
                                  );
                                  if (image != null) {
                                    setModalState(() {
                                      selectedImage = File(image.path);
                                    });
                                  }
                                } catch (e) {
                                  print("Error picking image from gallery: $e");
                                }
                              },
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: lightGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.photo_library_rounded, color: primaryGreen, size: 30),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Gallery',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            if (!locationsLoaded) {
              locationsLoaded = true;
              loadInitialLocations();
            }

            return AnimatedPadding(
              padding: MediaQuery.of(context).viewInsets,
              duration: const Duration(milliseconds: 100),
              curve: Curves.decelerate,
              child: Container(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: lightGreen,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                color: primaryGreen,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Profile Image Selector
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: primaryGreen, width: 3),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white,
                                  backgroundImage: selectedImage != null
                                      ? FileImage(selectedImage!) as ImageProvider
                                      : (_userData['profile_picture'] != null && _userData['profile_picture'].toString().isNotEmpty
                                          ? NetworkImage(_userData['profile_picture']) as ImageProvider
                                          : null),
                                  child: selectedImage == null && (_userData['profile_picture'] == null || _userData['profile_picture'].toString().isEmpty)
                                      ? Icon(Icons.storefront_rounded, size: 50, color: Colors.grey.shade400)
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: pickNewImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'First Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: firstNameController,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Enter your first name',
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.green.shade100),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.green.shade100),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: primaryGreen, width: 1.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'First name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Last Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: lastNameController,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Enter your last name',
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.green.shade100),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.green.shade100),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: primaryGreen, width: 1.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Last name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Shop Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: shopNameController,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Enter your shop name',
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.green.shade100),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.green.shade100),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: primaryGreen, width: 1.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Shop name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Enter your email address',
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.green.shade100),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.green.shade100),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: primaryGreen, width: 1.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Dropdown fields for country, state, district
                        Text(
                          'Country',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        isLoadingLocations
                            ? const LinearProgressIndicator()
                            : DropdownButtonFormField<int>(
                                value: selectedCountry?.id,
                                dropdownColor: Colors.white,
                                isExpanded: true,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                decoration: InputDecoration(
                                  fillColor: Colors.white,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.green.shade100),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.green.shade100),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: primaryGreen, width: 1.5),
                                  ),
                                ),
                                items: countriesList.map((c) {
                                  return DropdownMenuItem<int>(
                                    value: c.id,
                                    child: Text(c.name),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final c = countriesList.firstWhere((x) => x.id == val);
                                    onCountryChanged(c);
                                  }
                                },
                                validator: (value) => value == null ? 'Country is required' : null,
                              ),
                        const SizedBox(height: 16),
                        Text(
                          'State',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        isLoadingLocations
                            ? const LinearProgressIndicator()
                            : DropdownButtonFormField<int>(
                                value: selectedState?.id,
                                dropdownColor: Colors.white,
                                isExpanded: true,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                decoration: InputDecoration(
                                  fillColor: Colors.white,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.green.shade100),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.green.shade100),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: primaryGreen, width: 1.5),
                                  ),
                                ),
                                items: statesList.map((s) {
                                  return DropdownMenuItem<int>(
                                    value: s.id,
                                    child: Text(s.name),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final s = statesList.firstWhere((x) => x.id == val);
                                    onStateChanged(s);
                                  }
                                },
                                validator: (value) => value == null ? 'State is required' : null,
                              ),
                        const SizedBox(height: 16),
                        Text(
                          'District',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        isLoadingLocations
                            ? const LinearProgressIndicator()
                            : DropdownButtonFormField<int>(
                                value: selectedDistrict?.id,
                                dropdownColor: Colors.white,
                                isExpanded: true,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                decoration: InputDecoration(
                                  fillColor: Colors.white,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.green.shade100),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.green.shade100),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: primaryGreen, width: 1.5),
                                  ),
                                ),
                                items: districtsList.map((d) {
                                  return DropdownMenuItem<int>(
                                    value: d.id,
                                    child: Text(d.name),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final d = districtsList.firstWhere((x) => x.id == val);
                                    setModalState(() {
                                      selectedDistrict = d;
                                    });
                                  }
                                },
                                validator: (value) => value == null ? 'District is required' : null,
                              ),
                        const SizedBox(height: 16),
                        Text(
                          'Shop Location (Tap Map to Edit)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            double lat = double.tryParse(latitudeController.text) ?? 9.9312;
                            double lng = double.tryParse(longitudeController.text) ?? 76.2673;
                            LatLng shopLatLng = LatLng(lat, lng);

                            return Container(
                              height: 160,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.green.shade100, width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Stack(
                                  children: [
                                    FlutterMap(
                                      key: ValueKey('${lat}_${lng}'),
                                      options: MapOptions(
                                        initialCenter: shopLatLng,
                                        initialZoom: 14.0,
                                        interactionOptions: const InteractionOptions(
                                          flags: InteractiveFlag.none,
                                        ),
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName: 'com.example.grocery_app',
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: shopLatLng,
                                              width: 40,
                                              height: 40,
                                              child: Icon(
                                                Icons.location_pin,
                                                color: primaryGreen,
                                                size: 40,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    // Overlay InkWell to handle tap
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () async {
                                            final LatLng? result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => MapLocationPicker(
                                                  initialLatitude: double.tryParse(latitudeController.text),
                                                  initialLongitude: double.tryParse(longitudeController.text),
                                                ),
                                              ),
                                            );
                                            if (result != null) {
                                              setModalState(() {
                                                latitudeController.text = result.latitude.toString();
                                                longitudeController.text = result.longitude.toString();
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    // Floating Indicator Badge
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: primaryGreen,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text(
                                              'Tap to Edit',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
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
                        ),
                        const SizedBox(height: 16),
                        // Shop Open Status Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Shop Open Status',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Switch(
                              value: isOpen,
                              activeColor: primaryGreen,
                              onChanged: (val) {
                                setModalState(() {
                                  isOpen = val;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      setModalState(() {
                                        isSaving = true;
                                      });
                                      try {
                                        final userId = _userData['user_id'] ?? 0;
                                        await _apiService.updateProfile(
                                          userId: userId,
                                          firstName: firstNameController.text.trim(),
                                          lastName: lastNameController.text.trim(),
                                          email: emailController.text.trim(),
                                          shopName: shopNameController.text.trim(),
                                          country: selectedCountry?.id,
                                          state: selectedState?.id,
                                          district: selectedDistrict?.id,
                                          latitude: latitudeController.text.trim(),
                                          longitude: longitudeController.text.trim(),
                                          isOpen: isOpen,
                                          profilePicture: selectedImage,
                                        );
                                        await _loadUserData();
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Profile updated successfully!'),
                                              backgroundColor: primaryGreen,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModalState(() {
                                          isSaving = false;
                                        });
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString().replaceAll('Exception: ', '')),
                                              backgroundColor: Colors.redAccent,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDestructive ? Colors.red.shade100 : Colors.green.shade50,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDestructive ? Colors.red : primaryGreen).withOpacity(
              0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDestructive
                              ? Colors.red.shade700
                              : darkGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDestructive
                      ? Colors.red.shade300
                      : primaryGreen.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Orders'},
      {'icon': Icons.inventory_2_rounded, 'label': 'Products'},
      {'icon': Icons.settings, 'label': 'Settings'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(navItems.length, (index) {
            final active = _activeNavIndex == index;
            final item = navItems[index];
            return InkWell(
              onTap: () {
                setState(() {
                  _activeNavIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: active ? lightGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'],
                      color: active ? primaryGreen : Colors.grey.shade400,
                      size: 24,
                    ),
                    if (active) ...[
                      const SizedBox(width: 8),
                      Text(
                        item['label'],
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = months[dateTime.month - 1];
      final year = dateTime.year;
      final hourNum = dateTime.hour;
      final period = hourNum >= 12 ? 'PM' : 'AM';
      final hourVal = hourNum % 12 == 0 ? 12 : hourNum % 12;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hourVal:$minute $period';
    } catch (_) {
      return isoString;
    }
  }

  Widget _statusBadge(String status) {
    final lower = status.toLowerCase();
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.grey.shade700;

    if (lower == 'completed' || lower == 'approved') {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF1B8F3A);
    } else if (lower == 'pending') {
      bgColor = const Color(0xFFFFF3E0);
      textColor = Colors.orange.shade800;
    } else if (lower == 'failed' ||
        lower == 'rejected' ||
        lower == 'cancelled') {
      bgColor = const Color(0xFFFFEBEE);
      textColor = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sellerPaymentStatusBadge(String status) {
    final lower = status.toLowerCase();
    Color bgColor = const Color(0xFFFFF3E0);
    Color textColor = Colors.orange.shade800;

    if (lower == 'paid' || lower == 'completed' || lower == 'settled') {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF1B8F3A);
    } else if (lower == 'failed' ||
        lower == 'rejected' ||
        lower == 'refunded') {
      bgColor = const Color(0xFFFFEBEE);
      textColor = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _showShopOrderDetailBottomSheet(int orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ShopOrderDetailBottomSheet(
          orderId: orderId,
          apiService: _apiService,
          primaryGreen: primaryGreen,
          lightGreen: lightGreen,
          background: background,
          formatDateTime: _formatDateTime,
          statusBadge: _statusBadge,
          sellerPaymentStatusBadge: _sellerPaymentStatusBadge,
          onStatusUpdated: _loadShopOrders,
        );
      },
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '$label copied to clipboard!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildHorizontalStatusFilters() {
    final statuses = [
      {
        'key': 'all',
        'label': 'All',
        'icon': Icons.grid_view_rounded,
        'color': primaryGreen,
      },
      {
        'key': 'pending',
        'label': 'Pending',
        'icon': Icons.hourglass_empty_rounded,
        'color': Colors.orange,
      },
      {
        'key': 'shipped',
        'label': 'Shipped',
        'icon': Icons.local_shipping_rounded,
        'color': Colors.blue.shade700,
      },
      {
        'key': 'completed',
        'label': 'Completed',
        'icon': Icons.check_circle_outline_rounded,
        'color': primaryGreen,
      },
      {
        'key': 'cancelled',
        'label': 'Cancelled',
        'icon': Icons.cancel_outlined,
        'color': Colors.red.shade800,
      },
    ];

    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final item = statuses[index];
          final key = item['key'] as String;
          final label = item['label'] as String;
          final icon = item['icon'] as IconData;
          final color = item['color'] as Color;
          final isSelected = _selectedStatusFilter == key;

          int count = 0;
          if (key == 'all') {
            count = _shopOrders.length;
          } else if (key == 'completed') {
            count = _shopOrders
                .where(
                  (o) =>
                      o.status.toLowerCase() == 'completed' ||
                      o.status.toLowerCase() == 'approved',
                )
                .length;
          } else if (key == 'cancelled') {
            count = _shopOrders
                .where(
                  (o) =>
                      o.status.toLowerCase() == 'cancelled' ||
                      o.status.toLowerCase() == 'rejected' ||
                      o.status.toLowerCase() == 'failed',
                )
                .length;
          } else {
            count = _shopOrders
                .where((o) => o.status.toLowerCase() == key)
                .length;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : color.withOpacity(0.8),
              ),
              label: Text(
                '$label ($count)',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: color,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? color : Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedStatusFilter = key;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _orderSearchQuery = val;
          });
        },
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by Order No, Customer, Phone...',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: primaryGreen, size: 20),
          suffixIcon: _orderSearchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _orderSearchQuery = '';
                    });
                  },
                  child: Icon(
                    Icons.clear_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.green.shade50),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.green.shade50),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryGreen, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCardProgressStepper(String status) {
    final lower = status.toLowerCase();
    int activeIndex = 0; // default 0 (placed / pending)
    if (lower == 'shipped') {
      activeIndex = 1;
    } else if (lower == 'completed' || lower == 'approved') {
      activeIndex = 2;
    } else if (lower == 'cancelled' ||
        lower == 'rejected' ||
        lower == 'failed') {
      activeIndex = -1; // error/cancellation stepper
    }

    if (activeIndex == -1) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 14,
            ),
            SizedBox(width: 6),
            Text(
              'Order Cancelled / Rejected',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _stepNode(
            label: 'Placed',
            isActive: activeIndex >= 0,
            isCompleted: activeIndex > 0,
          ),
          _stepLine(isCompleted: activeIndex > 0),
          _stepNode(
            label: 'Shipped',
            isActive: activeIndex >= 1,
            isCompleted: activeIndex > 1,
          ),
          _stepLine(isCompleted: activeIndex > 1),
          _stepNode(
            label: 'Completed',
            isActive: activeIndex >= 2,
            isCompleted: activeIndex >= 2,
          ),
        ],
      ),
    );
  }

  Widget _stepNode({
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color color = Colors.grey.shade300;
    if (isCompleted) {
      color = primaryGreen;
    } else if (isActive) {
      color = Colors.orange;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 18,
          width: 18,
          decoration: BoxDecoration(
            color: isCompleted ? primaryGreen : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isCompleted ? 0 : 2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: isCompleted
              ? const Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                )
              : Center(
                  child: Container(
                    height: 6,
                    width: 6,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.orange : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: isActive ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _stepLine({required bool isCompleted}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 2,
          color: isCompleted ? primaryGreen : Colors.grey.shade200,
        ),
      ),
    );
  }

  Widget _paymentMethodBadge(String name) {
    final isCod =
        name.toLowerCase().contains('cash') ||
        name.toLowerCase().contains('cod');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCod ? const Color(0xFFE8F5E9) : const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCod ? Icons.payments_rounded : Icons.qr_code_2_rounded,
            size: 11,
            color: isCod ? primaryGreen : Colors.deepPurple,
          ),
          const SizedBox(width: 4),
          Text(
            name.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: isCod ? darkGreen : Colors.deepPurple.shade900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopOrdersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Received Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: _loadShopOrders,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: primaryGreen,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        // _buildMetricsCards(),
        // _buildSearchBar(),
        _buildHorizontalStatusFilters(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadShopOrders,
            color: primaryGreen,
            child: _buildShopOrdersContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsCards() {
    if (_shopOrdersLoading || _shopOrdersError != null || _shopOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalCount = _shopOrders.length;
    final pendingCount = _shopOrders
        .where((o) => o.status.toLowerCase() == 'pending')
        .length;
    double earningsSum = 0.0;
    for (var o in _shopOrders) {
      if (o.status.toLowerCase() == 'completed' ||
          o.status.toLowerCase() == 'approved') {
        earningsSum += double.tryParse(o.totalPrice) ?? 0.0;
      }
    }

    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Revenue',
              value: '₹${earningsSum.toStringAsFixed(0)}',
              icon: Icons.monetization_on_rounded,
              startColor: primaryGreen,
              endColor: darkGreen,
              textColor: Colors.white,
              iconColor: Colors.white.withOpacity(0.25),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
              title: 'Pending',
              value: '$pendingCount orders',
              icon: Icons.hourglass_empty_rounded,
              startColor: const Color(0xFFFFF3E0),
              endColor: const Color(0xFFFFF3E0),
              textColor: Colors.orange.shade900,
              iconColor: Colors.orange.shade200,
              border: Border.all(color: Colors.orange.shade100, width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
              title: 'Total',
              value: '$totalCount orders',
              icon: Icons.receipt_long_rounded,
              startColor: const Color(0xFFE8EAF6),
              endColor: const Color(0xFFE8EAF6),
              textColor: Colors.indigo.shade900,
              iconColor: Colors.indigo.shade200,
              border: Border.all(color: Colors.indigo.shade100, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color startColor,
    required Color endColor,
    required Color textColor,
    required Color iconColor,
    BoxBorder? border,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(icon, size: 64, color: iconColor),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: textColor.withOpacity(0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopOrdersContent() {
    if (_shopOrdersLoading) {
      return const OrdersListShimmer();
    }

    if (_shopOrdersError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _shopOrdersError!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadShopOrders,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_shopOrders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: lightGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 64,
                      color: primaryGreen.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Received Orders',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'When customers order products from your shop, they will appear here!',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final filteredOrders = _shopOrders.where((order) {
      final statusMatches =
          _selectedStatusFilter == 'all' ||
          order.status.toLowerCase() == _selectedStatusFilter.toLowerCase();

      final query = _orderSearchQuery.toLowerCase().trim();
      final searchMatches =
          query.isEmpty ||
          order.orderNo.toLowerCase().contains(query) ||
          order.fullName.toLowerCase().contains(query) ||
          order.phone.toLowerCase().contains(query) ||
          order.items.any(
            (item) => item.product.name.toLowerCase().contains(query),
          );

      return statusMatches && searchMatches;
    }).toList();

    if (filteredOrders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Matching Orders',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search query or status filter.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _orderSearchQuery = '';
                        _selectedStatusFilter = 'all';
                      });
                    },
                    child: Text(
                      'Clear Filters',
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _buildShopOrderCard(order);
      },
    );
  }

  Widget _buildShopOrderCard(OrderModel order) {
    Color statusColor = Colors.grey;
    final lower = order.status.toLowerCase();
    if (lower == 'completed' || lower == 'approved') {
      statusColor = primaryGreen;
    } else if (lower == 'pending') {
      statusColor = Colors.orange;
    } else if (lower == 'shipped') {
      statusColor = Colors.blue.shade700;
    } else if (lower == 'cancelled' ||
        lower == 'rejected' ||
        lower == 'failed') {
      statusColor = Colors.red.shade800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade50.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left side status accent bar
              Container(width: 6, color: statusColor),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showShopOrderDetailBottomSheet(order.id),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            order.orderNo,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.grey.shade800,
                                              fontFamily: 'monospace',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _copyToClipboard(
                                            order.orderNo,
                                            'Order Number',
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            margin: const EdgeInsets.only(
                                              left: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatDateTime(order.createdAt),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusBadge(order.status),
                            ],
                          ),

                          // Timeline stepper
                          _buildOrderCardProgressStepper(order.status),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFE8F5E9),
                            ),
                          ),

                          // Customer Details Info Box
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.shade50),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: primaryGreen,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        order.fullName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: darkGreen,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () => _copyToClipboard(
                                        order.phone,
                                        'Phone number',
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: lightGreen,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.phone_rounded,
                                              color: primaryGreen,
                                              size: 11,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              order.phone,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: darkGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: primaryGreen,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${order.address}, ${order.city}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (order.note != null &&
                                    order.note!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.sticky_note_2_rounded,
                                        color: goldAccent,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '"${order.note}"',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Order Items Preview
                          ...order.items
                              .take(2)
                              .map((item) => _buildShopOrderItemRow(item)),
                          if (order.items.length > 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 4),
                              child: Text(
                                '+ ${order.items.length - 2} more item${order.items.length - 2 > 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PAYOUT STATUS',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _sellerPaymentStatusBadge(
                                    order.sellerPaymentStatus ?? 'PENDING',
                                  ),
                                ],
                              ),
                              _paymentMethodBadge(order.paymentMethodName),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'EARNINGS',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${order.totalPrice}',
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      color: primaryGreen,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopOrderItemRow(OrderItemModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.product.image != null
                  ? Image.network(
                      item.product.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_basket_rounded,
                        color: Color(0xFF1B8F3A),
                        size: 20,
                      ),
                    )
                  : const Icon(
                      Icons.shopping_basket_rounded,
                      color: Color(0xFF1B8F3A),
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.quantityDisplay} • ₹${item.price}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: background,
        body: SafeArea(child: const HomePageShimmer()),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  void _showBankDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ShopBankDetailsBottomSheet(
          apiService: _apiService,
          primaryGreen: primaryGreen,
          lightGreen: lightGreen,
          background: background,
        );
      },
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShopSummaryCard(),
                  const SizedBox(height: 24),
                  _buildDateFilterSection(),
                  const SizedBox(height: 24),
                  if (_dashboardLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: ProductsListShimmer(itemCount: 3),
                    )
                  else if (_dashboardError != null)
                    _buildErrorState()
                  else ...[
                    _buildMetricsGrid(),
                    const SizedBox(height: 16),
                    _buildPieChartSection(),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopSummaryCard() {
    final shopName =
        _dashboardData?['shop_name'] ?? _userData['shop_name'] ?? 'My Store';
    final shopId = _dashboardData?['shop_id'] ?? _userData['user_id'] ?? '';
    final totalOrders = _dashboardData?['total_orders_count'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, darkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName.toString().toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // const SizedBox(height: 6),
                // Text(
                //   'Merchant ID: #$shopId',
                //   style: TextStyle(
                //     color: Colors.white.withOpacity(0.7),
                //     fontSize: 12,
                //     fontWeight: FontWeight.bold,
                //   ),
                // ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalOrders',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'TOTAL ORDERS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterSection() {
    final String formattedDateStr;
    if (_selectedStartDate.year == _selectedEndDate.year &&
        _selectedStartDate.month == _selectedEndDate.month &&
        _selectedStartDate.day == _selectedEndDate.day) {
      formattedDateStr =
          "${_selectedStartDate.day.toString().padLeft(2, '0')} ${_getMonthName(_selectedStartDate.month)} ${_selectedStartDate.year}";
    } else {
      formattedDateStr =
          "${_selectedStartDate.day.toString().padLeft(2, '0')} ${_getMonthName(_selectedStartDate.month)} - ${_selectedEndDate.day.toString().padLeft(2, '0')} ${_getMonthName(_selectedEndDate.month)} ${_selectedEndDate.year}";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Date Range Metrics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryGreen.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: primaryGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDateStr,
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: primaryGreen,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _selectedStartDate,
        end: _selectedEndDate,
      ),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryGreen,
              onPrimary: Colors.white,
              onSurface: Colors.grey.shade900,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryGreen,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (picked.start != _selectedStartDate || picked.end != _selectedEndDate) {
        setState(() {
          _selectedStartDate = picked.start;
          _selectedEndDate = picked.end;
        });
        _loadDashboardData();
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade700,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            _dashboardError ?? "Failed to load dashboard metrics",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = _dashboardData?['date_metrics'] ?? {};
    final total = metrics['total'] ?? 0;
    final completed = metrics['completed'] ?? 0;
    final shipped = metrics['shipped'] ?? 0;
    final cancelled = metrics['cancelled'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildSmallMetricCard(
            title: 'Total',
            value: '$total',
            icon: Icons.shopping_bag_rounded,
            color: Colors.orange,
            bgColor: Colors.orange.shade50,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSmallMetricCard(
            title: 'Completed',
            value: '$completed',
            icon: Icons.check_circle_rounded,
            color: primaryGreen,
            bgColor: const Color(0xFFEAF8EE),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSmallMetricCard(
            title: 'Shipped',
            value: '$shipped',
            icon: Icons.local_shipping_rounded,
            color: Colors.blue.shade700,
            bgColor: Colors.blue.shade50,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSmallMetricCard(
            title: 'Cancelled',
            value: '$cancelled',
            icon: Icons.cancel_rounded,
            color: Colors.red.shade600,
            bgColor: Colors.red.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection() {
    final metrics = _dashboardData?['date_metrics'] ?? {};
    final total = metrics['total'] ?? 0;
    final completed = metrics['completed'] ?? 0;
    final shipped = metrics['shipped'] ?? 0;
    final cancelled = metrics['cancelled'] ?? 0;
    final other = (total - (completed + shipped + cancelled)).clamp(0, total);

    final List<double> values = [
      completed.toDouble(),
      shipped.toDouble(),
      cancelled.toDouble(),
      other.toDouble(),
    ];
    final List<Color> colors = [
      primaryGreen,
      Colors.blue.shade700,
      Colors.red.shade600,
      Colors.amber.shade600,
    ];

    final List<String> labels = [
      'Completed',
      'Shipped',
      'Cancelled',
      'Other/Pending',
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Status Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 130,
                  width: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: PieChartPainter(values: values, colors: colors),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            'Orders',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(values.length, (index) {
                    final val = values[index].toInt();
                    if (val == 0 && total > 0) return const SizedBox.shrink();
                    
                    double percentage = total > 0 ? (val / total) * 100 : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[index],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${labels[index]} ($val)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopOrderDetailBottomSheet extends StatefulWidget {
  final int orderId;
  final ApiService apiService;
  final Color primaryGreen;
  final Color lightGreen;
  final Color background;
  final String Function(String) formatDateTime;
  final Widget Function(String) statusBadge;
  final Widget Function(String) sellerPaymentStatusBadge;
  final VoidCallback? onStatusUpdated;

  const _ShopOrderDetailBottomSheet({
    required this.orderId,
    required this.apiService,
    required this.primaryGreen,
    required this.lightGreen,
    required this.background,
    required this.formatDateTime,
    required this.statusBadge,
    required this.sellerPaymentStatusBadge,
    this.onStatusUpdated,
  });

  @override
  State<_ShopOrderDetailBottomSheet> createState() =>
      _ShopOrderDetailBottomSheetState();
}

class _ShopOrderDetailBottomSheetState
    extends State<_ShopOrderDetailBottomSheet> {
  OrderModel? _detail;
  bool _loading = true;
  String? _error;
  bool _updatingOrderStatus = false;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '$label copied to clipboard!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: widget.primaryGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await widget.apiService.getShopOrderDetail(
        orderId: widget.orderId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        _loading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    if (_detail == null) return;
    setState(() {
      _updatingOrderStatus = true;
    });
    try {
      final res = await widget.apiService.updateShopOrderStatus(
        orderId: widget.orderId,
        status: newStatus,
      );
      final updatedStatus = res['status']?.toString() ?? newStatus;

      if (!mounted) return;
      setState(() {
        _detail = OrderModel(
          id: _detail!.id,
          orderNo: _detail!.orderNo,
          status: updatedStatus,
          totalPrice: _detail!.totalPrice,
          paymentMethod: _detail!.paymentMethod,
          paymentMethodName: _detail!.paymentMethodName,
          paymentRef: _detail!.paymentRef,
          fullName: _detail!.fullName,
          phone: _detail!.phone,
          address: _detail!.address,
          city: _detail!.city,
          state: _detail!.state,
          pincode: _detail!.pincode,
          country: _detail!.country,
          note: _detail!.note,
          items: _detail!.items,
          createdAt: _detail!.createdAt,
          updatedAt: _detail!.updatedAt,
          sellerPaymentStatus: _detail!.sellerPaymentStatus,
        );
        _updatingOrderStatus = false;
      });

      widget.onStatusUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order status updated to ${updatedStatus.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1B8F3A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updatingOrderStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString().replaceAll('Exception:', '').trim()}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const OrderDetailShimmer();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final order = _detail!;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNo,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              _copyToClipboard(order.orderNo, 'Order Number'),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              widget.statusBadge(order.status),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'UPDATE ORDER STATUS',
            icon: Icons.local_shipping_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Order State:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_updatingOrderStatus)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1B8F3A),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['pending', 'shipped', 'completed', 'cancelled']
                      .map((status) {
                        final isSelected = order.status.toLowerCase() == status;
                        Color activeColor = Colors.grey.shade700;
                        if (status == 'completed')
                          activeColor = const Color(0xFF1B8F3A);
                        if (status == 'pending')
                          activeColor = Colors.orange.shade800;
                        if (status == 'shipped')
                          activeColor = Colors.blue.shade700;
                        if (status == 'cancelled')
                          activeColor = Colors.red.shade800;

                        return InkWell(
                          onTap: _updatingOrderStatus
                              ? null
                              : () => _updateOrderStatus(status),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withOpacity(0.12)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? activeColor
                                    : Colors.grey.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 12,
                                    color: activeColor,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? activeColor
                                        : Colors.grey.shade600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'ORDER ITEMS BREAKDOWN',
            icon: Icons.receipt_long_rounded,
            child: Column(
              children: [
                ...order.items.map((item) => _buildDetailItemRow(item)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE8F5E9),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '₹${order.totalPrice}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: widget.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _sectionCard(
            title: 'CUSTOMER & DELIVERY DETAILS',
            icon: Icons.local_shipping_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  Icons.person_rounded,
                  'Buyer Name',
                  order.fullName,
                  isCopyable: true,
                ),
                _infoRow(
                  Icons.phone_rounded,
                  'Buyer Phone',
                  order.phone,
                  isCopyable: true,
                ),
                _infoRow(
                  Icons.location_on_rounded,
                  'Delivery Address',
                  '${order.address}, ${order.city}, ${order.state} - ${order.pincode}, ${order.country}',
                  isCopyable: true,
                ),
                if (order.note != null && order.note!.isNotEmpty)
                  _infoRow(
                    Icons.sticky_note_2_rounded,
                    'Instructions / Note',
                    order.note!,
                  ),
              ],
            ),
          ),
          _sectionCard(
            title: 'PAYMENT & PAYOUT DETAIL',
            icon: Icons.payment_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  Icons.account_balance_wallet_rounded,
                  'Method',
                  order.paymentMethodName,
                ),
                if (order.paymentRef != null && order.paymentRef!.isNotEmpty)
                  _infoRow(
                    Icons.tag_rounded,
                    'Payment Ref ID',
                    order.paymentRef!,
                    isCopyable: true,
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.lightGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.monetization_on_rounded,
                        color: widget.primaryGreen,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payout Status',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          widget.sellerPaymentStatusBadge(
                            order.sellerPaymentStatus ?? 'PENDING',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _infoRow(
                  Icons.calendar_today_rounded,
                  'Placed At',
                  widget.formatDateTime(order.createdAt),
                ),
                _infoRow(
                  Icons.update_rounded,
                  'Last Updated',
                  widget.formatDateTime(order.updatedAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade50.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: widget.primaryGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: widget.primaryGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailItemRow(OrderItemModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: widget.lightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.product.image != null
                  ? Image.network(
                      item.product.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.shopping_basket_rounded,
                        color: widget.primaryGreen,
                        size: 24,
                      ),
                    )
                  : Icon(
                      Icons.shopping_basket_rounded,
                      color: widget.primaryGreen,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.product.categoryName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: widget.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${item.price}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Qty: ${item.quantityDisplay}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool isCopyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: widget.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: widget.primaryGreen, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isCopyable)
                      GestureDetector(
                        onTap: () => _copyToClipboard(value, label),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopBankDetailsBottomSheet extends StatefulWidget {
  final ApiService apiService;
  final Color primaryGreen;
  final Color lightGreen;
  final Color background;

  const _ShopBankDetailsBottomSheet({
    required this.apiService,
    required this.primaryGreen,
    required this.lightGreen,
    required this.background,
  });

  @override
  State<_ShopBankDetailsBottomSheet> createState() =>
      _ShopBankDetailsBottomSheetState();
}

class _ShopBankDetailsBottomSheetState
    extends State<_ShopBankDetailsBottomSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _bankDetails;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _holderController = TextEditingController();
  final TextEditingController _bankController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchBankDetails();
  }

  @override
  void dispose() {
    _holderController.dispose();
    _bankController.dispose();
    _branchController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _fetchBankDetails() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final details = await widget.apiService.getSellerBankDetails();
      setState(() {
        _bankDetails = details;
        if (details != null) {
          _holderController.text = details['account_holder_name'] ?? '';
          _bankController.text = details['bank_name'] ?? '';
          _branchController.text = details['branch_name'] ?? '';
          _accountController.text = details['account_number'] ?? '';
          _ifscController.text = details['ifsc_code'] ?? '';
          _upiController.text = details['upi_id'] ?? '';
        } else {
          _holderController.clear();
          _bankController.clear();
          _branchController.clear();
          _accountController.clear();
          _ifscController.clear();
          _upiController.clear();
        }
        _isEditing = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar("Error fetching bank details: $e", isError: true);
    }
  }

  Future<void> _saveBankDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_bankDetails != null && _bankDetails!['id'] != null) {
        final id = _bankDetails!['id'];
        await widget.apiService.updateSellerBankDetails(
          id: id,
          accountHolderName: _holderController.text.trim(),
          bankName: _bankController.text.trim(),
          branchName: _branchController.text.trim(),
          accountNumber: _accountController.text.trim(),
          ifscCode: _ifscController.text.trim().toUpperCase(),
          upiId: _upiController.text.trim(),
        );
        _showSnackBar("Bank details updated successfully!");
      } else {
        await widget.apiService.addSellerBankDetails(
          accountHolderName: _holderController.text.trim(),
          bankName: _bankController.text.trim(),
          branchName: _branchController.text.trim(),
          accountNumber: _accountController.text.trim(),
          ifscCode: _ifscController.text.trim().toUpperCase(),
          upiId: _upiController.text.trim(),
        );
        _showSnackBar("Bank details added successfully!");
      }
      await _fetchBankDetails();
    } catch (e) {
      _showSnackBar("Failed to save details: $e", isError: true);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteBankDetails() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Bank Details"),
        content: const Text(
          "Are you sure you want to delete your bank details? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final id = _bankDetails!['id'];
      await widget.apiService.deleteSellerBankDetails(id: id);
      _showSnackBar("Bank details deleted successfully!");
      await _fetchBankDetails();
    } catch (e) {
      _showSnackBar("Failed to delete details: $e", isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.redAccent : widget.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar("$label copied to clipboard!");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _bankDetails == null || _isEditing
                      ? (_bankDetails == null
                            ? "Add Bank Details"
                            : "Edit Bank Details")
                      : "Bank Account Details",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                if (_bankDetails != null && !_isEditing && !_isLoading)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade700,
                    ),
                    onPressed: _deleteBankDetails,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: widget.primaryGreen),
                ),
              )
            else if (_bankDetails != null && !_isEditing)
              _buildDetailsCard()
            else
              _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final String holder = _bankDetails!['account_holder_name'] ?? 'N/A';
    final String bank = _bankDetails!['bank_name'] ?? 'N/A';
    final String branch = _bankDetails!['branch_name'] ?? 'N/A';
    final String account = _bankDetails!['account_number'] ?? 'N/A';
    final String ifsc = _bankDetails!['ifsc_code'] ?? 'N/A';
    final String upi = _bankDetails!['upi_id'] ?? 'N/A';

    String maskedAccount = account;
    if (account.length > 4) {
      maskedAccount = '•••• •••• •••• ${account.substring(account.length - 4)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.primaryGreen, const Color(0xFF0C4D1D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.primaryGreen.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bank.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () => _copyToClipboard(account, "Account Number"),
                child: Row(
                  children: [
                    Text(
                      maskedAccount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.copy_rounded,
                      color: Colors.white54,
                      size: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ACCOUNT HOLDER",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          holder.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "IFSC CODE",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ifsc.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoDetailRow(Icons.warehouse_rounded, "Branch", branch),
                const Divider(height: 20, thickness: 0.5),
                _buildInfoDetailRow(
                  Icons.send_to_mobile_rounded,
                  "UPI ID for Payouts",
                  upi,
                  isCopyable: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text(
                  "Edit Details",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: widget.primaryGreen, width: 1.5),
                  foregroundColor: widget.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isCopyable = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.lightGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: widget.primaryGreen, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (isCopyable && value != 'N/A')
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              color: Colors.grey.shade400,
              size: 18,
            ),
            onPressed: () => _copyToClipboard(value, label),
          ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _holderController,
            label: "Account Holder Name",
            icon: Icons.person_outline_rounded,
            validator: (val) =>
                val == null || val.trim().isEmpty ? "Name is required" : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _bankController,
                  label: "Bank Name",
                  icon: Icons.account_balance_outlined,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? "Bank name is required"
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _branchController,
                  label: "Branch Name",
                  icon: Icons.warehouse_outlined,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? "Branch is required"
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _accountController,
            label: "Account Number",
            icon: Icons.numbers_rounded,
            keyboardType: TextInputType.number,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return "Account number is required";
              }
              if (val.trim().length < 8 || val.trim().length > 20) {
                return "Enter a valid account number";
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _ifscController,
                  label: "IFSC Code",
                  icon: Icons.code_rounded,
                  textCapitalization: TextCapitalization.characters,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "IFSC code is required";
                    }
                    final regExp = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                    if (!regExp.hasMatch(val.trim().toUpperCase())) {
                      return "Format: ABCD0123456";
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _upiController,
                  label: "UPI ID for Payouts",
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "UPI ID is required";
                    }
                    if (!val.contains('@')) {
                      return "Enter a valid UPI ID";
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_bankDetails != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBankDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _bankDetails == null
                              ? "Save Details"
                              : "Update Details",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: widget.primaryGreen, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.redAccent,
        ),
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0, (sum, item) => sum + item);
    if (total == 0) {
      final Paint paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14;
      canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 10, paint);
      return;
    }

    final int nonZeroSlices = values.where((v) => v > 0).length;
    double startAngle = -3.1415926535 / 2; // Start from top
    final double radius = size.width / 2;
    final Rect rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius - 10);

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final double sweepAngle = (values[i] / total) * 2 * 3.1415926535;

      final Paint paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      final double adjustSweep = nonZeroSlices > 1 ? sweepAngle - 0.12 : sweepAngle;
      canvas.drawArc(rect, startAngle + (nonZeroSlices > 1 ? 0.06 : 0), adjustSweep, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
