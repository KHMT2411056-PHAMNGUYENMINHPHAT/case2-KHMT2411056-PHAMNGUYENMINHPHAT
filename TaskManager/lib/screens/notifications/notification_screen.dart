import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';
import '../tasks/task_detail_screen.dart';

/// Màn hình 9 — Thông báo: xem thông báo giao việc, chia sẻ, đổi trạng thái;
/// đánh dấu đã đọc; mở công việc liên quan.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  bool _unreadOnly = false;
  String? _error;

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
      final items = await NotificationService.getAll(unreadOnly: _unreadOnly);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    try {
      await NotificationService.markAllRead();
      if (!mounted) return;
      setState(() => _items = _items.map((n) => n.copyWith(isRead: true)).toList());
      showResult(context, 'Đã đánh dấu tất cả là đã đọc');
      if (_unreadOnly) _load();
    } catch (e) {
      if (mounted) showResult(context, e.toString(), error: true);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      try {
        await NotificationService.markRead(n.id);
        if (mounted) {
          setState(() => _items = _items.map((x) => x.id == n.id ? x.copyWith(isRead: true) : x).toList());
        }
      } catch (_) {}
    }
    if (!mounted) return;
    if (n.taskId == null) {
      showResult(context, 'Thông báo này không gắn với công việc nào');
      return;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: n.taskId!)));
  }

  IconData _icon(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind;
      case 'task_shared':
        return Icons.share;
      case 'task_completed':
        return Icons.check_circle;
      case 'due_reminder':
        return Icons.alarm;
      case 'task_updated':
        return Icons.edit_calendar;
      case 'share_revoked':
      case 'task_unassigned':
        return Icons.block;
      default:
        return Icons.notifications;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'task_completed':
        return Colors.green;
      case 'due_reminder':
        return Colors.orange;
      case 'share_revoked':
      case 'task_unassigned':
        return Colors.red;
      case 'task_shared':
        return Colors.purple;
      default:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            icon: const Icon(Icons.done_all),
            onPressed: unread == 0 ? null : _markAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              ChoiceChip(
                label: const Text('Tất cả'),
                selected: !_unreadOnly,
                onSelected: (_) {
                  setState(() => _unreadOnly = false);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Chưa đọc'),
                selected: _unreadOnly,
                onSelected: (_) {
                  setState(() => _unreadOnly = true);
                  _load();
                },
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _items.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 120),
                                EmptyView(message: 'Không có thông báo', icon: Icons.notifications_none),
                              ])
                            : ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final n = _items[i];
                                  return ListTile(
                                    tileColor: n.isRead ? null : Colors.indigo.withValues(alpha: 0.06),
                                    leading: CircleAvatar(
                                      backgroundColor: _color(n.type).withValues(alpha: 0.15),
                                      child: Icon(_icon(n.type), color: _color(n.type)),
                                    ),
                                    title: Text(n.title,
                                        style: TextStyle(
                                            fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                                    subtitle: Text('${n.message}\n${DateFormatter.relative(n.createdAt)}'),
                                    isThreeLine: true,
                                    trailing: n.isRead
                                        ? null
                                        : const Icon(Icons.circle, size: 10, color: Colors.indigo),
                                    onTap: () => _open(n),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
