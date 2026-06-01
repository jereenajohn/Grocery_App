import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/country_model.dart';
import '../../models/state_model.dart';
import '../../models/district_model.dart';
import '../../services/api_service.dart';
import '../User/user_home_page.dart';
import '../Shop/shop_home_page.dart';
import 'admin_home_page.dart';


class RegisterPage extends StatefulWidget {
  final String? verifiedPhone;

  const RegisterPage({super.key, this.verifiedPhone});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  XFile? selectedXFile;
  Uint8List? selectedImageBytes;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String selectedUserType = 'user';

  int? selectedCountryId;
  int? selectedStateId;
  int? selectedDistrictId;

  double? selectedLatitude;
  double? selectedLongitude;

  List<CountryModel> countries = [];
  List<StateModel> states = [];
  List<DistrictModel> districts = [];

  bool isLoadingCountries = false;
  bool isLoadingStates = false;
  bool isLoadingDistricts = false;

  bool obscurePassword = true;

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color darkGreen = const Color(0xFF0F5F28);

  @override
  void initState() {
    super.initState();

    if (widget.verifiedPhone != null && widget.verifiedPhone!.isNotEmpty) {
      phoneController.text = widget.verifiedPhone!;
    }
    fetchCountries();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> fetchCountries() async {
    setState(() => isLoadingCountries = true);
    try {
      final response = await _apiService.getCountries();
      if (!mounted) return;
      setState(() {
        countries = response['results'] as List<CountryModel>;
        isLoadingCountries = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingCountries = false);
      showSnackBar(
        e.toString().replaceAll('Exception:', '').trim(),
        Colors.red,
      );
    }
  }

  Future<void> fetchStates(int countryId) async {
    setState(() {
      isLoadingStates = true;
      states = [];
      selectedStateId = null;
      districts = [];
      selectedDistrictId = null;
    });
    try {
      final response = await _apiService.getStatesByCountry(
        countryId: countryId,
      );
      if (!mounted) return;
      setState(() {
        states = response;
        isLoadingStates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingStates = false);
      showSnackBar(
        e.toString().replaceAll('Exception:', '').trim(),
        Colors.red,
      );
    }
  }

  Future<void> fetchDistricts(int stateId) async {
    setState(() {
      isLoadingDistricts = true;
      districts = [];
      selectedDistrictId = null;
    });
    try {
      final response = await _apiService.getDistrictsByState(stateId: stateId);
      if (!mounted) return;
      setState(() {
        districts = response;
        isLoadingDistricts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingDistricts = false);
      showSnackBar(
        e.toString().replaceAll('Exception:', '').trim(),
        Colors.red,
      );
    }
  }

  void showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> pickImage() async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Select Image Source',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: primaryGreen),
              title: const Text(
                'Pick from Gallery',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: primaryGreen),
              title: const Text(
                'Take a Photo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          selectedXFile = image;
          selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (source == ImageSource.camera) {
        // Fallback to gallery if camera is not supported
        showSnackBar(
          "Camera is not supported on this device. Opening Gallery...",
          Colors.orange,
        );
        try {
          final XFile? image = await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 85,
          );
          if (image != null) {
            final bytes = await image.readAsBytes();
            setState(() {
              selectedXFile = image;
              selectedImageBytes = bytes;
            });
          }
        } catch (err) {
          showSnackBar(
            "Error picking from gallery: ${err.toString()}",
            Colors.red,
          );
        }
      } else {
        showSnackBar("Error picking image: ${e.toString()}", Colors.red);
      }
    }
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedCountryId == null) {
      showSnackBar('Please select country', Colors.red);
      return;
    }
    if (selectedStateId == null) {
      showSnackBar('Please select state', Colors.red);
      return;
    }
    if (selectedDistrictId == null) {
      showSnackBar('Please select district', Colors.red);
      return;
    }
    if (selectedLatitude == null || selectedLongitude == null) {
      showSnackBar('Please select delivery location on map', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.registerUser(
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        userType: selectedUserType,
        country: selectedCountryId!,
        state: selectedStateId!,
        district: selectedDistrictId!,
        profilePicturePath: selectedXFile?.path,
        latitude: selectedLatitude,
        longitude: selectedLongitude,
      );

      await _apiService.saveRegisteredUserData(response);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.detail),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final String registeredUserType = response.user.userType;

      if (registeredUserType == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomePage()),
          (route) => false,
        );
      } else if (registeredUserType == 'shop') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ShopHomePage()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const UserHomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: primaryGreen),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
        borderSide: BorderSide(color: primaryGreen, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 35, 22, 32),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.local_grocery_store_rounded,
              color: primaryGreen,
              size: 31,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Fresh groceries are just one step away',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.88),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRegisterCard() {
    final bool isPhoneVerified =
        widget.verifiedPhone != null && widget.verifiedPhone!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.green.shade50),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (isPhoneVerified)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, color: primaryGreen, size: 22),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Phone number verified successfully',
                        style: TextStyle(
                          color: darkGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Profile Image Picker
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryGreen, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: selectedImageBytes != null
                          ? Image.memory(
                              selectedImageBytes!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  if (selectedImageBytes != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedXFile = null;
                            selectedImageBytes = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Profile Photo (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: firstNameController,
              decoration: inputDecoration(
                label: 'First Name',
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter first name';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: lastNameController,
              decoration: inputDecoration(
                label: 'Last Name',
                icon: Icons.person_outline_rounded,
              ),
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: phoneController,
              readOnly: isPhoneVerified,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration:
                  inputDecoration(
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    suffixIcon: isPhoneVerified
                        ? Icon(Icons.verified_rounded, color: primaryGreen)
                        : null,
                  ).copyWith(
                    counterText: '',
                    fillColor: isPhoneVerified ? lightGreen : Colors.white,
                  ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter phone number';
                }
                if (value.trim().length != 10) {
                  return 'Enter valid 10 digit phone number';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: inputDecoration(
                label: 'Email Address',
                icon: Icons.email_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter email';
                }
                if (!value.contains('@')) {
                  return 'Enter valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Country Dropdown
            isLoadingCountries
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(color: Color(0xFF1B8F3A)),
                  )
                : DropdownButtonFormField<int>(
                    value: selectedCountryId,
                    dropdownColor: Colors.white,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: primaryGreen,
                    ),
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
                      if (value != null) {
                        setState(() {
                          selectedCountryId = value;
                        });
                        fetchStates(value);
                      }
                    },
                    validator: (value) =>
                        value == null ? 'Please select country' : null,
                  ),

            const SizedBox(height: 14),

            // State Dropdown
            isLoadingStates
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(color: Color(0xFF1B8F3A)),
                  )
                : DropdownButtonFormField<int>(
                    value: selectedStateId,
                    dropdownColor: Colors.white,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: primaryGreen,
                    ),
                    decoration: inputDecoration(
                      label: 'Select State',
                      icon: Icons.location_city_rounded,
                    ),
                    items: states.map((state) {
                      return DropdownMenuItem<int>(
                        value: state.id,
                        child: Text(state.name),
                      );
                    }).toList(),
                    onChanged: selectedCountryId == null
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                selectedStateId = value;
                              });
                              fetchDistricts(value);
                            }
                          },
                    validator: (value) =>
                        value == null ? 'Please select state' : null,
                  ),

            const SizedBox(height: 14),

            // District Dropdown
            isLoadingDistricts
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(color: Color(0xFF1B8F3A)),
                  )
                : DropdownButtonFormField<int>(
                    value: selectedDistrictId,
                    dropdownColor: Colors.white,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: primaryGreen,
                    ),
                    decoration: inputDecoration(
                      label: 'Select District',
                      icon: Icons.map_rounded,
                    ),
                    items: districts.map((district) {
                      return DropdownMenuItem<int>(
                        value: district.id,
                        child: Text(district.name),
                      );
                    }).toList(),
                    onChanged: selectedStateId == null
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                selectedDistrictId = value;
                              });
                            }
                          },
                    validator: (value) =>
                        value == null ? 'Please select district' : null,
                  ),

            const SizedBox(height: 14),

            // Location Selector Field
            InkWell(
              onTap: () async {
                final LatLng? result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapLocationPicker(
                      initialLatitude: selectedLatitude,
                      initialLongitude: selectedLongitude,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    selectedLatitude = result.latitude;
                    selectedLongitude = result.longitude;
                  });
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: inputDecoration(
                  label: 'Delivery Location',
                  icon: Icons.location_on_rounded,
                  suffixIcon: selectedLatitude != null && selectedLongitude != null
                      ? Icon(Icons.check_circle_rounded, color: primaryGreen)
                      : Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.grey.shade400,
                          size: 16,
                        ),
                ),
                child: Text(
                  selectedLatitude != null && selectedLongitude != null
                      ? 'Location: ${selectedLatitude!.toStringAsFixed(6)}, ${selectedLongitude!.toStringAsFixed(6)}'
                      : 'Select Delivery Location (Tap to pick on Map)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selectedLatitude != null && selectedLongitude != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: selectedLatitude != null && selectedLongitude != null
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: selectedUserType,
              dropdownColor: Colors.white,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: primaryGreen,
              ),
              decoration: inputDecoration(
                label: 'User Type',
                icon: Icons.account_circle_outlined,
              ),
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),

                DropdownMenuItem(value: 'shop', child: Text('Shop')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedUserType = value;
                  });
                }
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  disabledBackgroundColor: Colors.green.shade200,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to login page if needed.
                  },
                  child: Text(
                    'Login',
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: lightGreen,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: darkGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your details will be safely stored for faster shopping experience.',
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFF9),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [buildHeader(), buildRegisterCard(), buildBottomInfo()],
          ),
        ),
      ),
    );
  }
}

class MapLocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const MapLocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  final MapController _mapController = MapController();
  LatLng _selectedPosition = const LatLng(9.9312, 76.2673); // Default to Cochin

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF1B8F3A);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Select Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                setState(() {
                  _selectedPosition = position.center;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.grocery_app',
              ),
            ],
          ),
          // Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0), // Offset to align pin bottom
              child: Icon(
                Icons.location_pin,
                color: primaryGreen,
                size: 48,
              ),
            ),
          ),
          // Selected Coordinates and Confirm Button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gps_fixed_rounded, color: primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}, Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, _selectedPosition);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Confirm Location',
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
        ],
      ),
    );
  }
}
