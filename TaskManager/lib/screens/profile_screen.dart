import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'statistics/statistics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _avatarController = TextEditingController();
  String _email = '';
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

    Future<void> _loadProfile() async {
    final data = await AuthService.getProfile();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data['id'] != null || data['_id'] != null) {
        _nameController.text = data['fullName'] ?? '';
        _avatarController.text = data['avatarUrl'] ?? '';
        _email = data['email'] ?? '';
      } else {
        _message = data['message'] ?? 'Không tải được thông tin';
      }
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _message = 'Họ tên không được để trống');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    final data = await AuthService.updateProfile(
      _nameController.text.trim(),
      _avatarController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = data['message'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: _email),
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email (không thể đổi)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _avatarController,
              decoration: const InputDecoration(
                labelText: 'Link ảnh đại diện (tùy chọn)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.deepPurple)),
              ),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Lưu thay đổi'),
            ),
            // Phần E2: mở màn hình thống kê
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Thống kê công việc'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}