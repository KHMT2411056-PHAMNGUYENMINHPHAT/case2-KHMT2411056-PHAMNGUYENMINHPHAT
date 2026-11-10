import '../models/app_notification.dart';
import 'api_client.dart';

class NotificationService {
  static Future<List<AppNotification>> getAll({bool unreadOnly = false}) async {
    final data = await ApiClient.get('/notifications', query: {if (unreadOnly) 'unreadOnly': 'true'});
    return (data as List).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<int> unreadCount() async {
    final data = await ApiClient.get('/notifications/unread-count');
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  static Future<void> markRead(String id) async {
    await ApiClient.patch('/notifications/$id/read');
  }

  static Future<void> markAllRead() async {
    await ApiClient.patch('/notifications/read-all');
  }
}
