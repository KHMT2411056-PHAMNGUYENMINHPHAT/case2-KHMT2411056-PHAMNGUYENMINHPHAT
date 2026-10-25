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
  final TaskApiService _apiService = TaskApiService();
  late Future<List<Task>> _futureTasks;

  @override
  void initState() {
    super.initState();
    // Gọi API lấy danh sách công việc khi vừa mở màn hình
    _futureTasks = _apiService.getTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Công Việc (Node.js API)'),
      ),
      body: FutureBuilder<List<Task>>(
        future: _futureTasks,
        builder: (context, snapshot) {
          // 1. Đang tải dữ liệu
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Có lỗi khi kết nối
          if (snapshot.hasError) {
            return Center(
              child: Text('Lỗi kết nối: ${snapshot.error}'),
            );
          }

          // 3. Không có dữ liệu
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có công việc nào.'));
          }

          // 4. Lấy dữ liệu thành công -> Hiển thị danh sách
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
                  subtitle: Text('${task.description}\nMức độ: ${task.priority}'),
                  trailing: Chip(
                    label: Text(task.status),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}