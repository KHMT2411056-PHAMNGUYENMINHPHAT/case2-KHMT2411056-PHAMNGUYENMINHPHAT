class Task {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? myRole; // owner | assignee | editor | viewer (phần C)

  bool get isOwner => myRole == 'owner';

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.startDate,
    this.dueDate,
    this.myRole,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      priority: _normPriority(json['priority']),
      status: _normStatus(json['status']),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate']).toLocal()
          : null,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate']).toLocal()
          : null,
      myRole: json['myRole']?.toString(),
    );
  }

  // Phần C dùng: todo | in_progress | completed và low | medium | high
  // (vẫn đọc được giá trị cũ của phần B: Pending/InProgress/Completed, Low/Medium/High)
  static String _normStatus(dynamic v) {
    final s = (v ?? '').toString().trim().toLowerCase();
    if (s == 'pending' || s.isEmpty) return 'todo';
    if (s == 'inprogress') return 'in_progress';
    return s;
  }

  static String _normPriority(dynamic v) {
    final s = (v ?? '').toString().trim().toLowerCase();
    return s.isEmpty ? 'medium' : s;
  }
}