const TaskActivity = require('../models/task_activity.model');

// Ghi lịch sử hoạt động; lỗi ghi log không làm hỏng request chính
async function logActivity(taskId, userId, action, details = {}) {
  try {
    await TaskActivity.create({ taskId, userId, action, details });
  } catch (err) {
    console.error('[activity] Không ghi được lịch sử:', err.message);
  }
}

module.exports = { logActivity };
