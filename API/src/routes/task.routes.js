// Bản cập nhật task.routes.js cho PHẦN C:
// giữ nguyên chức năng phần B (CRUD, tìm kiếm, lọc, sắp xếp) và thêm
// kiểm tra quyền owner / assignee / editor / viewer + công việc được chia sẻ.
const express = require('express');
const Task = require('../models/task.model');
const TaskShare = require('../models/task_share.model');
const TaskActivity = require('../models/task_activity.model');
const { User, PUBLIC_USER_FIELDS, publicUser } = require('../utils/user_model');
const {
  auth, getUserId, HttpError, asyncHandler, isValidId, escapeRegex, toUniqueArray,
} = require('../utils/helpers');
const { getTaskAccess, loadTaskWithAccess, buildAccessFilter } = require('../utils/permission');
const { logActivity } = require('../utils/activity');
const events = require('../services/task_event.service');

const router = express.Router();
router.use(auth);

const STATUSES = ['todo', 'in_progress', 'completed'];
const PRIORITIES = ['low', 'medium', 'high'];
const PRIORITY_RANK = { low: 1, medium: 2, high: 3 };

// Tương thích phần B: chấp nhận cả giá trị cũ (Pending/InProgress/Completed, Low/Medium/High)
const LEGACY_STATUS = { pending: 'todo', inprogress: 'in_progress', 'in progress': 'in_progress' };
function normStatus(v) {
  if (v === undefined || v === null || v === '') return v;
  const s = String(v).trim().toLowerCase();
  return LEGACY_STATUS[s] || s;
}
function normPriority(v) {
  if (v === undefined || v === null || v === '') return v;
  return String(v).trim().toLowerCase();
}

// Chuyển giá trị ngày: undefined = không gửi, null/'' = xóa ngày, sai định dạng = lỗi 400
function parseDate(value, label) {
  if (value === undefined) return undefined;
  if (value === null || value === '') return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) throw new HttpError(400, `${label} không hợp lệ`);
  return d;
}

function checkDates(startDate, dueDate) {
  if (startDate && dueDate && dueDate < startDate) {
    throw new HttpError(400, 'Hạn hoàn thành phải sau hoặc bằng ngày bắt đầu');
  }
}

const sameValue = (a, b) => {
  if (a instanceof Date || b instanceof Date) {
    return (a ? new Date(a).getTime() : null) === (b ? new Date(b).getTime() : null);
  }
  return String(a ?? '') === String(b ?? '');
};

// ------------------------------------------------------------------
// GET /api/tasks?scope=all|created|assigned|delegated|shared|primary
//               &status=&priority=&q=&assignee=&sortBy=dueDate|priority|createdAt&order=asc|desc
// ------------------------------------------------------------------
router.get('/', asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  const { scope = 'all', q, assignee, sortBy = 'createdAt', order } = req.query;
  const status = normStatus(req.query.status);
  const priority = normPriority(req.query.priority);
  const { filter: accessFilter, shareMap, sharedIds } = await buildAccessFilter(userId);

  let scopeFilter;
  switch (scope) {
    case 'created': scopeFilter = { createdBy: userId }; break;
    case 'assigned': // được giao cho tôi (được nhận)
    case 'received':
      scopeFilter = { $or: [{ assigneeIds: userId }, { primaryAssigneeId: userId }] }; break;
    case 'delegated': // tôi tạo và đã giao cho người khác
      scopeFilter = { createdBy: userId, 'assigneeIds.0': { $exists: true } }; break;
    case 'primary': scopeFilter = { primaryAssigneeId: userId }; break;
    case 'shared': scopeFilter = { _id: { $in: sharedIds } }; break;
    default: scopeFilter = accessFilter;
  }

  const and = [accessFilter, scopeFilter];
  if (status && STATUSES.includes(status)) and.push({ status });
  if (priority && PRIORITIES.includes(priority)) and.push({ priority });
  if (q && String(q).trim()) and.push({ title: { $regex: escapeRegex(String(q).trim()), $options: 'i' } });
  if (assignee && isValidId(String(assignee))) {
    and.push({ $or: [{ assigneeIds: assignee }, { primaryAssigneeId: assignee }] });
  }

  const tasks = await Task.find({ $and: and }).lean();

  // Sắp xếp (làm bằng JS để sắp xếp ưu tiên đúng thứ tự low < medium < high)
  const defaultOrder = sortBy === 'dueDate' ? 'asc' : 'desc';
  const dir = (order || defaultOrder) === 'asc' ? 1 : -1;
  tasks.sort((a, b) => {
    if (sortBy === 'priority') {
      return dir * ((PRIORITY_RANK[a.priority] || 0) - (PRIORITY_RANK[b.priority] || 0));
    }
    if (sortBy === 'dueDate') {
      if (!a.dueDate && !b.dueDate) return 0;
      if (!a.dueDate) return 1; // không có hạn luôn nằm cuối
      if (!b.dueDate) return -1;
      return dir * (new Date(a.dueDate) - new Date(b.dueDate));
    }
    return dir * (new Date(a.createdAt) - new Date(b.createdAt));
  });

  // Gắn vai trò của tôi với từng công việc (phân loại theo vai trò)
  const result = [];
  for (const t of tasks) {
    const access = await getTaskAccess(t, userId, shareMap);
    result.push({ ...t, myRole: access.role, sharePermission: access.sharePermission });
  }
  res.json(result);
}));

