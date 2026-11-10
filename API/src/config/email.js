// Cấu hình SMTP lấy từ biến môi trường (.env) — KHÔNG ghi mật khẩu vào code.
const nodemailer = require('nodemailer');

let transporter = null;

function isEmailConfigured() {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
}

function getTransporter() {
  if (!isEmailConfigured()) return null;
  if (!transporter) {
    const port = Number(process.env.SMTP_PORT || 587);
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port,
      secure: process.env.SMTP_SECURE === 'true' || port === 465,
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    });
  }
  return transporter;
}

function getFromAddress() {
  const name = process.env.APP_NAME || 'Task Manager';
  return process.env.MAIL_FROM || `"${name}" <${process.env.SMTP_USER}>`;
}

// Kiểm tra kết nối SMTP khi khởi động server (chỉ in log)
async function verifyEmailConfig() {
  const t = getTransporter();
  if (!t) {
    console.warn('[email] Chưa cấu hình SMTP trong .env — email sẽ được ghi log với trạng thái failed');
    return;
  }
  try {
    await t.verify();
    console.log('[email] Kết nối SMTP thành công');
  } catch (err) {
    console.error('[email] Không kết nối được SMTP:', err.message);
  }
}

module.exports = { getTransporter, getFromAddress, isEmailConfigured, verifyEmailConfig };
