import 'dart:convert';
import 'dart:io';
import 'package:grocery_app/models/district_model.dart';
import 'package:grocery_app/models/state_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../models/address_model.dart';
import '../models/country_model.dart';
import '../models/product_model.dart';
import '../models/register_response_model.dart';
import '../models/shop_approval_model.dart';
import '../models/shop_model.dart';
import '../models/category_model.dart';
import '../models/cart_item_model.dart';
import '../models/payment_method_model.dart';

class ApiService {
  // ─── OTP ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestOtp({required String phone}) async {
    final url = Uri.parse('${ApiConstants.api}api/grocery/request/otp/');
    final body = {"phone": phone};

    print("OTP REQUEST URL: $url");
    print("OTP REQUEST BODY: $body");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("OTP STATUS CODE: ${response.statusCode}");
    print("OTP RESPONSE BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      String errorMessage = "OTP request failed";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final url = Uri.parse('${ApiConstants.api}api/grocery/verify/otp/');
    final body = {"phone": phone, "otp": otp};

    print("VERIFY OTP URL: $url");
    print("VERIFY OTP BODY: $body");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("VERIFY OTP STATUS CODE: ${response.statusCode}");
    print("VERIFY OTP RESPONSE BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('access', decoded['access']?.toString() ?? '');
      await prefs.setString('refresh', decoded['refresh']?.toString() ?? '');
      await prefs.setBool('first_time', decoded['first_time'] ?? true);

      final user = decoded['user'];

      if (user is Map<String, dynamic>) {
        await prefs.setInt('user_id', user['id'] ?? 0);
        await prefs.setString('phone', user['phone']?.toString() ?? '');
        await prefs.setString('first_name', user['name']?.toString() ?? '');
        await prefs.setString('email', user['email']?.toString() ?? '');
        await prefs.setString('user_type', user['user_type']?.toString() ?? '');
        await prefs.setString(
          'approval_status',
          user['approval_status']?.toString() ?? '',
        );
      }

      return decoded;
    } else {
      String errorMessage = "OTP verification failed";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Register ────────────────────────────────────────────────

  Future<RegisterResponseModel> registerUser({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String userType,
    required int country,
    required int state,
    required int district,
    String? profilePicturePath,
    double? latitude,
    double? longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/register/');

    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['first_name'] = firstName;
    request.fields['last_name'] = lastName;
    request.fields['phone'] = phone;
    request.fields['email'] = email;
    request.fields['user_type'] = userType;
    request.fields['country'] = country.toString();
    request.fields['state'] = state.toString();
    request.fields['district'] = district.toString();

    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();

    if (profilePicturePath != null && profilePicturePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          profilePicturePath,
        ),
      );
    }

    print("REGISTER MULTIPART URL: $url");
    print("REGISTER FIELDS: ${request.fields}");

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print("REGISTER STATUS CODE: ${streamedResponse.statusCode}");
    print("REGISTER RESPONSE BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return RegisterResponseModel.fromJson(decoded);
    } else {
      String errorMessage = "Registration failed";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> saveRegisteredUserData(RegisterResponseModel response) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('is_registered', true);
    await prefs.setBool('first_time', false);
    await prefs.setInt('user_id', response.user.id);
    await prefs.setString('phone', response.user.phone);
    await prefs.setString('first_name', response.user.firstName);
    await prefs.setString('last_name', response.user.lastName);
    await prefs.setString('email', response.user.email);
    await prefs.setString('user_type', response.user.userType);
    await prefs.setString('approval_status', response.user.approvalStatus);
    await prefs.setString('profile_picture', response.user.profilePicture);

    if (response.user.country != null)
      await prefs.setInt('country', response.user.country!);
    if (response.user.state != null)
      await prefs.setInt('state', response.user.state!);
    if (response.user.district != null)
      await prefs.setInt('district', response.user.district!);
  }

  Future<Map<String, dynamic>> getSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'is_registered': prefs.getBool('is_registered') ?? false,
      'access': prefs.getString('access') ?? '',
      'refresh': prefs.getString('refresh') ?? '',
      'first_time': prefs.getBool('first_time') ?? true,
      'user_id': prefs.getInt('user_id') ?? 0,
      'phone': prefs.getString('phone') ?? '',
      'first_name': prefs.getString('first_name') ?? '',
      'last_name': prefs.getString('last_name') ?? '',
      'email': prefs.getString('email') ?? '',
      'user_type': prefs.getString('user_type') ?? '',
      'approval_status': prefs.getString('approval_status') ?? '',
      'profile_picture': prefs.getString('profile_picture') ?? '',
      'country': prefs.getInt('country') ?? 0,
      'state': prefs.getInt('state') ?? 0,
      'district': prefs.getInt('district') ?? 0,
    };
  }

