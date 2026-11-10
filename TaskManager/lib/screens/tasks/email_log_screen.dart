import 'package:flutter/material.dart';

import '../../services/email_log_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';

/// Lịch sử gửi email của 1 công việc (chỉ người tạo xem được) + gửi lại email lỗi.
class EmailLogScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  const EmailLogScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<EmailLogScreen> createState() => _EmailLogScreenState();
}

class _EmailLogScreenState extends State<EmailLogScreen> {
  EmailLogResult? _data;
  bool _loading = true;
  String? _error;
  final Set<String> _retrying = {};

  static const _events = {
    'task_assigned': 'Giao việc',
    'task_shared': 'Chia sẻ',
    'task_updated': 'Cập nhật',
    'task_completed': 'Hoàn thành',
    'due_reminder': 'Nhắc hạn',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final d = await EmailLogService.getByTask(widget.taskId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retry(EmailLog log) async {
    setState(() => _retrying.add(log.id));
    try {
      final msg = await EmailLogService.retry(log.id);
      if (mounted) showResult(context, msg, error: msg.contains('thất bại'));
      await _load();
    } catch (e) {
      if (mounted) showResult(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _retrying.remove(log.id));
    }
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'sent' => ('Đã gửi', Colors.green),
      'failed' => ('Thất bại', Colors.red),
      _ => ('Đang gửi', Colors.orange),
    };
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _data?.logs ?? [];
    final max = _data?.maxAttempts ?? 3;
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử email')),
      body: _loading
          ? const LoadingView()
          : _error != null && _data == null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: logs.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          EmptyView(message: 'Chưa có email nào được gửi', icon: Icons.mail_outline),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: logs.length,
                          itemBuilder: (_, i) {
                            final l = logs[i];
                            final canRetry = l.status == 'failed' && l.attempts < max;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                        child: Text(l.recipientEmail,
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      _statusChip(l.status),
                                    ]),
                                    Text(l.subject),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_events[l.eventType] ?? l.eventType} • '
                                      'Tạo: ${DateFormatter.dateTime(l.createdAt)} • '
                                      'Số lần thử: ${l.attempts}/$max',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    if (l.sentAt != null)
                                      Text('Gửi lúc: ${DateFormatter.dateTime(l.sentAt)}',
                                          style: const TextStyle(color: Colors.green, fontSize: 12)),
                                    if (l.errorMessage.isNotEmpty)
                                      Text('Lỗi: ${l.errorMessage}',
                                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                                    if (canRetry)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: _retrying.contains(l.id) ? null : () => _retry(l),
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Gửi lại'),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
