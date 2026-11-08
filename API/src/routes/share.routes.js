// /api/tasks/:id/shares — chia sẻ & phân quyền viewer/editor
const express = require('express');
const TaskShare = require('../models/task_share.model');
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

const PERMISSIONS = ['viewer', 'editor'];

async function shareList(taskId) {
  const shares = await TaskShare.find({ taskId }).sort({ createdAt: 1 }).lean();
  const ids = [...new Set(shares.flatMap((s) => [String(s.userId), String(s.sharedBy)]))];
  const users = await User.find({ _id: { $in: ids } }).select(PUBLIC_USER_FIELDS).lean();
  const map = new Map(users.map((u) => [String(u._id), publicUser(u)]));
  return shares
    .filter((s) => map.has(String(s.userId)))
    .map((s) => ({
      _id: s._id,
      taskId: s.taskId,
      permission: s.permission,
      user: map.get(String(s.userId)),
      sharedBy: map.get(String(s.sharedBy)) || null,
      createdAt: s.createdAt,
    }));
}

// GET — danh sách người được chia sẻ
router.get('/', asyncHandler(async (req, res) => {
  const { task } = await loadTaskWithAccess(req.params.id, getUserId(req), 'canView');
  res.json(await shareList(task._id));
}));

// POST — chia sẻ cho nhiều người. body: { userIds?: [], emails?: [], permission: 'viewer'|'editor' }
router.post('/', asyncHandler(async (req, res) => {
  const actorId = getUserId(req);
  const { task } = await loadTaskWithAccess(req.params.id, actorId, 'canManageShares');

  const permission = req.body.permission || 'viewer';
  if (!PERMISSIONS.includes(permission)) throw new HttpError(400, 'Quyền phải là viewer hoặc editor');

  const userIds = toUniqueArray(req.body.userIds).filter(isValidId);
  const emails = toUniqueArray(req.body.emails).map((e) => e.toLowerCase()).filter(isEmail);
  if (!userIds.length && !emails.length) throw new HttpError(400, 'Vui lòng chọn người để chia sẻ');

  const or = [];
  if (userIds.length) or.push({ _id: { $in: userIds } });
  // auth.routes.js lưu email nguyên dạng (có thể có chữ hoa) -> so khớp không phân biệt hoa thường
  if (emails.length) {
    or.push({ email: { $in: emails.map((e) => new RegExp(`^${escapeRegex(e)}$`, 'i')) } });
  }
  const found = await User.find({ $or: or }).select('_id email').lean();
  const foundEmails = new Set(found.map((u) => String(u.email).toLowerCase()));
  const notFoundEmails = emails.filter((e) => !foundEmails.has(e));

  const created = [];
  let updated = 0;
  for (const u of found) {
    const uid = String(u._id);
    if (uid === String(task.createdBy)) continue; // không chia sẻ cho chính người tạo
    const existing = await TaskShare.findOne({ taskId: task._id, userId: uid });
    if (existing) {
      if (existing.permission !== permission) {
        existing.permission = permission;
        await existing.save();
        updated += 1;
      }
    } else {
      await TaskShare.create({ taskId: task._id, userId: uid, permission, sharedBy: actorId });
      created.push(uid);
    }
  }

  if (created.length) {
    await logActivity(task._id, actorId, 'shared', { userIds: created, permission });
    events.onShared(task, created, permission, actorId).catch(console.error);
  }

  let message = `Đã chia sẻ cho ${created.length} người`;
  if (updated) message += `, cập nhật quyền ${updated} người`;
  if (notFoundEmails.length) message += `. Không tìm thấy tài khoản: ${notFoundEmails.join(', ')}`;

  res.json({ message, added: created.length, updated, notFoundEmails, shares: await shareList(task._id) });
}));

// PATCH /:shareId — đổi quyền. body: { permission }
router.patch('/:shareId', asyncHandler(async (req, res) => {
  const actorId = getUserId(req);
  requireValidId(req.params.shareId, 'Mã chia sẻ');
  const { task } = await loadTaskWithAccess(req.params.id, actorId, 'canManageShares');
  const { permission } = req.body;
  if (!PERMISSIONS.includes(permission)) throw new HttpError(400, 'Quyền phải là viewer hoặc editor');

  const share = await TaskShare.findOne({ _id: req.params.shareId, taskId: task._id });
  if (!share) throw new HttpError(404, 'Không tìm thấy bản ghi chia sẻ');
  const from = share.permission;
  if (from !== permission) {
    share.permission = permission;
    await share.save();
    await logActivity(task._id, actorId, 'share_permission_changed', {
      userId: String(share.userId), from, to: permission,
    });
    events.onSharePermissionChanged(task, String(share.userId), permission, actorId).catch(console.error);
  }
  res.json({ message: 'Đã thay đổi quyền', shares: await shareList(task._id) });
}));

// DELETE /:shareId — thu hồi quyền
router.delete('/:shareId', asyncHandler(async (req, res) => {
  const actorId = getUserId(req);
  requireValidId(req.params.shareId, 'Mã chia sẻ');
  const { task } = await loadTaskWithAccess(req.params.id, actorId, 'canManageShares');

  const share = await TaskShare.findOneAndDelete({ _id: req.params.shareId, taskId: task._id });
  if (!share) throw new HttpError(404, 'Không tìm thấy bản ghi chia sẻ');

  await logActivity(task._id, actorId, 'share_revoked', { userId: String(share.userId) });
  events.onShareRevoked(task, String(share.userId), actorId).catch(console.error);
  res.json({ message: 'Đã thu hồi quyền truy cập', shares: await shareList(task._id) });
}));

module.exports = router;
