import 'user.dart';

class TaskActivity {
  final String id;
  final String action;
  final Map<String, dynamic> details;
  final AppUser? user;
  final List<AppUser> relatedUsers;
  final DateTime? createdAt;

  TaskActivity({
    required this.id,
    required this.action,
    required this.details,
    this.user,
    this.relatedUsers = const [],
    this.createdAt,
  });

  factory TaskActivity.fromJson(Map<String, dynamic> j) => TaskActivity(
        id: (j['_id'] ?? '').toString(),
        action: (j['action'] ?? '').toString(),
        details: j['details'] is Map ? Map<String, dynamic>.from(j['details']) : {},
        user: j['user'] is Map ? AppUser.fromJson(Map<String, dynamic>.from(j['user'])) : null,
        relatedUsers: (j['relatedUsers'] as List? ?? [])
            .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
      );
}
