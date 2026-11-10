// Gửi email + lưu lịch sử (email_logs) với trạng thái pending / sent / failed
const EmailLog = require('../models/email_log.model');
const { getTransporter, getFromAddress } = require('../config/email');

const MAX_ATTEMPTS = Number(process.env.EMAIL_MAX_ATTEMPTS || 3);
const DUPLICATE_WINDOW_MS = 2 * 60 * 1000; // chặn gửi trùng trong 2 phút

/** Thực hiện gửi 1 email đã có log */
async function deliver(logId) {
  const log = await EmailLog.findById(logId).select('+html +text');
  if (!log || log.status === 'sent') return log;

  log.attempts += 1;
  const transporter = getTransporter();
  try {
    if (!transporter) throw new Error('Chưa cấu hình SMTP trên server');
    await transporter.sendMail({
      from: getFromAddress(),
      to: log.recipientEmail,
      subject: log.subject,
      html: log.html,
      text: log.text,
    });
    log.status = 'sent';
    log.sentAt = new Date();
    log.errorMessage = '';
  } catch (err) {
    log.status = 'failed';
    log.errorMessage = String(err.message || err).slice(0, 500);
    console.error(`[email] Gửi tới ${log.recipientEmail} thất bại:`, log.errorMessage);
  }
  await log.save();
  return log;
}

/**
 * Ghi nhận yêu cầu gửi email rồi gửi ngầm (không làm chậm API).
 * Bỏ qua nếu vừa có email giống hệt (cùng người nhận, công việc, sự kiện, tiêu đề).
 */
async function queueEmail({ to, taskId = null, eventType, subject, html, text }) {
  if (!to) return null;
  const recipientEmail = String(to).toLowerCase().trim();

  const duplicate = await EmailLog.findOne({
    recipientEmail, taskId, eventType, subject,
    status: { $in: ['pending', 'sent'] },
    createdAt: { $gte: new Date(Date.now() - DUPLICATE_WINDOW_MS) },
  }).lean();
  if (duplicate) return duplicate;

  const log = await EmailLog.create({
    taskId, recipientEmail, eventType, subject, html, text, status: 'pending',
  });
  setImmediate(() => deliver(log._id).catch((e) => console.error('[email]', e.message)));
  return log;
}

/** Gửi lại email thất bại (có giới hạn số lần) */
async function retryEmail(logId) {
  const log = await EmailLog.findById(logId);
  if (!log) return { ok: false, status: 404, message: 'Không tìm thấy lịch sử email' };
  if (log.status === 'sent') return { ok: false, status: 400, message: 'Email này đã gửi thành công' };
  if (log.status === 'pending') return { ok: false, status: 400, message: 'Email đang được gửi, vui lòng đợi' };
  if (log.attempts >= MAX_ATTEMPTS) {
    return { ok: false, status: 400, message: `Đã thử gửi tối đa ${MAX_ATTEMPTS} lần` };
  }
  log.status = 'pending';
  await log.save();
  const result = await deliver(log._id);
  return {
    ok: result.status === 'sent',
    status: 200,
    message: result.status === 'sent' ? 'Gửi lại thành công' : `Gửi lại thất bại: ${result.errorMessage}`,
    log: result,
  };
}

/** Tác vụ định kỳ: tự gửi lại các email failed còn lượt (cách lần trước >= 5 phút) */
async function retryFailedEmails() {
  const logs = await EmailLog.find({
    status: 'failed',
    attempts: { $lt: MAX_ATTEMPTS },
    updatedAt: { $lte: new Date(Date.now() - 5 * 60 * 1000) },
  }).limit(20);
  for (const log of logs) {
    await deliver(log._id);
  }
  return logs.length;
}

module.exports = { queueEmail, retryEmail, retryFailedEmails, deliver, MAX_ATTEMPTS };
