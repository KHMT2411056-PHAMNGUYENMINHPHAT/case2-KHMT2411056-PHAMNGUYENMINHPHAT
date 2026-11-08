import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import 'auth_service.dart';

class TaskApiService {
  static const String baseUrl = 'http://localhost:3000/api/tasks';

  // Từ phần C, mọi API /api/tasks đều yêu cầu đăng nhập
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Task>> fetchTasks({
    String q = '',
    String status = '',
    String priority = '',
    String scope = '',
    String sortBy = 'createdAt',
    String order = 'desc',
  }) async {
    final params = <String, String>{
      if (q.isNotEmpty) 'q': q,
      if (status.isNotEmpty) 'status': status,
      if (priority.isNotEmpty) 'priority': priority,
      if (scope.isNotEmpty) 'scope': scope,
      'sortBy': sortBy,
      'order': order,
    };
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Task.fromJson(data)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại');
    } else {
      throw Exception('Lỗi khi tải danh sách công việc');
    }
  }

  static Future<bool> createTask(Map<String, dynamic> taskData) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: await _headers(),
      body: json.encode(taskData),
    );
    return response.statusCode == 201;
  }

  static Future<bool> updateTask(String id, Map<String, dynamic> taskData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: await _headers(),
      body: json.encode(taskData),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deleteTask(String id) async {
    final response =
        await http.delete(Uri.parse('$baseUrl/$id'), headers: await _headers());
    return response.statusCode == 200;
  }
}
