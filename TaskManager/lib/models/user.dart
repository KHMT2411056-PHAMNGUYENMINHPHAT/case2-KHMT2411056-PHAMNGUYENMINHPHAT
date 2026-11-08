/// Thông tin công khai của người dùng (dùng khi giao việc / chia sẻ).
class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String avatarUrl;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl = '',
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
    );
  }

  /// Tên hiển thị: họ tên, nếu rỗng thì dùng email
  String get displayName => fullName.isNotEmpty ? fullName : email;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  bool operator ==(Object other) => other is AppUser && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
