import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/assignment_service.dart';
import '../../widgets/badges.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/user_search_box.dart';

/// Màn hình 7 — Giao công việc:
/// tìm người theo tên/email, chọn nhiều người, chọn người phụ trách chính, xác nhận.
/// Trả về true khi có thay đổi (để màn hình trước tải lại).
class AssignTaskScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  const AssignTaskScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  List<AppUser> _current = []; // đã được giao
  final List<AppUser> _selected = []; // chọn thêm (chưa lưu)
  String? _primaryId;
  String? _savedPrimaryId;
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
      final r = await AssignmentService.getAssignees(widget.taskId);
      if (!mounted) return;
      setState(() {
        _current = r.assignees;
        _primaryId = r.primaryAssigneeId;
        _savedPrimaryId = r.primaryAssigneeId;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasPending => _selected.isNotEmpty || _primaryId != _savedPrimaryId;

  Future<void> _save() async {
    if (!_hasPending) return;
    setState(() => _saving = true);
    try {
      final r = await AssignmentService.assign(
        widget.taskId,
        userIds: _selected.map((u) => u.id).toList(),
        primaryAssigneeId: _primaryId,
      );
      if (!mounted) return;
      setState(() {
        _current = r.assignees;
        _primaryId = r.primaryAssigneeId;
        _savedPrimaryId = r.primaryAssigneeId;
        _selected.clear();
        _changed = true;
      });
      showResult(context, r.message.isEmpty ? 'Đã giao việc' : r.message);
    } catch (e) {
      if (mounted) showResult(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(AppUser u) async {
    final ok = await confirmDialog(context,
        title: 'Hủy giao việc', message: 'Hủy giao công việc cho ${u.displayName}?', okText: 'Hủy giao');
    if (!ok) return;
    try {
      final r = await AssignmentService.remove(widget.taskId, u.id);
      if (!mounted) return;
      setState(() {
        _current = r.assignees;
        _primaryId = r.primaryAssigneeId;
        _savedPrimaryId = r.primaryAssigneeId;
        _changed = true;
      });
      showResult(context, r.message);
    } catch (e) {
      if (mounted) showResult(context, e.toString(), error: true);
    }
  }

  Widget _userTile(AppUser u, {required bool pending}) {
    final isPrimary = u.id == _primaryId;
    return Card(
      child: ListTile(
        leading: UserAvatar(u),
        title: Text(u.displayName),
        subtitle: Text(isPrimary ? '${u.email}\nNgười phụ trách chính' : u.email),
        isThreeLine: isPrimary,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Chọn làm người phụ trách chính',
              icon: Icon(isPrimary ? Icons.star : Icons.star_border,
                  color: isPrimary ? Colors.amber : null),
              onPressed: () => setState(() => _primaryId = u.id),
            ),
            IconButton(
              tooltip: pending ? 'Bỏ chọn' : 'Hủy giao việc',
              icon: Icon(pending ? Icons.close : Icons.person_remove_outlined, color: Colors.red),
              onPressed: () {
                if (pending) {
                  setState(() {
                    _selected.remove(u);
                    if (_primaryId == u.id) _primaryId = _savedPrimaryId;
                  });
                } else {
                  _remove(u);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exclude = {..._current.map((u) => u.id), ..._selected.map((u) => u.id)};
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Giao công việc')),
        body: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(widget.taskTitle, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Text('Tìm người để giao việc', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      UserSearchBox(
                        excludeIds: exclude,
                        onSelected: (u) => setState(() {
                          _selected.add(u);
                          _primaryId ??= u.id; // chưa có ai phụ trách chính -> chọn người đầu tiên
                        }),
                      ),
                      if (_selected.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Đã chọn (${_selected.length}) — chưa lưu',
                            style: Theme.of(context).textTheme.titleMedium),
                        ..._selected.map((u) => _userTile(u, pending: true)),
                      ],
                      const SizedBox(height: 16),
                      Text('Đang được giao (${_current.length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Text('Bấm ★ để chọn người phụ trách chính',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      if (_current.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Chưa giao cho ai', style: TextStyle(color: Colors.grey)),
                        ),
                      ..._current.map((u) => _userTile(u, pending: false)),
                      const SizedBox(height: 80),
                    ],
                  ),
        bottomNavigationBar: _loading || _error != null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: _hasPending && !_saving ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_selected.isNotEmpty
                        ? 'Xác nhận giao việc (${_selected.length})'
                        : 'Lưu người phụ trách chính'),
                  ),
                ),
              ),
      ),
    );
  }
}
