import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_oldController.text.isEmpty || _newController.text.isEmpty) {
      setState(() {
        _success = false;
        _message = 'Vui lòng nhập đầy đủ thông tin';
      });
      return;
    }
    if (_newController.text.length < 6) {
      setState(() {
        _success = false;
        _message = 'Mật khẩu mới phải từ 6 ký tự';
      });
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() {
        _success = false;
        _message = 'Mật khẩu xác nhận không khớp';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });
    final data = await AuthService.changePassword(
        _oldController.text, _newController.text);
    if (!mounted) return;
    final ok = data['message'] == 'Đổi mật khẩu thành công';
    setState(() {
      _loading = false;
      _success = ok;
      _message = data['message'];
    });
    if (ok) {
      _oldController.clear();
      _newController.clear();
      _confirmController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: _oldController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _success ? Colors.green : Colors.red),
                ),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Đổi mật khẩu'),
            ),
          ],
        ),
      ),
    );
  }
}