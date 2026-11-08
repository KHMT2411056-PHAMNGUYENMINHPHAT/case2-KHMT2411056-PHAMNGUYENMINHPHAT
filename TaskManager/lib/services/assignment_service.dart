import '../models/user.dart';
import 'api_client.dart';

class AssigneeResult {
  final String? primaryAssigneeId;
  final List<AppUser> assignees;
  final String message;
  AssigneeResult(this.primaryAssigneeId, this.assignees, [this.message = '']);

  factory AssigneeResult.fromJson(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    return AssigneeResult(
      map['primaryAssigneeId']?.toString(),
      (map['assignees'] as List? ?? [])
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      (map['message'] ?? '').toString(),
    );
  }
}

class AssignmentService {
  static Future<AssigneeResult> getAssignees(String taskId) async {
    return AssigneeResult.fromJson(await ApiClient.get('/tasks/$taskId/assignees'));
  }

  /// Giao việc cho nhiều người + chọn người phụ trách chính
  static Future<AssigneeResult> assign(String taskId,
      {List<String> userIds = const [], List<String> emails = const [], String? primaryAssigneeId}) async {
    final data = await ApiClient.post('/tasks/$taskId/assignees', {
      'userIds': userIds,
      'emails': emails,
      if (primaryAssigneeId != null) 'primaryAssigneeId': primaryAssigneeId,
    });
    return AssigneeResult.fromJson(data);
  }

  static Future<AssigneeResult> setPrimary(String taskId, String userId) async {
    final data = await ApiClient.patch('/tasks/$taskId/assignees/$userId', {'isPrimary': true});
    return AssigneeResult.fromJson(data);
  }

  static Future<AssigneeResult> remove(String taskId, String userId) async {
    return AssigneeResult.fromJson(await ApiClient.delete('/tasks/$taskId/assignees/$userId'));
  }
}
