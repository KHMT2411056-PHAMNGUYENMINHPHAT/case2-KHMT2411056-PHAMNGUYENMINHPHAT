import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class TaskApiService {
  static const String baseUrl = 'http://10.0.2.2:3000/api/tasks';

  // GET
  static Future<List<Task>> fetchTasks() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Task.fromJson(data)).toList();
    } else {
      throw Exception('Lỗi khi tải danh sách công việc');
    }
  }

  // POST
  static Future<bool> createTask(Map<String, dynamic> taskData) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(taskData),
    );
    return response.statusCode == 201;
  }

  // PUT
  static Future<bool> updateTask(String id, Map<String, dynamic> taskData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(taskData),
    );
    return response.statusCode == 200;
  }

  // DELETE
  static Future<bool> deleteTask(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    return response.statusCode == 200;
  }
}