  Future<void> clearSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ─── Countries ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getCountries({String? search, int? page}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/countries/view/',
    ).replace(queryParameters: queryParams);

    print("COUNTRIES GET URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("COUNTRIES STATUS CODE: ${response.statusCode}");
    print("COUNTRIES RESPONSE BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic>) {
        final List resultsJson = decoded['results'] ?? [];
        return {
          'count': decoded['count'] ?? 0,
          'next': decoded['next'],
          'previous': decoded['previous'],
          'results': List<CountryModel>.from(
            resultsJson.map((item) => CountryModel.fromJson(item)),
          ),
        };
      } else if (decoded is List) {
        return {
          'count': decoded.length,
          'next': null,
          'previous': null,
          'results': List<CountryModel>.from(
            decoded.map((item) => CountryModel.fromJson(item)),
          ),
        };
      }
      throw Exception("Unexpected response format");
    } else {
      String errorMessage = "Failed to load countries";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> addCountry({required String name, required String code}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/countries/view/');
    final body = {"name": name, "code": code};

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to add country";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> updateCountry({
    required int id,
    required String name,
    required String code,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/countries/update/$id/',
    );

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"name": name, "code": code}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to update country");
    }
  }

  Future<void> deleteCountry({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/countries/update/$id/',
    );

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to delete country");
    }
  }

  // ─── States ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStates({String? search, int? page}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/states/view/',
    ).replace(queryParameters: queryParams);

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("STATES STATUS CODE: ${response.statusCode}");
    print("STATES RESPONSE BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic>) {
        final List resultsJson = decoded['results'] ?? [];
        return {
          'count': decoded['count'] ?? 0,
          'next': decoded['next'],
          'previous': decoded['previous'],
          'results': List<StateModel>.from(
            resultsJson.map((item) => StateModel.fromJson(item)),
          ),
        };
      } else if (decoded is List) {
        return {
          'count': decoded.length,
          'next': null,
          'previous': null,
          'results': List<StateModel>.from(
            decoded.map((item) => StateModel.fromJson(item)),
          ),
        };
      }
      throw Exception("Unexpected response format");
    } else {
      throw Exception("Failed to load states");
    }
  }

  Future<void> addState({required String name, required int country}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/states/view/');

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"name": name, "country": country}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to add state");
    }
  }

  Future<void> updateState({
    required int id,
    required String name,
    required int country,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/states/update/$id/');

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"name": name, "country": country}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to update state");
    }
  }

  Future<void> deleteState({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/states/update/$id/');

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to delete state");
    }
  }

  // ─── Districts ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getDistricts({String? search, int? page}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/districts/view/',
    ).replace(queryParameters: queryParams);

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DISTRICTS STATUS CODE: ${response.statusCode}");
    print("DISTRICTS RESPONSE BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic>) {
        final List resultsJson = decoded['results'] ?? [];
        return {
          'count': decoded['count'] ?? 0,
          'next': decoded['next'],
          'previous': decoded['previous'],
          'results': List<DistrictModel>.from(
            resultsJson.map((item) => DistrictModel.fromJson(item)),
          ),
        };
      } else if (decoded is List) {
        return {
          'count': decoded.length,
          'next': null,
          'previous': null,
          'results': List<DistrictModel>.from(
            decoded.map((item) => DistrictModel.fromJson(item)),
          ),
        };
      }
      throw Exception("Unexpected response format");
    } else {
      throw Exception("Failed to load districts");
    }
  }

  Future<void> addDistrict({required String name, required int state}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/districts/view/');

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"name": name, "state": state}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to add district");
    }
  }

  Future<void> updateDistrict({
    required int id,
    required String name,
    required int state,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/districts/update/$id/',
    );

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"name": name, "state": state}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to update district");
    }
  }

  Future<void> deleteDistrict({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/districts/update/$id/',
    );

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to delete district");
    }
  }

  Future<List<StateModel>> getStatesByCountry({required int countryId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/states/by/country/$countryId/',
    );
    print("GET STATES BY COUNTRY URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET STATES BY COUNTRY STATUS: ${response.statusCode}");
    print("GET STATES BY COUNTRY RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is List) {
        return decoded.map((item) => StateModel.fromJson(item)).toList();
      } else if (decoded is Map<String, dynamic> &&
          decoded['results'] is List) {
        final List results = decoded['results'];
        return results.map((item) => StateModel.fromJson(item)).toList();
      }
      return [];
    } else {
      throw Exception("Failed to load states by country");
    }
  }

  Future<List<DistrictModel>> getDistrictsByState({
    required int stateId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/districts/by/state/$stateId/',
    );
    print("GET DISTRICTS BY STATE URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET DISTRICTS BY STATE STATUS: ${response.statusCode}");
    print("GET DISTRICTS BY STATE RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is List) {
        return decoded.map((item) => DistrictModel.fromJson(item)).toList();
      } else if (decoded is Map<String, dynamic> &&
          decoded['results'] is List) {
        final List results = decoded['results'];
        return results.map((item) => DistrictModel.fromJson(item)).toList();
      }
      return [];
    } else {
      throw Exception("Failed to load districts by state");
    }
  }

  // ─── Shop Approvals ──────────────────────────────────────────

  Future<Map<String, dynamic>> getShopApprovals({
    String? approvalStatus,
    String? search,
    int? page,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (approvalStatus != null && approvalStatus.isNotEmpty) {
      queryParams['approval_status'] = approvalStatus;
    }
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/shop/approvals/view/',
    ).replace(queryParameters: queryParams);

    print("SHOP APPROVALS GET URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("SHOP APPROVALS STATUS CODE: ${response.statusCode}");
    print("SHOP APPROVALS RESPONSE BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic>) {
        final List resultsJson = decoded['results'] ?? [];
        return {
          'count': decoded['count'] ?? 0,
          'next': decoded['next'],
          'previous': decoded['previous'],
          'results': List<ShopApprovalModel>.from(
            resultsJson.map((item) => ShopApprovalModel.fromJson(item)),
          ),
        };
      }
      throw Exception("Unexpected shop approvals response format");
    } else {
      String errorMessage = "Failed to load shop approvals";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> updateShopApprovalStatus({
    required int userId,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/shop/approval/$userId/',
    );
    final body = {"approval_status": status};

    print("SHOP APPROVAL PATCH URL: $url");
    print("SHOP APPROVAL PATCH BODY: $body");

    final response = await http.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("SHOP APPROVAL PATCH STATUS: ${response.statusCode}");
    print("SHOP APPROVAL PATCH RESPONSE: ${response.body}");

    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to update approval status";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Categories ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getCategories({
    int? page,
    String? search,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/categories/view/',
    ).replace(queryParameters: queryParams);

    print("CATEGORIES GET URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("CATEGORIES STATUS CODE: ${response.statusCode}");
    print("CATEGORIES RESPONSE BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic>) {
        final List resultsJson = decoded['results'] ?? [];
        return {
          'count': decoded['count'] ?? 0,
          'next': decoded['next'],
          'previous': decoded['previous'],
          'results': List<CategoryModel>.from(
            resultsJson.map((item) => CategoryModel.fromJson(item)),
          ),
        };
      } else if (decoded is List) {
        return {
          'count': decoded.length,
          'next': null,
          'previous': null,
          'results': List<CategoryModel>.from(
            decoded.map((item) => CategoryModel.fromJson(item)),
          ),
        };
      }
      throw Exception("Unexpected categories response format");
    } else {
      String errorMessage = "Failed to load categories";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> addCategory({
    required String name,
    required String description,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/categories/view/');

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"name": name, "description": description}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to add category";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> updateCategory({
    required int id,
    required String name,
    required String description,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/categories/update/$id/',
    );

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"name": name, "description": description}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to update category";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteCategory({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/categories/update/$id/',
    );

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to delete category";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Products ────────────────────────────────────────────────

  Future<List<ProductModel>> getProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/products/view/');
    print("GET PRODUCTS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET PRODUCTS STATUS CODE: ${response.statusCode}");
    print("GET PRODUCTS RESPONSE: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => ProductModel.fromJson(e)).toList();
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load products";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> addProduct({
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required double stock,
    required String unit,
    required double lowStockThreshold,
    File? image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/products/view/');

    print("ADD PRODUCT URL: $url");

    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['category'] = categoryId.toString();
    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['price'] = price;
    request.fields['stock'] = stock.toString();
    request.fields['unit'] = unit;
    request.fields['low_stock_threshold'] = lowStockThreshold.toString();

    if (image != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', image.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print("ADD PRODUCT STATUS CODE: ${response.statusCode}");
    print("ADD PRODUCT RESPONSE: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to add product";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> updateProduct({
    required int productId,
    required int categoryId,
    required String name,
    required String description,
    required String price,
    required double stock,
    required String unit,
    required double lowStockThreshold,
    File? image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/products/update/$productId/');

    print("UPDATE PRODUCT URL: $url");

    final request = http.MultipartRequest('PUT', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['category'] = categoryId.toString();
    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['price'] = price;
    request.fields['stock'] = stock.toString();
    request.fields['unit'] = unit;
    request.fields['low_stock_threshold'] = lowStockThreshold.toString();

    if (image != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', image.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print("UPDATE PRODUCT STATUS CODE: ${response.statusCode}");
    print("UPDATE PRODUCT RESPONSE: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to update product";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteProduct({required int productId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/products/update/$productId/');

    print("DELETE PRODUCT URL: $url");

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DELETE PRODUCT STATUS CODE: ${response.statusCode}");
    print("DELETE PRODUCT RESPONSE: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 204 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to delete product";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }


  // ─── Addresses ───────────────────────────────────────────────

  Future<List<AddressModel>> getAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/addresses/view/');
    print("GET ADDRESSES URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET ADDRESSES STATUS CODE: ${response.statusCode}");
    print("GET ADDRESSES RESPONSE: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => AddressModel.fromJson(e)).toList();
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load addresses";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<AddressModel> addAddress({
    required String address,
    required String landmark,
    required String city,
    required int country,
    required int state,
    required int district,
    required String postalCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/addresses/view/');
    final body = {
      "address": address,
      "landmark": landmark,
      "city": city,
      "country": country,
      "state": state,
      "district": district,
      "postal_code": postalCode,
    };

    print("ADD ADDRESS URL: $url");
    print("ADD ADDRESS BODY: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("ADD ADDRESS STATUS CODE: ${response.statusCode}");
    print("ADD ADDRESS RESPONSE: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AddressModel.fromJson(jsonDecode(response.body));
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to add address";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<AddressModel> updateAddress({
    required int addressId,
    required String address,
    required String landmark,
    required String city,
    required int country,
    required int state,
    required int district,
    required String postalCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/addresses/update/$addressId/',
    );
    final body = {
      "address": address,
      "landmark": landmark,
      "city": city,
      "country": country,
      "state": state,
      "district": district,
      "postal_code": postalCode,
    };

    print("UPDATE ADDRESS URL: $url");
    print("UPDATE ADDRESS BODY: $body");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("UPDATE ADDRESS STATUS CODE: ${response.statusCode}");
    print("UPDATE ADDRESS RESPONSE: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AddressModel.fromJson(jsonDecode(response.body));
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to update address";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteAddress({required int addressId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/addresses/update/$addressId/',
    );

    print("DELETE ADDRESS URL: $url");

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DELETE ADDRESS STATUS CODE: ${response.statusCode}");

    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to delete address";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Shops ───────────────────────────────────────────────────

  Future<List<ShopModel>> getShops() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/shops/view/');
    print("GET SHOPS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET SHOPS STATUS: ${response.statusCode}");
    print("GET SHOPS BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => ShopModel.fromJson(e)).toList();
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load shops";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<List<ProductModel>> getProductsByShop({required int shopId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/products/by/shop/$shopId/',
    );
    print("GET PRODUCTS BY SHOP URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET PRODUCTS BY SHOP STATUS: ${response.statusCode}");
    print("GET PRODUCTS BY SHOP BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => ProductModel.fromJson(e)).toList();
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load shop products";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Change Phone Number ─────────────────────────────────────

  Future<Map<String, dynamic>> requestOldPhoneOtp({
    required String oldPhone,
    required String newPhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/change/phone/request/old/otp/',
    );

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "old_phone": oldPhone,
        "new_phone": newPhone,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    }

    throw Exception(
      decoded['detail'] ?? decoded['message'] ?? "Requesting old OTP failed",
    );
  }

  Future<Map<String, dynamic>> verifyOldPhoneOtp({
    required String oldOtp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/change/phone/verify/old/otp/',
    );

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"otp": oldOtp}),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    }

    throw Exception(
      decoded['detail'] ?? decoded['message'] ?? "Verifying old OTP failed",
    );
  }

  Future<Map<String, dynamic>> requestNewPhoneOtp({
    required String newPhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/change/phone/request/new/otp/',
    );

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"new_phone": newPhone}),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    }

    throw Exception(
      decoded['detail'] ?? decoded['message'] ?? "Requesting new OTP failed",
    );
  }

  Future<Map<String, dynamic>> verifyNewPhoneOtp({
    required String newOtp,
    required String newPhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/change/phone/verify/new/otp/',
    );

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"otp": newOtp}),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final updatedPhone = decoded['new_phone']?.toString() ?? newPhone;
      await prefs.setString('phone', updatedPhone);
      return decoded;
    }

    throw Exception(
      decoded['detail'] ?? decoded['message'] ?? "Verifying new OTP failed",
    );
  }

  // ─── Shops by Category ──────────────────────────────────────

  Future<Map<String, dynamic>> getShopsByCategory({required int categoryId, int? page}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/shops/by/category/$categoryId/',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    print("GET SHOPS BY CATEGORY URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET SHOPS BY CATEGORY STATUS: ${response.statusCode}");
    print("GET SHOPS BY CATEGORY BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic>) {
        final List resultsJson = decoded['results'] ?? [];
        return {
          'count': decoded['count'] ?? 0,
          'next': decoded['next'],
          'previous': decoded['previous'],
          'results': List<ShopModel>.from(
            resultsJson.map((item) => ShopModel.fromJson(item)),
          ),
        };
      } else if (decoded is List) {
        return {
          'count': decoded.length,
          'next': null,
          'previous': null,
          'results': List<ShopModel>.from(
            decoded.map((item) => ShopModel.fromJson(item)),
          ),
        };
      }
      throw Exception("Unexpected response format");
    } else {
      String errorMessage = "Failed to load shops for category";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Products by Shop Prioritized by Category ───────────────

  Future<Map<String, dynamic>> getProductsByShopPrioritizeCategory({
    required int shopId,
    required int categoryId,
    int? page,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/products/by/shop/$shopId/prioritize/category/$categoryId/',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    print("GET PRODUCTS BY SHOP PRIORITIZE CATEGORY URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET PRODUCTS BY SHOP PRIORITIZE CATEGORY STATUS: ${response.statusCode}");
    print("GET PRODUCTS BY SHOP PRIORITIZE CATEGORY BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic>) {
        final List resultsJson = decoded['results'] ?? [];
        return {
          'count': decoded['count'] ?? 0,
          'next': decoded['next'],
          'previous': decoded['previous'],
          'results': List<ProductModel>.from(
            resultsJson.map((item) => ProductModel.fromJson(item)),
          ),
        };
      } else if (decoded is List) {
        return {
          'count': decoded.length,
          'next': null,
          'previous': null,
          'results': List<ProductModel>.from(
            decoded.map((item) => ProductModel.fromJson(item)),
          ),
        };
      }
      throw Exception("Unexpected response format");
    } else {
      String errorMessage = "Failed to load products";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Cart ─────────────────────────────────────────────────────

  Future<List<CartItemModel>> getCart() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/cart/view/');
    print("GET CART URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET CART STATUS CODE: ${response.statusCode}");
    print("GET CART RESPONSE: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items =
          decoded is List ? decoded : (decoded['results'] ?? []);
      return items.map((e) => CartItemModel.fromJson(e)).toList();
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load cart items";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> addToCart({required int productId, required int quantity}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/cart/view/');
    final body = {
      "product_id": productId,
      "quantity": quantity,
    };

    print("ADD TO CART URL: $url");
    print("ADD TO CART BODY: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("ADD TO CART STATUS CODE: ${response.statusCode}");
    print("ADD TO CART RESPONSE: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to add to cart";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

Future<void> deleteCartItem({required int productId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/cart/remove/$productId/',
    );
    print("DELETE CART ITEM URL: $url");

    // Try HTTP DELETE first
    var response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DELETE CART ITEM STATUS CODE: ${response.statusCode}");
    print("DELETE CART ITEM RESPONSE: ${response.body}");

    // If DELETE fails with 405 Method Not Allowed, try POST as a fallback
    if (response.statusCode == 405) {
      print("DELETE returned 405, trying POST as fallback...");
      response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      print(
        "DELETE CART ITEM (POST FALLBACK) STATUS CODE: ${response.statusCode}",
      );
      print("DELETE CART ITEM (POST FALLBACK) RESPONSE: ${response.body}");
    }

    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to delete cart item";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }
  // ─── Admin Payment Methods ────────────────────────────────────

  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/payment/methods/view/');
    print("GET PAYMENT METHODS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET PAYMENT METHODS STATUS CODE: ${response.statusCode}");
    print("GET PAYMENT METHODS RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> items =
          decoded is List ? decoded : (decoded['results'] ?? []);
      return items.map((e) => PaymentMethodModel.fromJson(e)).toList();
    } else {
      String errorMessage = "Failed to load payment methods";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<PaymentMethodModel> createPaymentMethod({
    required String name,
    required String code,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/payment/methods/view/');
    final body = {
      "name": name,
      "code": code,
    };

    print("CREATE PAYMENT METHOD URL: $url");
    print("CREATE PAYMENT METHOD BODY: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("CREATE PAYMENT METHOD STATUS CODE: ${response.statusCode}");
    print("CREATE PAYMENT METHOD RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return PaymentMethodModel.fromJson(decoded);
    } else {
      String errorMessage = "Failed to create payment method";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<PaymentMethodModel> getPaymentMethodDetails({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/payment/methods/update/$id/');
    print("GET PAYMENT METHOD DETAILS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET PAYMENT METHOD DETAILS STATUS CODE: ${response.statusCode}");
    print("GET PAYMENT METHOD DETAILS RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return PaymentMethodModel.fromJson(decoded);
    } else {
      String errorMessage = "Failed to load payment method details";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<PaymentMethodModel> updatePaymentMethod({
    required int id,
    required String name,
    required String code,
    required bool isActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/payment/methods/update/$id/');
    final body = {
      "name": name,
      "code": code,
      "is_active": isActive,
    };

    print("UPDATE PAYMENT METHOD URL: $url");
    print("UPDATE PAYMENT METHOD BODY: $body");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("UPDATE PAYMENT METHOD STATUS CODE: ${response.statusCode}");
    print("UPDATE PAYMENT METHOD RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return PaymentMethodModel.fromJson(decoded);
    } else {
      String errorMessage = "Failed to update payment method";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deletePaymentMethod({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/payment/methods/update/$id/');
    print("DELETE PAYMENT METHOD URL: $url");

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DELETE PAYMENT METHOD STATUS CODE: ${response.statusCode}");
    print("DELETE PAYMENT METHOD RESPONSE: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 204 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to delete payment method";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }
}
