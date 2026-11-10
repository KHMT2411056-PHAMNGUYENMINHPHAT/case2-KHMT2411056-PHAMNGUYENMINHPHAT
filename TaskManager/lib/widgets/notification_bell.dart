import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/notifications/notification_screen.dart';
import '../services/notification_service.dart';

/// Nút chuông có số thông báo chưa đọc. Đặt vào AppBar.actions:
///   actions: [const NotificationBell(), ...]
class NotificationBell extends StatefulWidget {
  /// Gọi sau khi đóng màn hình thông báo (ví dụ để tải lại danh sách công việc)
  final VoidCallback? onClosed;
  const NotificationBell({super.key, this.onClosed});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Cập nhật mỗi 30 giây
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final c = await NotificationService.unreadCount();
      if (mounted) setState(() => _count = c);
    } catch (_) {
      // Bỏ qua lỗi mạng tạm thời
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Thông báo',
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
        _refresh();
        widget.onClosed?.call();
      },
      icon: Badge(
        isLabelVisible: _count > 0,
        label: Text(_count > 99 ? '99+' : '$_count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
