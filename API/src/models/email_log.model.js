const mongoose = require('mongoose');

const { ObjectId } = mongoose.Schema.Types;

const emailLogSchema = new mongoose.Schema(
  {
    taskId: { type: ObjectId, ref: 'Task', default: null, index: true },
    recipientEmail: { type: String, required: true, lowercase: true, trim: true },
    eventType: { type: String, required: true }, // task_assigned, task_shared, task_updated, task_completed, due_reminder
    subject: { type: String, required: true },
    // Nội dung lưu lại để có thể gửi lại; không trả về trong API danh sách
    html: { type: String, select: false },
    text: { type: String, select: false },
    status: { type: String, enum: ['pending', 'sent', 'failed'], default: 'pending', index: true },
    attempts: { type: Number, default: 0 },
    errorMessage: { type: String, default: '' },
    sentAt: { type: Date, default: null },
  },
  { timestamps: { createdAt: true, updatedAt: true } }
);

module.exports = mongoose.models.EmailLog ||
  mongoose.model('EmailLog', emailLogSchema, 'email_logs');