// ------------------------------------------------------------------
// POST /api/tasks  — tạo công việc
// ------------------------------------------------------------------
router.post('/', asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  const { title, description, category } = req.body;
  const priority = normPriority(req.body.priority);
  const status = normStatus(req.body.status);
  if (!title || !String(title).trim()) throw new HttpError(400, 'Vui lòng nhập tên công việc');
  if (priority && !PRIORITIES.includes(priority)) throw new HttpError(400, 'Mức ưu tiên không hợp lệ');
  if (status && !STATUSES.includes(status)) throw new HttpError(400, 'Trạng thái không hợp lệ');

  const startDate = parseDate(req.body.startDate, 'Ngày bắt đầu');
  const dueDate = parseDate(req.body.dueDate, 'Hạn hoàn thành');
  checkDates(startDate, dueDate);

  // Cho phép giao việc ngay khi tạo (không bắt buộc)
  let assigneeIds = toUniqueArray(req.body.assigneeIds).filter(isValidId);
  if (assigneeIds.length) {
    const found = await User.find({ _id: { $in: assigneeIds } }).select('_id').lean();
    assigneeIds = found.map((u) => String(u._id));
  }
  let primaryAssigneeId = req.body.primaryAssigneeId ? String(req.body.primaryAssigneeId) : null;
  if (primaryAssigneeId && !assigneeIds.includes(primaryAssigneeId)) primaryAssigneeId = null;
  if (!primaryAssigneeId && assigneeIds.length) primaryAssigneeId = assigneeIds[0];

  const task = await Task.create({
    title: String(title).trim(),
    description: description ? String(description).trim() : '',
    ...(category ? { category: String(category).trim() } : {}),
    createdBy: userId,
    assigneeIds,
    primaryAssigneeId,
    startDate: startDate ?? null,
    dueDate: dueDate ?? null,
    priority: priority || 'medium',
    status: status || 'todo',
    completedAt: status === 'completed' ? new Date() : null,
  });

  await logActivity(task._id, userId, 'created', { title: task.title });
  if (assigneeIds.length) {
    await logActivity(task._id, userId, 'assigned', { userIds: assigneeIds });
    events.onAssigned(task, assigneeIds, userId).catch(console.error);
  }
  res.status(201).json({ ...task.toObject(), myRole: 'owner' });
}));

// ------------------------------------------------------------------
// GET /api/tasks/:id — chi tiết (kèm người tạo, người được giao, quyền của tôi)
// ------------------------------------------------------------------
router.get('/:id', asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  const { task, access } = await loadTaskWithAccess(req.params.id, userId, 'canView');

  const [creator, assignees, shareCount] = await Promise.all([
    User.findById(task.createdBy).select(PUBLIC_USER_FIELDS).lean(),
    User.find({ _id: { $in: task.assigneeIds } }).select(PUBLIC_USER_FIELDS).lean(),
    TaskShare.countDocuments({ taskId: task._id }),
  ]);
  const primary = assignees.find((u) => String(u._id) === String(task.primaryAssigneeId));

  res.json({
    ...task.toObject(),
    myRole: access.role,
    access,
    creator: publicUser(creator),
    assignees: assignees.map(publicUser),
    primaryAssignee: publicUser(primary),
    shareCount,
  });
}));

