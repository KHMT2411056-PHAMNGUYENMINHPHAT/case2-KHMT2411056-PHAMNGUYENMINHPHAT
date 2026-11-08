import 'package:flutter/material.dart';

import '../models/user.dart';
import '../utils/task_labels.dart';

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Badge(this.text, this.color, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) =>
      _Badge(TaskLabels.status(status), TaskLabels.statusColor(status), icon: Icons.circle);
}

class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge(this.priority, {super.key});
  @override
  Widget build(BuildContext context) => _Badge('Ưu tiên ${TaskLabels.priority(priority)}',
      TaskLabels.priorityColor(priority), icon: Icons.flag);
}

/// Badge vai trò của tôi: Người tạo / Người phụ trách / Được chia sẻ.
/// Có thể dùng trong danh sách công việc phần B với field myRole từ API.
class RoleBadge extends StatelessWidget {
  final String? role;
  const RoleBadge(this.role, {super.key});
  @override
  Widget build(BuildContext context) {
    if (role == null || role!.isEmpty) return const SizedBox.shrink();
    return _Badge(TaskLabels.role(role), TaskLabels.roleColor(role), icon: Icons.person);
  }
}

class UserAvatar extends StatelessWidget {
  final AppUser user;
  final double radius;
  const UserAvatar(this.user, {super.key, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    if (user.avatarUrl.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(user.avatarUrl));
    }
    return CircleAvatar(radius: radius, child: Text(user.initials, style: TextStyle(fontSize: radius * 0.7)));
  }
}
