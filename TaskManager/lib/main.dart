import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chance_password_screen.dart';
import 'models/task.dart';
import 'services/task_api_service.dart';
import 'services/auth_service.dart';
import 'screens/assignment/assign_task_screen.dart';
import 'screens/sharing/task_sharing_screen.dart';
import 'screens/tasks/task_detail_screen.dart';
import 'widgets/badges.dart';
import 'widgets/loading_view.dart';

void main() {
  runApp(const MyApp());
}

String _fmtDate(DateTime? d) {
  if (d == null) return 'Chưa chọn';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<Task>> _tasksFuture;

  String _search = '';
  String _statusFilter = '';
  String _priorityFilter = '';
  String _scopeFilter = ''; // '' = tất cả | created | assigned | shared (phần C4)
  String _sortBy = 'createdAt';
  String _order = 'desc';
  Timer? _debounce;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshTasks() {
    setState(() {
      _tasksFuture = TaskApiService.fetchTasks(
        q: _search,
        status: _statusFilter,
        priority: _priorityFilter,
        scope: _scopeFilter,
        sortBy: _sortBy,
        order: _order,
      );
    });
  }

  // Trả về true nếu đã lưu (dùng lại cho nút "Chỉnh sửa" ở màn hình chi tiết)
  Future<bool> _showTaskDialog({Task? task}) async {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    String status = task?.status ?? 'todo';
    String priority = task?.priority ?? 'medium';
    DateTime? startDate = task?.startDate;
    DateTime? dueDate = task?.dueDate;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDate(bool isStart) async {
            final initial = (isStart ? startDate : dueDate) ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setDialogState(() {
                if (isStart) {
                  startDate = picked;
                } else {
                  dueDate = picked;
                }
              });
            }
          }

          return AlertDialog(
            title: Text(task == null ? 'Thêm công việc' : 'Chỉnh sửa công việc'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Tên công việc'),
                  ),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Mô tả'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                    items: const [
                      DropdownMenuItem(value: 'todo', child: Text('Chưa làm')),
                      DropdownMenuItem(value: 'in_progress', child: Text('Đang làm')),
                      DropdownMenuItem(value: 'completed', child: Text('Đã xong')),
                    ],
                    onChanged: (val) => status = val!,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Mức độ ưu tiên'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Thấp')),
                      DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                      DropdownMenuItem(value: 'high', child: Text('Cao')),
                    ],
                    onChanged: (val) => priority = val!,
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ngày bắt đầu'),
                    subtitle: Text(_fmtDate(startDate)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (startDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setDialogState(() => startDate = null),
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => pickDate(true),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hạn hoàn thành'),
                    subtitle: Text(_fmtDate(dueDate)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dueDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setDialogState(() => dueDate = null),
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => pickDate(false),
                        ),
                      ],
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    setDialogState(
                        () => error = 'Tên công việc không được để trống');
                    return;
                  }
                  if (startDate != null &&
                      dueDate != null &&
                      dueDate!.isBefore(startDate!)) {
                    setDialogState(() =>
                        error = 'Hạn hoàn thành phải sau ngày bắt đầu');
                    return;
                  }

                  Map<String, dynamic> data = {
                    'title': titleController.text.trim(),
                    'description': descController.text,
                    'status': status,
                    'priority': priority,
                    'startDate': startDate?.toUtc().toIso8601String(),
                    'dueDate': dueDate?.toUtc().toIso8601String(),
                  };

                  bool success;
                  if (task == null) {
                    success = await TaskApiService.createTask(data);
                  } else {
                    success = await TaskApiService.updateTask(task.id, data);
                  }

                  if (!dialogContext.mounted) return;
                  if (success) {
                    Navigator.pop(dialogContext, true);
                  } else {
                    setDialogState(() => error = task == null
                        ? 'Không tạo được công việc'
                        : 'Không lưu được (có thể bạn không có quyền sửa)');
                  }
                },
                child: Text(task == null ? 'Thêm' : 'Lưu'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) _refreshTasks();
    return saved == true;
  }

  // Phần C4: mở màn hình chi tiết (người được giao, chia sẻ, tiến độ, vai trò)
  Future<void> _openDetail(Task task) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          taskId: task.id,
          // Dùng lại hộp thoại sửa của phần B với dữ liệu mới nhất từ màn hình chi tiết
          onEdit: (ctx, t) => _showTaskDialog(
            task: Task(
              id: t.id,
              title: t.title,
              description: t.description,
              category: task.category,
              priority: t.priority,
              status: t.status,
              startDate: t.startDate,
              dueDate: t.dueDate,
              myRole: t.myRole,
            ),
          ),
        ),
      ),
    );
    if (changed == true) _refreshTasks();
  }

  // Phần C2: mở màn hình giao việc (chỉ người tạo được giao, API trả 403 nếu không có quyền)
  Future<void> _openAssign(Task task) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignTaskScreen(taskId: task.id, taskTitle: task.title),
      ),
    );
    if (changed == true) _refreshTasks();
  }

  // Phần C3: chia sẻ & quyền truy cập (chỉ người tạo được thêm/đổi/thu hồi; người khác chỉ xem)
  Future<void> _openSharing(Task task) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskSharingScreen(
          taskId: task.id,
          taskTitle: task.title,
          canManage: task.isOwner,
        ),
      ),
    );
    if (changed == true) _refreshTasks();
  }

  void _deleteTask(String id) async {
    final ok = await confirmDialog(context,
        title: 'Xóa công việc',
        message: 'Bạn chắc chắn muốn xóa công việc này?',
        okText: 'Xóa');
    if (!ok) return;
    bool success = await TaskApiService.deleteTask(id);
    if (!mounted) return;
    if (success) {
      showResult(context, 'Đã xóa công việc');
      _refreshTasks();
    } else {
      showResult(context, 'Không xóa được (chỉ người tạo được xóa)', error: true);
    }
  }

  Future<void> _onMenuSelected(String value) async {
    if (value == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } else if (value == 'password') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
      );
    } else if (value == 'logout') {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: '),
        DropdownButton<String>(
          value: value,
          items: options.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên công việc',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _search = '';
                        _refreshTasks();
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                _search = v.trim();
                _refreshTasks();
              });
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filterDropdown(
                label: 'Phạm vi',
                value: _scopeFilter,
                options: const {
                  '': 'Tất cả',
                  'created': 'Của tôi',
                  'assigned': 'Được giao',
                  'shared': 'Được chia sẻ',
                },
                onChanged: (v) {
                  _scopeFilter = v;
                  _refreshTasks();
                },
              ),
              _filterDropdown(
                label: 'Trạng thái',
                value: _statusFilter,
                options: const {
                  '': 'Tất cả',
                  'todo': 'Chưa làm',
                  'in_progress': 'Đang làm',
                  'completed': 'Đã xong',
                },
                onChanged: (v) {
                  _statusFilter = v;
                  _refreshTasks();
                },
              ),
              _filterDropdown(
                label: 'Ưu tiên',
                value: _priorityFilter,
                options: const {
                  '': 'Tất cả',
                  'low': 'Thấp',
                  'medium': 'Trung bình',
                  'high': 'Cao',
                },
                onChanged: (v) {
                  _priorityFilter = v;
                  _refreshTasks();
                },
              ),
              _filterDropdown(
                label: 'Sắp xếp',
                value: _sortBy,
                options: const {
                  'createdAt': 'Thời gian tạo',
                  'dueDate': 'Hạn hoàn thành',
                  'priority': 'Mức ưu tiên',
                },
                onChanged: (v) {
                  _sortBy = v;
                  _refreshTasks();
                },
              ),
              IconButton(
                tooltip: _order == 'asc' ? 'Tăng dần' : 'Giảm dần',
                icon: Icon(_order == 'asc'
                    ? Icons.arrow_upward
                    : Icons.arrow_downward),
                onPressed: () {
                  _order = _order == 'asc' ? 'desc' : 'asc';
                  _refreshTasks();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Công Việc (Node.js API)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTasks,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: _onMenuSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Hồ sơ cá nhân')),
              PopupMenuItem(value: 'password', child: Text('Đổi mật khẩu')),
              PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<Task>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Lỗi kết nối: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('Không có công việc phù hợp'));
                }

                final tasks = snapshot.data!;
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        onTap: () => _openDetail(task),
                        title: Text(
                          task.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task.description.isNotEmpty)
                              Text(task.description,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            // Phân loại theo vai trò + trạng thái + ưu tiên
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              RoleBadge(task.myRole),
                              StatusBadge(task.status),
                              PriorityBadge(task.priority),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                                'Bắt đầu: ${_fmtDate(task.startDate)} | Hạn: ${_fmtDate(task.dueDate)}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              tooltip: 'Giao việc / Chia sẻ',
                              onSelected: (v) => v == 'assign'
                                  ? _openAssign(task)
                                  : _openSharing(task),
                              itemBuilder: (_) => [
                                if (task.isOwner)
                                  const PopupMenuItem(
                                    value: 'assign',
                                    child: ListTile(
                                      leading: Icon(Icons.person_add_alt_1,
                                          color: Colors.green),
                                      title: Text('Giao việc'),
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'share',
                                  child: ListTile(
                                    leading: const Icon(Icons.share,
                                        color: Colors.indigo),
                                    title: Text(task.isOwner
                                        ? 'Chia sẻ & quyền'
                                        : 'Thành viên'),
                                  ),
                                ),
                              ],
                            ),
                            if (task.canEdit)
                              IconButton(
                                tooltip: 'Chỉnh sửa',
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showTaskDialog(task: task),
                              ),
                            if (task.isOwner)
                              IconButton(
                                tooltip: 'Xóa',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTask(task.id),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}