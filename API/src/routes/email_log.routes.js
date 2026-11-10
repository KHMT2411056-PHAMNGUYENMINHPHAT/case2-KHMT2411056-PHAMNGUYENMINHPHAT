// Lịch sử gửi email:
//   GET  /api/tasks/:id/email-logs   (chỉ người tạo công việc)
//   POST /api/email-logs/:id/retry   (chỉ người tạo công việc, tối đa EMAIL_MAX_ATTEMPTS lần)
// Router này mount ở '/api' nên KHÔNG dùng router.use(auth) (tránh chặn /api/auth/login),
// mà gắn auth vào từng route.
const express = require('express');
const EmailLog = require('../models/email_log.model');
const Task = require('../models/task.model');
const { auth, getUserId, asyncHandler, requireValidId, HttpError } = require('../utils/helpers');
const { loadTaskWithAccess } = require('../utils/permission');
const { retryEmail, MAX_ATTEMPTS } = require('../services/email.service');

const router = express.Router();

router.get('/tasks/:id/email-logs', auth, asyncHandler(async (req, res) => {
  const { task } = await loadTaskWithAccess(req.params.id, getUserId(req), 'canManageShares');
  const logs = await EmailLog.find({ taskId: task._id }).sort({ createdAt: -1 }).limit(200).lean();
  res.json({ maxAttempts: MAX_ATTEMPTS, logs });
}));

router.post('/email-logs/:id/retry', auth, asyncHandler(async (req, res) => {
  requireValidId(req.params.id, 'Mã lịch sử email');
  const log = await EmailLog.findById(req.params.id).lean();
  if (!log) throw new HttpError(404, 'Không tìm thấy lịch sử email');

  if (log.taskId) {
    const task = await Task.findById(log.taskId).lean();
    if (!task || String(task.createdBy) !== getUserId(req)) {
      throw new HttpError(403, 'Bạn không có quyền gửi lại email này');
    }
  } else {
    throw new HttpError(403, 'Bạn không có quyền gửi lại email này');
  }

  const result = await retryEmail(log._id);
  if (result.status !== 200) throw new HttpError(result.status, result.message);
  const l = result.log;
  res.json({
    message: result.message,
    ok: result.ok,
    log: l && { _id: l._id, status: l.status, attempts: l.attempts, errorMessage: l.errorMessage, sentAt: l.sentAt },
  });
}));

module.exports = router;
