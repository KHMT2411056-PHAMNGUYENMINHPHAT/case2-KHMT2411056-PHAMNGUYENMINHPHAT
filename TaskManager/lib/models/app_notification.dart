class AppNotification {
  final String id;
  final String? taskId;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    this.taskId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final task = json['taskId'];
    return AppNotification(
      id: (json['_id'] ?? '').toString(),
      taskId: task == null ? null : (task is Map ? task['_id']?.toString() : task.toString()),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        taskId: taskId,
        type: type,
        title: title,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
