// Lấy model User từ file user.model.js đã có ở phần A.
// Hỗ trợ cả 2 kiểu export: module.exports = User  hoặc  module.exports = { User }
const userModule = require('../models/user.model');

const User = userModule && userModule.modelName
  ? userModule
  : (userModule.User || userModule.default);

if (!User || !User.modelName) {
  throw new Error('Không đọc được model User từ src/models/user.model.js');
}

// Các trường công khai của người dùng (không bao giờ trả passwordHash)
const PUBLIC_USER_FIELDS = 'fullName name email avatarUrl';

function publicUser(u) {
  if (!u) return null;
  return {
    _id: u._id,
    fullName: u.fullName || u.name || '',
    email: u.email,
    avatarUrl: u.avatarUrl || '',
  };
}

module.exports = { User, PUBLIC_USER_FIELDS, publicUser };
