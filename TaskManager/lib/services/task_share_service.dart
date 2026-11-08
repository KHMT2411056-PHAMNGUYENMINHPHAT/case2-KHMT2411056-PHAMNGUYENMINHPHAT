import '../models/task_share.dart';
import 'api_client.dart';

class ShareResult {
  final List<TaskShare> shares;
  final String message;
  ShareResult(this.shares, this.message);
}

class TaskShareService {
  static List<TaskShare> _parse(dynamic list) => (list as List? ?? [])
      .map((e) => TaskShare.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  static Future<List<TaskShare>> getShares(String taskId) async {
    return _parse(await ApiClient.get('/tasks/$taskId/shares'));
  }

  static Future<ShareResult> share(String taskId,
      {required List<String> userIds, String permission = 'viewer'}) async {
    final data = await ApiClient.post('/tasks/$taskId/shares', {
      'userIds': userIds,
      'permission': permission,
    });
    return ShareResult(_parse(data['shares']), (data['message'] ?? '').toString());
  }

  static Future<ShareResult> updatePermission(String taskId, String shareId, String permission) async {
    final data = await ApiClient.patch('/tasks/$taskId/shares/$shareId', {'permission': permission});
    return ShareResult(_parse(data['shares']), (data['message'] ?? '').toString());
  }

  static Future<ShareResult> revoke(String taskId, String shareId) async {
    final data = await ApiClient.delete('/tasks/$taskId/shares/$shareId');
    return ShareResult(_parse(data['shares']), (data['message'] ?? '').toString());
  }
}
