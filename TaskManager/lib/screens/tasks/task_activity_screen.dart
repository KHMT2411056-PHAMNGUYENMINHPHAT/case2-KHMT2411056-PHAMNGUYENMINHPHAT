import 'package:flutter/material.dart';

import '../../models/task_activity.dart';
import '../../services/activity_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/task_labels.dart';
import '../../widgets/loading_view.dart';

/// Lịch sử hoạt động của công việc (dạng timeline).
class TaskActivityScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  const TaskActivityScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<TaskActivityScreen> createState() => _TaskActivityScreenState();
}

class _TaskActivityScreenState extends State<TaskActivityScreen> {
  List<TaskActivity> _items = [];
  bool _loading = true;
  String? _error;

  static const _fieldNames = {
    'title': 'tên',
    'description': 'mô tả',
    'startDate': 'ngày bắt đầu',
    'dueDate': 'hạn hoàn thành',
    'priority': 'mức ưu tiên',
    'status': 'trạng thái',
    'category': 'danh mục', // field giữ lại từ phần B
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final items = await ActivityService.getByTask(widget.taskId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _names(TaskActivity a) => a.relatedUsers.map((u) => u.displayName).join(', ');

  String _describe(TaskActivity a) {
    final d = a.details;
    switch (a.action) {
      case 'created':
        return 'đã tạo công việc';
      case 'updated':
        {
          final Iterable<dynamic> changes =
              d['changes'] is Map ? (d['changes'] as Map).keys : const <dynamic>[];
          final fields = changes.map((k) => _fieldNames['$k'] ?? '$k').join(', ');
          return 'đã cập nhật $fields';
        }
      case 'status_changed':
        return 'đã đổi trạng thái: ${TaskLabels.status('${d['from']}')} → ${TaskLabels.status('${d['to']}')}';
      case 'assigned':
        return 'đã giao việc cho ${_names(a)}';
      case 'unassigned':
        return 'đã hủy giao việc cho ${_names(a)}';
      case 'primary_changed':
        return a.relatedUsers.isEmpty
            ? 'đã bỏ người phụ trách chính'
            : 'đã chọn ${_names(a)} làm người phụ trách chính';
      case 'shared':
        return 'đã chia sẻ cho ${_names(a)} (${TaskLabels.permission('${d['permission']}')})';
      case 'share_permission_changed':
        return 'đã đổi quyền của ${_names(a)} thành ${TaskLabels.permission('${d['to']}')}';
      case 'share_revoked':
        return 'đã thu hồi quyền của ${_names(a)}';
      default:
        return a.action;
    }
  }

  IconData _icon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_task;
      case 'status_changed':
        return Icons.sync_alt;
      case 'assigned':
      case 'unassigned':
      case 'primary_changed':
        return Icons.person_add_alt;
      case 'shared':
      case 'share_permission_changed':
      case 'share_revoked':
        return Icons.share;
      default:
        return Icons.edit;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử hoạt động')),
      body: _loading
          ? const LoadingView()
          : _error != null && _items.isEmpty
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          EmptyView(message: 'Chưa có hoạt động nào', icon: Icons.history),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length + 1,
                          itemBuilder: (_, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(widget.taskTitle,
                                    style: Theme.of(context).textTheme.titleLarge),
                              );
                            }
                            final a = _items[i - 1];
                            final isLast = i == _items.length;
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Column(children: [
                                    CircleAvatar(radius: 16, child: Icon(_icon(a.action), size: 18)),
                                    if (!isLast)
                                      Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
                                  ]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 16, top: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text.rich(TextSpan(children: [
                                            TextSpan(
                                                text: a.user?.displayName ?? 'Ai đó',
                                                style: const TextStyle(fontWeight: FontWeight.bold)),
                                            TextSpan(text: ' ${_describe(a)}'),
                                          ])),
                                          const SizedBox(height: 2),
                                          Text(DateFormatter.dateTime(a.createdAt),
                                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
