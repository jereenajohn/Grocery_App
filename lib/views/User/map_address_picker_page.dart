import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grocery_app/models/address_model.dart';
import 'package:grocery_app/models/country_model.dart';
import 'package:grocery_app/models/state_model.dart';
import 'package:grocery_app/models/district_model.dart';
import 'package:grocery_app/services/api_service.dart';
import '../widgets/shimmer_loading.dart';

class MapAddressPickerPage extends StatefulWidget {
  final AddressModel? existingAddress;
  const MapAddressPickerPage({
    super.key,
    this.existingAddress,
  });

  @override
  State<MapAddressPickerPage> createState() => _MapAddressPickerPageState();
}

class _MapAddressPickerPageState extends State<MapAddressPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  LatLng _currentCenter = const LatLng(9.9312, 76.2673); // Default to Cochin
  bool _isMoving = false;
  bool _isGeocoding = false;
  String _geocodedAddress = "Locating...";
  Map<String, dynamic>? _rawGeocodedDetails;

  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  Timer? _reverseGeocodeDebounce;

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color background = const Color(0xFFF7FFF9);

  @override
  void initState() {
    super.initState();
    if (widget.existingAddress != null &&
        widget.existingAddress!.latitude != null &&
        widget.existingAddress!.longitude != null) {
      _currentCenter = LatLng(
        widget.existingAddress!.latitude!,
        widget.existingAddress!.longitude!,
      );
    }
    // Perform initial geocoding for the default position
    _triggerReverseGeocode(_currentCenter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _reverseGeocodeDebounce?.cancel();
    super.dispose();
  }

  // ─── SEARCH LOGIC ───────────────────────────────────────────

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1',
        );
        final response = await http.get(
          url,
          headers: {'User-Agent': 'grocery_app/1.0 (aazim@grocery_app.com)'},
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as List;
          if (mounted) {
            setState(() {
              _searchResults = decoded;
              _isSearching = false;
            });
          }
        } else {
          if (mounted) setState(() => _isSearching = false);
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat'] ?? '');
    final lon = double.tryParse(result['lon'] ?? '');
    if (lat != null && lon != null) {
      final target = LatLng(lat, lon);
      setState(() {
        _currentCenter = target;
        _searchResults = [];
        _searchController.text = result['display_name'] ?? '';
      });
      _mapController.move(target, 16.0);
      _triggerReverseGeocode(target);
      FocusScope.of(context).unfocus();
    }
  }

  // ─── REVERSE GEOCODING LOGIC ─────────────────────────────────

  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    setState(() {
      _currentCenter = position.center;
      _isMoving = true;
    });

    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _isMoving = false);
        _triggerReverseGeocode(_currentCenter);
      }
    });
  }

  Future<void> _triggerReverseGeocode(LatLng coords) async {
    setState(() {
      _isGeocoding = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${coords.latitude}&lon=${coords.longitude}&format=json&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'grocery_app/1.0 (aazim@grocery_app.com)'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final String displayName = decoded['display_name'] ?? "Unknown Location";
        if (mounted) {
          setState(() {
            _geocodedAddress = displayName;
            _rawGeocodedDetails = decoded;
            _isGeocoding = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _geocodedAddress = "Failed to fetch address";
            _isGeocoding = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _geocodedAddress = "Check network connection";
          _isGeocoding = false;
        });
      }
    }
  }

  // ─── CONFIRMATION SHEET ──────────────────────────────────────

  void _showConfirmationSheet() {
    if (_rawGeocodedDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Still fetching location details. Please wait.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _AddressConfirmSheet(
          geocodedData: _rawGeocodedDetails!,
          apiService: _apiService,
          primaryGreen: primaryGreen,
          darkGreen: darkGreen,
          lightGreen: lightGreen,
          existingAddress: widget.existingAddress,
        );
      },
    ).then((success) {
      if (success == true && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Flutter Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              onPositionChanged: _onMapPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.grocery_app',
              ),
            ],
          ),

          // Central Pin Icon with nice animation
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.translationValues(0, _isMoving ? -10 : 0, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.location_pin,
                        color: primaryGreen,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Shadow below pin when moving
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isMoving ? 10 : 20,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: _isMoving ? 4 : 2,
                            spreadRadius: _isMoving ? 1 : 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Glassmorphic Search Bar at Top
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(color: Colors.green.shade50),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: "Search location or street...",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1B8F3A),
                            ),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged("");
                          },
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(Icons.search_rounded, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                // Suggestions list view
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index] as Map<String, dynamic>;
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: lightGreen,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.place_rounded, color: primaryGreen, size: 18),
                          ),
                          title: Text(
                            result['display_name'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Details & Confirm Container
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.green.shade50),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: lightGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.location_on_rounded, color: primaryGreen, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Selected Location",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isGeocoding)
                    ShimmerEffect(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: double.infinity, height: 14, borderRadius: 6),
                          const SizedBox(height: 6),
                          ShimmerBox(width: 200, height: 14, borderRadius: 6),
                        ],
                      ),
                    )
                  else
                    Text(
                      _geocodedAddress,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isGeocoding ? null : _showConfirmationSheet,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        "Confirm Location",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primaryGreen.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ADDRESS CONFIRM BOTTOM SHEET ────────────────────────────

class _AddressConfirmSheet extends StatefulWidget {
  final Map<String, dynamic> geocodedData;
  final ApiService apiService;
  final Color primaryGreen;
  final Color darkGreen;
  final Color lightGreen;
  final AddressModel? existingAddress;

  const _AddressConfirmSheet({
    required this.geocodedData,
    required this.apiService,
    required this.primaryGreen,
    required this.darkGreen,
    required this.lightGreen,
    this.existingAddress,
  });

  @override
  State<_AddressConfirmSheet> createState() => _AddressConfirmSheetState();
}

class _AddressConfirmSheetState extends State<_AddressConfirmSheet> {
  final _formKey = GlobalKey<FormState>();

  final _addressCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();

  List<CountryModel> _countries = [];
  List<StateModel> _states = [];
  List<DistrictModel> _districts = [];

  CountryModel? _selectedCountry;
  StateModel? _selectedState;
  DistrictModel? _selectedDistrict;

  bool _isLoadingDropdowns = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillGeocodedData();
    _loadAndMatchDropdowns();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  void _prefillGeocodedData() {
    final addr = widget.geocodedData['address'] as Map<String, dynamic>? ?? {};

    // Build street address from components
    final String road = addr['road'] ?? '';
    final String suburb = addr['suburb'] ?? addr['neighbourhood'] ?? addr['village'] ?? '';
    final String city = addr['city'] ?? addr['town'] ?? addr['suburb'] ?? addr['county'] ?? addr['state_district'] ?? '';
    final String postcode = addr['postcode'] ?? '';

    List<String> addressParts = [];
    if (road.isNotEmpty) addressParts.add(road);
    if (suburb.isNotEmpty) addressParts.add(suburb);
    
    // Default street address prefill
    _addressCtrl.text = addressParts.isNotEmpty 
        ? addressParts.join(', ') 
        : (widget.geocodedData['display_name'] ?? '');

    _cityCtrl.text = city;
    _postalCtrl.text = postcode;
  }

  String _cleanString(String s) {
    return s.toLowerCase()
        .replaceAll('state', '')
        .replaceAll('district', '')
        .replaceAll('province', '')
        .replaceAll('territory', '')
        .replaceAll(' ', '')
        .trim();
  }

  Future<void> _loadAndMatchDropdowns() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final addr = widget.geocodedData['address'] as Map<String, dynamic>? ?? {};
      final String geoCountryName = addr['country'] ?? '';
      final String geoStateName = addr['state'] ?? '';
      final String geoDistrictName = addr['district'] ?? addr['county'] ?? addr['state_district'] ?? '';

      // 1. Load Countries
      final countriesData = await widget.apiService.getCountries();
      final countries = (countriesData['results'] as List<CountryModel>);
      setState(() => _countries = countries);

      // Attempt matching country
      for (var c in _countries) {
        if (_cleanString(c.name) == _cleanString(geoCountryName) ||
            _cleanString(geoCountryName).contains(_cleanString(c.name)) ||
            _cleanString(c.name).contains(_cleanString(geoCountryName))) {
          _selectedCountry = c;
          break;
        }
      }

      // 2. Load States (if Country matched)
      if (_selectedCountry != null) {
        final states = await widget.apiService.getStatesByCountry(countryId: _selectedCountry!.id);
        setState(() => _states = states);

        // Attempt matching state
        for (var s in _states) {
          if (_cleanString(s.name) == _cleanString(geoStateName) ||
              _cleanString(geoStateName).contains(_cleanString(s.name)) ||
              _cleanString(s.name).contains(_cleanString(geoStateName))) {
            _selectedState = s;
            break;
          }
        }
      }

      // 3. Load Districts (if State matched)
      if (_selectedState != null) {
        final districts = await widget.apiService.getDistrictsByState(stateId: _selectedState!.id);
        setState(() => _districts = districts);

        // Attempt matching district
        for (var d in _districts) {
          if (_cleanString(d.name) == _cleanString(geoDistrictName) ||
              _cleanString(geoDistrictName).contains(_cleanString(d.name)) ||
              _cleanString(d.name).contains(_cleanString(geoDistrictName))) {
            _selectedDistrict = d;
            break;
          }
        }
      }

      // 4. Fallback to existing address if matching failed
      if (widget.existingAddress != null) {
        if (_selectedCountry == null) {
          try {
            _selectedCountry = _countries.firstWhere((c) => c.id == widget.existingAddress!.country);
          } catch (_) {}
        }

        if (_selectedCountry != null && _states.isEmpty) {
          final states = await widget.apiService.getStatesByCountry(countryId: _selectedCountry!.id);
          setState(() => _states = states);
        }

        if (_selectedState == null && _selectedCountry != null) {
          try {
            _selectedState = _states.firstWhere((s) => s.id == widget.existingAddress!.state);
          } catch (_) {}
        }

        if (_selectedState != null && _districts.isEmpty) {
          final districts = await widget.apiService.getDistrictsByState(stateId: _selectedState!.id);
          setState(() => _districts = districts);
        }

        if (_selectedDistrict == null && _selectedState != null) {
          try {
            _selectedDistrict = _districts.firstWhere((d) => d.id == widget.existingAddress!.district);
          } catch (_) {}
        }
      }
    } catch (_) {}
    setState(() => _isLoadingDropdowns = false);
  }

  Future<void> _onCountryChanged(CountryModel? country) async {
    setState(() {
      _selectedCountry = country;
      _selectedState = null;
      _selectedDistrict = null;
      _states = [];
      _districts = [];
    });
    if (country == null) return;
    try {
      final states = await widget.apiService.getStatesByCountry(countryId: country.id);
      setState(() => _states = states);
    } catch (_) {}
  }

  Future<void> _onStateChanged(StateModel? state) async {
    setState(() {
      _selectedState = state;
      _selectedDistrict = null;
      _districts = [];
    });
    if (state == null) return;
    try {
      final districts = await widget.apiService.getDistrictsByState(stateId: state.id);
      setState(() => _districts = districts);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountry == null || _selectedState == null || _selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select country, state and district'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final latVal = widget.geocodedData['lat'];
      final lonVal = widget.geocodedData['lon'];
      final double? latitude = latVal != null ? double.tryParse(latVal.toString()) : null;
      final double? longitude = lonVal != null ? double.tryParse(lonVal.toString()) : null;

      AddressModel newAddr;
      if (widget.existingAddress != null) {
        newAddr = await widget.apiService.updateAddress(
          addressId: widget.existingAddress!.id,
          address: _addressCtrl.text.trim(),
          landmark: _landmarkCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          country: _selectedCountry!.id,
          state: _selectedState!.id,
          district: _selectedDistrict!.id,
          postalCode: _postalCtrl.text.trim(),
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        newAddr = await widget.apiService.addAddress(
          address: _addressCtrl.text.trim(),
          landmark: _landmarkCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          country: _selectedCountry!.id,
          state: _selectedState!.id,
          district: _selectedDistrict!.id,
          postalCode: _postalCtrl.text.trim(),
          latitude: latitude,
          longitude: longitude,
        );
      }

      // Select this address as the active primary address
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_address_id', newAddr.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Address saved & set to active: ${newAddr.city}'),
            backgroundColor: widget.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: widget.darkGreen,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: widget.primaryGreen, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: widget.primaryGreen, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?) onChanged,
    bool enabled = true,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: widget.primaryGreen),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13),
        prefixIcon: Icon(icon, color: widget.primaryGreen, size: 20),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: widget.primaryGreen, width: 1.6),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(displayText(item)),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7FFF9),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Form(
              key: _formKey,
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
                  const Text(
                    "Verify Address Details",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "We matched geocoded coordinates to these values. Please check and correct them if needed.",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                  ),
                  const SizedBox(height: 20),

                  if (_isLoadingDropdowns)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1B8F3A),
                        ),
                      ),
                    )
                  else ...[
                    _sectionLabel('Delivery Details'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressCtrl,
                      label: 'Street Address',
                      hint: 'e.g. 123 Main Street, Apt 4B',
                      icon: Icons.home_rounded,
                      maxLines: 2,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _landmarkCtrl,
                      label: 'Landmark (optional)',
                      hint: 'e.g. Near Central Park',
                      icon: Icons.place_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _cityCtrl,
                      label: 'City',
                      hint: 'e.g. Springfield',
                      icon: Icons.location_city_rounded,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'City is required' : null,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _postalCtrl,
                      label: 'Postal Code',
                      hint: 'e.g. 12345',
                      icon: Icons.local_post_office_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Postal code is required' : null,
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel('Location Relationships'),
                    const SizedBox(height: 12),
                    
                    _buildDropdown<CountryModel>(
                      label: 'Country',
                      icon: Icons.flag_rounded,
                      value: _selectedCountry,
                      items: _countries,
                      displayText: (c) => c.name,
                      onChanged: _onCountryChanged,
                      validator: (v) => v == null ? 'Select a country' : null,
                    ),
                    const SizedBox(height: 14),
                    
                    _buildDropdown<StateModel>(
                      label: 'State',
                      icon: Icons.map_rounded,
                      value: _selectedState,
                      items: _states,
                      displayText: (s) => s.name,
                      onChanged: _onStateChanged,
                      enabled: _selectedCountry != null,
                      validator: (v) => v == null ? 'Select a state' : null,
                    ),
                    const SizedBox(height: 14),
                    
                    _buildDropdown<DistrictModel>(
                      label: 'District',
                      icon: Icons.grain_rounded,
                      value: _selectedDistrict,
                      items: _districts,
                      displayText: (d) => d.name,
                      onChanged: (d) => setState(() => _selectedDistrict = d),
                      enabled: _selectedState != null,
                      validator: (v) => v == null ? 'Select a district' : null,
                    ),
                    const SizedBox(height: 30),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_location_alt_rounded),
                        label: const Text(
                          'Save & Deliver Here',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primaryGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: widget.primaryGreen.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
