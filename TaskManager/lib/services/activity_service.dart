import '../models/task_activity.dart';
import 'api_client.dart';

class ActivityService {
  static Future<List<TaskActivity>> getByTask(String taskId) async {
    final data = await ApiClient.get('/tasks/$taskId/activities');
    return (data as List).map((e) => TaskActivity.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
