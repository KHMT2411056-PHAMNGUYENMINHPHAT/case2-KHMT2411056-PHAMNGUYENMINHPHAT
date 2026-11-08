const mongoose = require('mongoose');
const { User } = require('../utils/user_model');

const { ObjectId } = mongoose.Schema.Types;

const taskShareSchema = new mongoose.Schema(
  {
    taskId: { type: ObjectId, ref: 'Task', required: true, index: true },
    userId: { type: ObjectId, ref: User.modelName, required: true, index: true },
    permission: { type: String, enum: ['viewer', 'editor'], default: 'viewer' },
    sharedBy: { type: ObjectId, ref: User.modelName, required: true },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

// Unique compound index: 1 người chỉ có 1 bản ghi chia sẻ cho 1 công việc
taskShareSchema.index({ taskId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.models.TaskShare ||
  mongoose.model('TaskShare', taskShareSchema, 'task_shares');
