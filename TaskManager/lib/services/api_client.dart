import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lỗi trả về từ API (đã có message tiếng Việt từ backend).
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Client dùng chung cho các service mới (phần C, D, E).
///
/// ⚠️ Sửa [baseUrl] cho GIỐNG baseUrl trong auth_service.dart / task_api_service.dart:
///  - Android emulator : http://10.0.2.2:3000/api
///  - Chrome (web)      : http://localhost:3000/api
///  - Điện thoại thật   : http://<IP máy tính>:3000/api
class ApiClient {
  // Giống auth_service.dart / task_api_service.dart (đang chạy trên Chrome/web)
  static const String baseUrl = 'http://localhost:3000/api';

  /// Key lưu token trong SharedPreferences. Nếu auth_service.dart của bạn
  /// lưu với key khác, thêm key đó vào ĐẦU danh sách này.
  static const List<String> tokenKeys = [
    'token', 'accessToken', 'access_token', 'jwt', 'authToken', 'auth_token',
  ];

  static const Duration _timeout = Duration(seconds: 15);

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in tokenKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null) return uri;
    final clean = <String, String>{};
    query.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) clean[k] = v.toString();
    });
    return uri.replace(queryParameters: clean.isEmpty ? null : clean);
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _send(() async => http.get(_uri(path, query), headers: await _headers()));
  }

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    return _send(() async => http.post(_uri(path),
        headers: await _headers(), body: jsonEncode(body ?? {})));
  }

  static Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    return _send(() async => http.put(_uri(path),
        headers: await _headers(), body: jsonEncode(body ?? {})));
  }

  static Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    return _send(() async => http.patch(_uri(path),
        headers: await _headers(), body: jsonEncode(body ?? {})));
  }

  static Future<dynamic> delete(String path) async {
    return _send(() async => http.delete(_uri(path), headers: await _headers()));
  }

  static Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('Máy chủ phản hồi quá lâu, vui lòng thử lại');
    } on http.ClientException {
      throw ApiException('Không kết nối được máy chủ. Kiểm tra backend và baseUrl');
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        data = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    String message = 'Có lỗi xảy ra (mã ${res.statusCode})';
    if (data is Map && data['message'] != null) message = data['message'].toString();
    if (res.statusCode == 401) message = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại';
    throw ApiException(message, statusCode: res.statusCode);
  }
}
