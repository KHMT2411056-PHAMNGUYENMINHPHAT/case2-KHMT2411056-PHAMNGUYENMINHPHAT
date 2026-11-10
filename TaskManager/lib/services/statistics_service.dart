import 'api_client.dart';

class StatusCount {
  final int todo, inProgress, completed, total;
  StatusCount({this.todo = 0, this.inProgress = 0, this.completed = 0, this.total = 0});

  factory StatusCount.fromJson(dynamic j) {
    final m = j is Map ? j : const {};
    int v(String k) => (m[k] as num?)?.toInt() ?? 0;
    return StatusCount(
        todo: v('todo'), inProgress: v('in_progress'), completed: v('completed'), total: v('total'));
  }
}

class TaskStats {
  final StatusCount byStatus;
  final Map<String, int> byPriority;
  final int completionRate;
  TaskStats(this.byStatus, this.byPriority, this.completionRate);
}

class AssignmentStats {
  final StatusCount created, delegated, assignedToMe, primary, shared;
  AssignmentStats(this.created, this.delegated, this.assignedToMe, this.primary, this.shared);
}

class TaskBrief {
  final String id, title, status, priority;
  final DateTime? dueDate;
  TaskBrief(this.id, this.title, this.status, this.priority, this.dueDate);

  factory TaskBrief.fromJson(Map<String, dynamic> j) => TaskBrief(
        (j['_id'] ?? '').toString(),
        (j['title'] ?? '').toString(),
        (j['status'] ?? 'todo').toString(),
        (j['priority'] ?? 'medium').toString(),
        DateTime.tryParse((j['dueDate'] ?? '').toString())?.toLocal(),
      );
}

class DeadlineStats {
  final int days, upcomingCount, overdueCount;
  final List<TaskBrief> upcoming, overdue;
  DeadlineStats(this.days, this.upcomingCount, this.overdueCount, this.upcoming, this.overdue);
}

class StatisticsService {
  static Future<TaskStats> tasks() async {
    final d = await ApiClient.get('/statistics/tasks');
    final p = d['byPriority'] is Map ? d['byPriority'] as Map : const {};
    return TaskStats(
      StatusCount.fromJson(d['byStatus']),
      {for (final k in ['low', 'medium', 'high']) k: (p[k] as num?)?.toInt() ?? 0},
      (d['completionRate'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<AssignmentStats> assignments() async {
    final d = await ApiClient.get('/statistics/assignments');
    return AssignmentStats(
      StatusCount.fromJson(d['created']),
      StatusCount.fromJson(d['delegated']),
      StatusCount.fromJson(d['assignedToMe']),
      StatusCount.fromJson(d['primary']),
      StatusCount.fromJson(d['shared']),
    );
  }

  static Future<DeadlineStats> deadlines({int days = 3}) async {
    final d = await ApiClient.get('/statistics/deadlines', query: {'days': days});
    List<TaskBrief> list(dynamic l) =>
        (l as List? ?? []).map((e) => TaskBrief.fromJson(Map<String, dynamic>.from(e))).toList();
    return DeadlineStats(
      (d['days'] as num?)?.toInt() ?? days,
      (d['upcomingCount'] as num?)?.toInt() ?? 0,
      (d['overdueCount'] as num?)?.toInt() ?? 0,
      list(d['upcoming']),
      list(d['overdue']),
    );
  }
}
