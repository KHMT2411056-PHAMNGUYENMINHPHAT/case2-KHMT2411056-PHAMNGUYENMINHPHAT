import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_service.dart';
import 'badges.dart';

/// Ô tìm người theo tên/email, hiện kết quả để chọn.
/// [excludeIds]: những người đã có trong danh sách (không hiện nữa).
class UserSearchBox extends StatefulWidget {
  final Set<String> excludeIds;
  final ValueChanged<AppUser> onSelected;
  final String hint;

  const UserSearchBox({
    super.key,
    required this.onSelected,
    this.excludeIds = const {},
    this.hint = 'Nhập tên hoặc email để tìm...',
  });

  @override
  State<UserSearchBox> createState() => _UserSearchBoxState();
}

class _UserSearchBoxState extends State<UserSearchBox> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<AppUser> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await UserService.search(q);
      if (!mounted) return;
      setState(() => _results = users);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _results.where((u) => !widget.excludeIds.contains(u.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (_controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _search('');
                        },
                      )
                    : null),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (_controller.text.trim().isNotEmpty && !_loading && _error == null && visible.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Không tìm thấy người dùng phù hợp', style: TextStyle(color: Colors.grey)),
          ),
        ...visible.map((u) => ListTile(
              dense: true,
              leading: UserAvatar(u, radius: 16),
              title: Text(u.displayName),
              subtitle: Text(u.email),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: () => widget.onSelected(u),
            )),
      ],
    );
  }
}