// ------------------------------------------------------------------
// PUT /api/tasks/:id — sửa thông tin (owner hoặc editor)
// ------------------------------------------------------------------
router.put('/:id', asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  const { task, access } = await loadTaskWithAccess(req.params.id, userId, 'canEdit');
  const body = { ...req.body };
  if (body.status !== undefined) body.status = normStatus(body.status);
  if (body.priority !== undefined) body.priority = normPriority(body.priority);

  const updates = {};
  if (body.category !== undefined) updates.category = String(body.category || '').trim() || 'Other';
  if (body.title !== undefined) {
    if (!String(body.title).trim()) throw new HttpError(400, 'Tên công việc không được để trống');
    updates.title = String(body.title).trim();
  }
  if (body.description !== undefined) updates.description = String(body.description || '').trim();
  if (body.priority !== undefined) {
    if (!PRIORITIES.includes(body.priority)) throw new HttpError(400, 'Mức ưu tiên không hợp lệ');
    updates.priority = body.priority;
  }
  if (body.status !== undefined) {
    if (!STATUSES.includes(body.status)) throw new HttpError(400, 'Trạng thái không hợp lệ');
    updates.status = body.status;
  }
  const startDate = parseDate(body.startDate, 'Ngày bắt đầu');
  const dueDate = parseDate(body.dueDate, 'Hạn hoàn thành');
  if (startDate !== undefined) updates.startDate = startDate;
  if (dueDate !== undefined) updates.dueDate = dueDate;
  checkDates(
    updates.startDate !== undefined ? updates.startDate : task.startDate,
    updates.dueDate !== undefined ? updates.dueDate : task.dueDate
  );

  // Ghi nhận thay đổi
  const changes = {};
  for (const [key, value] of Object.entries(updates)) {
    if (!sameValue(task[key], value)) changes[key] = { from: task[key], to: value };
  }
  if (!Object.keys(changes).length) {
    return res.json({ ...task.toObject(), myRole: access.role });
  }

  const oldStatus = task.status;
  Object.assign(task, updates);
  if (changes.dueDate) task.reminderSentAt = null; // đổi hạn -> cho phép nhắc lại
  if (changes.status) task.completedAt = task.status === 'completed' ? new Date() : null;
  await task.save();

  await logActivity(task._id, userId, 'updated', { changes });
  const important = ['title', 'dueDate', 'startDate', 'priority', 'description'].filter((k) => changes[k]);
  if (important.length) {
    const subset = Object.fromEntries(important.map((k) => [k, changes[k]]));
    events.onImportantChange(task, subset, userId).catch(console.error);
  }
  if (changes.status) {
    await logActivity(task._id, userId, 'status_changed', { from: oldStatus, to: task.status });
    events.onStatusChanged(task, oldStatus, task.status, userId).catch(console.error);
  }
  res.json({ ...task.toObject(), myRole: access.role });
}));

// ------------------------------------------------------------------
// PATCH /api/tasks/:id/status — owner, người được giao, editor
// ------------------------------------------------------------------
router.patch('/:id/status', asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  const status = normStatus(req.body.status);
  if (!STATUSES.includes(status)) throw new HttpError(400, 'Trạng thái không hợp lệ');
  const { task, access } = await loadTaskWithAccess(req.params.id, userId, 'canUpdateStatus');

  const oldStatus = task.status;
  if (oldStatus !== status) {
    task.status = status;
    task.completedAt = status === 'completed' ? new Date() : null;
    await task.save();
    await logActivity(task._id, userId, 'status_changed', { from: oldStatus, to: status });
    events.onStatusChanged(task, oldStatus, status, userId).catch(console.error);
  }
  res.json({ ...task.toObject(), myRole: access.role });
}));

// ------------------------------------------------------------------
// DELETE /api/tasks/:id — chỉ người tạo
// ------------------------------------------------------------------
router.delete('/:id', asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  const { task } = await loadTaskWithAccess(req.params.id, userId, 'canDelete');
  await Promise.all([
    TaskShare.deleteMany({ taskId: task._id }),
    TaskActivity.deleteMany({ taskId: task._id }),
    task.deleteOne(),
  ]);
  res.json({ message: 'Đã xóa công việc' });
}));

module.exports = router;
