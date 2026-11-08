import 'user.dart';

/// Quyền của người dùng hiện tại trên 1 công việc (do backend tính).
class TaskAccess {
  final bool canEdit;
  final bool canUpdateStatus;
  final bool canDelete;
  final bool canAssign;
  final bool canManageShares;

  const TaskAccess({
    this.canEdit = false,
    this.canUpdateStatus = false,
    this.canDelete = false,
    this.canAssign = false,
    this.canManageShares = false,
  });

  factory TaskAccess.fromJson(Map<String, dynamic>? json) {
    final j = json ?? {};
    return TaskAccess(
      canEdit: j['canEdit'] == true,
      canUpdateStatus: j['canUpdateStatus'] == true,
      canDelete: j['canDelete'] == true,
      canAssign: j['canAssign'] == true,
      canManageShares: j['canManageShares'] == true,
    );
  }
}

/// Chi tiết công việc (kèm người tạo, người được giao, vai trò của tôi).
/// Tách riêng với Task của phần B để không làm ảnh hưởng code cũ.
class TaskDetail {
  final String id;
  final String title;
  final String description;
  final String status; // todo | in_progress | completed
  final String priority; // low | medium | high
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final AppUser? creator;
  final List<AppUser> assignees;
  final String? primaryAssigneeId;
  final String? myRole; // owner | assignee | editor | viewer
  final TaskAccess access;
  final int shareCount;

  TaskDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.startDate,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
    this.creator,
    this.assignees = const [],
    this.primaryAssigneeId,
    this.myRole,
    this.access = const TaskAccess(),
    this.shareCount = 0,
  });

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory TaskDetail.fromJson(Map<String, dynamic> json) {
    return TaskDetail(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'todo').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      startDate: _date(json['startDate']),
      dueDate: _date(json['dueDate']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      creator: json['creator'] is Map
          ? AppUser.fromJson(Map<String, dynamic>.from(json['creator']))
          : null,
      assignees: (json['assignees'] as List? ?? [])
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      primaryAssigneeId: json['primaryAssigneeId']?.toString(),
      myRole: json['myRole']?.toString(),
      access: TaskAccess.fromJson(
          json['access'] is Map ? Map<String, dynamic>.from(json['access']) : null),
      shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
    );
  }

  AppUser? get primaryAssignee {
    for (final u in assignees) {
      if (u.id == primaryAssigneeId) return u;
    }
    return null;
  }

  bool get isOverdue =>
      dueDate != null && status != 'completed' && dueDate!.isBefore(DateTime.now());
}
