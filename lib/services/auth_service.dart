import 'dart:convert';
import 'package:grocery_app/models/district_model.dart';
import 'package:grocery_app/models/state_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../models/country_model.dart';
import '../models/register_response_model.dart';

class AuthService {
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

  Future<RegisterResponseModel> registerUser({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required String userType,
    required int country,
    required int state,
    required int district,
  }) async {
    final url = Uri.parse('${ApiConstants.api}api/grocery/register/');

    final body = {
      "first_name": firstName,
      "last_name": lastName,
      "phone": phone,
      "email": email,
      "password": password,
      "user_type": userType,
      "country": country,
      "state": state,
      "district": district,
    };

    print("REGISTER URL: $url");
    print("REGISTER BODY: $body");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("REGISTER STATUS CODE: ${response.statusCode}");
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
    await prefs.setInt('user_id', response.user.id);
    await prefs.setString('phone', response.user.phone);
    await prefs.setString('first_name', response.user.firstName);
    await prefs.setString('last_name', response.user.lastName);
    await prefs.setString('email', response.user.email);
    await prefs.setString('user_type', response.user.userType);
    await prefs.setString('approval_status', response.user.approvalStatus);
    await prefs.setString('profile_picture', response.user.profilePicture);

    if (response.user.country != null) {
      await prefs.setInt('country', response.user.country!);
    }

    if (response.user.state != null) {
      await prefs.setInt('state', response.user.state!);
    }

    if (response.user.district != null) {
      await prefs.setInt('district', response.user.district!);
    }
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

  Future<List<CountryModel>> getCountries() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/countries/view/');

    print("COUNTRIES GET URL: $url");
    print("COUNTRIES TOKEN: $token");

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
      return List<CountryModel>.from(
        decoded.map((item) => CountryModel.fromJson(item)),
      );
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

    print("COUNTRY POST URL: $url");
    print("COUNTRY POST BODY: $body");
    print("COUNTRY TOKEN: $token");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    print("COUNTRY POST STATUS CODE: ${response.statusCode}");
    print("COUNTRY POST RESPONSE BODY: ${response.body}");

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

  Future<List<StateModel>> getStates() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/states/view/');

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
      return List<StateModel>.from(
        decoded.map((item) => StateModel.fromJson(item)),
      );
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

    print("ADD STATE STATUS CODE: ${response.statusCode}");
    print("ADD STATE RESPONSE BODY: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to add state");
    }
  }

  Future<List<DistrictModel>> getDistricts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access') ?? '';

    final url = Uri.parse('${ApiConstants.api}api/grocery/districts/view/');

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
      return List<DistrictModel>.from(
        decoded.map((item) => DistrictModel.fromJson(item)),
      );
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

    print("ADD DISTRICT STATUS CODE: ${response.statusCode}");
    print("ADD DISTRICT RESPONSE BODY: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? "Failed to add district");
    }
  }
}
