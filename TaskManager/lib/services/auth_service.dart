import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://localhost:3000/api/auth';

  // Token của người đang đăng nhập
  static String? token;

  static const Duration _timeout = Duration(seconds: 10);

  static Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> register(
      String fullName, String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': fullName,
              'email': email,
              'password': password,
            }),
          )
          .timeout(_timeout);
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Không thể kết nối đến server'};
    }
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (data['token'] != null) {
        token = data['token']; // lưu token sau khi đăng nhập
      }
      return data;
    } catch (e) {
      return {'message': 'Không thể kết nối đến server'};
    }
  }

  static void logout() {
    token = null;
  }

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/me'), headers: _authHeaders)
          .timeout(_timeout);
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Không thể kết nối đến server'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
      String fullName, String avatarUrl) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/me'),
            headers: _authHeaders,
            body: jsonEncode({'fullName': fullName, 'avatarUrl': avatarUrl}),
          )
          .timeout(_timeout);
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Không thể kết nối đến server'};
    }
  }

  static Future<Map<String, dynamic>> changePassword(
      String oldPassword, String newPassword) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/change-password'),
            headers: _authHeaders,
            body: jsonEncode(
                {'oldPassword': oldPassword, 'newPassword': newPassword}),
          )
          .timeout(_timeout);
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Không thể kết nối đến server'};
    }
  }
}