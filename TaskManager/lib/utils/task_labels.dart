import 'package:flutter/material.dart';

/// Nhãn tiếng Việt + màu cho trạng thái, ưu tiên, vai trò, quyền.
class TaskLabels {
  static const statuses = ['todo', 'in_progress', 'completed'];

  static String status(String s) {
    switch (s) {
      case 'in_progress':
        return 'Đang thực hiện';
      case 'completed':
        return 'Đã hoàn thành';
      default:
        return 'Chưa thực hiện';
    }
  }

  static Color statusColor(String s) {
    switch (s) {
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Tiến độ ước lượng theo trạng thái
  static double progress(String s) {
    switch (s) {
      case 'in_progress':
        return 0.5;
      case 'completed':
        return 1.0;
      default:
        return 0.0;
    }
  }

  static String priority(String p) {
    switch (p) {
      case 'high':
        return 'Cao';
      case 'low':
        return 'Thấp';
      default:
        return 'Trung bình';
    }
  }

  static Color priorityColor(String p) {
    switch (p) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  static String role(String? r) {
    switch (r) {
      case 'owner':
        return 'Người tạo';
      case 'assignee':
        return 'Người phụ trách';
      case 'editor':
        return 'Được chia sẻ (sửa)';
      case 'viewer':
        return 'Được chia sẻ (xem)';
      default:
        return '';
    }
  }

  static Color roleColor(String? r) {
    switch (r) {
      case 'owner':
        return Colors.indigo;
      case 'assignee':
        return Colors.deepOrange;
      case 'editor':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  static String permission(String p) => p == 'editor' ? 'Chỉnh sửa' : 'Chỉ xem';
}
