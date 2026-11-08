const mongoose = require('mongoose');
const { User } = require('../utils/user_model');

const { ObjectId } = mongoose.Schema.Types;

// action: created, updated, status_changed, assigned, unassigned, primary_changed,
//         shared, share_permission_changed, share_revoked
const taskActivitySchema = new mongoose.Schema(
  {
    taskId: { type: ObjectId, ref: 'Task', required: true, index: true },
    userId: { type: ObjectId, ref: User.modelName, required: true },
    action: { type: String, required: true },
    details: { type: Object, default: {} },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

module.exports = mongoose.models.TaskActivity ||
  mongoose.model('TaskActivity', taskActivitySchema, 'task_activities');
