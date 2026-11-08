/// Định dạng ngày giờ không cần package intl.
class DateFormatter {
  static String _two(int n) => n.toString().padLeft(2, '0');

  static String date(DateTime? d) {
    if (d == null) return 'Chưa đặt';
    return '${_two(d.day)}/${_two(d.month)}/${d.year}';
  }

  static String dateTime(DateTime? d) {
    if (d == null) return 'Chưa đặt';
    return '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
  }

  /// "5 phút trước", "2 giờ trước", ...
  static String relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return dateTime(d);
  }

  /// "Còn 3 ngày", "Quá hạn 2 ngày"
  static String dueText(DateTime? due) {
    if (due == null) return 'Không có hạn';
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) {
      final days = diff.inDays.abs();
      return days == 0 ? 'Quá hạn ${diff.inHours.abs()} giờ' : 'Quá hạn $days ngày';
    }
    if (diff.inHours < 24) return 'Còn ${diff.inHours} giờ';
    return 'Còn ${diff.inDays} ngày';
  }
}
