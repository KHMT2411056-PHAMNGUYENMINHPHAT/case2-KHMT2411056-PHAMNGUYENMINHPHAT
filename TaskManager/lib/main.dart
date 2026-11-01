import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chance_password_screen.dart';
import 'models/task.dart';
import 'services/task_api_service.dart';
import 'services/auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  void _refreshTasks() {
    setState(() {
      _tasksFuture = TaskApiService.fetchTasks();
    });
  }

    void _showTaskDialog({Task? task}) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    String status = task?.status ?? 'Pending';
    String priority = task?.priority ?? 'Medium';
    DateTime? startDate = task?.startDate;
    DateTime? dueDate = task?.dueDate;
    String? error;

    showDialog(
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
                      DropdownMenuItem(value: 'Pending', child: Text('Chưa làm')),
                      DropdownMenuItem(value: 'InProgress', child: Text('Đang làm')),
                      DropdownMenuItem(value: 'Completed', child: Text('Đã xong')),
                    ],
                    onChanged: (val) => status = val!,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Mức độ ưu tiên'),
                    items: const [
                      DropdownMenuItem(value: 'Low', child: Text('Thấp')),
                      DropdownMenuItem(value: 'Medium', child: Text('Trung bình')),
                      DropdownMenuItem(value: 'High', child: Text('Cao')),
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
                    setDialogState(() => error = 'Tên công việc không được để trống');
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

                  if (success && mounted) {
                    Navigator.pop(dialogContext);
                    _refreshTasks();
                  }
                },
                child: Text(task == null ? 'Thêm' : 'Lưu'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteTask(String id) async {
    bool success = await TaskApiService.deleteTask(id);
    if (success) {
      _refreshTasks();
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
      body: FutureBuilder<List<Task>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Lỗi kết nối: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có công việc nào'));
          }

          final tasks = snapshot.data!;
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      '${task.description}\n'
                      'Trạng thái: ${task.status} | Ưu tiên: ${task.priority}\n'
                      'Bắt đầu: ${_fmtDate(task.startDate)} | Hạn: ${_fmtDate(task.dueDate)}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showTaskDialog(task: task),
                      ),
                      IconButton(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}