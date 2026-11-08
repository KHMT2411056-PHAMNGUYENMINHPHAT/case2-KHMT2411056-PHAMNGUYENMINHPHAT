import '../models/task_detail.dart';
import 'api_client.dart';

class TaskDetailService {
  static Future<TaskDetail> getDetail(String taskId) async {
    final data = await ApiClient.get('/tasks/$taskId');
    return TaskDetail.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> updateStatus(String taskId, String status) async {
    await ApiClient.patch('/tasks/$taskId/status', {'status': status});
  }

  static Future<void> delete(String taskId) async {
    await ApiClient.delete('/tasks/$taskId');
  }
}
