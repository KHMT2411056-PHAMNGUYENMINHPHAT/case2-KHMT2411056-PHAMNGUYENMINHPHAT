import '../models/user.dart';
import 'api_client.dart';

class UserService {
  /// Tìm người dùng theo họ tên hoặc email
  static Future<List<AppUser>> search(String q) async {
    if (q.trim().isEmpty) return [];
    final data = await ApiClient.get('/users/search', query: {'q': q.trim()});
    return (data as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
