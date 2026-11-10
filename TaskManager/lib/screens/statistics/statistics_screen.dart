import 'package:flutter/material.dart';

import '../../services/statistics_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/task_labels.dart';
import '../../widgets/badges.dart';
import '../../widgets/loading_view.dart';
import '../tasks/task_detail_screen.dart';

/// Thống kê: theo trạng thái, việc được giao / đang phụ trách, sắp đến hạn & quá hạn.
/// Mở từ màn hình Cá nhân (profile_screen.dart).
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  TaskStats? _tasks;
  AssignmentStats? _assign;
  DeadlineStats? _deadlines;
  int _days = 3;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _tasks == null;
      _error = null;
    });
    try {
      final r = await Future.wait([
        StatisticsService.tasks(),
        StatisticsService.assignments(),
        StatisticsService.deadlines(days: _days),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = r[0] as TaskStats;
        _assign = r[1] as AssignmentStats;
        _deadlines = r[2] as DeadlineStats;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _card(String title, Widget child, {IconData? icon}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _bar(String label, int value, int total, Color color) {
    final ratio = total == 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 12,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ),
        SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _numberBox(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text('$value',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _assignRow(String label, StatusCount c) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text('Chưa làm ${c.todo} • Đang làm ${c.inProgress} • Xong ${c.completed}'),
      trailing: CircleAvatar(child: Text('${c.total}')),
    );
  }

  Widget _taskList(List<TaskBrief> items, {required bool overdue}) {
    if (items.isEmpty) {
      return Text(overdue ? 'Không có công việc quá hạn 👍' : 'Không có công việc sắp đến hạn',
          style: const TextStyle(color: Colors.grey));
    }
    return Column(
      children: items
          .map((t) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(overdue ? Icons.warning_amber : Icons.schedule,
                    color: overdue ? Colors.red : Colors.orange),
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${DateFormatter.dateTime(t.dueDate)} • ${DateFormatter.dueText(t.dueDate)}',
                    style: TextStyle(color: overdue ? Colors.red : null)),
                trailing: PriorityBadge(t.priority),
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)));
                  _load();
                },
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê công việc')),
      body: _loading
          ? const LoadingView(message: 'Đang tải thống kê...')
          : _error != null && _tasks == null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    final s = _tasks!.byStatus;
    final a = _assign!;
    final d = _deadlines!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          _numberBox('Tổng công việc', s.total, Colors.indigo),
          _numberBox('Sắp đến hạn', d.upcomingCount, Colors.orange),
          _numberBox('Quá hạn', d.overdueCount, Colors.red),
        ]),
        const SizedBox(height: 8),
        _card(
          'Theo trạng thái',
          icon: Icons.pie_chart_outline,
          Column(children: [
            _bar(TaskLabels.status('todo'), s.todo, s.total, TaskLabels.statusColor('todo')),
            _bar(TaskLabels.status('in_progress'), s.inProgress, s.total,
                TaskLabels.statusColor('in_progress')),
            _bar(TaskLabels.status('completed'), s.completed, s.total,
                TaskLabels.statusColor('completed')),
            const SizedBox(height: 8),
            Text('Tỉ lệ hoàn thành: ${_tasks!.completionRate}%',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
        _card(
          'Theo mức ưu tiên',
          icon: Icons.flag_outlined,
          Column(
            children: ['high', 'medium', 'low']
                .map((p) => _bar(TaskLabels.priority(p), _tasks!.byPriority[p] ?? 0, s.total,
                    TaskLabels.priorityColor(p)))
                .toList(),
          ),
        ),
        _card(
          'Giao việc & phụ trách',
          icon: Icons.people_outline,
          Column(children: [
            _assignRow('Tôi đang phụ trách chính', a.primary),
            _assignRow('Được giao cho tôi', a.assignedToMe),
            _assignRow('Tôi giao cho người khác', a.delegated),
            _assignRow('Tôi tạo', a.created),
            _assignRow('Được chia sẻ với tôi', a.shared),
          ]),
        ),
        _card(
          'Quá hạn (${d.overdueCount})',
          icon: Icons.warning_amber,
          _taskList(d.overdue, overdue: true),
        ),
        _card(
          'Sắp đến hạn',
          icon: Icons.schedule,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [1, 3, 7]
                    .map((n) => ChoiceChip(
                          label: Text('$n ngày'),
                          selected: _days == n,
                          onSelected: (_) {
                            setState(() => _days = n);
                            _load();
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              _taskList(d.upcoming, overdue: false),
            ],
          ),
        ),
      ],
    );
  }
}
