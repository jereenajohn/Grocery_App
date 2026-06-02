import 'dart:async';
import 'package:flutter/material.dart';
import 'package:grocery_app/models/banner_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/address_model.dart';
import '../../models/category_model.dart';
import '../../models/shop_model.dart';
import '../../services/api_service.dart';
import '../address_page.dart';
import '../request_otp_page.dart';
import 'category_shops_page.dart';
import 'shop_products_page.dart';
import 'cart_page.dart';
import 'all_shops_page.dart';

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
  List<CategoryModel> _categories = [];
  bool _categoriesLoading = true;

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
    _loadShops();
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
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _loadShops({String? search}) async {
    setState(() => _shopsLoading = true);
    try {
      final shops = await _apiService.getShops(search: search);
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
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressPage()),
                );
                _loadAddresses();
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
                          ? 'Deliver to: ${_primaryAddress!.city}, ${_primaryAddress!.stateName}'
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryGreen,
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
          SizedBox(
            height: 104,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        height: 10,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
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
                          child: Icon(
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
      return Container(
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        height: 148,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
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
                'Nearby Shops',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              if (_shopsLoading)
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryGreen,
                  ),
                )
              else
                Text(
                  '${_shops.length} shops',
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        if (_shopsLoading)
          Container(
            height: 160,
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: primaryGreen),
          )
        else if (_shops.isEmpty)
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
                  'No shops available nearby',
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
              itemCount: _shops.length,
              itemBuilder: (context, index) {
                final shop = _shops[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopProductsPage(shop: shop),
                      ),
                    );
                  },
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
                                          color: Colors.white.withOpacity(0.9),
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
                                    '4.5 • 25-30 mins',
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

  Widget _buildBottomNavBar() {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.storefront_rounded, 'label': 'Shops'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
      {'icon': Icons.logout_rounded, 'label': 'Logout'},
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
                  _showSettingsBottomSheet();
                  return;
                }
                if (index == 3) {
                  _logout();
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
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    Widget bodyWidget;
    if (_activeNavIndex == 1) {
      bodyWidget = const AllShopsPage();
    } else {
      bodyWidget = SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildPromoBanner(),
              _buildCategories(),
              _buildShops(),
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
