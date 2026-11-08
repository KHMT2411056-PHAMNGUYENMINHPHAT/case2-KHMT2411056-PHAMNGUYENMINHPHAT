import 'user.dart';

class TaskShare {
  final String id;
  final String taskId;
  final AppUser user;
  final String permission; // viewer | editor
  final AppUser? sharedBy;
  final DateTime? createdAt;

  TaskShare({
    required this.id,
    required this.taskId,
    required this.user,
    required this.permission,
    this.sharedBy,
    this.createdAt,
  });

  factory TaskShare.fromJson(Map<String, dynamic> json) {
    return TaskShare(
      id: (json['_id'] ?? '').toString(),
      taskId: (json['taskId'] ?? '').toString(),
      user: AppUser.fromJson(Map<String, dynamic>.from(json['user'] ?? {})),
      permission: (json['permission'] ?? 'viewer').toString(),
      sharedBy: json['sharedBy'] is Map
          ? AppUser.fromJson(Map<String, dynamic>.from(json['sharedBy']))
          : null,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal(),
    );
  }
}
