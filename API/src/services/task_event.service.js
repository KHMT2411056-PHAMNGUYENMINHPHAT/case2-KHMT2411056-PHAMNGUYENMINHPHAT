// PHẦN D: bản đầy đủ — tạo thông báo trong ứng dụng + gửi email cho từng sự kiện.
// (Thay thế file rỗng của phần C; các route đã gọi sẵn các hàm này.)
const TaskShare = require('../models/task_share.model');
const { User } = require('../utils/user_model');
const { notifyUsers } = require('./notification.service');
const { queueEmail } = require('./email.service');
const { templates, STATUS, PERMISSION } = require('../utils/email_templates');

const REMINDER_HOURS = () => Number(process.env.REMINDER_HOURS || 24);

async function actorName(actorId) {
  if (!actorId) return 'Hệ thống';
  const u = await User.findById(actorId).select('fullName name email').lean();
  return u ? (u.fullName || u.name || u.email) : 'Một người dùng';
}

async function usersByIds(ids) {
  const unique = [...new Set((ids || []).map(String))];
  if (!unique.length) return [];
  return User.find({ _id: { $in: unique } }).select('email fullName name').lean();
}

/** Tất cả người liên quan: người tạo + người được giao + người được chia sẻ (trừ người thực hiện) */
async function participantIds(task, excludeId) {
  const shares = await TaskShare.find({ taskId: task._id }).select('userId').lean();
  const ids = [
    String(task.createdBy),
    ...(task.assigneeIds || []).map(String),
    ...shares.map((s) => String(s.userId)),
  ];
  return [...new Set(ids)].filter((id) => id && id !== String(excludeId || ''));
}

async function emailUsers(userIds, task, eventType, mail) {
  const users = await usersByIds(userIds);
  await Promise.all(users.map((u) => queueEmail({
    to: u.email, taskId: task._id, eventType, subject: mail.subject, html: mail.html, text: mail.text,
  })));
}

// ---- 1. Giao việc mới -> thông báo + email cho người được giao ----
async function onAssigned(task, userIds, actorId) {
  const targets = (userIds || []).map(String).filter((id) => id !== String(actorId));
  if (!targets.length) return;
  const name = await actorName(actorId);
  await notifyUsers(targets, {
    taskId: task._id,
    type: 'task_assigned',
    title: 'Bạn được giao công việc mới',
    message: `${name} đã giao cho bạn: "${task.title}"`,
  });
  await emailUsers(targets, task, 'task_assigned', templates.taskAssigned({ task, actorName: name }));
}

async function onUnassigned(task, userId, actorId) {
  if (String(userId) === String(actorId)) return;
  const name = await actorName(actorId);
  await notifyUsers([userId], {
    taskId: task._id,
    type: 'task_unassigned',
    title: 'Bạn không còn được giao công việc',
    message: `${name} đã hủy giao "${task.title}" cho bạn`,
  });
}

// ---- 2. Chia sẻ / mời tham gia -> thông báo + email ----
async function onShared(task, userIds, permission, actorId) {
  const targets = (userIds || []).map(String).filter((id) => id !== String(actorId));
  if (!targets.length) return;
  const name = await actorName(actorId);
  await notifyUsers(targets, {
    taskId: task._id,
    type: 'task_shared',
    title: 'Bạn được chia sẻ một công việc',
    message: `${name} đã chia sẻ "${task.title}" (quyền: ${PERMISSION[permission]})`,
  });
  await emailUsers(targets, task, 'task_shared', templates.taskShared({ task, actorName: name, permission }));
}

async function onSharePermissionChanged(task, userId, permission, actorId) {
  const name = await actorName(actorId);
  await notifyUsers([userId], {
    taskId: task._id,
    type: 'share_permission_changed',
    title: 'Quyền truy cập đã thay đổi',
    message: `${name} đã đổi quyền của bạn trên "${task.title}" thành ${PERMISSION[permission]}`,
  });
}

async function onShareRevoked(task, userId, actorId) {
  const name = await actorName(actorId);
  await notifyUsers([userId], {
    taskId: null, // không còn quyền mở công việc
    type: 'share_revoked',
    title: 'Quyền truy cập đã bị thu hồi',
    message: `${name} đã thu hồi quyền của bạn trên "${task.title}"`,
  });
}

// ---- 3. Hạn hoàn thành / thông tin quan trọng thay đổi -> thông báo + email ----
async function onImportantChange(task, changes, actorId) {
  const targets = await participantIds(task, actorId);
  if (!targets.length) return;
  const name = await actorName(actorId);
  const isDue = Boolean(changes.dueDate);
  await notifyUsers(targets, {
    taskId: task._id,
    type: 'task_updated',
    title: isDue ? 'Hạn hoàn thành đã thay đổi' : 'Công việc được cập nhật',
    message: `${name} đã cập nhật "${task.title}"`,
  });
  await emailUsers(targets, task, 'task_updated', templates.taskUpdated({ task, actorName: name, changes }));
}

// ---- 4. Đổi trạng thái; hoàn thành -> gửi email ----
async function onStatusChanged(task, from, to, actorId) {
  const targets = await participantIds(task, actorId);
  if (!targets.length) return;
  const name = await actorName(actorId);
  if (to === 'completed') {
    await notifyUsers(targets, {
      taskId: task._id,
      type: 'task_completed',
      title: 'Công việc đã hoàn thành',
      message: `${name} đã hoàn thành "${task.title}"`,
    });
    await emailUsers(targets, task, 'task_completed', templates.taskCompleted({ task, actorName: name }));
  } else {
    await notifyUsers(targets, {
      taskId: task._id,
      type: 'status_changed',
      title: 'Trạng thái công việc thay đổi',
      message: `${name}: "${task.title}" ${STATUS[from]} → ${STATUS[to]}`,
    });
  }
}

// ---- 5. Nhắc việc trước hạn (gọi từ jobs/reminder.job.js) ----
async function onReminder(task) {
  // Nhắc người được giao; nếu chưa giao ai thì nhắc người tạo
  const targets = task.assigneeIds && task.assigneeIds.length
    ? task.assigneeIds.map(String)
    : [String(task.createdBy)];
  const hours = REMINDER_HOURS();
  await notifyUsers(targets, {
    taskId: task._id,
    type: 'due_reminder',
    title: 'Công việc sắp đến hạn',
    message: `"${task.title}" sẽ đến hạn trong ${hours} giờ tới`,
  });
  await emailUsers(targets, task, 'due_reminder', templates.dueReminder({ task, hours }));
}

module.exports = {
  onAssigned, onUnassigned, onShared, onSharePermissionChanged,
  onShareRevoked, onImportantChange, onStatusChanged, onReminder,
};
