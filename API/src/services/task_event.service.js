// PHẦN C: các hàm sự kiện để trống.
// Sang PHẦN D, file này được thay bằng bản đầy đủ (tạo thông báo + gửi email).
// Các route ở phần C đã gọi sẵn các hàm này nên phần D không phải sửa route.

async function onAssigned(/* task, userIds, actorId */) {}
async function onUnassigned(/* task, userId, actorId */) {}
async function onShared(/* task, userIds, permission, actorId */) {}
async function onSharePermissionChanged(/* task, userId, permission, actorId */) {}
async function onShareRevoked(/* task, userId, actorId */) {}
async function onImportantChange(/* task, changes, actorId */) {}
async function onStatusChanged(/* task, from, to, actorId */) {}
async function onReminder(/* task */) {}

module.exports = {
  onAssigned, onUnassigned, onShared, onSharePermissionChanged,
  onShareRevoked, onImportantChange, onStatusChanged, onReminder,
};
