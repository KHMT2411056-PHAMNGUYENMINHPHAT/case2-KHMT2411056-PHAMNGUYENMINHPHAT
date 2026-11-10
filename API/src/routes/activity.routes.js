// /api/tasks/:id/activities — lịch sử hoạt động của công việc
const express = require('express');
const TaskActivity = require('../models/task_activity.model');
const { User, PUBLIC_USER_FIELDS, publicUser } = require('../utils/user_model');
const { auth, getUserId, asyncHandler } = require('../utils/helpers');
const { loadTaskWithAccess } = require('../utils/permission');

const router = express.Router({ mergeParams: true });
router.use(auth);

router.get('/', asyncHandler(async (req, res) => {
  const { task } = await loadTaskWithAccess(req.params.id, getUserId(req), 'canView');
  const activities = await TaskActivity.find({ taskId: task._id }).sort({ createdAt: -1 }).limit(200).lean();

  // Lấy thông tin người thực hiện + người được nhắc tới trong details
  const ids = new Set();
  for (const a of activities) {
    ids.add(String(a.userId));
    const d = a.details || {};
    if (d.userId) ids.add(String(d.userId));
    (d.userIds || []).forEach((u) => ids.add(String(u)));
  }
  const users = await User.find({ _id: { $in: [...ids] } }).select(PUBLIC_USER_FIELDS).lean();
  const map = Object.fromEntries(users.map((u) => [String(u._id), publicUser(u)]));

  res.json(activities.map((a) => ({
    ...a,
    user: map[String(a.userId)] || null,
    relatedUsers: [
      ...((a.details && a.details.userIds) || []),
      ...((a.details && a.details.userId) ? [a.details.userId] : []),
    ].map((id) => map[String(id)]).filter(Boolean),
  })));
}));

module.exports = router;
