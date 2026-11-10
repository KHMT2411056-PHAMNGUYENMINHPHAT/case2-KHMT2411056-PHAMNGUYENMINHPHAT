const Notification = require('../models/notification.model');

/** Tạo thông báo trong ứng dụng cho nhiều người */
async function notifyUsers(userIds, { taskId = null, type, title, message = '' }) {
  const unique = [...new Set((userIds || []).map(String))].filter(Boolean);
  if (!unique.length) return [];
  try {
    return await Notification.insertMany(
      unique.map((userId) => ({ userId, taskId, type, title, message }))
    );
  } catch (err) {
    console.error('[notification] Không tạo được thông báo:', err.message);
    return [];
  }
}

module.exports = { notifyUsers };
