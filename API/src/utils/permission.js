const Task = require('../models/task.model');
const TaskShare = require('../models/task_share.model');
const { HttpError, requireValidId } = require('./helpers');

const idOf = (v) => (v && v._id ? String(v._id) : v ? String(v) : '');

/**
 * Tính quyền của 1 người trên 1 công việc.
 *  - owner (người tạo): toàn quyền
 *  - assignee (người được giao): xem + cập nhật trạng thái
 *  - editor (được chia sẻ quyền sửa): xem + sửa thông tin + trạng thái,
 *    KHÔNG được xóa, KHÔNG giao việc, KHÔNG quản lý chia sẻ
 *  - viewer: chỉ xem
 * Một người vừa được giao vừa được chia sẻ -> lấy quyền cao nhất.
 */
async function getTaskAccess(task, userId, shareCache) {
  const uid = String(userId);
  const isOwner = idOf(task.createdBy) === uid;
  const isPrimary = idOf(task.primaryAssigneeId) === uid;
  const isAssignee = isPrimary || (task.assigneeIds || []).some((a) => idOf(a) === uid);

  let sharePermission = null;
  if (shareCache) {
    sharePermission = shareCache.get(String(task._id)) || null;
  } else if (!isOwner) {
    const share = await TaskShare.findOne({ taskId: task._id, userId: uid }).lean();
    sharePermission = share ? share.permission : null;
  }

  let role = null;
  if (isOwner) role = 'owner';
  else if (isAssignee) role = 'assignee';
  else if (sharePermission === 'editor') role = 'editor';
  else if (sharePermission === 'viewer') role = 'viewer';

  return {
    role,
    isOwner,
    isAssignee,
    isPrimary,
    sharePermission,
    canView: role !== null,
    canEdit: isOwner || sharePermission === 'editor',
    canUpdateStatus: isOwner || isAssignee || sharePermission === 'editor',
    canDelete: isOwner,
    canAssign: isOwner,
    canManageShares: isOwner,
  };
}

/** Tải task + kiểm tra quyền. need = 'canView' | 'canEdit' | 'canDelete' | ... */
async function loadTaskWithAccess(taskId, userId, need = 'canView') {
  requireValidId(taskId, 'Mã công việc');
  const task = await Task.findById(taskId);
  if (!task) throw new HttpError(404, 'Không tìm thấy công việc');
  const access = await getTaskAccess(task, userId);
  if (!access.canView) throw new HttpError(404, 'Không tìm thấy công việc');
  if (!access[need]) throw new HttpError(403, 'Bạn không có quyền thực hiện thao tác này');
  return { task, access };
}

/** Điều kiện lọc mọi công việc người dùng được phép xem */
async function buildAccessFilter(userId) {
  const shares = await TaskShare.find({ userId }).select('taskId permission').lean();
  const shareMap = new Map(shares.map((s) => [String(s.taskId), s.permission]));
  const sharedIds = shares.map((s) => s.taskId);
  return {
    shareMap,
    sharedIds,
    filter: {
      $or: [
        { createdBy: userId },
        { assigneeIds: userId },
        { primaryAssigneeId: userId },
        { _id: { $in: sharedIds } },
      ],
    },
  };
}

module.exports = { getTaskAccess, loadTaskWithAccess, buildAccessFilter, idOf };
