import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/address_model.dart';
import '../models/country_model.dart';
import '../models/state_model.dart';
import '../models/district_model.dart';
import '../services/api_service.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  final ApiService _apiService = ApiService();

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color background = const Color(0xFFF7FFF9);

  List<AddressModel> _addresses = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _loadSelectedAddressId();
  }

  Future<void> _loadSelectedAddressId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedAddressId = prefs.getInt('selected_address_id');
      });
    } catch (_) {}
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final addresses = await _apiService.getAddresses();
      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAddress(AddressModel addr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Address', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove "${addr.address}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.deleteAddress(addressId: addr.id);
      _loadAddresses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Address deleted'),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _selectAddress(AddressModel addr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_address_id', addr.id);
      setState(() {
        _selectedAddressId = addr.id;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Primary address updated to ${addr.city}'),
          backgroundColor: primaryGreen,
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.pop(context, addr);
        }
      });
    } catch (_) {}
  }

  void _openAddressForm({AddressModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddressFormPage(existing: existing),
      ),
    );
    if (result == true) _loadAddresses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Addresses',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: _loadAddresses,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : _error != null
              ? _buildError()
              : _addresses.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddressForm(),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 72, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAddresses,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_off_rounded, size: 64, color: primaryGreen.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Addresses Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a delivery address to get started.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: _addresses.length,
      itemBuilder: (context, index) {
        final addr = _addresses[index];
        return _buildAddressCard(addr, index);
      },
    );
  }

  Widget _buildAddressCard(AddressModel addr, int index) {
    final bool isSelected = _selectedAddressId != null
        ? _selectedAddressId == addr.id
        : index == 0;

    return GestureDetector(
      onTap: () => _selectAddress(addr),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.green.shade50,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(isSelected ? 0.08 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isSelected
                          ? primaryGreen.withOpacity(0.12)
                          : primaryGreen.withOpacity(0.08),
                      lightGreen,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Address ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: darkGreen,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded, color: Colors.white, size: 10),
                                  SizedBox(width: 3),
                                  Text(
                                    'Primary',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  // Edit
                  InkWell(
                    onTap: () => _openAddressForm(existing: addr),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_rounded, size: 17, color: Colors.blue.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete
                  InkWell(
                    onTap: () => _deleteAddress(addr),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red.shade600),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.home_rounded, addr.address),
                  if (addr.landmark.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoRow(Icons.place_rounded, addr.landmark, label: 'Landmark'),
                  ],
                  const SizedBox(height: 8),
                  _infoRow(Icons.location_city_rounded, addr.city, label: 'City'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(Icons.flag_rounded, addr.countryName),
                      _chip(Icons.map_rounded, addr.stateName),
                      _chip(Icons.grain_rounded, addr.districtName),
                      _chip(Icons.local_post_office_rounded, addr.postalCode),
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

  Widget _infoRow(IconData icon, String value, {String? label}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: primaryGreen),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 13.5),
              children: [
                if (label != null)
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: primaryGreen),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: darkGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ADDRESS FORM PAGE (Add / Edit)
// ─────────────────────────────────────────────────────────────

class _AddressFormPage extends StatefulWidget {
  final AddressModel? existing;
  const _AddressFormPage({this.existing});

  @override
  State<_AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<_AddressFormPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color background = const Color(0xFFF7FFF9);

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

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (_isEditing) {
      final e = widget.existing!;
      _addressCtrl.text = e.address;
      _landmarkCtrl.text = e.landmark;
      _cityCtrl.text = e.city;
      _postalCtrl.text = e.postalCode;
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final countriesData = await _apiService.getCountries();
      final countries = (countriesData['results'] as List<CountryModel>);
      setState(() {
        _countries = countries;
      });

      if (_isEditing) {
        final existing = widget.existing!;
        // Pre-select country
        try {
          _selectedCountry = _countries.firstWhere((c) => c.id == existing.country);
        } catch (_) {}

        if (_selectedCountry != null) {
          final states = await _apiService.getStatesByCountry(countryId: _selectedCountry!.id);
          setState(() => _states = states);
          try {
            _selectedState = _states.firstWhere((s) => s.id == existing.state);
          } catch (_) {}

          if (_selectedState != null) {
            final districts = await _apiService.getDistrictsByState(stateId: _selectedState!.id);
            setState(() => _districts = districts);
            try {
              _selectedDistrict = _districts.firstWhere((d) => d.id == existing.district);
            } catch (_) {}
          }
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
      final states = await _apiService.getStatesByCountry(countryId: country.id);
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
      final districts = await _apiService.getDistrictsByState(stateId: state.id);
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
      if (_isEditing) {
        await _apiService.updateAddress(
          addressId: widget.existing!.id,
          address: _addressCtrl.text.trim(),
          landmark: _landmarkCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          country: _selectedCountry!.id,
          state: _selectedState!.id,
          district: _selectedDistrict!.id,
          postalCode: _postalCtrl.text.trim(),
        );
      } else {
        await _apiService.addAddress(
          address: _addressCtrl.text.trim(),
          landmark: _landmarkCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          country: _selectedCountry!.id,
          state: _selectedState!.id,
          district: _selectedDistrict!.id,
          postalCode: _postalCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Address' : 'New Address',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
      ),
      body: _isLoadingDropdowns
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    _sectionLabel('Location'),
                    const SizedBox(height: 12),
                    // Country dropdown
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
                    // State dropdown
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
                    // District dropdown
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
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
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
                            : Icon(_isEditing ? Icons.save_rounded : Icons.add_location_alt_rounded),
                        label: Text(
                          _isEditing ? 'Save Changes' : 'Add Address',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: primaryGreen.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: darkGreen,
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
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryGreen, size: 20),
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
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
          borderSide: BorderSide(color: primaryGreen, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
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
      validator: validator,
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? primaryGreen : Colors.grey, size: 20),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade50,
        labelStyle: TextStyle(
          color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade100),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryGreen, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  displayText(item),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      hint: Text(
        enabled ? 'Select $label' : 'Select ${label == "State" ? "a country first" : "a state first"}',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(16),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: enabled ? primaryGreen : Colors.grey),
    );
  }
}
