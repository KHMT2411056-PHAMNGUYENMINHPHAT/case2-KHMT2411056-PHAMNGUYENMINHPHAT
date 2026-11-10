import 'api_client.dart';

class EmailLog {
  final String id;
  final String recipientEmail;
  final String eventType;
  final String subject;
  final String status; // pending | sent | failed
  final int attempts;
  final String errorMessage;
  final DateTime? sentAt;
  final DateTime? createdAt;

  EmailLog({
    required this.id,
    required this.recipientEmail,
    required this.eventType,
    required this.subject,
    required this.status,
    required this.attempts,
    required this.errorMessage,
    this.sentAt,
    this.createdAt,
  });

  factory EmailLog.fromJson(Map<String, dynamic> j) => EmailLog(
        id: (j['_id'] ?? '').toString(),
        recipientEmail: (j['recipientEmail'] ?? '').toString(),
        eventType: (j['eventType'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        status: (j['status'] ?? 'pending').toString(),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        errorMessage: (j['errorMessage'] ?? '').toString(),
        sentAt: DateTime.tryParse((j['sentAt'] ?? '').toString())?.toLocal(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
      );
}

class EmailLogResult {
  final int maxAttempts;
  final List<EmailLog> logs;
  EmailLogResult(this.maxAttempts, this.logs);
}

class EmailLogService {
  static Future<EmailLogResult> getByTask(String taskId) async {
    final data = await ApiClient.get('/tasks/$taskId/email-logs');
    return EmailLogResult(
      (data['maxAttempts'] as num?)?.toInt() ?? 3,
      (data['logs'] as List? ?? []).map((e) => EmailLog.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }

  /// Trả về message kết quả
  static Future<String> retry(String logId) async {
    final data = await ApiClient.post('/email-logs/$logId/retry');
    return (data['message'] ?? 'Đã gửi lại').toString();
  }
}
