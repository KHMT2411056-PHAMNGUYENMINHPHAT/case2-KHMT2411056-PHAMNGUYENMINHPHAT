import 'package:flutter/material.dart';

import '../../models/task_share.dart';
import '../../models/user.dart';
import '../../services/assignment_service.dart';
import '../../services/task_share_service.dart';
import '../../utils/task_labels.dart';
import '../../widgets/badges.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/user_search_box.dart';

/// Màn hình 8 — Quản lý chia sẻ và quyền truy cập.
/// [canManage] = true (người tạo): thêm người, đổi viewer/editor, thu hồi.
/// [canManage] = false: chỉ xem danh sách người được giao & được chia sẻ.
class TaskSharingScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final bool canManage;
  const TaskSharingScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.canManage = false,
  });

  @override
  State<TaskSharingScreen> createState() => _TaskSharingScreenState();
}

class _TaskSharingScreenState extends State<TaskSharingScreen> {
  List<TaskShare> _shares = [];
  List<AppUser> _assignees = [];
  String? _primaryId;
  final List<AppUser> _selected = [];
  String _permission = 'viewer';
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        TaskShareService.getShares(widget.taskId),
        AssignmentService.getAssignees(widget.taskId),
      ]);
      if (!mounted) return;
      final a = results[1] as AssigneeResult;
      setState(() {
        _shares = results[0] as List<TaskShare>;
        _assignees = a.assignees;
        _primaryId = a.primaryAssigneeId;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      final r = await TaskShareService.share(widget.taskId,
          userIds: _selected.map((u) => u.id).toList(), permission: _permission);
      if (!mounted) return;
      setState(() {
        _shares = r.shares;
        _selected.clear();
        _changed = true;
      });
      showResult(context, r.message);
    } catch (e) {
      if (mounted) showResult(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePermission(TaskShare s, String permission) async {
    if (s.permission == permission) return;
    try {
      final r = await TaskShareService.updatePermission(widget.taskId, s.id, permission);
      if (!mounted) return;
      setState(() {
        _shares = r.shares;
        _changed = true;
      });
      showResult(context, '${s.user.displayName}: ${TaskLabels.permission(permission)}');
    } catch (e) {
      if (mounted) showResult(context, e.toString(), error: true);
    }
  }

  Future<void> _revoke(TaskShare s) async {
    final ok = await confirmDialog(context,
        title: 'Thu hồi quyền',
        message: 'Thu hồi quyền truy cập của ${s.user.displayName}?',
        okText: 'Thu hồi');
    if (!ok) return;
    try {
      final r = await TaskShareService.revoke(widget.taskId, s.id);
      if (!mounted) return;
      setState(() {
        _shares = r.shares;
        _changed = true;
      });
      showResult(context, r.message);
    } catch (e) {
      if (mounted) showResult(context, e.toString(), error: true);
    }
  }

  Widget _permissionSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'viewer', label: Text('Chỉ xem'), icon: Icon(Icons.visibility)),
        ButtonSegment(value: 'editor', label: Text('Chỉnh sửa'), icon: Icon(Icons.edit)),
      ],
      selected: {_permission},
      onSelectionChanged: (s) => setState(() => _permission = s.first),
    );
  }

  Widget _shareTile(TaskShare s) {
    return Card(
      child: ListTile(
        leading: UserAvatar(s.user),
        title: Text(s.user.displayName),
        subtitle: Text('${s.user.email}\nQuyền: ${TaskLabels.permission(s.permission)}'),
        isThreeLine: true,
        trailing: widget.canManage
            ? PopupMenuButton<String>(
                onSelected: (v) => v == 'revoke' ? _revoke(s) : _changePermission(s, v),
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                      value: 'viewer', checked: s.permission == 'viewer', child: const Text('Chỉ xem')),
                  CheckedPopupMenuItem(
                      value: 'editor', checked: s.permission == 'editor', child: const Text('Chỉnh sửa')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'revoke',
                    child: Text('Thu hồi quyền', style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            : Chip(label: Text(TaskLabels.permission(s.permission))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final exclude = {..._shares.map((s) => s.user.id), ..._selected.map((u) => u.id)};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.canManage ? 'Chia sẻ & quyền truy cập' : 'Thành viên')),
        body: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(widget.taskTitle, style: Theme.of(context).textTheme.titleLarge),
                        if (widget.canManage) ...[
                          const SizedBox(height: 16),
                          Text('Thêm người được chia sẻ', style: titleStyle),
                          const SizedBox(height: 8),
                          UserSearchBox(
                            excludeIds: exclude,
                            onSelected: (u) => setState(() => _selected.add(u)),
                          ),
                          if (_selected.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _selected
                                  .map((u) => InputChip(
                                        avatar: UserAvatar(u, radius: 12),
                                        label: Text(u.displayName),
                                        onDeleted: () => setState(() => _selected.remove(u)),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                            _permissionSelector(),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _saving ? null : _share,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.share),
                              label: Text('Chia sẻ cho ${_selected.length} người'),
                            ),
                          ],
                        ],
                        const SizedBox(height: 24),
                        Text('Người được chia sẻ (${_shares.length})', style: titleStyle),
                        if (_shares.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Chưa chia sẻ cho ai', style: TextStyle(color: Colors.grey)),
                          ),
                        ..._shares.map(_shareTile),
                        const SizedBox(height: 24),
                        Text('Người được giao (${_assignees.length})', style: titleStyle),
                        if (_assignees.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Chưa giao cho ai', style: TextStyle(color: Colors.grey)),
                          ),
                        ..._assignees.map((u) => Card(
                              child: ListTile(
                                leading: UserAvatar(u),
                                title: Text(u.displayName),
                                subtitle: Text(u.email),
                                trailing: u.id == _primaryId
                                    ? const Chip(
                                        avatar: Icon(Icons.star, color: Colors.amber, size: 16),
                                        label: Text('Chính'),
                                      )
                                    : null,
                              ),
                            )),
                      ],
                    ),
                  ),
      ),
    );
  }
}
