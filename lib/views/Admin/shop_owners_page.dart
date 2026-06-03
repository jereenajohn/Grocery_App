import 'package:flutter/material.dart';
import '../widgets/shimmer_loading.dart';
import '../../services/api_service.dart';
import '../../models/shop_approval_model.dart';

class ShopOwnersPage extends StatefulWidget {
  const ShopOwnersPage({super.key});

  @override
  State<ShopOwnersPage> createState() => _ShopOwnersPageState();
}

class _ShopOwnersPageState extends State<ShopOwnersPage> {
  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);
  final Color darkGreen = const Color(0xFF0F5F28);
  final Color goldAccent = const Color(0xFFFFB300);
  final Color background = const Color(0xFFF7FFF9);

  final ApiService _apiService = ApiService();

  List<ShopApprovalModel> _shopOwners = [];
  int _currentPage = 1;
  int _totalCount = 0;
  bool _isLoadingShops = false;
  int? _updatingUserId;
  String _searchQuery = '';
  String _selectedStatus = ''; // '' (All), 'pending', 'approved', 'rejected'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchShopApprovals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchShopApprovals() async {
    setState(() => _isLoadingShops = true);
    try {
      final response = await _apiService.getShopApprovals(
        approvalStatus: _selectedStatus.isNotEmpty ? _selectedStatus : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        page: _currentPage,
      );
      setState(() {
        _shopOwners = response['results'] as List<ShopApprovalModel>;
        _totalCount = response['count'] as int;
        _isLoadingShops = false;
      });
    } catch (e) {
      setState(() => _isLoadingShops = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateApprovalStatus(int userId, String status) async {
    setState(() {
      _updatingUserId = userId;
    });

    try {
      await _apiService.updateShopApprovalStatus(userId: userId, status: status);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shop registration ${status == 'approved' ? 'approved' : 'rejected'} successfully!'),
          backgroundColor: status == 'approved' ? primaryGreen : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _fetchShopApprovals();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _updatingUserId = null;
      });
    }
  }

  String _cleanName(String raw) {
    final leadingRegExp = RegExp(r'^\d+\s*[-–—]?\s*');
    String cleaned = raw.replaceAll(leadingRegExp, '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s*[-–—]?\s*\(\d+\)$'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s*[-–—]?\s*\d+$'), '').trim();
    if (cleaned.isEmpty || RegExp(r'^\d+$').hasMatch(cleaned)) {
      return '';
    }
    return cleaned;
  }

  String _displayLocation(ShopApprovalModel shop) {
    final cName = _cleanName(shop.country);
    final sName = _cleanName(shop.state);
    final dName = _cleanName(shop.district);
    
    final List<String> parts = [];
    if (dName.isNotEmpty) parts.add(dName);
    if (sName.isNotEmpty) parts.add(sName);
    if (cName.isNotEmpty) parts.add(cName);
    
    return parts.join(', ');
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop Owner Approvals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Manage registered shop approvals',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildShopSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by owner name...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded, color: primaryGreen, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
            _currentPage = 1;
          });
          _fetchShopApprovals();
        },
      ),
    );
  }

  Widget buildStatusFilter() {
    final List<Map<String, String>> statuses = [
      {'label': 'All', 'value': ''},
      {'label': 'Pending', 'value': 'pending'},
      {'label': 'Approved', 'value': 'approved'},
      {'label': 'Rejected', 'value': 'rejected'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((status) {
          final isSelected = _selectedStatus == status['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                status['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: primaryGreen,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? primaryGreen : Colors.green.shade100,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedStatus = status['value']!;
                    _currentPage = 1;
                  });
                  _fetchShopApprovals();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildShopListSection() {
    if (_isLoadingShops) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: ProductsListShimmer(itemCount: 4),
      );
    }

    if (_shopOwners.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.storefront_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'No registered shop owners found.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _shopOwners.length,
          itemBuilder: (context, index) {
            final shop = _shopOwners[index];
            Color statusColor = primaryGreen;
            if (shop.approvalStatus == 'pending') {
              statusColor = goldAccent;
            } else if (shop.approvalStatus == 'rejected') {
              statusColor = Colors.red;
            }

            final String fullName = '${shop.firstName} ${shop.lastName}'.trim();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: lightGreen,
                    backgroundImage: shop.profilePicture != null && shop.profilePicture!.isNotEmpty
                        ? NetworkImage(shop.profilePicture!)
                        : null,
                    child: shop.profilePicture == null || shop.profilePicture!.isEmpty
                        ? Icon(Icons.storefront_rounded, color: primaryGreen, size: 22)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                shop.approvalStatus.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${shop.phone}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Email: ${shop.email}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: primaryGreen),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _displayLocation(shop),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFE2F0D9)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (shop.approvalStatus == 'pending' || shop.approvalStatus == 'approved')
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.red.shade100),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                icon: _updatingUserId == shop.id
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                                      )
                                    : const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: _updatingUserId != null
                                    ? null
                                    : () => _updateApprovalStatus(shop.id, 'rejected'),
                              ),
                            if (shop.approvalStatus == 'pending')
                              const SizedBox(width: 8),
                            if (shop.approvalStatus == 'pending' || shop.approvalStatus == 'rejected')
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: lightGreen,
                                  foregroundColor: primaryGreen,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.green.shade100),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                icon: _updatingUserId == shop.id
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B8F3A)),
                                      )
                                    : const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: _updatingUserId != null
                                    ? null
                                    : () => _updateApprovalStatus(shop.id, 'approved'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildBottomPagination() {
    if (_shopOwners.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total: $_totalCount owners',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  color: _currentPage > 1 ? primaryGreen : Colors.grey.shade300,
                  onPressed: _currentPage > 1
                      ? () {
                          setState(() => _currentPage--);
                          _fetchShopApprovals();
                        }
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Page $_currentPage',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: darkGreen,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  color: (_currentPage * 6) < _totalCount ? primaryGreen : Colors.grey.shade300,
                  onPressed: (_currentPage * 6) < _totalCount
                      ? () {
                          setState(() => _currentPage++);
                          _fetchShopApprovals();
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildShopSearch(),
                    const SizedBox(height: 12),
                    buildStatusFilter(),
                    const SizedBox(height: 16),
                    buildShopListSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildBottomPagination(),
    );
  }
}
