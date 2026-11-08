const mongoose = require('mongoose');
const { User } = require('../utils/user_model');

const { ObjectId } = mongoose.Schema.Types;

const taskSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 200 },
    description: { type: String, default: '', trim: true, maxlength: 5000 },
    // Giữ lại field của phần B
    category: { type: String, default: 'Other', trim: true },
    createdBy: { type: ObjectId, ref: User.modelName, required: true, index: true },
    assigneeIds: [{ type: ObjectId, ref: User.modelName }],
    primaryAssigneeId: { type: ObjectId, ref: User.modelName, default: null },
    startDate: { type: Date, default: null },
    dueDate: { type: Date, default: null },
    priority: { type: String, enum: ['low', 'medium', 'high'], default: 'medium' },
    status: { type: String, enum: ['todo', 'in_progress', 'completed'], default: 'todo' },
    completedAt: { type: Date, default: null },
    // Dùng cho phần D: đã gửi nhắc hạn chưa (reset khi đổi dueDate)
    reminderSentAt: { type: Date, default: null },
  },
  { timestamps: true }
);

taskSchema.index({ assigneeIds: 1 });
taskSchema.index({ primaryAssigneeId: 1 });
taskSchema.index({ dueDate: 1, status: 1 });

module.exports = mongoose.models.Task || mongoose.model('Task', taskSchema);
