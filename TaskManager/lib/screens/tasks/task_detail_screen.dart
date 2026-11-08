import 'package:flutter/material.dart';

import '../../models/task_detail.dart';
import '../../models/user.dart';
import '../../services/task_detail_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/task_labels.dart';
import '../../widgets/badges.dart';
import '../../widgets/loading_view.dart';
import '../assignment/assign_task_screen.dart';
import '../sharing/task_sharing_screen.dart';

/// Màn hình 4 — Chi tiết công việc: mô tả, thời hạn, trạng thái, người tạo,
/// người phụ trách, người được chia sẻ; mở giao việc / quản lý chia sẻ;
/// theo dõi tiến độ (đổi trạng thái theo quyền).
///
/// Mở từ danh sách:
///   final changed = await Navigator.push(context,
///     MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)));
///   if (changed == true) _loadTasks();
class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  /// (Tùy chọn) mở màn hình sửa của phần B. Trả về true nếu đã sửa.
  final Future<bool?> Function(BuildContext context, TaskDetail task)? onEdit;

  const TaskDetailScreen({super.key, required this.taskId, this.onEdit});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskDetail? _task;
  bool _loading = true;
  bool _updatingStatus = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _task == null;
      _error = null;
    });
    try {
      final t = await TaskDetailService.getDetail(widget.taskId);
      if (mounted) setState(() => _task = t);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    final t = _task!;
    if (status == t.status) return;
    setState(() => _updatingStatus = true);
    try {
      await TaskDetailService.updateStatus(t.id, status);
      _changed = true;
      await _load();
      if (mounted) showResult(context, 'Đã chuyển sang "${TaskLabels.status(status)}"');
    } catch (e) {
      if (mounted) showResult(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Xóa công việc', message: 'Bạn chắc chắn muốn xóa công việc này?', okText: 'Xóa');
    if (!ok) return;
    try {
      await TaskDetailService.delete(_task!.id);
      if (!mounted) return;
      showResult(context, 'Đã xóa công việc');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showResult(context, e.toString(), error: true);
    }
  }

  Future<void> _open(Widget screen) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => screen));
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  void _onMenu(String value) {
    final t = _task!;
    switch (value) {
      case 'assign':
        _open(AssignTaskScreen(taskId: t.id, taskTitle: t.title));
        break;
      case 'share':
        _open(TaskSharingScreen(taskId: t.id, taskTitle: t.title, canManage: t.access.canManageShares));
        break;
      case 'delete':
        _delete();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
          actions: [
            if (t != null && t.access.canEdit && widget.onEdit != null)
              IconButton(
                tooltip: 'Chỉnh sửa',
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final changed = await widget.onEdit!(context, t);
                  if (changed == true) {
                    _changed = true;
                    _load();
                  }
                },
              ),
            if (t != null)
              PopupMenuButton<String>(
                onSelected: _onMenu,
                itemBuilder: (_) => [
                  if (t.access.canAssign)
                    const PopupMenuItem(
                        value: 'assign',
                        child: ListTile(leading: Icon(Icons.person_add), title: Text('Giao việc'))),
                  PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                          leading: const Icon(Icons.share),
                          title: Text(t.access.canManageShares ? 'Chia sẻ & quyền' : 'Thành viên'))),
                  if (t.access.canDelete)
                    const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                            leading: Icon(Icons.delete_outline, color: Colors.red),
                            title: Text('Xóa', style: TextStyle(color: Colors.red)))),
                ],
              ),
          ],
        ),
        body: _loading
            ? const LoadingView()
            : (_error != null && t == null)
                ? ErrorView(message: _error!, onRetry: _load)
                : RefreshIndicator(onRefresh: _load, child: _buildBody(t!)),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _personTile(AppUser? u, {String? note}) {
    if (u == null) {
      return const Text('Chưa có', style: TextStyle(color: Colors.grey));
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(u),
      title: Text(u.displayName),
      subtitle: Text(note == null ? u.email : '${u.email} • $note'),
    );
  }

  Widget _buildBody(TaskDetail t) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          StatusBadge(t.status),
          PriorityBadge(t.priority),
          RoleBadge(t.myRole),
        ]),

        _section(
          'Mô tả',
          Text(t.description.isEmpty ? 'Không có mô tả' : t.description,
              style: t.description.isEmpty ? const TextStyle(color: Colors.grey) : null),
        ),

        _section(
          'Thời hạn',
          Column(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Ngày bắt đầu'),
              trailing: Text(DateFormatter.date(t.startDate)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event, color: t.isOverdue ? Colors.red : null),
              title: const Text('Hạn hoàn thành'),
              subtitle: t.dueDate == null || t.status == 'completed'
                  ? null
                  : Text(DateFormatter.dueText(t.dueDate),
                      style: TextStyle(color: t.isOverdue ? Colors.red : Colors.green)),
              trailing: Text(DateFormatter.dateTime(t.dueDate)),
            ),
          ]),
        ),

        // ---- Theo dõi tiến độ ----
        _section(
          'Tiến độ',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: TaskLabels.progress(t.status),
                  minHeight: 10,
                  color: TaskLabels.statusColor(t.status),
                ),
              ),
              const SizedBox(height: 4),
              Text('${(TaskLabels.progress(t.status) * 100).round()}% — ${TaskLabels.status(t.status)}'),
              const SizedBox(height: 12),
              if (t.access.canUpdateStatus)
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'todo', label: Text('Chưa làm')),
                    ButtonSegment(value: 'in_progress', label: Text('Đang làm')),
                    ButtonSegment(value: 'completed', label: Text('Hoàn thành')),
                  ],
                  selected: {t.status},
                  onSelectionChanged:
                      _updatingStatus ? null : (s) => _changeStatus(s.first),
                )
              else
                const Text('Bạn chỉ có quyền xem công việc này',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ),
        ),

        _section('Người tạo', _personTile(t.creator, note: DateFormatter.dateTime(t.createdAt))),
        _section('Người phụ trách chính', _personTile(t.primaryAssignee)),
        _section(
          'Người được giao (${t.assignees.length})',
          t.assignees.isEmpty
              ? const Text('Chưa giao cho ai', style: TextStyle(color: Colors.grey))
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: t.assignees
                      .map((u) => Chip(
                            avatar: UserAvatar(u, radius: 12),
                            label: Text(u.displayName),
                            deleteIcon: u.id == t.primaryAssigneeId
                                ? const Icon(Icons.star, color: Colors.amber, size: 18)
                                : null,
                            onDeleted: u.id == t.primaryAssigneeId ? () {} : null,
                          ))
                      .toList(),
                ),
        ),
        _section(
          'Người được chia sẻ',
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.group_outlined),
            title: Text('${t.shareCount} người'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _onMenu('share'),
          ),
        ),

        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (t.access.canAssign)
            OutlinedButton.icon(
              onPressed: () => _onMenu('assign'),
              icon: const Icon(Icons.person_add),
              label: const Text('Giao việc'),
            ),
          OutlinedButton.icon(
            onPressed: () => _onMenu('share'),
            icon: const Icon(Icons.share),
            label: Text(t.access.canManageShares ? 'Quản lý chia sẻ' : 'Xem thành viên'),
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }
}
