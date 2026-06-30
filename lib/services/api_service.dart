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
import '../models/banner_model.dart';
import '../models/order_model.dart';
import '../models/platform_fee_model.dart';
import '../models/convenience_fee_model.dart';
import '../models/delivery_charge_model.dart';

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
        await prefs.setString('shop_name', user['shop_name']?.toString() ?? '');
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
    String? shopName,
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

    if (shopName != null && shopName.isNotEmpty) {
      request.fields['shop_name'] = shopName;
    }

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
      'shop_name': prefs.getString('shop_name') ?? '',
      'approval_status': prefs.getString('approval_status') ?? '',
      'profile_picture': prefs.getString('profile_picture') ?? '',
      'country': prefs.getInt('country') ?? 0,
      'state': prefs.getInt('state') ?? 0,
      'district': prefs.getInt('district') ?? 0,
      'country_name': prefs.getString('country_name') ?? '',
      'state_name': prefs.getString('state_name') ?? '',
      'district_name': prefs.getString('district_name') ?? '',
      'latitude': prefs.getString('latitude') ?? '',
      'longitude': prefs.getString('longitude') ?? '',
      'is_open': prefs.getBool('is_open') ?? true,
    };
  }

  Future<Map<String, dynamic>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    // 1. Try hitting the standard profile view endpoint
    final url = Uri.parse('${ApiConstants.api}api/grocery/profile/');
    print("GET PROFILE API CALL TO: $url");
    try {
      final response = await http
          .get(
            url,
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 10));

      print("GET PROFILE STATUS CODE: ${response.statusCode}");
      print("GET PROFILE RESPONSE BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final status = decoded['approval_status']?.toString() ?? 'pending';
          await prefs.setString('approval_status', status);
          if (decoded['first_name'] != null) await prefs.setString('first_name', decoded['first_name'].toString());
          if (decoded['last_name'] != null) await prefs.setString('last_name', decoded['last_name'].toString());
          if (decoded['email'] != null) await prefs.setString('email', decoded['email'].toString());
          if (decoded['shop_name'] != null) await prefs.setString('shop_name', decoded['shop_name'].toString());
          if (decoded['latitude'] != null) await prefs.setString('latitude', decoded['latitude'].toString());
          if (decoded['longitude'] != null) await prefs.setString('longitude', decoded['longitude'].toString());
          if (decoded['is_open'] != null) await prefs.setBool('is_open', decoded['is_open'] == true);
          if (decoded['profile_picture'] != null) await prefs.setString('profile_picture', decoded['profile_picture'].toString());
          
          if (decoded['country'] != null) {
            await prefs.setString('country_name', decoded['country'].toString());
            final parsedCountry = int.tryParse(decoded['country'].toString());
            if (parsedCountry != null) await prefs.setInt('country', parsedCountry);
          }
          if (decoded['state'] != null) {
            await prefs.setString('state_name', decoded['state'].toString());
            final parsedState = int.tryParse(decoded['state'].toString());
            if (parsedState != null) await prefs.setInt('state', parsedState);
          }
          if (decoded['district'] != null) {
            await prefs.setString('district_name', decoded['district'].toString());
            final parsedDistrict = int.tryParse(decoded['district'].toString());
            if (parsedDistrict != null) await prefs.setInt('district', parsedDistrict);
          }
          return decoded;
        }
      }
    } catch (e) {
      print("GET PROFILE standard API exception: $e");
    }

    // 2. Fallback: Search the approvals list for matching phone
    print("GET PROFILE fallback 1: Searching shop approvals list");
    try {
      final approvalsData = await getShopApprovals(page: 1);
      final List results = approvalsData['results'] ?? [];
      final myPhone = prefs.getString('phone') ?? '';

      for (var item in results) {
        if (item is ShopApprovalModel && item.phone == myPhone) {
          final status = item.approvalStatus;
          print("GET PROFILE fallback 1: Found matching approval shop with status $status");
          await prefs.setString('approval_status', status);
          await prefs.setString('first_name', item.firstName);
          await prefs.setString('last_name', item.lastName);
          await prefs.setString('email', item.email);
          if (item.profilePicture != null) {
            await prefs.setString('profile_picture', item.profilePicture!);
          }
          await prefs.setString('country_name', item.country);
          await prefs.setString('state_name', item.state);
          await prefs.setString('district_name', item.district);
          if (item.latitude != null) await prefs.setString('latitude', item.latitude!);
          if (item.longitude != null) await prefs.setString('longitude', item.longitude!);

          return {
            'approval_status': status,
            'id': item.id,
            'phone': item.phone,
            'first_name': item.firstName,
            'last_name': item.lastName,
            'email': item.email,
            'user_type': 'shop',
            'country_name': item.country,
            'state_name': item.state,
            'district_name': item.district,
            'latitude': item.latitude,
            'longitude': item.longitude,
            'profile_picture': item.profilePicture,
          };
        }
      }
    } catch (e) {
      print("GET PROFILE fallback 1 exception: $e");
    }

    // 3. Fallback: Check getShops approved store list
    print("GET PROFILE fallback 2: Searching approved shops list");
    try {
      final shops = await getShops();
      final myPhone = prefs.getString('phone') ?? '';
      ShopModel? matchingShop;
      for (var s in shops) {
        if (s.phone == myPhone) {
          matchingShop = s;
          break;
        }
      }
      if (matchingShop != null) {
        print("GET PROFILE fallback 2: Found matching approved shop ${matchingShop.shop_name}");
        await prefs.setString('approval_status', 'approved');
        await prefs.setString('first_name', matchingShop.firstName);
        await prefs.setString('last_name', matchingShop.lastName);
        await prefs.setString('email', matchingShop.email);
        await prefs.setString('shop_name', matchingShop.shop_name);
        if (matchingShop.profilePicture != null) {
          await prefs.setString('profile_picture', matchingShop.profilePicture!);
        }
        await prefs.setString('country_name', matchingShop.countryName);
        await prefs.setString('state_name', matchingShop.stateName);
        await prefs.setString('district_name', matchingShop.districtName);
        await prefs.setInt('country', matchingShop.country);
        await prefs.setInt('state', matchingShop.state);
        await prefs.setInt('district', matchingShop.district);
        if (matchingShop.latitude != null) await prefs.setString('latitude', matchingShop.latitude!);
        if (matchingShop.longitude != null) await prefs.setString('longitude', matchingShop.longitude!);
        await prefs.setBool('is_open', matchingShop.isOpen);

        return {
          'approval_status': 'approved',
          'id': matchingShop.id,
          'phone': matchingShop.phone,
          'first_name': matchingShop.firstName,
          'last_name': matchingShop.lastName,
          'email': matchingShop.email,
          'shop_name': matchingShop.shop_name,
          'user_type': 'shop',
          'country': matchingShop.country,
          'state': matchingShop.state,
          'district': matchingShop.district,
          'latitude': matchingShop.latitude,
          'longitude': matchingShop.longitude,
          'is_open': matchingShop.isOpen,
          'profile_picture': matchingShop.profilePicture,
        };
      }
    } catch (e) {
      print("GET PROFILE fallback 2 exception: $e");
    }

    // 4. Default: Return saved local profile status
    final savedStatus = prefs.getString('approval_status') ?? 'pending';
    print("GET PROFILE fallback default: Returning status $savedStatus");
    return {'approval_status': savedStatus};
  }

  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String firstName,
    required String lastName,
    required String email,
    String? shopName,
    int? country,
    int? state,
    int? district,
    String? latitude,
    String? longitude,
    bool? isOpen,
    File? profilePicture,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';
    final url = Uri.parse('${ApiConstants.api}api/grocery/profile/update/$userId/');

    final request = http.MultipartRequest('PUT', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['first_name'] = firstName;
    request.fields['last_name'] = lastName;
    request.fields['email'] = email;
    if (shopName != null && shopName.isNotEmpty) {
      request.fields['shop_name'] = shopName;
    }
    if (country != null) {
      request.fields['country'] = country.toString();
    }
    if (state != null) {
      request.fields['state'] = state.toString();
    }
    if (district != null) {
      request.fields['district'] = district.toString();
    }
    if (latitude != null) {
      request.fields['latitude'] = latitude;
    }
    if (longitude != null) {
      request.fields['longitude'] = longitude;
    }
    if (isOpen != null) {
      request.fields['is_open'] = isOpen.toString();
    }
    if (profilePicture != null) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_picture', profilePicture.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      await prefs.setString('first_name', decoded['first_name']?.toString() ?? firstName);
      await prefs.setString('last_name', decoded['last_name']?.toString() ?? lastName);
      await prefs.setString('email', decoded['email']?.toString() ?? email);
      if (decoded['shop_name'] != null) {
        await prefs.setString('shop_name', decoded['shop_name']?.toString() ?? '');
      }
      if (decoded['country'] != null) {
        final parsedCountry = int.tryParse(decoded['country'].toString());
        if (parsedCountry != null) {
          await prefs.setInt('country', parsedCountry);
        } else if (country != null) {
          await prefs.setInt('country', country);
        }
      }
      if (decoded['state'] != null) {
        final parsedState = int.tryParse(decoded['state'].toString());
        if (parsedState != null) {
          await prefs.setInt('state', parsedState);
        } else if (state != null) {
          await prefs.setInt('state', state);
        }
      }
      if (decoded['district'] != null) {
        final parsedDistrict = int.tryParse(decoded['district'].toString());
        if (parsedDistrict != null) {
          await prefs.setInt('district', parsedDistrict);
        } else if (district != null) {
          await prefs.setInt('district', district);
        }
      }
      if (decoded['latitude'] != null) {
        await prefs.setString('latitude', decoded['latitude']?.toString() ?? '');
      }
      if (decoded['longitude'] != null) {
        await prefs.setString('longitude', decoded['longitude']?.toString() ?? '');
      }
      if (decoded['is_open'] != null) {
        await prefs.setBool('is_open', decoded['is_open'] == true);
      }
      if (decoded['profile_picture'] != null) {
        await prefs.setString('profile_picture', decoded['profile_picture'].toString());
      }
      return decoded;
    } else {
      String errorMessage = "Failed to update profile";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
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
    File? image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/categories/view/');

    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['name'] = name;
    request.fields['description'] = description;

    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

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
    File? image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/categories/update/$id/',
    );

    final request = http.MultipartRequest('PUT', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['name'] = name;
    request.fields['description'] = description;

    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

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

    final url = Uri.parse('${ApiConstants.api}api/grocery/my/products/view/');
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
    request.fields['low_stock_threshold'] = lowStockThreshold.toStringAsFixed(
      2,
    );

    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print("ADD PRODUCT STATUS CODE: ${response.statusCode}");
    print("ADD PRODUCT RESPONSE: ${response.body}");
    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to add product";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
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

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/products/update/$productId/',
    );

    print("UPDATE PRODUCT URL: $url");

    final request = http.MultipartRequest('PUT', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['category'] = categoryId.toString();
    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['price'] = price;
    request.fields['stock'] = stock.toString();
    request.fields['unit'] = unit;
    request.fields['low_stock_threshold'] = lowStockThreshold.toStringAsFixed(
      2,
    );

    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print("UPDATE PRODUCT STATUS CODE: ${response.statusCode}");
    print("UPDATE PRODUCT RESPONSE: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to update product";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteProduct({required int productId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/products/update/$productId/',
    );

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

    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 201) {
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
    double? latitude,
    double? longitude,
  }) async {
    try {
      final existing = await getAddresses();
      if (existing.isNotEmpty) {
        return await updateAddress(
          addressId: existing.first.id,
          address: address,
          landmark: landmark,
          city: city,
          country: country,
          state: state,
          district: district,
          postalCode: postalCode,
          latitude: latitude,
          longitude: longitude,
        );
      }
    } catch (e) {
      print("Error checking existing addresses, proceeding to add: $e");
    }

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
      "latitude": latitude,
      "longitude": longitude,
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
    double? latitude,
    double? longitude,
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
      "latitude": latitude,
      "longitude": longitude,
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

  Future<List<ShopModel>> getShops({String? search, double? radius}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (radius != null) {
      queryParams['radius'] = radius.toStringAsFixed(1);
    }

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/shops/view/',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
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

  Future<double> getRadiusFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/shops/filter/radius/');
    print("GET RADIUS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET RADIUS STATUS CODE: ${response.statusCode}");
    print("GET RADIUS RESPONSE: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final radiusVal = decoded['radius'];
      if (radiusVal is num) {
        return radiusVal.toDouble();
      }
      return double.tryParse(radiusVal?.toString() ?? '') ?? 10.0;
    } else {
      throw Exception("Failed to load radius filter");
    }
  }

  Future<void> updateRadiusFilter(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/shops/filter/radius/');
    print("UPDATE RADIUS URL: $url");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"radius": radius}),
    );

    print("UPDATE RADIUS STATUS CODE: ${response.statusCode}");
    print("UPDATE RADIUS RESPONSE: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 204 && response.statusCode != 201) {
      throw Exception("Failed to update radius filter");
    }
  }

  Future<List<ShopModel>> getTopRatedShops() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/shops/top-rated/');
    print("GET TOP RATED SHOPS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET TOP RATED SHOPS STATUS: ${response.statusCode}");
    print("GET TOP RATED SHOPS BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => ShopModel.fromJson(e)).toList();
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load top rated shops";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getShopsPaginated({String? search, int? page}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (page != null) {
      queryParams['page'] = page.toString();
    }

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/shops/view/',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    print("GET SHOPS PAGINATED URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET SHOPS PAGINATED STATUS: ${response.statusCode}");
    print("GET SHOPS PAGINATED BODY: ${response.body}");

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
      throw Exception("Unexpected shops response format");
    } else {
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
      body: jsonEncode({"old_phone": oldPhone, "new_phone": newPhone}),
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

  Future<Map<String, dynamic>> getShopsByCategory({
    required int categoryId,
    int? page,
  }) async {
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
        errorMessage =
            decoded['detail']?.toString() ??
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

    print(
      "GET PRODUCTS BY SHOP PRIORITIZE CATEGORY STATUS: ${response.statusCode}",
    );
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
        errorMessage =
            decoded['detail']?.toString() ??
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
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => CartItemModel.fromJson(e)).toList();
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load cart items";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getCartSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/cart/summary/');
    print("GET CART SUMMARY URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET CART SUMMARY STATUS: ${response.statusCode}");
    print("GET CART SUMMARY BODY: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic> && decoded['status'] == 'success') {
        return decoded['data'] ?? {};
      }
      throw Exception("Unexpected cart summary response format");
    } else {
      String errorMessage = "Failed to load cart summary";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }


  Future<void> addToCart({
    required int productId,
    required int quantity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/cart/view/');
    final body = {"product_id": productId, "quantity": quantity};

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
        errorMessage =
            decoded['detail']?.toString() ??
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

  // ─── Cart Shop Context ───────────────────────────────────────

  Future<int?> getCartShopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('cart_shop_id');
  }

  Future<void> setCartShopId(int? shopId) async {
    final prefs = await SharedPreferences.getInstance();
    if (shopId == null) {
      await prefs.remove('cart_shop_id');
    } else {
      await prefs.setInt('cart_shop_id', shopId);
    }
  }

  Future<String?> getCartShopName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cart_shop_name');
  }

  Future<void> setCartShopName(String? shopName) async {
    final prefs = await SharedPreferences.getInstance();
    if (shopName == null) {
      await prefs.remove('cart_shop_name');
    } else {
      await prefs.setString('cart_shop_name', shopName);
    }
  }

  Future<void> clearCart() async {
    final items = await getCart();
    for (var item in items) {
      try {
        await deleteCartItem(productId: item.product.id);
      } catch (_) {
        // Fallback to sending quantity 0 if delete fails
        await addToCart(productId: item.product.id, quantity: 0);
      }
    }
    await setCartShopId(null);
    await setCartShopName(null);
  }

  Future<void> syncCartShopContext(List<CartItemModel> cartItems) async {
    if (cartItems.isEmpty) {
      await setCartShopId(null);
      await setCartShopName(null);
      return;
    }

    final currentShopId = await getCartShopId();
    if (currentShopId != null) {
      return; // Already synced
    }

    // Try to sync/detect
    try {
      final firstProductId = cartItems.first.product.id;
      final shops = await getShops();
      for (var shop in shops) {
        final products = await getProductsByShop(shopId: shop.id);
        if (products.any((p) => p.id == firstProductId)) {
          await setCartShopId(shop.id);
          await setCartShopName(shop.shop_name);
          break;
        }
      }
    } catch (e) {
      print("Error syncing cart shop context: $e");
    }
  }

  // ─── Order Ratings ───────────────────────────────────────────

  Future<Map<String, dynamic>?> getOrderRating({required int orderId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';
    final url = Uri.parse('${ApiConstants.api}api/grocery/orders/$orderId/rating/');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load rating";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> submitOrderRating({
    required int orderId,
    required int rating,
    required String review,
    required bool isUpdate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';
    final url = Uri.parse('${ApiConstants.api}api/grocery/orders/$orderId/rating/');
    final body = {
      "rating": rating,
      "review": review,
    };

    final response = isUpdate
        ? await http.put(
            url,
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode(body),
          )
        : await http.post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode(body),
          );

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      String errorMessage = "Failed to submit rating";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Admin Payment Methods ────────────────────────────────────

  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/payment/methods/view/',
    );
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
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => PaymentMethodModel.fromJson(e)).toList();
    } else {
      String errorMessage = "Failed to load payment methods";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
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

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/payment/methods/view/',
    );
    final body = {"name": name, "code": code};

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
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<PaymentMethodModel> getPaymentMethodDetails({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/payment/methods/update/$id/',
    );
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
        errorMessage =
            decoded['detail']?.toString() ??
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

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/payment/methods/update/$id/',
    );
    final body = {"name": name, "code": code, "is_active": isActive};

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
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deletePaymentMethod({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/payment/methods/update/$id/',
    );
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

    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to delete payment method";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Checkout ───────────────────────────────────────────────

  Future<Map<String, dynamic>> checkout({
    required String paymentMethod,
    required String fullName,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String country,
    required String note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/checkout/');
    final body = {
      "payment_method": paymentMethod,
      "full_name": fullName,
      "phone": phone,
      "address": address,
      "city": city,
      "state": state,
      "pincode": pincode,
      "country": country,
      "note": note,
    };

    print("CHECKOUT URL: $url");
    print("CHECKOUT BODY: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("CHECKOUT STATUS CODE: ${response.statusCode}");
    print("CHECKOUT RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      String errorMessage = "Checkout failed";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<List<BannerModel>> getBanners() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/banners/view/');

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final List items = decoded is List ? decoded : decoded['results'] ?? [];
      return items.map((e) => BannerModel.fromJson(e)).toList();
    }

    throw Exception("Failed to load banners");
  }

  Future<void> addBanner({
    required String title,
    required String description,
    File? image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/banners/view/');
    final request = http.MultipartRequest('POST', url);

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['description'] = description;

    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to add banner");
    }
  }

  Future<void> updateBanner({
    required int bannerId,
    required String title,
    required String description,
    File? image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/banners/update/$bannerId/',
    );

    final request = http.MultipartRequest('PUT', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['description'] = description;

    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to update banner");
    }
  }

  Future<void> deleteBanner({required int bannerId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/banners/update/$bannerId/',
    );

    final response = await http.delete(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200 &&
        response.statusCode != 204 &&
        response.statusCode != 201) {
      throw Exception("Failed to delete banner");
    }
  }

  Future<Map<String, dynamic>> createRazorpayOrder({
    required double amount,
    required String fullName,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String country,
    required String note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/checkout/razorpay/create/',
    );

    final body = {
      "amount": amount.toStringAsFixed(2),
      "full_name": fullName,
      "phone": phone,
      "address": address,
      "city": city,
      "state": state,
      "pincode": pincode,
      "country": country,
      "note": note,
    };

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    }

    throw Exception(
      decoded['error'] ??
          decoded['detail'] ??
          decoded['message'] ??
          "Failed to create Razorpay order",
    );
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/checkout/razorpay/verify/',
    );

    final body = {
      "razorpay_order_id": razorpayOrderId,
      "razorpay_payment_id": razorpayPaymentId,
      "razorpay_signature": razorpaySignature,
    };

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    }

    throw Exception(
      decoded['message'] ??
          decoded['error'] ??
          decoded['detail'] ??
          "Payment verification failed",
    );
  }

  // ─── Booked Orders ──────────────────────────────────────────

  Future<List<OrderModel>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/orders/view/');
    print("GET ORDERS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET ORDERS STATUS: ${response.statusCode}");
    print("GET ORDERS BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => OrderModel.fromJson(e)).toList();
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load orders";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<OrderModel> getOrderDetail({required int orderId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/orders/update/$orderId/',
    );
    print("GET ORDER DETAIL URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET ORDER DETAIL STATUS: ${response.statusCode}");
    print("GET ORDER DETAIL BODY: ${response.body}");

    if (response.statusCode == 200) {
      return OrderModel.fromJson(jsonDecode(response.body));
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load order details";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Shop Received Orders ────────────────────────────────────

  Future<List<OrderModel>> getShopOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/shop/orders/view/');
    print("GET SHOP ORDERS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET SHOP ORDERS STATUS: ${response.statusCode}");
    print("GET SHOP ORDERS BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => OrderModel.fromJson(e)).toList();
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load shop orders";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<OrderModel> getShopOrderDetail({required int orderId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/shop/orders/detail/view/$orderId/',
    );
    print("GET SHOP ORDER DETAIL URL: $url");

    final response = await http.get(
      url,

      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET SHOP ORDER DETAIL STATUS: ${response.statusCode}");
    print("GET SHOP ORDER DETAIL BODY: ${response.body}");

    if (response.statusCode == 200) {
      return OrderModel.fromJson(jsonDecode(response.body));
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load shop order details";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getOrderPaymentStatus({required int orderId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/orders/$orderId/payment/status/',
    );
    print("GET PAYMENT STATUS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET PAYMENT STATUS CODE: ${response.statusCode}");
    print("GET PAYMENT STATUS RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      String errorMessage = "Failed to load payment status";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> updateOrderPaymentStatus({
    required int orderId,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/orders/$orderId/payment/status/',
    );
    final body = {"seller_payment_status": status.toUpperCase()};

    print("UPDATE PAYMENT STATUS URL: $url");
    print("UPDATE PAYMENT STATUS BODY: $body");

    final response = await http.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("UPDATE PAYMENT STATUS CODE: ${response.statusCode}");
    print("UPDATE PAYMENT STATUS RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map<String, dynamic>
          ? decoded
          : {"seller_payment_status": status};
    } else {
      String errorMessage = "Failed to update payment status";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> updateShopOrderStatus({
    required int orderId,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/shop/orders/$orderId/status/',
    );
    final body = {"status": status};

    print("UPDATE SHOP ORDER STATUS URL: $url");
    print("UPDATE SHOP ORDER STATUS BODY: $body");

    final response = await http.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("UPDATE SHOP ORDER STATUS CODE: ${response.statusCode}");
    print("UPDATE SHOP ORDER STATUS RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map<String, dynamic> ? decoded : {"status": status};
    } else {
      String errorMessage = "Failed to update order status";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> toggleShopStatus(bool isOpen) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/shop/status/update/view/',
    );
    final body = {"is_open": isOpen};

    print("TOGGLE SHOP STATUS URL: $url");
    print("TOGGLE SHOP STATUS BODY: $body");

    final response = await http.patch(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("TOGGLE SHOP STATUS CODE: ${response.statusCode}");
    print("TOGGLE SHOP STATUS RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      String errorMessage = "Failed to toggle shop status";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>?> getSellerBankDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/seller/bank/details/view/');

    print("GET SELLER BANK DETAILS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET SELLER BANK DETAILS CODE: ${response.statusCode}");
    print("GET SELLER BANK DETAILS RESPONSE: ${response.body}");

    if (response.statusCode == 404) {
      return null;
    }

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map<String, dynamic> && decoded['status'] == 'success') {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is List && data.isNotEmpty) {
          return data.first as Map<String, dynamic>;
        }
      }
      return null;
    } else {
      String errorMessage = "Failed to load bank details";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> addSellerBankDetails({
    required String accountHolderName,
    required String bankName,
    required String branchName,
    required String accountNumber,
    required String ifscCode,
    required String upiId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/seller/bank/details/view/');
    final body = {
      "account_holder_name": accountHolderName,
      "bank_name": bankName,
      "branch_name": branchName,
      "account_number": accountNumber,
      "ifsc_code": ifscCode,
      "upi_id": upiId,
    };

    print("ADD SELLER BANK DETAILS URL: $url");
    print("ADD SELLER BANK DETAILS BODY: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("ADD SELLER BANK DETAILS CODE: ${response.statusCode}");
    print("ADD SELLER BANK DETAILS RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      String errorMessage = "Failed to add bank details";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> updateSellerBankDetails({
    required int id,
    required String accountHolderName,
    required String bankName,
    required String branchName,
    required String accountNumber,
    required String ifscCode,
    required String upiId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/seller/bank/details/update/$id/');
    final body = {
      "account_holder_name": accountHolderName,
      "bank_name": bankName,
      "branch_name": branchName,
      "account_number": accountNumber,
      "ifsc_code": ifscCode,
      "upi_id": upiId,
    };

    print("UPDATE SELLER BANK DETAILS URL: $url");
    print("UPDATE SELLER BANK DETAILS BODY: $body");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("UPDATE SELLER BANK DETAILS CODE: ${response.statusCode}");
    print("UPDATE SELLER BANK DETAILS RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      String errorMessage = "Failed to update bank details";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> deleteSellerBankDetails({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/seller/bank/details/update/$id/');

    print("DELETE SELLER BANK DETAILS URL: $url");

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DELETE SELLER BANK DETAILS CODE: ${response.statusCode}");
    print("DELETE SELLER BANK DETAILS RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      String errorMessage = "Failed to delete bank details";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getShopDashboard(String startDate, String endDate) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/shop/dashboard/?start_date=$startDate&end_date=$endDate',
    );

    print("GET SHOP DASHBOARD URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET SHOP DASHBOARD CODE: ${response.statusCode}");
    print("GET SHOP DASHBOARD RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      String errorMessage = "Failed to load dashboard data";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Admin Orders ──────────────────────────────────────────

  Future<Map<String, dynamic>> getAdminOrders({
    int? page,
    String? startDate,
    String? endDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();
    if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/orders/view/',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    print("GET ADMIN ORDERS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET ADMIN ORDERS STATUS: ${response.statusCode}");
    print("GET ADMIN ORDERS BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic>) {
        final List resultsJson = decoded['results'] ?? [];
        return {
          'count': decoded['count'] ?? 0,
          'next': decoded['next'],
          'previous': decoded['previous'],
          'results': List<OrderModel>.from(
            resultsJson.map((item) => OrderModel.fromJson(item)),
          ),
        };
      }
      throw Exception("Unexpected response format");
    } else {
      String errorMessage = "Failed to load admin orders";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<OrderModel> getAdminOrderDetail({required int orderId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/orders/detail/view/$orderId/',
    );
    print("GET ADMIN ORDER DETAIL URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET ADMIN ORDER DETAIL STATUS: ${response.statusCode}");
    print("GET ADMIN ORDER DETAIL BODY: ${response.body}");

    if (response.statusCode == 200) {
      return OrderModel.fromJson(jsonDecode(response.body));
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load admin order details";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getUnpaidPayouts({int? page}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/payouts/pending/',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    print("GET UNPAID PAYOUTS URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET UNPAID PAYOUTS STATUS: ${response.statusCode}");
    print("GET UNPAID PAYOUTS BODY: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic>) {
        final List resultsJson = decoded['results'] ?? [];
        return {
          'count': decoded['count'] ?? 0,
          'next': decoded['next'],
          'previous': decoded['previous'],
          'results': List<OrderModel>.from(
            resultsJson.map((item) => OrderModel.fromJson(item)),
          ),
        };
      }
      throw Exception("Unexpected response format");
    } else {
      String errorMessage = "Failed to load unpaid payouts";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<OrderModel> getUnpaidPayoutDetail({required int orderId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/payouts/pending/$orderId/',
    );
    print("GET UNPAID PAYOUT DETAIL URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET UNPAID PAYOUT DETAIL STATUS: ${response.statusCode}");
    print("GET UNPAID PAYOUT DETAIL BODY: ${response.body}");

    if (response.statusCode == 200) {
      return OrderModel.fromJson(jsonDecode(response.body));
    } else {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to load unpaid payout details";
      if (decoded is Map<String, dynamic>) {
        errorMessage =
            decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Admin Platform Fees ──────────────────────────────────────

  Future<List<PlatformFeeModel>> getPlatformFees() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/admin/platform/fees/view/');
    print("GET PLATFORM FEES URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET PLATFORM FEES STATUS CODE: ${response.statusCode}");
    print("GET PLATFORM FEES RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => PlatformFeeModel.fromJson(e)).toList();
    } else {
      String errorMessage = "Failed to load platform fees";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<PlatformFeeModel> createPlatformFee({
    required String name,
    required String amount,
    required bool isActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/admin/platform/fees/view/');
    final body = {
      "name": name,
      "amount": amount,
      "is_active": isActive,
    };

    print("POST PLATFORM FEE URL: $url");
    print("POST PLATFORM FEE BODY: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("POST PLATFORM FEE STATUS CODE: ${response.statusCode}");
    print("POST PLATFORM FEE RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return PlatformFeeModel.fromJson(decoded);
    } else {
      String errorMessage = "Failed to create platform fee";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<PlatformFeeModel> updatePlatformFee({
    required int id,
    required String name,
    required String amount,
    required bool isActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/platform/fees/update/$id/',
    );
    final body = {
      "name": name,
      "amount": amount,
      "is_active": isActive,
    };

    print("PUT PLATFORM FEE URL: $url");
    print("PUT PLATFORM FEE BODY: $body");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("PUT PLATFORM FEE STATUS CODE: ${response.statusCode}");
    print("PUT PLATFORM FEE RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return PlatformFeeModel.fromJson(decoded);
    } else {
      String errorMessage = "Failed to update platform fee";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deletePlatformFee({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/platform/fees/update/$id/',
    );

    print("DELETE PLATFORM FEE URL: $url");

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DELETE PLATFORM FEE STATUS CODE: ${response.statusCode}");

    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to delete platform fee";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Admin Convenience Fees ──────────────────────────────────

  Future<List<ConvenienceFeeModel>> getConvenienceFees() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/admin/convenience/fees/view/');
    print("GET CONVENIENCE FEES URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET CONVENIENCE FEES STATUS CODE: ${response.statusCode}");
    print("GET CONVENIENCE FEES RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => ConvenienceFeeModel.fromJson(e)).toList();
    } else {
      String errorMessage = "Failed to load convenience fees";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<ConvenienceFeeModel> createConvenienceFee({
    required String name,
    required String amount,
    required bool isActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/admin/convenience/fees/view/');
    final body = {
      "name": name,
      "amount": amount,
      "is_active": isActive,
    };

    print("POST CONVENIENCE FEE URL: $url");
    print("POST CONVENIENCE FEE BODY: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("POST CONVENIENCE FEE STATUS CODE: ${response.statusCode}");
    print("POST CONVENIENCE FEE RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ConvenienceFeeModel.fromJson(decoded);
    } else {
      String errorMessage = "Failed to create convenience fee";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<ConvenienceFeeModel> updateConvenienceFee({
    required int id,
    required String name,
    required String amount,
    required bool isActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/convenience/fees/update/$id/',
    );
    final body = {
      "name": name,
      "amount": amount,
      "is_active": isActive,
    };

    print("PUT CONVENIENCE FEE URL: $url");
    print("PUT CONVENIENCE FEE BODY: $body");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("PUT CONVENIENCE FEE STATUS CODE: ${response.statusCode}");
    print("PUT CONVENIENCE FEE RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ConvenienceFeeModel.fromJson(decoded);
    } else {
      String errorMessage = "Failed to update convenience fee";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteConvenienceFee({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/convenience/fees/update/$id/',
    );

    print("DELETE CONVENIENCE FEE URL: $url");

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DELETE CONVENIENCE FEE STATUS CODE: ${response.statusCode}");

    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to delete convenience fee";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // ─── Admin Delivery Charges ──────────────────────────────────

  Future<List<DeliveryChargeModel>> getDeliveryCharges() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/admin/delivery/charges/view/');
    print("GET DELIVERY CHARGES URL: $url");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("GET DELIVERY CHARGES STATUS CODE: ${response.statusCode}");
    print("GET DELIVERY CHARGES RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] ?? []);
      return items.map((e) => DeliveryChargeModel.fromJson(e)).toList();
    } else {
      String errorMessage = "Failed to load delivery charges";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<DeliveryChargeModel> createDeliveryCharge({
    required String name,
    required String amount,
    required String minOrderAmount,
    required bool isActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/admin/delivery/charges/view/');
    final body = {
      "name": name,
      "amount": amount,
      "min_order_amount": minOrderAmount,
      "is_active": isActive,
    };

    print("POST DELIVERY CHARGE URL: $url");
    print("POST DELIVERY CHARGE BODY: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("POST DELIVERY CHARGE STATUS CODE: ${response.statusCode}");
    print("POST DELIVERY CHARGE RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return DeliveryChargeModel.fromJson(decoded);
    } else {
      String errorMessage = "Failed to create delivery charge";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<DeliveryChargeModel> updateDeliveryCharge({
    required int id,
    required String name,
    required String amount,
    required String minOrderAmount,
    required bool isActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/delivery/charges/update/$id/',
    );
    final body = {
      "name": name,
      "amount": amount,
      "min_order_amount": minOrderAmount,
      "is_active": isActive,
    };

    print("PUT DELIVERY CHARGE URL: $url");
    print("PUT DELIVERY CHARGE BODY: $body");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("PUT DELIVERY CHARGE STATUS CODE: ${response.statusCode}");
    print("PUT DELIVERY CHARGE RESPONSE: ${response.body}");

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return DeliveryChargeModel.fromJson(decoded);
    } else {
      String errorMessage = "Failed to update delivery charge";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteDeliveryCharge({required int id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse(
      '${ApiConstants.api}api/grocery/admin/delivery/charges/update/$id/',
    );

    print("DELETE DELIVERY CHARGE URL: $url");

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DELETE DELIVERY CHARGE STATUS CODE: ${response.statusCode}");

    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = jsonDecode(response.body);
      String errorMessage = "Failed to delete delivery charge";
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['detail']?.toString() ?? decoded['message']?.toString() ?? decoded.toString();
      }
      throw Exception(errorMessage);
    }
  }
}

