import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grocery_app/models/country_model.dart';
import 'package:grocery_app/models/state_model.dart';
import 'package:grocery_app/models/district_model.dart';
import '../widgets/shimmer_loading.dart';
import 'package:grocery_app/models/banner_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/address_model.dart';
import '../../models/category_model.dart';
import '../../models/shop_model.dart';
import '../../services/api_service.dart';
import '../address_page.dart';
import '../request_otp_page.dart';
import 'map_address_picker_page.dart';
import 'category_shops_page.dart';
import 'shop_products_page.dart';
import 'cart_page.dart';
import 'all_shops_page.dart';
import 'orders_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  int _activeNavIndex = 0;
  AddressModel? _primaryAddress;
  List<ShopModel> _shops = [];
  bool _shopsLoading = true;
  List<ShopModel> _topRatedShops = [];
  bool _topRatedShopsLoading = true;
  List<CategoryModel> _categories = [];
  bool _categoriesLoading = true;
  double _selectedRadius = 10.0;

  List<BannerModel> _banners = [];
  bool _bannersLoading = true;

  final PageController _promoPageController = PageController();
  Timer? _promoTimer;
  Timer? _searchDebounceTimer;
  int _currentPromoPage = 0;

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color goldAccent = const Color(0xFFFFB300);
  final Color background = const Color(0xFFF7FFF9);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAddresses();
    _initializeShopsAndRadius();
    _loadCategories();
    _startPromoAutoScroll();
    _loadBanners();
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _promoPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPromoAutoScroll() {
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_banners.isEmpty) return;
      final nextPage = (_currentPromoPage + 1) % _banners.length;
      _promoPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _apiService.getSavedUserData();
      setState(() {
        _userData = data;
        _isLoading = false;
      });

      // Pull latest profile from server
      await _apiService.getProfile();
      final updatedData = await _apiService.getSavedUserData();
      if (mounted) {
        setState(() {
          _userData = updatedData;
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

  Future<void> _loadAddresses() async {
    try {
      final addresses = await _apiService.getAddresses();
      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getInt('selected_address_id');
      setState(() {
        if (addresses.isEmpty) {
          _primaryAddress = null;
        } else if (selectedId != null) {
          try {
            _primaryAddress = addresses.firstWhere((a) => a.id == selectedId);
          } catch (_) {
            _primaryAddress = addresses.first;
          }
        } else {
          _primaryAddress = addresses.first;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadBanners() async {
    setState(() => _bannersLoading = true);

    try {
      final banners = await _apiService.getBanners();

      setState(() {
        _banners = banners;
        _bannersLoading = false;
      });
    } catch (e) {
      setState(() => _bannersLoading = false);
    }
  }

  Future<void> _loadRadiusFilter() async {
    try {
      final radius = await _apiService.getRadiusFilter();
      if (mounted) {
        setState(() {
          _selectedRadius = radius;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTopRatedShops() async {
    setState(() => _topRatedShopsLoading = true);
    try {
      final shops = await _apiService.getTopRatedShops();
      setState(() {
        _topRatedShops = shops;
        _topRatedShopsLoading = false;
      });
    } catch (_) {
      setState(() => _topRatedShopsLoading = false);
    }
  }

  Future<void> _initializeShopsAndRadius() async {
    await _loadRadiusFilter();
    await _loadShops();
    await _loadTopRatedShops();
  }

  Future<void> _loadShops({String? search}) async {
    setState(() => _shopsLoading = true);
    try {
      final shops = await _apiService.getShops(search: search, radius: _selectedRadius);
      setState(() {
        _shops = shops;
        _shopsLoading = false;
      });
    } catch (_) {
      setState(() => _shopsLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final result = await _apiService.getCategories();
      final List<CategoryModel> cats = List<CategoryModel>.from(
        result['results'] ?? [],
      );
      setState(() {
        _categories = cats;
        _categoriesLoading = false;
      });
    } catch (_) {
      setState(() => _categoriesLoading = false);
    }
  }

  Map<String, dynamic> _getCategoryVisuals(String name) {
    final lower = name.toLowerCase();
    final Map<String, Map<String, dynamic>> mapping = {
      'fruit': {
        'icon': Icons.apple,
        'color': const Color(0xFFFFEBEE),
        'iconColor': const Color(0xFFEF5350),
      },
      'vegetable': {
        'icon': Icons.eco_rounded,
        'color': const Color(0xFFE8F5E9),
        'iconColor': const Color(0xFF4CAF50),
      },
      'veggie': {
        'icon': Icons.eco_rounded,
        'color': const Color(0xFFE8F5E9),
        'iconColor': const Color(0xFF4CAF50),
      },
      'dairy': {
        'icon': Icons.egg_alt_rounded,
        'color': const Color(0xFFFFF8E1),
        'iconColor': const Color(0xFFFFB300),
      },
      'milk': {
        'icon': Icons.egg_alt_rounded,
        'color': const Color(0xFFFFF8E1),
        'iconColor': const Color(0xFFFFB300),
      },
      'ice cream': {
        'icon': Icons.icecream,
        'color': const Color(0xFFFFF8E1),
        'iconColor': const Color(0xFFFFB300),
      },
      'bakery': {
        'icon': Icons.cookie_rounded,
        'color': const Color(0xFFEFEBE9),
        'iconColor': const Color(0xFF8D6E63),
      },
      'biscuit': {
        'icon': Icons.cookie_rounded,
        'color': const Color(0xFFEFEBE9),
        'iconColor': const Color(0xFF8D6E63),
      },
      'bread': {
        'icon': Icons.cookie_rounded,
        'color': const Color(0xFFEFEBE9),
        'iconColor': const Color(0xFF8D6E63),
      },
      'meat': {
        'icon': Icons.restaurant_rounded,
        'color': const Color(0xFFFBE9E7),
        'iconColor': const Color(0xFFFF5722),
      },
      'chicken': {
        'icon': Icons.restaurant_rounded,
        'color': const Color(0xFFFBE9E7),
        'iconColor': const Color(0xFFFF5722),
      },
      'fish': {
        'icon': Icons.set_meal_rounded,
        'color': const Color(0xFFE0F2F1),
        'iconColor': const Color(0xFF00897B),
      },
      'seafood': {
        'icon': Icons.set_meal_rounded,
        'color': const Color(0xFFE0F2F1),
        'iconColor': const Color(0xFF00897B),
      },
      'drink': {
        'icon': Icons.local_drink_rounded,
        'color': const Color(0xFFE0F7FA),
        'iconColor': const Color(0xFF00BCD4),
      },
      'beverage': {
        'icon': Icons.local_drink_rounded,
        'color': const Color(0xFFE0F7FA),
        'iconColor': const Color(0xFF00BCD4),
      },
      'juice': {
        'icon': Icons.local_drink_rounded,
        'color': const Color(0xFFE0F7FA),
        'iconColor': const Color(0xFF00BCD4),
      },
      'snack': {
        'icon': Icons.fastfood_rounded,
        'color': const Color(0xFFFFF3E0),
        'iconColor': const Color(0xFFFF9800),
      },
      'frozen': {
        'icon': Icons.ac_unit_rounded,
        'color': const Color(0xFFE3F2FD),
        'iconColor': const Color(0xFF2196F3),
      },
      'spice': {
        'icon': Icons.grass_rounded,
        'color': const Color(0xFFFFF8E1),
        'iconColor': const Color(0xFFFF8F00),
      },
      'grain': {
        'icon': Icons.grain_rounded,
        'color': const Color(0xFFF3E5F5),
        'iconColor': const Color(0xFF9C27B0),
      },
      'rice': {
        'icon': Icons.grain_rounded,
        'color': const Color(0xFFF3E5F5),
        'iconColor': const Color(0xFF9C27B0),
      },
      'cereal': {
        'icon': Icons.grain_rounded,
        'color': const Color(0xFFF3E5F5),
        'iconColor': const Color(0xFF9C27B0),
      },
      'organic': {
        'icon': Icons.spa_rounded,
        'color': const Color(0xFFE8F5E9),
        'iconColor': const Color(0xFF388E3C),
      },
      'cleaning': {
        'icon': Icons.cleaning_services_rounded,
        'color': const Color(0xFFE8EAF6),
        'iconColor': const Color(0xFF3F51B5),
      },
      'personal': {
        'icon': Icons.person_rounded,
        'color': const Color(0xFFFCE4EC),
        'iconColor': const Color(0xFFE91E63),
      },
      'baby': {
        'icon': Icons.child_care_rounded,
        'color': const Color(0xFFF3E5F5),
        'iconColor': const Color(0xFFAB47BC),
      },
      'pet': {
        'icon': Icons.pets_rounded,
        'color': const Color(0xFFE8F5E9),
        'iconColor': const Color(0xFF66BB6A),
      },
    };

    for (final key in mapping.keys) {
      if (lower.contains(key)) return mapping[key]!;
    }

    // Default visuals for unknown categories
    return {
      'icon': Icons.category_rounded,
      'color': const Color(0xFFF5F5F5),
      'iconColor': const Color(0xFF78909C),
    };
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
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
        content: const Text('Are you sure you want to log out?'),
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
    final String firstName = _userData['first_name'] ?? 'Guest';
    final String lastName = _userData['last_name'] ?? '';
    final String fullName = '$firstName $lastName'.trim();
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                              Icons.person_rounded,
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
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartPage()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapAddressPickerPage(
                      existingAddress: _primaryAddress,
                    ),
                  ),
                );
                if (result == true) {
                  _loadAddresses();
                }
              },
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _primaryAddress != null
                          ? 'Deliver to: ${_primaryAddress!.address}, ${_primaryAddress!.city}'
                          : 'Tap to add a delivery address',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.green.shade50),
              ),
              child: TextField(
                onChanged: (value) {
                  _searchDebounceTimer?.cancel();
                  _searchDebounceTimer = Timer(
                    const Duration(milliseconds: 500),
                    () {
                      _loadShops(search: value.trim());
                    },
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Search fresh foods, veggies...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: primaryGreen),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusSlider() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.radar_rounded, color: primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Search Radius',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selectedRadius.toStringAsFixed(0)} km',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '5 km',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primaryGreen,
                    inactiveTrackColor: Colors.grey.shade100,
                    trackHeight: 4.0,
                    thumbColor: primaryGreen,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayColor: primaryGreen.withOpacity(0.12),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                  ),
                  child: Slider(
                    value: _selectedRadius,
                    min: 5.0,
                    max: 20.0,
                    divisions: 15,
                    onChanged: (value) {
                      setState(() {
                        _selectedRadius = value;
                      });
                    },
                    onChangeEnd: (value) async {
                      try {
                        await _apiService.updateRadiusFilter(value);
                        _loadShops();
                      } catch (_) {}
                    },
                  ),
                ),
              ),
              Text(
                '20 km',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Explore Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              if (_categoriesLoading)
                SizedBox(
                  height: 16,
                  width: 16,
                  child: ShimmerEffect(
                    child: ShimmerBox(width: 50, height: 14, borderRadius: 6),
                  ),
                )
              else
                Text(
                  'See All',
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        if (_categoriesLoading)
          const CategoryShimmer()
        else if (_categories.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade50),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  color: Colors.grey.shade400,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Text(
                  'No categories available',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final visuals = _getCategoryVisuals(cat.name);
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryShopsPage(category: cat),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            color: visuals['color'],
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (visuals['iconColor'] as Color)
                                    .withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: cat.image != null && cat.image!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    cat.image!,
                                    fit: BoxFit.cover,
                                    width: 64,
                                    height: 64,
                                    errorBuilder: (ctx, err, stack) => Icon(
                                      visuals['icon'],
                                      color: visuals['iconColor'],
                                      size: 28,
                                    ),
                                  ),
                                )
                              : Icon(
                                  visuals['icon'],
                                  color: visuals['iconColor'],
                                  size: 28,
                                ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPromoBanner() {
    if (_bannersLoading) {
      return const BannerShimmer();
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          height: 148,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: PageView.builder(
              controller: _promoPageController,
              itemCount: _banners.length,
              onPageChanged: (index) {
                setState(() => _currentPromoPage = index);
              },
              itemBuilder: (context, index) {
                final banner = _banners[index];

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      banner.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: lightGreen,
                          child: Icon(
                            Icons.image_not_supported_rounded,
                            color: primaryGreen,
                            size: 45,
                          ),
                        );
                      },
                    ),

                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.50),
                            Colors.black.withOpacity(0.10),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),

                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.shopping_basket_rounded,
                        size: 160,
                        color: Colors.white.withOpacity(0.10),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            banner.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          Text(
                            banner.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _currentPromoPage == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _currentPromoPage == index
                    ? primaryGreen
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildShops() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Rated Shops',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              if (_topRatedShopsLoading)
                SizedBox(
                  height: 16,
                  width: 16,
                  child: ShimmerEffect(
                    child: ShimmerBox(width: 60, height: 14, borderRadius: 6),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllShopsPage(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: primaryGreen,
                        size: 11,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_topRatedShopsLoading)
          const ShopsListShimmer(itemCount: 2)
        else if (_topRatedShops.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade50),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  color: Colors.grey.shade400,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Text(
                  'No top rated shops available',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _topRatedShops.length > 6 ? 7 : (_topRatedShops.isEmpty ? 0 : _topRatedShops.length + 1),
              itemBuilder: (context, index) {
                final showViewAll = (_topRatedShops.length > 6 && index == 6) || (_topRatedShops.length <= 6 && index == _topRatedShops.length);

                if (showViewAll) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllShopsPage(),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 110,
                          width: 150,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.shade50),
                            boxShadow: [
                              BoxShadow(
                                color: primaryGreen.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: lightGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: primaryGreen,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'View All',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: darkGreen,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _topRatedShops.length > 6
                                    ? '${_topRatedShops.length - 6} more shops'
                                    : 'Explore all',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final shop = _topRatedShops[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopProductsPage(shop: shop),
                      ),
                    );
                  },
                  child: Opacity(
                    opacity: shop.isOpen ? 1.0 : 0.65,
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover Image Block
                          Container(
                            height: 110,
                            width: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: lightGreen,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: shop.productImage != null
                                      ? Image.network(
                                          shop.productImage!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  _buildCardPlaceholder(),
                                        )
                                      : _buildCardPlaceholder(),
                                ),
                                if (!shop.isOpen)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.85),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.0,
                                            ),
                                          ),
                                          child: const Text(
                                            'CLOSED',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Bottom Gradient Overlay
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.05),
                                            Colors.black.withOpacity(0.85),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Favorite Heart Icon
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.favorite_border_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                // Price Tag Overlay
                                if (shop.productPrice != null)
                                  Positioned(
                                    bottom: 8,
                                    left: 10,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'ITEMS',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          'AT ₹${shop.productPrice!.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Shop details below the image
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shop.shop_name,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF1B8F3A),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      shop.avgRating?.toStringAsFixed(1) ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Grocery • ${shop.districtName}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
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
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCardPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lightGreen, primaryGreen.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          color: primaryGreen.withOpacity(0.4),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildVerticalShopCard(ShopModel shop) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ShopProductsPage(shop: shop)),
        );
      },
      child: Opacity(
        opacity: shop.isOpen ? 1.0 : 0.65,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.green.shade50.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image Block
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: shop.productImage != null
                          ? Image.network(
                              shop.productImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildCardPlaceholder(),
                            )
                          : _buildCardPlaceholder(),
                    ),
                    if (!shop.isOpen)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'CLOSED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Bottom Gradient Overlay
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.85),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Price Tag Overlay
                    if (shop.productPrice != null)
                      Positioned(
                        bottom: 10,
                        left: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ITEMS',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'AT ₹${shop.productPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Shop details below Cover Image
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.shop_name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E1E1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1B8F3A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                shop.avgRating?.toStringAsFixed(1) ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Grocery • ${shop.districtName}, ${shop.stateName}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 10),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: primaryGreen,
                          size: 15,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalAllShops() {
    if (_shopsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ShopsListShimmer(itemCount: 2),
      );
    }

    if (_shops.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 4, 12),
            child: Text(
              'All Shops',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          ..._shops.map((shop) => _buildVerticalShopCard(shop)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.storefront_rounded, 'label': 'Shops'},
      {'icon': Icons.shopping_bag_rounded, 'label': 'Orders'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
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
              onTap: () async {
                if (index == 0) {
                  setState(() {
                    _activeNavIndex = index;
                  });
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                  return;
                }
                if (index == 1) {
                  setState(() {
                    _activeNavIndex = index;
                  });
                  return;
                }

                if (index == 2) {
                  setState(() {
                    _activeNavIndex = index;
                  });
                  return;
                }
                if (index == 3) {
                  _showSettingsBottomSheet();
                  return;
                }
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

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                      Icons.settings_rounded,
                      color: primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.green.shade50),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: lightGreen,
                      child: Text(
                        _userData['first_name'] != null &&
                                _userData['first_name'].toString().isNotEmpty
                            ? _userData['first_name']
                                  .toString()[0]
                                  .toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_userData['first_name'] ?? ''} ${_userData['last_name'] ?? ''}'
                                .trim(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _userData['email'] ?? 'No email set',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _userData['phone'] ?? 'No phone set',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingsActionTile(
                icon: Icons.location_on_rounded,
                title: 'Manage Addresses',
                subtitle: 'Add or update your delivery points',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressPage()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsActionTile(
                icon: Icons.person_outline_rounded,
                title: 'Edit Profile',
                subtitle: 'Update your personal details',
                onTap: () {
                  Navigator.pop(context);
                  _showEditProfileBottomSheet();
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsActionTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Sign out of your account securely',
                iconColor: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileBottomSheet() {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(text: _userData['first_name'] ?? '');
    final lastNameController = TextEditingController(text: _userData['last_name'] ?? '');
    final emailController = TextEditingController(text: _userData['email'] ?? '');
    
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
                          'Select Avatar Source',
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
                                      ? Icon(Icons.person_rounded, size: 50, color: Colors.grey.shade400)
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
                                          country: selectedCountry?.id,
                                          state: selectedState?.id,
                                          district: selectedDistrict?.id,
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

  Widget _buildSettingsActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.green.shade50.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? primaryGreen).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor ?? primaryGreen, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
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

    Widget bodyWidget;
    if (_activeNavIndex == 1) {
      bodyWidget = const AllShopsPage();
    } else if (_activeNavIndex == 2) {
      bodyWidget = const OrdersPage();
    } else {
      bodyWidget = SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildRadiusSlider(),
              _buildPromoBanner(),
              _buildCategories(),
              _buildShops(),
              _buildVerticalAllShops(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: bodyWidget,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
}
