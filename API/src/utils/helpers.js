const mongoose = require('mongoose');

// ---- Lấy middleware xác thực đã viết ở phần A (auth.middleware.js) ----
// Hỗ trợ: module.exports = fn  hoặc  module.exports = { protect } / { auth } / { verifyToken } ...
const authModule = require('../middleware/auth.middleware');
const auth = typeof authModule === 'function'
  ? authModule
  : (authModule.protect || authModule.auth || authModule.authMiddleware ||
     authModule.verifyToken || authModule.authenticate || authModule.requireAuth);

if (typeof auth !== 'function') {
  throw new Error('Không tìm thấy hàm middleware trong src/middleware/auth.middleware.js');
}

// Lấy id người dùng đăng nhập, hỗ trợ nhiều cách đặt tên trong middleware
function getUserId(req) {
  const u = req.user || {};
  const id = u._id || u.id || u.userId || req.userId;
  return id ? String(id) : null;
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// Bọc route async: lỗi có status -> trả message; lỗi khác -> 500 không lộ chi tiết
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch((err) => {
    if (err instanceof HttpError) {
      return res.status(err.status).json({ message: err.message });
    }
    if (err && err.name === 'ValidationError') {
      return res.status(400).json({ message: 'Dữ liệu không hợp lệ' });
    }
    if (err && err.code === 11000) {
      return res.status(409).json({ message: 'Dữ liệu bị trùng' });
    }
    console.error(err);
    return res.status(500).json({ message: 'Lỗi máy chủ, vui lòng thử lại' });
  });

const isValidId = (id) => typeof id === 'string' && mongoose.Types.ObjectId.isValid(id) && /^[a-f\d]{24}$/i.test(id);

function requireValidId(id, label = 'id') {
  if (!isValidId(String(id || ''))) throw new HttpError(400, `${label} không hợp lệ`);
}

const escapeRegex = (s) => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const isEmail = (s) => typeof s === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s.trim());

// Chuẩn hóa mảng: nhận mảng hoặc 1 giá trị, bỏ rỗng, bỏ trùng
function toUniqueArray(value) {
  if (value === undefined || value === null || value === '') return [];
  const arr = Array.isArray(value) ? value : [value];
  return [...new Set(arr.map((v) => String(v).trim()).filter(Boolean))];
}

module.exports = {
  auth, getUserId, HttpError, asyncHandler,
  isValidId, requireValidId, escapeRegex, isEmail, toUniqueArray,
};
