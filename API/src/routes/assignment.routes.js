// /api/tasks/:id/assignees — giao việc, chỉ định người phụ trách chính
const express = require('express');
const { User, PUBLIC_USER_FIELDS, publicUser } = require('../utils/user_model');
const {
  auth, getUserId, HttpError, asyncHandler, isValidId, isEmail, toUniqueArray, requireValidId,
  escapeRegex,
} = require('../utils/helpers');
const { loadTaskWithAccess } = require('../utils/permission');
const { logActivity } = require('../utils/activity');
const events = require('../services/task_event.service');

const router = express.Router({ mergeParams: true });
router.use(auth);

async function assigneeList(task) {
  const users = await User.find({ _id: { $in: task.assigneeIds } }).select(PUBLIC_USER_FIELDS).lean();
  return users.map((u) => ({
    ...publicUser(u),
    isPrimary: String(u._id) === String(task.primaryAssigneeId),
  }));
}

// GET — danh sách người được giao (ai xem được công việc thì xem được danh sách)
router.get('/', asyncHandler(async (req, res) => {
  const { task } = await loadTaskWithAccess(req.params.id, getUserId(req), 'canView');
  res.json({
    primaryAssigneeId: task.primaryAssigneeId,
    assignees: await assigneeList(task),
  });
}));

// POST — giao cho 1 hoặc nhiều người qua userIds và/hoặc emails
// body: { userIds?: [], emails?: [], primaryAssigneeId?: "" }
router.post('/', asyncHandler(async (req, res) => {
  const actorId = getUserId(req);
  const { task } = await loadTaskWithAccess(req.params.id, actorId, 'canAssign');

  const userIds = toUniqueArray(req.body.userIds).filter(isValidId);
  const emails = toUniqueArray(req.body.emails).map((e) => e.toLowerCase()).filter(isEmail);
  const primaryAssigneeId = req.body.primaryAssigneeId ? String(req.body.primaryAssigneeId) : null;

  if (!userIds.length && !emails.length && !primaryAssigneeId) {
    throw new HttpError(400, 'Vui lòng chọn ít nhất một người để giao việc');
  }

  // Tìm user theo id + email
  const or = [];
  if (userIds.length) or.push({ _id: { $in: userIds } });
  // auth.routes.js lưu email nguyên dạng (có thể có chữ hoa) -> so khớp không phân biệt hoa thường
  if (emails.length) {
    or.push({ email: { $in: emails.map((e) => new RegExp(`^${escapeRegex(e)}$`, 'i')) } });
  }
  const found = or.length ? await User.find({ $or: or }).select('_id email').lean() : [];
  const foundEmails = new Set(found.map((u) => String(u.email).toLowerCase()));
  const notFoundEmails = emails.filter((e) => !foundEmails.has(e));

  const current = new Set(task.assigneeIds.map(String));
  const newIds = found.map((u) => String(u._id)).filter((id) => !current.has(id));
  newIds.forEach((id) => task.assigneeIds.push(id));

  // Người phụ trách chính
  const allIds = task.assigneeIds.map(String);
  let primaryChanged = false;
  if (primaryAssigneeId) {
    if (!allIds.includes(primaryAssigneeId)) {
      throw new HttpError(400, 'Người phụ trách chính phải nằm trong danh sách được giao');
    }
    primaryChanged = String(task.primaryAssigneeId) !== primaryAssigneeId;
    task.primaryAssigneeId = primaryAssigneeId;
  } else if (!task.primaryAssigneeId && allIds.length) {
    task.primaryAssigneeId = allIds[0];
    primaryChanged = true;
  }

  await task.save();

  if (newIds.length) {
    await logActivity(task._id, actorId, 'assigned', { userIds: newIds });
    events.onAssigned(task, newIds, actorId).catch(console.error);
  }
  if (primaryChanged) {
    await logActivity(task._id, actorId, 'primary_changed', { userId: String(task.primaryAssigneeId) });
  }

  let message = newIds.length ? `Đã giao việc cho ${newIds.length} người` : 'Đã cập nhật người phụ trách';
  if (notFoundEmails.length) message += `. Không tìm thấy tài khoản: ${notFoundEmails.join(', ')}`;

  res.json({
    message,
    added: newIds.length,
    notFoundEmails,
    primaryAssigneeId: task.primaryAssigneeId,
    assignees: await assigneeList(task),
  });
}));

// PATCH /:userId — đặt/bỏ người phụ trách chính. body: { isPrimary: true|false }
router.patch('/:userId', asyncHandler(async (req, res) => {
  const actorId = getUserId(req);
  requireValidId(req.params.userId, 'Mã người dùng');
  const { task } = await loadTaskWithAccess(req.params.id, actorId, 'canAssign');
  const target = req.params.userId;

  if (!task.assigneeIds.map(String).includes(target)) {
    throw new HttpError(404, 'Người này chưa được giao công việc');
  }
  const isPrimary = req.body.isPrimary !== false;
  if (isPrimary) task.primaryAssigneeId = target;
  else if (String(task.primaryAssigneeId) === target) task.primaryAssigneeId = null;
  await task.save();

  await logActivity(task._id, actorId, 'primary_changed', { userId: isPrimary ? target : null });
  res.json({
    message: 'Đã cập nhật người phụ trách chính',
    primaryAssigneeId: task.primaryAssigneeId,
    assignees: await assigneeList(task),
  });
}));

// DELETE /:userId — hủy giao việc cho 1 người
router.delete('/:userId', asyncHandler(async (req, res) => {
  const actorId = getUserId(req);
  requireValidId(req.params.userId, 'Mã người dùng');
  const { task } = await loadTaskWithAccess(req.params.id, actorId, 'canAssign');
  const target = req.params.userId;

  if (!task.assigneeIds.map(String).includes(target)) {
    throw new HttpError(404, 'Người này chưa được giao công việc');
  }
  task.assigneeIds = task.assigneeIds.filter((id) => String(id) !== target);
  if (String(task.primaryAssigneeId) === target) {
    task.primaryAssigneeId = task.assigneeIds[0] || null;
  }
  await task.save();

  await logActivity(task._id, actorId, 'unassigned', { userId: target });
  events.onUnassigned(task, target, actorId).catch(console.error);
  res.json({
    message: 'Đã hủy giao việc',
    primaryAssigneeId: task.primaryAssigneeId,
    assignees: await assigneeList(task),
  });
}));

module.exports = router;
