// Tác vụ định kỳ: nhắc việc trước hạn (mặc định 24 giờ) + tự gửi lại email lỗi
const cron = require('node-cron');
const Task = require('../models/task.model');
const events = require('../services/task_event.service');
const { retryFailedEmails } = require('../services/email.service');

async function runDueReminders() {
  const hours = Number(process.env.REMINDER_HOURS || 24);
  const now = new Date();
  const limit = new Date(now.getTime() + hours * 60 * 60 * 1000);

  const candidates = await Task.find({
    status: { $ne: 'completed' },
    dueDate: { $gt: now, $lte: limit },
    reminderSentAt: null,
    createdBy: { $ne: null }, // bỏ qua task cũ của phần B (chưa có người tạo)
  }).select('_id').lean();

  let sent = 0;
  for (const { _id } of candidates) {
    // Đánh dấu "đã nhắc" theo kiểu nguyên tử để không gửi trùng
    const task = await Task.findOneAndUpdate(
      { _id, reminderSentAt: null },
      { $set: { reminderSentAt: now } },
      { returnDocument: 'after' }
    );
    if (!task) continue;
    try {
      await events.onReminder(task);
      sent += 1;
    } catch (err) {
      console.error('[reminder] Lỗi nhắc việc', String(_id), err.message);
    }
  }
  if (sent) console.log(`[reminder] Đã nhắc ${sent} công việc sắp đến hạn`);
  return sent;
}

function startReminderJob() {
  const expression = process.env.REMINDER_CRON || '*/10 * * * *'; // mỗi 10 phút
  if (!cron.validate(expression)) {
    console.error('[reminder] REMINDER_CRON không hợp lệ:', expression);
    return;
  }
  cron.schedule(expression, async () => {
    try {
      await runDueReminders();
      await retryFailedEmails();
    } catch (err) {
      console.error('[reminder]', err.message);
    }
  });
  console.log(`[reminder] Đã bật nhắc việc (${expression}), trước hạn ${process.env.REMINDER_HOURS || 24} giờ`);
}

module.exports = { startReminderJob, runDueReminders };
