import 'package:flutter/material.dart';
import 'models/task.dart';
import 'services/task_api_service.dart';

void main() {
  runApp(const MyApp());
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
      home: const TaskListScreen(),
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
    String status = task?.status ?? 'todo';
    String priority = task?.priority ?? 'medium';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                value: status,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: const [
                  DropdownMenuItem(value: 'todo', child: Text('Chưa làm (todo)')),
                  DropdownMenuItem(value: 'in_progress', child: Text('Đang làm (in_progress)')),
                  DropdownMenuItem(value: 'completed', child: Text('Đã xong (completed)')),
                ],
                onChanged: (val) => status = val!,
              ),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(labelText: 'Mức độ ưu tiên'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Thấp (low)')),
                  DropdownMenuItem(value: 'medium', child: Text('Trung bình (medium)')),
                  DropdownMenuItem(value: 'high', child: Text('Cao (high)')),
                ],
                onChanged: (val) => priority = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty) return;

              Map<String, dynamic> data = {
                'title': titleController.text,
                'description': descController.text,
                'status': status,
                'priority': priority,
              };

              bool success;
              if (task == null) {
                success = await TaskApiService.createTask(data);
              } else {
                success = await TaskApiService.updateTask(task.id, data);
              }

              if (success && mounted) {
                Navigator.pop(context);
                _refreshTasks();
              }
            },
            child: Text(task == null ? 'Thêm' : 'Lưu'),
          ),
        ],
      ),
    );
  }

  void _deleteTask(String id) async {
    bool success = await TaskApiService.deleteTask(id);
    if (success) {
      _refreshTasks();
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
          )
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
                  subtitle: Text('${task.description}\nTrạng thái: ${task.status} | Ưu tiên: ${task.priority}'),
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