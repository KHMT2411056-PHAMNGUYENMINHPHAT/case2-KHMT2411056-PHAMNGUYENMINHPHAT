// /api/statistics — thống kê công việc của người dùng hiện tại
const express = require('express');
const Task = require('../models/task.model');
const { auth, getUserId, asyncHandler } = require('../utils/helpers');
const { buildAccessFilter, idOf } = require('../utils/permission');

const router = express.Router();
router.use(auth);

const emptyStatus = () => ({ todo: 0, in_progress: 0, completed: 0, total: 0 });

function countByStatus(tasks) {
  const r = emptyStatus();
  for (const t of tasks) {
    if (r[t.status] !== undefined) r[t.status] += 1;
    r.total += 1;
  }
  return r;
}

async function accessibleTasks(userId) {
  const { filter, sharedIds } = await buildAccessFilter(userId);
  const tasks = await Task.find(filter)
    .select('title status priority dueDate createdBy assigneeIds primaryAssigneeId createdAt')
    .lean();
  return { tasks, sharedSet: new Set(sharedIds.map(String)) };
}

const brief = (t) => ({
  _id: t._id, title: t.title, status: t.status, priority: t.priority, dueDate: t.dueDate,
});

// GET /api/statistics/tasks — tổng số công việc theo trạng thái (+ theo ưu tiên)
router.get('/tasks', asyncHandler(async (req, res) => {
  const { tasks } = await accessibleTasks(getUserId(req));
  const byPriority = { low: 0, medium: 0, high: 0 };
  tasks.forEach((t) => { if (byPriority[t.priority] !== undefined) byPriority[t.priority] += 1; });
  const byStatus = countByStatus(tasks);
  res.json({
    byStatus,
    byPriority,
    completionRate: byStatus.total ? Math.round((byStatus.completed / byStatus.total) * 100) : 0,
  });
}));

// GET /api/statistics/assignments — việc tôi tạo/giao đi, việc được giao cho tôi, việc tôi phụ trách chính
router.get('/assignments', asyncHandler(async (req, res) => {
  const userId = getUserId(req);
  const { tasks, sharedSet } = await accessibleTasks(userId);

  const created = tasks.filter((t) => idOf(t.createdBy) === userId);
  const delegated = created.filter((t) => (t.assigneeIds || []).some((a) => idOf(a) !== userId));
  const assignedToMe = tasks.filter((t) => (t.assigneeIds || []).some((a) => idOf(a) === userId));
  const primary = tasks.filter((t) => idOf(t.primaryAssigneeId) === userId);
  const shared = tasks.filter((t) => sharedSet.has(String(t._id)));

  res.json({
    created: countByStatus(created), // tôi tạo
    delegated: countByStatus(delegated), // tôi giao cho người khác
    assignedToMe: countByStatus(assignedToMe), // được giao cho tôi
    primary: countByStatus(primary), // tôi đang phụ trách chính
    shared: countByStatus(shared), // được chia sẻ với tôi
  });
}));

// GET /api/statistics/deadlines?days=3 — sắp đến hạn và quá hạn (chưa hoàn thành)
router.get('/deadlines', asyncHandler(async (req, res) => {
  const days = Math.min(Math.max(Number(req.query.days) || 3, 1), 30);
  const { tasks } = await accessibleTasks(getUserId(req));
  const now = Date.now();
  const limit = now + days * 24 * 60 * 60 * 1000;

  const open = tasks.filter((t) => t.status !== 'completed' && t.dueDate);
  const upcoming = open
    .filter((t) => { const d = new Date(t.dueDate).getTime(); return d >= now && d <= limit; })
    .sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate));
  const overdue = open
    .filter((t) => new Date(t.dueDate).getTime() < now)
    .sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate));

  res.json({
    days,
    upcomingCount: upcoming.length,
    overdueCount: overdue.length,
    upcoming: upcoming.slice(0, 20).map(brief),
    overdue: overdue.slice(0, 20).map(brief),
  });
}));

module.exports = router;
