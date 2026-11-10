const mongoose = require('mongoose');
const { User } = require('../utils/user_model');

const { ObjectId } = mongoose.Schema.Types;

// type: task_assigned, task_unassigned, task_shared, share_permission_changed,
//       share_revoked, task_updated, status_changed, task_completed, due_reminder
const notificationSchema = new mongoose.Schema(
  {
    userId: { type: ObjectId, ref: User.modelName, required: true, index: true },
    taskId: { type: ObjectId, ref: 'Task', default: null },
    type: { type: String, required: true },
    title: { type: String, required: true },
    message: { type: String, default: '' },
    isRead: { type: Boolean, default: false },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

notificationSchema.index({ userId: 1, isRead: 1, createdAt: -1 });

module.exports = mongoose.models.Notification ||
  mongoose.model('Notification', notificationSchema, 'notifications');
