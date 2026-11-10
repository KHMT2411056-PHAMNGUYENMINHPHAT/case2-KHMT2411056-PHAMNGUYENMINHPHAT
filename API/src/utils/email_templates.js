// Mẫu email HTML đơn giản cho các sự kiện công việc
const APP = () => process.env.APP_NAME || 'Task Manager';

const escapeHtml = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const fmtDate = (d) => (d
  ? new Date(d).toLocaleString('vi-VN', { timeZone: process.env.TZ_DISPLAY || 'Asia/Ho_Chi_Minh' })
  : 'Chưa đặt');

const STATUS = { todo: 'Chưa thực hiện', in_progress: 'Đang thực hiện', completed: 'Đã hoàn thành' };
const PRIORITY = { low: 'Thấp', medium: 'Trung bình', high: 'Cao' };
const PERMISSION = { viewer: 'Chỉ xem', editor: 'Chỉnh sửa' };
const FIELD = {
  title: 'Tên công việc', description: 'Mô tả', startDate: 'Ngày bắt đầu',
  dueDate: 'Hạn hoàn thành', priority: 'Mức ưu tiên',
};

function fieldValue(key, value) {
  if (key === 'startDate' || key === 'dueDate') return fmtDate(value);
  if (key === 'priority') return PRIORITY[value] || value;
  return value || '(trống)';
}

function taskBox(task) {
  return `
  <table style="border-collapse:collapse;width:100%;margin:12px 0;font-size:14px">
    <tr><td style="padding:6px;color:#666;width:140px">Công việc</td><td style="padding:6px"><b>${escapeHtml(task.title)}</b></td></tr>
    <tr><td style="padding:6px;color:#666">Trạng thái</td><td style="padding:6px">${STATUS[task.status] || task.status}</td></tr>
    <tr><td style="padding:6px;color:#666">Ưu tiên</td><td style="padding:6px">${PRIORITY[task.priority] || task.priority}</td></tr>
    <tr><td style="padding:6px;color:#666">Hạn hoàn thành</td><td style="padding:6px">${fmtDate(task.dueDate)}</td></tr>
  </table>`;
}

function layout(heading, bodyHtml) {
  return `<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;background:#f4f5f7;padding:20px">
  <div style="max-width:560px;margin:auto;background:#fff;border-radius:8px;padding:24px">
    <h2 style="margin-top:0;color:#3f51b5">${escapeHtml(heading)}</h2>
    ${bodyHtml}
    <p style="color:#888;font-size:12px;margin-top:24px">Mở ứng dụng ${escapeHtml(APP())} để xem chi tiết.
    Email được gửi tự động, vui lòng không trả lời.</p>
  </div></body></html>`;
}

const templates = {
  taskAssigned({ task, actorName }) {
    const subject = `[${APP()}] Bạn được giao công việc: ${task.title}`;
    const html = layout('Bạn có công việc mới', `
      <p><b>${escapeHtml(actorName)}</b> đã giao cho bạn một công việc.</p>${taskBox(task)}`);
    return { subject, html, text: `${actorName} đã giao cho bạn công việc "${task.title}". Hạn: ${fmtDate(task.dueDate)}` };
  },

  taskShared({ task, actorName, permission }) {
    const subject = `[${APP()}] ${actorName} đã chia sẻ công việc với bạn`;
    const html = layout('Bạn được mời tham gia công việc', `
      <p><b>${escapeHtml(actorName)}</b> đã chia sẻ công việc với bạn với quyền
      <b>${PERMISSION[permission] || permission}</b>.</p>${taskBox(task)}`);
    return { subject, html, text: `${actorName} đã chia sẻ công việc "${task.title}" (quyền: ${PERMISSION[permission]})` };
  },

  taskUpdated({ task, actorName, changes }) {
    const rows = Object.entries(changes).map(([k, c]) => `
      <tr><td style="padding:6px;color:#666">${FIELD[k] || k}</td>
      <td style="padding:6px"><s style="color:#999">${escapeHtml(fieldValue(k, c.from))}</s> → <b>${escapeHtml(fieldValue(k, c.to))}</b></td></tr>`).join('');
    const subject = changes.dueDate
      ? `[${APP()}] Hạn hoàn thành thay đổi: ${task.title}`
      : `[${APP()}] Công việc được cập nhật: ${task.title}`;
    const html = layout('Thông tin công việc đã thay đổi', `
      <p><b>${escapeHtml(actorName)}</b> đã cập nhật công việc <b>${escapeHtml(task.title)}</b>:</p>
      <table style="border-collapse:collapse;width:100%;font-size:14px">${rows}</table>`);
    return { subject, html, text: `${actorName} đã cập nhật công việc "${task.title}"` };
  },

  taskCompleted({ task, actorName }) {
    const subject = `[${APP()}] Công việc đã hoàn thành: ${task.title}`;
    const html = layout('Công việc đã hoàn thành 🎉', `
      <p><b>${escapeHtml(actorName)}</b> đã đánh dấu hoàn thành công việc.</p>${taskBox(task)}`);
    return { subject, html, text: `${actorName} đã hoàn thành công việc "${task.title}"` };
  },

  dueReminder({ task, hours }) {
    const subject = `[${APP()}] Nhắc việc: "${task.title}" sắp đến hạn`;
    const html = layout('Công việc sắp đến hạn', `
      <p>Công việc của bạn sẽ đến hạn trong khoảng <b>${hours} giờ</b> tới.</p>${taskBox(task)}`);
    return { subject, html, text: `Công việc "${task.title}" sẽ đến hạn lúc ${fmtDate(task.dueDate)}` };
  },
};

module.exports = { templates, fmtDate, STATUS, PERMISSION };
